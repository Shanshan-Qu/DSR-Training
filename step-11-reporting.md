# Step 11 — Operational reporting & dashboards

_The "show me, weekly, by email" lab._ 📊 Builds the report set Emma asked for in her 28-April feedback: storage cost & forecast, data-movement cost, application health, and Backup Center summary — both **scheduled** (delivered to your inbox) and **on-demand** (pinned to a dashboard).

> [!NOTE]
> Time: ~90 minutes.
> Pairs with **Module 11 (new)** of the training plan v3.
>
> **💰 Lab cost:** under NZD $1. Cost Management views, Workbooks, and Azure Dashboards are **free**. The only cost is the small Blob storage used for scheduled cost-export CSVs (a few cents per month).

---

## 🧭 What you'll learn

- How to build a **storage cost & 12-month forecast** view in Cost Management
- How to **schedule a cost export** to Blob and **subscribe to a weekly cost email**
- How to assemble an **Azure Monitor Workbook** that shows data-movement cost (egress, transactions, tier-change events)
- How to build a **Rosetta Application Health Dashboard** in the Azure portal and share it with the team
- How to subscribe to the **Backup Center** daily summary email
- Which **built-in Insights workbooks** (Storage Insights, VM Insights, Advisor) the team should bookmark — and what each is good for

---

## 🧩 The reporting set, at a glance

| Report | Type | Who reads it | Refresh |
|---|---|---|---|
| Storage Cost & Forecast (Cost Management) | Saved view + scheduled email + Blob CSV export | Tech lead, app owner | Weekly |
| Data Movement Cost (Workbook) | On-demand workbook | Tech lead | Live |
| Rosetta Application Health (Dashboard) | Pinned dashboard | Whole team | Live |
| Backup Center Summary | Scheduled email | Tech lead | Daily |
| Storage Insights / VM Insights | Built-in workbook | Anyone | Live |
| Azure Advisor — cost recommendations | On-demand | Tech lead | Live |
| Defender for Storage alerts (if enabled by Core Support) | Email + portal | Tech lead | Real-time |

---

## ⌨️ Activity 1: Storage Cost & 12-month Forecast view

1. Portal → **Cost Management → Cost analysis**.
2. Scope: lab subscription. Time range: **Last 12 months** (or longest available).
3. **Group by** → **Service name**.
4. Add a filter: **Service name = Storage**.
5. Switch chart type to **Area** → toggle **Forecast = on** → set **forecast horizon = 12 months**.
6. **Save view as** → name `Storage cost — 12mo forecast`.
7. Click **Subscribe** at the top → **+ New subscription**.
   - Name: `weekly-storage-cost`
   - Frequency: **Weekly**, Monday 09:00 NZST
   - Recipients: your email (in production: a team distribution list)
   - Format: **CSV + chart image**
8. Save.

> [!TIP]
> The forecast is based on the last 60 days of actual cost. If your lab has only a few days of data, the forecast line will be flat. In production it tracks the automated Hot → Cool → Cold lifecycle moves accurately.

### Activity 1b — Scheduled CSV export to Blob (for FinOps/Power BI)

1. Cost Management → **Exports → + Add**.
2. Name: `daily-cost-export`. Type: **Daily export of month-to-date costs**.
3. Storage account: `stdialabsXXXX`. Container: `cost-exports` (create if needed).
4. Save. The first export runs the next day.

This drops a partitioned CSV (`{year}/{month}/{day}/...`) into Blob — ready for Power BI to consume, or for ingestion into a custom report.

---

## ⌨️ Activity 2: Data Movement Cost workbook

This workbook surfaces **what your storage is costing you to operate**, not just to store: egress bytes, transaction counts, and the cost of automated tier changes (the lifecycle policy). Useful for spotting "why did the bill jump 30% this week" answers.

1. Portal → **Monitor → Workbooks → + New**.
2. Click **Advanced editor** (`</>` icon) and paste this template, then **Apply**:

```json
{
  "version": "Notebook/1.0",
  "items": [
    { "type": 1, "content": { "json": "# Rosetta — Data Movement Cost\nLast 30 days. Source: Storage diagnostic logs + AzureMetrics." } },
    { "type": 3, "content": {
        "version": "KqlItem/1.0",
        "query": "StorageBlobLogs | where TimeGenerated > ago(30d) | summarize Transactions = count() by bin(TimeGenerated, 1d), OperationName | render columnchart",
        "size": 1, "title": "Daily blob transactions by operation",
        "queryType": 0, "resourceType": "microsoft.operationalinsights/workspaces"
    } },
    { "type": 3, "content": {
        "version": "KqlItem/1.0",
        "query": "AzureMetrics | where ResourceProvider == 'MICROSOFT.STORAGE' and MetricName == 'Egress' | summarize EgressBytes = sum(Total) by bin(TimeGenerated, 1d), Resource | render timechart",
        "size": 1, "title": "Daily egress (bytes) per storage account",
        "queryType": 0, "resourceType": "microsoft.operationalinsights/workspaces"
    } },
    { "type": 3, "content": {
        "version": "KqlItem/1.0",
        "query": "StorageBlobLogs | where TimeGenerated > ago(30d) and OperationName in ('SetBlobTier','SetBlobAccessTier','TierChange') | summarize TierChanges = count() by bin(TimeGenerated, 1d), DestinationTier=tostring(parse_json(Properties).destinationAccessTier) | render columnchart",
        "size": 1, "title": "Lifecycle tier-change events (cost = 1 transaction per blob moved)",
        "queryType": 0, "resourceType": "microsoft.operationalinsights/workspaces"
    } }
  ]
}
```

