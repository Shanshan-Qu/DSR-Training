# Step 5 — Storage for preservation

_The big one._ 🗄️ This is the lab that maps most directly to your day-to-day work with Rosetta. You'll exercise **Storage Explorer**, **lifecycle tiers**, **soft-delete**, **versioning**, **immutability** (legal hold), and the **change feed**.

> [!NOTE]
> Time: ~120 minutes.
> Pairs with **Module 5** of the training plan.

---

## 🧭 What you'll learn

- How to use **Azure Storage Explorer** end-to-end against the lab account
- The protective features that matter most for preservation: **soft-delete**, **versioning**, **immutability / legal hold**
- How **lifecycle policies** automatically move blobs between Hot / Cool / Cold
- How to use the **change feed** as an audit log
- The three storage account types used in the Rosetta production design (Blob, NFS Premium, SMB Standard)
- Why production storage is **private-link only** and how that differs from the lab
- What **blobfuse2** is and where you'll see it on Rosetta servers
- How **Azure Files share snapshots** protect NFS and SMB shares

---

## 🧩 Concept refresher — the protective stack

Think of these four features as layers of defence for preservation data:

```
┌────────────────────────────────────────────────────────┐
│  Immutability / Legal hold   ← can't change for N days │  Compliance
├────────────────────────────────────────────────────────┤
│  Versioning                  ← every overwrite kept    │  Recovery from edits
├────────────────────────────────────────────────────────┤
│  Soft-delete (blob + container) ← undelete window      │  Recovery from accidents
├────────────────────────────────────────────────────────┤
│  Change feed                 ← audit log of operations │  Forensics
└────────────────────────────────────────────────────────┘
              ↑
        Your blob data
```

You don't need all four for every workload, but **soft-delete + versioning + change feed** is the minimum baseline for a preservation account in my opinion.

| Replication | What it protects against | When to use |
|---|---|---|
| **LRS** — Locally redundant | Disk failure | Lab, dev, ephemeral data |
| **ZRS** — Zone redundant | One AZ outage | Most production |
| **GRS** — Geo redundant | Regional disaster | Long-term archive, irreplaceable data |

> [!IMPORTANT]
> **Lab vs. production:** The lab storage account (`stdialabsXXXX`) uses **LRS** to keep costs low. All Rosetta production accounts — `stanlnznfileprdrosi01/02` and `stanlnznblobprdrosi01` — use **ZRS (Zone Redundant Storage)** to survive a full Availability Zone outage. Never use LRS for preservation data in production.

---

## ⌨️ Activity 1: Connect Storage Explorer

1. Install **Azure Storage Explorer** if you haven't already (free): [https://azure.microsoft.com/en-us/products/storage/storage-explorer](https://azure.microsoft.com/en-us/products/storage/storage-explorer).
2. Open it → sign in with your DIA-issued Azure credential.
3. In the left tree: **Subscriptions → your training sub → Storage Accounts → `stdialabsXXXX` → Blob Containers**.
4. Open `rosetta-objects`. You should see whatever you uploaded in Step 2.

> [!TIP]
> You can also open Storage Explorer **inside the portal** — every storage account has a "Storage browser" blade that's the same tool, no install needed. Use the desktop app for serious work (it's faster and supports drag-and-drop).

---

## ⌨️ Activity 2: Turn on the protective features

In the portal → `stdialabsXXXX` → **Data protection**.

1. **Enable soft delete for blobs**: 14 days.
2. **Enable soft delete for containers**: 14 days.

> [!IMPORTANT]
> **Lab vs. production retention values:** The lab uses 14 days to avoid cost. In production, the Rosetta Blob account (`stanlnznblobprdrosi01`) uses **365 days** for both blob and container soft-delete. Azure Files shares (NFS and SMB) use **31-day soft-delete + 31 days of rolling snapshots**. Always match or exceed these values when you configure storage in production.
3. **Enable versioning for blobs**: on.
4. **Enable change feed**: on. (You can leave the retention default.)
5. **Enable point-in-time restore**: leave OFF for the lab — it requires versioning + change feed + a separate cost.
6. Save.

