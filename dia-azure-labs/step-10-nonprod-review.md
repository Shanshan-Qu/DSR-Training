# Step 10 — Nonprod Environment Review

_Now it's real._ 🔍 The vendor has deployed the Digital Storage and Resilience (DSR) nonprod environment. This module is a structured walkthrough of what was actually built — confirming the design is implemented correctly, familiarising the team with the real resource names, and establishing the operational baseline before go-live.

> [!NOTE]
> Time: ~90 minutes.
> Pairs with **Module 10** of the training plan.
> **Pre-req:** Steps 1–9 completed. You need at least Reader access to the DSR nonprod subscription (`sub-dia-dsr-uat` or equivalent).

---

## 🧭 What you'll learn

- How to systematically verify a deployed Azure environment against a design document
- What "good" looks like for each DSR component: storage accounts, VMs, networking, monitoring, backup, governance
- How to establish a cost and compliance **baseline** you can compare against each month
- What to look for when something doesn't match the design — and who to raise it with

---

## 🧩 Review checklist — the five layers

We review the environment in five layers, from the outside in:

```
┌──────────────────────────────────────────────────────────────────┐
│  5. Governance        ← policies applied, RBAC assignments       │
├──────────────────────────────────────────────────────────────────┤
│  4. Monitoring        ← AMA on VMs, diagnostic settings, alerts  │
├──────────────────────────────────────────────────────────────────┤
│  3. Data protection   ← backup vault, storage soft-delete/ver.   │
├──────────────────────────────────────────────────────────────────┤
│  2. Storage accounts  ← three types, private endpoints, shares   │
├──────────────────────────────────────────────────────────────────┤
│  1. Networking        ← VNet, subnets, private endpoints, DNS    │
└──────────────────────────────────────────────────────────────────┘
```

---

## ⌨️ Activity 1: Networking baseline

### 1a: Find the VNet and subnets

1. Portal → `sub-dia-dsr-uat` → **Resource groups** → find the DSR network resource group (ask your Core Support contact if unsure of the name).
2. Open the **Virtual Network** → **Subnets**. Confirm you can see at minimum:
   - A VM subnet for the Rosetta application servers
   - A **private endpoints subnet** (Zone Agnostic) — this is `ANL UAT Cloud Storage Private Links Subnet`
3. Note the address prefixes. Screenshot or copy to your review notes.

### 1b: Verify private endpoints

1. Portal → search **Private endpoints** → filter by the DSR subscription.
2. Confirm **three private endpoints** exist for the Rosetta UAT storage accounts:
   - One for `stanlnznfileuatrosi01` (NFS Files)
   - One for `stanlnznfileuatrosi02` (SMB Files)
   - One for `stanlnznblobuatrosi01` (Blob)
3. Click each one → **DNS configuration** tab → confirm the FQDN resolves to a **private IP** (starts with `10.`), not a public Azure IP.

> [!TIP]
> If a private endpoint shows "Pending" connection state, it needs approval. This should have been done by Core Support during deployment — flag it if you see it.

### 1c: Private DNS Zones

1. Portal → **Private DNS zones** → filter to your subscription.
2. Confirm these zones exist and have auto-registration or A-records for the storage accounts:
   - `privatelink.file.core.windows.net`
   - `privatelink.blob.core.windows.net`
3. Each zone should be **linked to the DSR VNet**. Click the zone → **Virtual network links** to confirm.

---

## ⌨️ Activity 2: Storage accounts baseline

### 2a: Verify all three account types

In the DSR nonprod resource group, confirm these three storage accounts exist:

| Expected name | Kind | SKU | Protocol | Purpose |
|---|---|---|---|---|
| `stanlnznfileuatrosi01` | FileStorage | Premium ZRS | NFSv4 | Rosetta NFS shares |
| `stanlnznfileuatrosi02` | StorageV2 | Standard ZRS | SMBv3 | DPS export / operational export |
| `stanlnznblobuatrosi01` | StorageV2 | Standard ZRS | Blob API | Permanent object storage |

For each account:
1. Portal → storage account → **Overview** → note Kind, Replication, and Region.
2. Confirm **Public network access = Disabled** (Networking blade → Firewalls and virtual networks).
3. Confirm **Minimum TLS version = TLS 1.2**.

### 2b: Verify NFS file shares (stanlnznfileuatrosi01)

