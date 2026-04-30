# Step 5 — Storage for preservation

_The big one._ 🗄️ This is the lab that maps most directly to your day-to-day work with Rosetta. You'll exercise **Storage Explorer**, **lifecycle tiers**, **soft-delete**, **versioning**, **immutability** (legal hold), and the **change feed**.

> [!NOTE]
> Time: ~120 minutes.
> Pairs with **Module 5** of the training plan.

---

## 🧭 What you'll learn

- How to use **Azure Storage Explorer** end-to-end against the lab account
- The protective features that matter most for preservation: **soft-delete**, **versioning**, **immutability / legal hold**
- How **lifecycle policies** automatically move blobs between Hot / Cool / Archive
- How to use the **change feed** as an audit log

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
6. Add another action: **More than 365 days → Move to Archive**.
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
            "tierToArchive": { "daysAfterModificationGreaterThan": 365 }
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
- [ ] Lifecycle policy `move-to-cool-30d` is in place
- [ ] You've written a recovery runbook

---

➡️ **Next step:** [Step 6 — Terraform on Azure](./step-6-terraform.md)