Wait ~30 seconds for the settings to apply.

---

## ⌨️ Activity 3: Soft-delete in action

1. In Storage Explorer, upload `lab/test-1.txt` to `rosetta-objects`.
2. Delete it.
3. In Storage Explorer, click **Show deleted blobs** (top toolbar). You'll see your file with a deleted-on date and the days remaining in the soft-delete window.
4. Right-click → **Undelete**. Refresh. The file is back.

> [!IMPORTANT]
> Soft-delete is a recovery aid, not a backup. For real backup of preservation data, you still need **Recovery Services vault** (Step 7) — and an **off-region copy** if the data is irreplaceable.

---

## ⌨️ Activity 4: Versioning in action

1. Upload a file `lab/versioned.txt` with the word `v1` inside.
2. Edit the local file → `v2` → upload again to the same name. Choose **Overwrite** when prompted.
3. In Storage Explorer, right-click the blob → **Manage Versions**.
4. You should see two versions. The current one says `v2`; the older one says `v1`.
5. Right-click the `v1` version → **Promote to current**. Refresh — `v1` is now the current version.

This is your safety net for "someone overwrote the manifest by mistake."

---

## ⌨️ Activity 5: Immutability / legal hold

1. Upload `lab/legal-hold.txt`.
2. Right-click the **container** `rosetta-objects` → **Access policy → Immutable blob storage → Add policy**.
3. Type: **Legal hold**. Tag: `dia-archive-2026`.
4. Save.
5. Try to delete `lab/legal-hold.txt`. Storage Explorer will refuse — Azure returns `BlobIsImmutable`.

> [!IMPORTANT]
> Legal holds are designed to be hard to remove. In production, only specific roles can clear them. **Do not enable legal holds in production without an explicit retention requirement** — you can't easily walk it back.

To clean up the lab afterward:

1. Same blade → **Clear legal hold** for tag `dia-archive-2026`.
2. Now you can delete the file.

---

## ⌨️ Activity 6: Read the change feed

The change feed is itself stored in a hidden container called `$blobchangefeed` on the same account.

1. In Storage Explorer, tick **Show hidden containers** (View menu) → reload.
2. Open `$blobchangefeed → log`. You'll see Avro files dated by hour.
3. These are designed for tools like Spark/Synapse to consume — for ad-hoc queries, you can use `Get-AzStorageBlobChangeFeed` in PowerShell:

```powershell
Get-AzStorageAccount -ResourceGroupName rg-dia-azure-labs `
  -Name (Get-AzStorageAccount -ResourceGroupName rg-dia-azure-labs)[0].StorageAccountName |
  Get-AzStorageBlobChangeFeed -Start (Get-Date).AddHours(-1) -End (Get-Date) |
  Select-Object EventType, Subject, EventTime |
  Format-Table