1. Portal → `stanlnznfileuatrosi01` → **File shares**.
2. Confirm these six shares exist:

| Share name | Protocol |
|---|---|
| `sts-deposit-01` | NFS |
| `sts-operstg-01` | NFS |
| `sts-opershr-01` | NFS |
| `sts-dpsin-01` | NFS |
| `sts-dpscms-01` | NFS |
| `sts-dpspub-01` | NFS |

3. For each share: click → **Overview** → note **Quota** and **Used capacity** (should be near zero in a fresh deployment).
4. Click **Snapshots** → confirm the snapshot policy is configured (should show automated snapshots).

### 2c: Verify SMB file shares (stanlnznfileuatrosi02)

1. Portal → `stanlnznfileuatrosi02` → **File shares**.
2. Confirm two SMB shares exist: `sts-dpsexp-01` and `sts-operexp-01`.
3. Portal → **Configuration** → confirm **Active Directory** authentication is enabled (this is the Entra ID identity-based protection for SMB).

### 2d: Verify Blob data protection (stanlnznblobuatrosi01)

1. Portal → `stanlnznblobuatrosi01` → **Data protection**. Confirm:
   - Blob soft-delete: **enabled, 31 days** (minimum; production is 365 days)
   - Container soft-delete: **enabled, 31 days**
   - Blob versioning: **enabled**
   - Change feed: **enabled**
2. **Containers** blade → confirm `stct-permanent-01` exists.
3. **Lifecycle management** → confirm a policy exists that moves blobs from Hot → Cold after N days.

> [!IMPORTANT]
> If any of the above settings are missing or misconfigured, **do not fix them yourself** — raise a change request with Core Support, referencing the design document section. Changing these settings in production without a change record is a governance breach.

---

## ⌨️ Activity 3: Monitoring baseline

### 3a: Log Analytics workspace

1. Portal → **Log Analytics workspaces** → find the DSR workspace (e.g. `log-anl-uat`).
2. **Agents** blade → confirm both RHEL 9 and Windows VMs show as connected with the **Azure Monitor Agent (AMA)**.
3. Run a quick heartbeat check in **Logs**:

```kql
Heartbeat
| where TimeGenerated > ago(1h)
| summarize LastHeartbeat = max(TimeGenerated) by Computer
| order by LastHeartbeat asc
```

Every VM should appear with a heartbeat in the last 5 minutes. Any VM missing from this list needs investigation.

### 3b: Storage diagnostic settings

For each of the three storage accounts:
1. Portal → storage account → **Monitoring → Diagnostic settings**.
2. Confirm a diagnostic setting exists for **blob** (and **file** for the file accounts) that sends to the LAW.

### 3c: Alert rules

1. Portal → **Monitor → Alert rules** → filter to the DSR subscription.
2. Document the alert rules you find. At minimum there should be:
   - VM heartbeat missing
   - Backup job failure
   - High blob delete rate (ransomware detection)
3. For each rule: note the **condition**, **severity**, and **action group**.
4. Click the action group → confirm it points to the correct team distribution list.

---

## ⌨️ Activity 4: Data protection baseline

### 4a: Recovery Services vault

1. Portal → **Recovery Services vaults** → find the DSR vault (e.g. `rsv-anl-uat`).
2. **Properties → Security Settings**: confirm **Soft delete = enabled** and **Immutability** is configured.
3. **Backup policies** → list the policies. Note the schedule, retention (daily/weekly/monthly), and which workloads each policy covers.
4. **Backup items** → confirm all Rosetta VMs are enrolled under a policy and show **Last backup status = Completed** (or a recent successful job).

### 4b: File share snapshot schedule

1. For each Azure File Share (both NFS and SMB accounts):
   - Portal → storage account → File shares → share name → **Snapshots**.
   - Confirm the automated snapshot schedule shows 31-day rolling coverage.

> [!TIP]
> If the file shares are protected by Azure Backup, the snapshot schedule is managed by the vault backup policy rather than a manual schedule on the share. Check the RSV backup items for the file share workload type.

---

## ⌨️ Activity 5: Governance baseline

### 5a: Policy compliance

1. Portal → **Policy → Compliance** → set scope to the DSR subscription.
2. Note the overall compliance percentage.
3. Look for any **Non-compliant** resources. Categorise each one:
   - Is it a configuration issue the vendor should fix before handover?
   - Is it a known exception with an approved exemption?
   - Is it something the team needs to act on?