3. Set the workspace at the top to your lab Log Analytics workspace.
4. **Save** → name `Rosetta — Data Movement Cost`. Pin to your dashboard (Activity 3).

> [!IMPORTANT]
> For this to populate in the lab, **storage diagnostic settings must be on** for the lab account (Step 2). In production, Core Support enables them on every storage account.

A pre-baked copy of this workbook JSON is in [`assets/workbook-data-movement-cost.json`](assets/workbook-data-movement-cost.json) — import it via the same `</>` editor.

---

## ⌨️ Activity 3: Rosetta Application Health dashboard

1. Portal → **Dashboard → + New dashboard → Blank** → name `Rosetta Operations`.
2. Pin the following tiles (right-click → **Pin to dashboard** from each source blade):

| Tile | Source | What it tells you |
|---|---|---|
| VM heartbeat (count by computer) | LAW → query `Heartbeat \| summarize arg_max(TimeGenerated, *) by Computer \| project Computer, MinutesAgo = datetime_diff('minute', now(), TimeGenerated)` → pin chart | Are all Rosetta VMs reporting? |
| Recent alerts | Monitor → Alerts → filter "Severity ≤ Sev2, last 24h" → Pin | Open issues at a glance |
| Blob delete spike | LAW saved query from Step 3 → pin chart | Ransomware early warning |
| Storage account capacity (UsedCapacity) | Each storage account → Metrics → UsedCapacity → pin | Capacity trend |
| Backup job status (last 7 days) | Backup Center → Backup jobs → filter Failed/InProgress → pin | Did last night's backup run? |
| Action group health | Monitor → Action groups → pin a small inventory | Are the right people on the alert list? |
| Cost month-to-date | Cost Management → MTD view filtered to DSR sub → pin | Live spend |

3. **Share dashboard** → publish to a resource group → grant the preservation team **Reader** on that RG. Now the same view is in everyone's portal.

A starter dashboard JSON is in [`assets/dashboard-rosetta-ops.json`](assets/dashboard-rosetta-ops.json) — import via **Dashboard → + New dashboard → Upload**.

---

## ⌨️ Activity 4: Backup Center scheduled email

> Even with RSV configuration owned by Core Support, the Preservation Team should still be on the **read-only** distribution for daily backup health.

1. Portal → search **Backup center** → open it.
2. **Reports** → **+ New report → Summary**.
3. Time range: **Last 7 days**. Vaults: all in scope (or just `rsv-dia-labs` for the lab).
4. **Save & email**: subscribe daily, recipients = team distribution list (lab: your email).
5. Format: **PDF**.

The email arrives ~07:00 daily with: protected items, success/failure counts, soft-delete inventory, policy compliance.

---

## ⌨️ Activity 5: Bookmark the built-in Insights

These are **free, zero-config** views — you just need Reader role on the resource.

| Insight | Where | What it gives you out of the box |
|---|---|---|
| **Storage Insights** | Monitor → Insights → Storage accounts | Latency, availability, transactions, capacity per account, all stitched together |
| **VM Insights** | Monitor → Insights → Virtual machines | Performance, dependencies, processes per VM (requires AMA — already installed) |
| **Network Insights** | Monitor → Insights → Networks | Private endpoint and NSG flow visualisation |
| **Azure Advisor — Cost** | Advisor → Cost | Idle resources, right-sizing, reservation suggestions |
| **Defender for Storage alerts** (if enabled) | Defender for Cloud → Workload protections → Storage | Anomalous access, mass-delete, malware uploads |

**Action:** open each one against your lab subscription and pin the most useful chart from each to your `Rosetta Operations` dashboard.

---

## 🦾 Now your turn!

Build a **one-page weekly operations report** that the team can review every Monday morning. Combine:

1. The cost forecast image from Activity 1's email.
2. A screenshot of the Application Health dashboard (Activity 3).
3. The Backup Center summary (Activity 4).
4. Any open Sev≤2 alerts from the last 7 days.

Save this as a Word/PDF template in your team's SharePoint. The combination of automated emails + the dashboard means assembly takes < 10 minutes.

---

## ✅ Success checklist

- [ ] `Storage cost — 12mo forecast` view is saved with weekly email subscription
- [ ] Daily cost CSV export to Blob is configured
- [ ] `Rosetta — Data Movement Cost` workbook is saved and renders three charts
- [ ] `Rosetta Operations` dashboard exists with at least 5 pinned tiles, shared with the team
- [ ] Backup Center daily PDF email is subscribed
- [ ] Storage Insights, VM Insights, and Advisor are bookmarked in portal favourites
- [ ] You've drafted the one-page weekly operations report template

---

## 💰 Cost note

- All Cost Management features used here (analysis, exports, subscriptions, budgets) are **free**.
- Workbooks and Azure Dashboards are **free**.
- The CSV export drops a few KB per day into Blob → < $0.01/month.
- The only material lab cost (the two B2s VMs from Step 0) is unaffected by this lab.

---

➡️ **You've reached the end of the lab series!** Re-run [`./assets/deploy-lab.ps1 -Cleanup`](assets/deploy-lab.ps1) when you're done to remove the lab subscription's resources.