```

You'll see a row per upload / delete / version-create. **This is your audit trail.**

---

## ⌨️ Activity 7: Lifecycle policy — cool tier after 30 days

1. Portal → `stdialabsXXXX` → **Lifecycle management → + Add a rule**.
2. Name: `move-to-cool-30d`.
3. Rule scope: **Limit blobs with filters**.
4. Filter set: `prefixMatch = ["rosetta-objects/"]`, blob type **Block blobs**, subtype **Base blobs**.
5. Base blobs → **More than 30 days since last modified → Move to Cool**.
6. Add another action: **More than 365 days → Move to Cold**.

> [!NOTE]
> **Cold vs. Archive tier:** The production Rosetta Blob account uses **Cold** (not Archive). Cold tier data is online and retrievable immediately at low cost. Archive tier data is offline — retrieval takes up to 15 hours (rehydration). Use Cold for preservation data that must remain accessible; use Archive only for data with known, infrequent access and acceptable retrieval latency.
7. Save.

The portal will show you the JSON it generated. Copy it — you'll keep this with your runbook.

```json
{
  "rules": [
    {
      "enabled": true,
      "name": "move-to-cool-30d",
      "type": "Lifecycle",
      "definition": {
        "actions": {
          "baseBlob": {
            "tierToCool":    { "daysAfterModificationGreaterThan": 30  },
            "tierToCold":    { "daysAfterModificationGreaterThan": 365 }
          }
        },
        "filters": {
          "blobTypes": [ "blockBlob" ],
          "prefixMatch": [ "rosetta-objects/" ]
        }
      }
    }
  ]
}
```

> [!TIP]
> Lifecycle is **free** to define and runs once a day. The only cost is the (one-time) tier-change transaction per blob.

---

---

## 🧩 Production context — Azure Files, Private Endpoints, and blobfuse2

> [!NOTE]
> The following sections are **conceptual** — no hands-on activities because they require resources that can't be replicated in a generic lab subscription (Premium NFS requires a VNet with a private endpoint; SMB identity auth requires domain-joining). Read them before the live session so the concepts land during the walkthrough.

### The three storage account types in the Rosetta design

The lab uses a single **StorageV2 LRS** Blob account. Production uses three distinct account types per environment (prod / uat / dev):

| Account | Kind | Replication | Protocol | Auth model | Example production name |
|---|---|---|---|---|---|
| NFS file shares | **FileStorage Premium** | ZRS | NFSv4 | POSIX UID/GID | `stanlnznfileprdrosi01` |
| SMB file shares | **StorageV2 Standard** | ZRS | SMBv3 | Entra ID identity-based (DACL) | `stanlnznfileprdrosi02` |
| Object/Blob storage | **StorageV2 Standard** | ZRS | BLOB API / NFSv3 | Azure RBAC (Managed Identity) | `stanlnznblobprdrosi01` |

#### Azure Files NFS (FileStorage Premium)

This is the **primary storage backend for Rosetta**. Six NFSv4 shares are mounted by the Rosetta repository, deposit, and delivery servers on RHEL 9:

```
/exlibris1/deposit_storage    → sts-deposit-01
/exlibris1/operational_storage → sts-operstg-01
/exlibris1/operational_shared  → sts-opershr-01
/ndha/dps_in                  → sts-dpsin-01
/ndha/dps_cmsint              → sts-dpscms-01
/ndha/dps_publishing          → sts-dpspub-01
```

Key differences from Blob:
- Uses **POSIX UID/GID** for file permissions — not Azure RBAC. Access is controlled by the local Linux user IDs, same as any NFS share.
- Account kind must be **FileStorage Premium** (a separate, dedicated account type — you cannot mix NFS Premium shares with Blob in the same account).
- NFSv4 requires the storage account to be on a **VNet with a private endpoint** — public NFS is not supported.
- Protective features: **31-day file share soft-delete** + **31-day rolling Azure File Snapshots** (see the snapshots section below).

#### Azure Files SMB (StorageV2 Standard + Entra ID identity-based protection)

The two SMB export shares (`sts-dpsexp-01`, `sts-operexp-01`) are used by Windows DFS clients and the NLNZ Windows DFS server:

```
\\stanlnznfileprdrosi02\sts-dpsexp-01   → DPS export
\\stanlnznfileprdrosi02\sts-operexp-01  → operational export
```

Key differences from NFS:
- Uses **Entra ID identity-based authentication** with Windows-style DACLs, not Azure RBAC. The storage account is domain-enabled and syncs with DIA Active Directory via Entra ID Connect Sync.
- SMB is available on StorageV2 Standard accounts (unlike NFS which needs FileStorage Premium).
- Windows clients mount it as a network drive through the NLNZ Windows DFS namespace — they don't see the Azure storage account name directly.

### Private Endpoints — why the lab looks different from production

The lab storage account `stdialabsXXXX` is accessible over the public internet (using Azure RBAC for auth). This is fine for training but **not how production is configured**.

All production Rosetta storage accounts connect exclusively via **Private Link endpoints** in the `ANL Cloud Storage Private Links Subnet`:

```
ANL Production Cloud Storage Private Links Subnet (Zone Agnostic)
  ├── NFS Files Private Link Endpoint   → stanlnznfileprdrosi01
  ├── SMB Files Private Link Endpoint   → stanlnznfileprdrosi02
  └── Blob Private Link Endpoint        → stanlnznblobprdrosi01