4. For any Non-compliant resource that is blocking handover, document it in a table: Resource name | Policy name | Expected value | Actual value | Owner to fix.

### 5b: RBAC assignments

1. Portal → DSR resource group → **Access control (IAM) → Role assignments**.
2. Run this Resource Graph query to get a full picture:

```kusto
AuthorizationResources
| where type == "microsoft.authorization/roleassignments"
| where subscriptionId == "<your-sub-id>"
| project principalId, roleDefinitionId, scope
| join kind=leftouter (
    AuthorizationResources
    | where type == "microsoft.authorization/roledefinitions"
    | project id, roleName = properties.roleName
) on $left.roleDefinitionId == $right.id
```

3. Look for:
   - Any `Owner` assignments that should be `Contributor`
   - Any service principal assignments for the vendor that should be removed post-deployment
   - Any missing assignments for the preservation team's day-to-day roles

### 5c: Tags

1. Portal → DSR resource group → **Tags** blade → confirm the expected tag set (e.g. `env=uat`, `owner`, `project`, `costcentre`) is applied.
2. Run a Resource Graph query to find any untagged resources:

```kusto
Resources
| where subscriptionId == "<your-sub-id>"
| where tags !contains "owner"
| project name, type, resourceGroup
| order by type asc
```

---

## ⌨️ Activity 6: Cost baseline

Establish a cost baseline **before** any workloads run — this is your reference point for "is this environment costing what we expected?"

1. Portal → **Cost Management → Cost analysis**.
2. Scope: DSR subscription. Granularity: Daily. Group by: Service name.
3. Date range: **This month to date**.
4. Save as **DSR UAT — baseline month-to-date**.
5. In **Budgets**, confirm a budget exists for the nonprod subscription with alert thresholds at 50%, 80%, and 100%.

---

## 📋 Handover sign-off checklist

Use this as your formal acceptance checklist when taking handover from the vendor.

### Networking
- [ ] VNet and subnets exist with correct address ranges
- [ ] Private endpoints exist for all three storage accounts
- [ ] Private endpoint DNS resolves to private IPs
- [ ] Private DNS zones linked to VNet

### Storage
- [ ] `stanlnznfileuatrosi01` (NFS) — all 6 NFSv4 shares present, public access disabled, ZRS
- [ ] `stanlnznfileuatrosi02` (SMB) — both SMBv3 shares present, Entra ID auth enabled, ZRS
- [ ] `stanlnznblobuatrosi01` (Blob) — `stct-permanent-01` container present, soft-delete + versioning + change feed enabled, lifecycle policy in place, ZRS

### Monitoring
- [ ] All Rosetta VMs show AMA heartbeat in Log Analytics
- [ ] Storage diagnostic settings send blob/file logs to LAW
- [ ] Alert rules exist for VM heartbeat, backup failures, and blob delete spike
- [ ] Action groups point to the correct team distribution list

### Data protection
- [ ] Recovery Services vault enrolled for all Rosetta VMs
- [ ] At least one successful backup job per VM
- [ ] File share snapshot schedule confirmed (31-day rolling)
- [ ] Vault soft-delete and immutability enabled

### Governance
- [ ] Policy compliance ≥ 90% (or all non-compliant items are documented exceptions)
- [ ] No Owner-level vendor assignments remaining
- [ ] Preservation team RBAC assignments in place for day-to-day roles
- [ ] All resources tagged with required tag set

### Cost
- [ ] Cost budget exists with alert thresholds
- [ ] Baseline cost view saved

---

## 🦾 Now your turn!

Write a **one-page handover report** using the checklist above as your structure. For any item that is not yet met, note:
- What is missing
- Which team is responsible for fixing it
- Target date

This document becomes the formal acceptance sign-off for the nonprod handover.

---

## ✅ Success checklist

- [ ] You've completed all five review layers and have notes for each
- [ ] You've confirmed private endpoints resolve to private IPs
- [ ] You've run the heartbeat KQL and all VMs appear
- [ ] You've documented any non-compliant policies with an owner assigned
- [ ] You've removed or flagged any over-privileged vendor RBAC assignments
- [ ] You've established a cost baseline view and budget
- [ ] You've produced a handover sign-off report

---

➡️ **Back to start:** [README](./README.md)
