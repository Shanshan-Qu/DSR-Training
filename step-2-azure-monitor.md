# Step 2 — Azure Monitor fundamentals

_Let's plug in the dashboard lights._ 💡 Azure Monitor is what tells you **whether Rosetta and its supporting Azure resources are healthy**, **why they're slow**, and **fires alerts** when something needs attention.

> [!NOTE]
> Time: ~90 minutes.
> Pairs with **Module 2** of the training plan v3.
>
> **💰 Lab cost:** under NZD $1. Log Analytics ingestion is metered per GB; the lab generates a few MB. Alert rules are billed per evaluation but the lab uses the free tier (≤ 10 rules).

---

## 🧭 What you'll learn

- The pieces of Azure Monitor and how they connect
- What the **Azure Monitor Agent (AMA)** does and how to confirm it's working on a VM
- How to enable **diagnostic settings** on a storage account so blob operations end up in Log Analytics
- How to create an **alert rule** with an **action group** that emails the team
- How to use **Azure Monitor Workbooks** — what's available out-of-the-box and how to customise them for preservation-specific views

---

## 🧩 Concept refresher — acronyms first

| Term | What it actually is |
|------|---------------------|
| **Logs** | Time-stamped structured records (Heartbeat, Perf, AzureActivity, StorageBlobLogs…). Queried with KQL. |
| **Metrics** | Numeric, near-real-time samples (CPU %, blob count, request latency). Charted, alerted on. |
| **Log Analytics workspace (LAW)** | The container that stores logs. You query a workspace, not a resource. |
| **AMA** (Azure Monitor Agent) | The agent that runs **inside the VM** and ships data to a LAW. Replaces the older Log Analytics Agent (MMA / OMS). |
| **Diagnostic settings** | Per-resource configuration that says "send your platform logs/metrics to this LAW". Required for storage, vault, and most PaaS. |
| **Action group** | A reusable list of "who/what to notify" (email, SMS, webhook, runbook). |
| **Alert rule** | "When metric/log condition X is true, fire action group Y." |

The relationship in plain English:

```
[ VM / Storage / Vault ]
       │
       │  metrics & logs
       ▼
  [ AMA / diagnostic settings ]
       │
       ▼
  [ Log Analytics workspace ]  ◄──  KQL queries (Step 3)
       │
       ▼
  [ Alert rules ]  ──►  [ Action groups ]  ──►  📧 SMS / email
```

---

## ⌨️ Activity 1: Verify AMA is working _(optional — requires the VM tier)_

> [!NOTE]
> Skip this activity if you didn't run `deploy-vms.ps1`. It needs the two lab VMs and their AMA extension. See [step-optional-vm-setup.md](step-optional-vm-setup.md) for the one-off VM setup. Activities 2–5 below do **not** depend on VMs.

1. Portal → `vm-rhel-lab` → **Settings → Extensions + applications**.
2. Confirm `AzureMonitorLinuxAgent` is **Provisioning succeeded**.
3. Repeat for `vm-win-lab` (`AzureMonitorWindowsAgent`).
4. Open `la-dia-labs` → **Logs**. Run:

```kql
Heartbeat
| where TimeGenerated > ago(1h)
| summarize LastHeartbeat = max(TimeGenerated) by Computer
```

You should see both VMs with a `LastHeartbeat` within the last 5 minutes.

> [!TIP]
> If a VM is missing, give it 15 more minutes and try again. The agent has to install, register, and run a heartbeat before it shows up.

---

## ⌨️ Activity 2: Turn on diagnostic settings for storage

By default, an Azure Storage account does **not** send blob operations to Log Analytics. We'll fix that — it's the single most useful piece of evidence when investigating "who deleted that object?"

1. Portal → your storage account `stdialabsXXXX` → **Monitoring → Diagnostic settings**.
2. Click **+ Add diagnostic setting** for **`blob`**.
3. Name: `to-la-dia-labs`.
4. Tick **`StorageRead`**, **`StorageWrite`**, **`StorageDelete`** under Logs.
5. Tick **`Transaction`** under Metrics.
6. Destination → **Send to Log Analytics workspace** → `la-dia-labs`.
7. Save.