```

This means:
- The storage accounts have **public network access disabled**.
- Traffic never leaves the Azure backbone — it travels over the private endpoint's private IP inside the VNet.
- The DNS name for the storage account resolves to the private IP inside the VNet (via Private DNS Zone), not the public Azure IP.

To see this in production: portal → storage account → **Networking → Firewalls and virtual networks**. You'll see **Disabled (public access)** with a list of private endpoint connections.

### blobfuse2 — Blob storage mounted as a filesystem

The **WOD (Web of Documents)** PODMAN containers on Rosetta's Wayback servers mount the `stct-wod-01` Blob container as a local filesystem path using **blobfuse2**:

```bash
# What you'll see in server configs / Ansible / container volume mounts:
/var/lib/containers/storage/volumes/wod  →  stanlnznblobprdwod01 / stct-wod-01
```

blobfuse2 is an open-source FUSE driver that makes a Blob container look like a local directory to Linux processes. The container authenticates using the VM's **Entra ID Managed Identity** — no storage keys in config files. If you see `blobfuse2` in a mount list or a failing service, it means the Blob account or the Managed Identity role assignment needs attention.

---

## ⌨️ Activity 8: Azure File Share Snapshots (read through + portal exploration)

Azure Files share snapshots are a separate, incremental point-in-time copy of an entire file share — different from blob versioning or soft-delete, which work at the blob level.

**Production configuration:** 31-day rolling snapshots on all NFS and SMB shares, plus 31-day file share soft-delete.

**How they work:**

```
Share snapshot at T+0  (full copy, stored once)
Share snapshot at T+1d (only the delta from T+0 is stored)
Share snapshot at T+2d (only the delta from T+1d is stored)
...
Up to 200 snapshots per share
```

**To explore in the portal** (use a production share if you have read access, or the lab account's file shares if any exist):

1. Portal → storage account → **File shares** → pick a share.
2. Click **Snapshots** in the share blade.
3. You'll see the list of snapshots with timestamps.
4. Click a snapshot → **Browse** — you can navigate the directory tree at that point in time.
5. Right-click a file in a snapshot → **Restore** to restore a single file without rolling back the whole share.

> [!TIP]
> Azure Backup can also manage file share snapshots automatically on a schedule (instead of manually). In the Rosetta production design, Azure Backup is the orchestrator for the 31-day rolling snapshot schedule — you won't see individual snapshot buttons being clicked by operators.

---

## 🦾 Now your turn!

Write a runbook (a short markdown doc) that combines what you learned:

> **"A preservation officer reports they accidentally deleted 200 manifest files at 14:30 today. Walk me through recovery."**

Your runbook should reference: soft-delete window, change feed query for the time range, and the right Azure role to undelete blobs in bulk.

---

## ✅ Success checklist

- [ ] Storage Explorer connects to the lab account
- [ ] Blob soft-delete, container soft-delete, versioning, change feed are all enabled
- [ ] You've successfully soft-deleted and undeleted a blob
- [ ] You've created two versions of a blob and promoted an older one
- [ ] You've added and cleared a legal hold
- [ ] You've inspected the change feed and seen events
- [ ] Lifecycle policy `move-to-cool-30d` is in place (moving to **Cold**, not Archive)
- [ ] You can name the three production storage account types and their protocols (NFS Premium / SMB Standard / Blob)
- [ ] You can explain the difference between POSIX UID/GID (NFS) auth and Entra ID identity-based (SMB) auth and Azure RBAC (Blob) auth
- [ ] You understand why production storage uses private endpoints and the lab doesn't
- [ ] You know what blobfuse2 is and where it's used in the Rosetta server estate
- [ ] You've explored Azure File Share Snapshots in the portal
- [ ] You've written a recovery runbook

---

➡️ **Next step:** [Step 6 — Terraform on Azure](./step-6-terraform.md)