Repeat for **table** and **queue** if you use them (Rosetta typically doesn't — blob is enough).

> [!IMPORTANT]
> Diagnostic settings are **per-resource**. There's no "turn it on for the whole subscription" toggle in the basic UI. Azure Policy is how you enforce this at scale (Module 8).

---

## ⌨️ Activity 3: Generate some traffic

Open Cloud Shell and run a few blob operations against the lab account:

```bash
RG="rg-dia-azure-labs"
SA=$(az storage account list -g $RG --query "[0].name" -o tsv)

# Upload a file
echo "hello rosetta" > sample.txt
az storage blob upload \
  --account-name $SA --container-name rosetta-objects \
  --name "lab/sample-$(date +%s).txt" --file sample.txt --auth-mode login

# Delete it
az storage blob delete \
  --account-name $SA --container-name rosetta-objects \
  --name "lab/sample-XXXX.txt" --auth-mode login   # use the name you uploaded
```

Wait ~5 minutes for the logs to land.

---

## ⌨️ Activity 4: Create an alert rule + action group _(VM-based version is optional)_

We'll build a simple alert: **"Email the team if any VM stops sending heartbeats for 10 minutes."**

> [!NOTE]
> The `Heartbeat` query below requires VMs. If you didn't run `deploy-vms.ps1`, build the alert against `StorageBlobLogs` instead (e.g. delete-spike alert from the bonus task at the bottom of this lab) — the action-group walkthrough is identical.

1. Portal → `la-dia-labs` → **Alerts → + Create → Alert rule**.
2. **Scope**: confirm it's the workspace.
3. **Condition**: Custom log search.
   ```kql
   Heartbeat
   | summarize LastHeartbeat = max(TimeGenerated) by Computer
   | where LastHeartbeat < ago(10m)
   ```
   Threshold: `Number of results > 0`. Aggregation: 5 min.
4. **Actions** → **+ Create action group**.
   - Name: `ag-preservation-oncall`
   - Notifications → Email → `your-name@dia.govt.nz` (use your own email for the lab).
5. **Details**: Severity 2, name `alert-vm-heartbeat-missing`.
6. Create.

> [!TIP]
> Action groups are **reusable**. In production we'd point this group at a distribution list (e.g. `digitalpreservation-oncall@dia.govt.nz`) and reuse it across every alert.

---

## ⌨️ Activity 5: Azure Monitor Workbooks

Workbooks are interactive reports built into Azure Monitor. Unlike pinned dashboard tiles (which are static charts), Workbooks can have drop-down parameters, time-range pickers, and conditional formatting — making them much richer for operational reporting.

### 5a: Explore what's available out-of-the-box

1. Portal → **Monitor → Workbooks**.
2. You'll see a gallery divided by category. Browse:
   - **Virtual machines** section → open **"VM Availability and Performance"** — this is the standard VM health workbook.
   - **Storage** section → open **"Storage Account Overview"** — shows capacity, transaction rates, errors per storage account.
   - **Azure Backup** section → open **"Backup Summary"** — shows backup job success/failure rates across all vaults.
3. For each one, use the **Time range** parameter at the top to change the window. Note how the whole report updates — this is what makes Workbooks more powerful than pinned tiles.

> [!TIP]
> These built-in workbooks are maintained by Microsoft and update automatically. They're the "what is there as standard" answer — use them before building anything custom.

### 5b: Build a custom storage-focused Workbook

1. Portal → **Monitor → Workbooks → + New**.
2. Click **Edit** → **Add → Add query**.
3. Paste this query (requires storage diagnostic settings from Activity 2):

```kql
StorageBlobLogs
| where TimeGenerated > {TimeRange:start}
| summarize
    Uploads   = countif(OperationName == "PutBlob"),
    Deletes   = countif(OperationName == "DeleteBlob"),
    Reads     = countif(OperationName == "GetBlob")
  by bin(TimeGenerated, 1h), AccountName
| render columnchart
```

4. Click **Done Editing** on the query item. Click the **Time Range** drop-down — Workbooks automatically wire the `{TimeRange:start}` token to the picker.
5. Add a second query item → **Add → Add query**:

```kql
StorageBlobLogs
| where TimeGenerated > {TimeRange:start}
| where OperationName == "DeleteBlob"
| summarize DeleteCount = count() by bin(TimeGenerated, 15m)
| render timechart
```

6. Name this item **"Blob deletions over time"**. This is your ransomware early-warning chart — a sudden spike in the delete line is the signal.
7. Click **Save** → name: `Preservation Storage Activity`, resource group: `rg-dia-azure-labs`.

The workbook is now a shared resource. Anyone with Reader access to the resource group can open it.

### 5c: Customising standard workbooks

1. Go back to **Monitor → Workbooks → Azure Backup → Backup Summary**.
2. Click **Edit** (pencil icon, top bar).
3. Click the **↑ Edit** on any query tile → change the `TimeRange` default from `7d` to `30d`.
4. Click **Save As** → save a copy to your resource group as `Preservation Backup Summary`.

> [!NOTE]
> You are saving a **copy** — the original Microsoft-maintained workbook is untouched. DIA Core Support can later commit your customised version to the platform Terraform repo so it deploys automatically to every environment.

---

## 🦾 Now your turn!

Build a second alert that fires when the lab storage account's **blob delete** count exceeds 10 in 5 minutes — useful for spotting accidental mass-deletion.

Hint: the metric is on the storage account itself (Metrics blade), or you can write a log alert against `StorageBlobLogs` filtered to `OperationName == "DeleteBlob"`.

---

## ✅ Success checklist

- [ ] _Optional:_ Both VMs return `Heartbeat` rows in the last 5 minutes (skip if no VM tier)
- [ ] Storage diagnostic settings for **blob** are sending to `la-dia-labs`
- [ ] You ran a blob upload + delete and saw rows appear in `StorageBlobLogs` after a few minutes
- [ ] `ag-preservation-oncall` action group exists with your email as a recipient
- [ ] An alert rule is created and **enabled** (heartbeat-missing if you have VMs, blob-delete-spike otherwise)
- [ ] You've created the bonus "mass delete" alert
- [ ] You've explored the built-in VM, Storage, and Backup workbooks in the gallery
- [ ] You've built and saved the custom `Preservation Storage Activity` workbook with blob operations chart and delete-spike chart
- [ ] You've saved a customised copy of the Backup Summary workbook

---

➡️ **Next step:** [Step 3 — Must-know KQL](./step-3-kql.md)
