# Step 3 — Must-know KQL

_Time to ask the workspace questions._ 🔍 KQL (Kusto Query Language) is what you use to interrogate Log Analytics. The good news: 80% of your day-to-day questions need only a small handful of operators.

> [!NOTE]
> Time: ~90 minutes.
> Pairs with **Module 3** of the training plan v3.
>
> **💰 Lab cost:** under NZD $1. KQL queries against Log Analytics are billed only on data scanned beyond the included free quota — lab volume is well below the threshold.

---

## 🧭 What you'll learn

- The five operators that solve almost everything: `where`, `project`, `summarize`, `extend`, `join`
- A "must-know" library of queries you can copy-paste in production
- How to **save** queries so the next person on call doesn't reinvent them
- How to pin a result chart to an **Azure dashboard**

---

## 🧩 Concept refresher — the KQL pipeline

KQL reads top-to-bottom. Each `|` passes the result of the line above into the next operator.

```kql
TableName
| where TimeGenerated > ago(1h)        // 1. filter early — cheapest operation
| project Computer, CounterName, CounterValue, TimeGenerated   // 2. trim columns
| summarize avg(CounterValue) by Computer, CounterName         // 3. aggregate
| order by avg_CounterValue desc       // 4. sort
| take 20                              // 5. limit
```

Three rules to keep you fast and cheap:

1. **Filter on time first.** `TimeGenerated > ago(1h)` is always your first `where`.
2. **Project early.** Drop columns you don't need before aggregating — cheaper, easier to read.
3. **Use `take`, not `limit`.** Same thing, but `take` is the canonical KQL spelling.

---

## 📚 Must-know query #1 — "Is everything up?" _(optional — needs the VM tier)_

> [!NOTE]
> `Heartbeat` and `Perf` only contain rows if you ran [step-optional-vm-setup.md](step-optional-vm-setup.md). If you skipped the VM tier, read these two queries for the syntax patterns and jump to query #3 — the rest of this lab uses `StorageBlobLogs`, `AzureActivity`, and `AzureDiagnostics`, none of which need VMs.

```kql
Heartbeat
| where TimeGenerated > ago(15m)
| summarize LastHeartbeat = max(TimeGenerated), AgentVersion = arg_max(TimeGenerated, Version) by Computer
| extend MinutesSinceLastHeartbeat = datetime_diff('minute', now(), LastHeartbeat)
| order by MinutesSinceLastHeartbeat desc
```

What it tells you: every VM, when it last checked in, and which AMA version it's running.

---

## 📚 Must-know query #2 — "Top CPU offenders, last hour"

```kql
Perf
| where TimeGenerated > ago(1h)
| where ObjectName == "Processor" and CounterName == "% Processor Time"
| summarize avg_cpu = avg(CounterValue) by Computer, bin(TimeGenerated, 5m)
| render timechart
```

Switch the `bin` to `15m` for a longer window without blowing up the dataset.

---

## 📚 Must-know query #3 — "Who deleted that blob?"

This one is gold for preservation work. Requires the diagnostic settings you turned on in Step 2.

```kql
StorageBlobLogs
| where TimeGenerated > ago(24h)
| where OperationName == "DeleteBlob"
| project TimeGenerated, AccountName, Uri, RequesterObjectId, RequesterAppId, StatusCode, UserAgentHeader
| order by TimeGenerated desc
```

Tip: `RequesterObjectId` is the Azure AD user/SP **object ID**. Resolve it to a name in the **Microsoft Entra ID** blade if you need a human-readable answer.

---

## 📚 Must-know query #3b — "Ransomware early warning — mass delete spike"

A sudden burst of blob deletes across a storage account is the earliest Azure-visible signal of a ransomware attack. This query builds a per-15-minute count you can alert on.

```kql
StorageBlobLogs
| where TimeGenerated > ago(4h)
| where OperationName == "DeleteBlob"
| summarize DeleteCount = count() by bin(TimeGenerated, 15m), AccountName
| order by TimeGenerated desc
```

Run as a time-chart (`| render timechart`) to see the shape. In production, set an **alert rule** with threshold `DeleteCount > 50` in any 15-minute window — that's the trip wire.

---

## 📚 Must-know query #3c — "Storage capacity trend (last 7 days)"

Useful for forecasting storage growth and spotting unexpected data accumulation.

```kql
AzureMetrics
| where TimeGenerated > ago(7d)
| where ResourceProvider == "MICROSOFT.STORAGE"
| where MetricName == "UsedCapacity"
| summarize AvgCapacityGB = avg(Average) / 1073741824 by bin(TimeGenerated, 1d), Resource
| order by TimeGenerated asc
| render timechart
```

> [!TIP]
> In production, run this across all three Rosetta storage accounts to get a combined capacity trend. Pin the chart to the `Preservation Operations` dashboard — it answers "are we growing as expected?"

---

## 📚 Must-know query #3d — "Backup job failures"

```kql
AddonAzureBackupJobs
| where TimeGenerated > ago(7d)
| where JobStatus == "Failed" or JobStatus == "CompletedWithWarnings"
| project TimeGenerated, ResourceId, JobOperation, JobStatus, JobFailureCode, BackupItemUniqueId
| order by TimeGenerated desc
```

If this returns rows, something in the backup schedule needs attention. In production, also set an alert rule against this query so the on-call team is notified without having to run it manually.

---

## 📚 Must-know query #4 — "What changed in the subscription?"

```kql
AzureActivity
| where TimeGenerated > ago(7d)
| where ActivityStatusValue == "Success"
| where OperationNameValue !contains "list" and OperationNameValue !contains "read"
| project TimeGenerated, Caller, OperationNameValue, ResourceGroup, Resource
| order by TimeGenerated desc
```

The two `!contains` filters drop read/list noise — the result is the **write activity** (create, update, delete).

---

## 📚 Must-know query #5 — "Why did that alert fire?"

When an alert wakes someone up, this is the query you start with — it pulls the rows that triggered it.

```kql
Heartbeat
| where TimeGenerated > ago(30m)
| summarize LastHeartbeat = max(TimeGenerated) by Computer
| where LastHeartbeat < ago(10m)
```

Same shape as the alert condition in Step 2 — copy-paste from the alert rule.

---

## ⌨️ Activity 1: Run all five against your lab

1. Open `la-dia-labs` → **Logs**.
2. Paste each query above, run, confirm you get rows back. (Query #5 should return zero rows if your VMs are healthy — that's correct!)
3. For Query #2, click **Chart** at the top to see the time series rendered.

---

## ⌨️ Activity 2: Save the pack

We'll save these so the team can reuse them.

1. In the Logs blade, click **Save → Save as query**.
2. Name: `01 - Heartbeat health`. Category: `DIA Preservation`. Save type: **Query**.
3. Repeat for the other queries. Use prefix numbering so they sort sensibly:
   - `02 - Top CPU offenders`
   - `03 - Blob deletes (who)`
   - `03b - Blob delete spike (ransomware)`
   - `03c - Storage capacity trend`
   - `03d - Backup job failures`
   - `04 - Subscription changes`
4. Click **Queries** in the toolbar → filter by category → confirm all appear.

> [!TIP]
> Saved queries live in the workspace, not on your account. Anyone with read access to the workspace sees them — exactly what you want for shared on-call.

---

## ⌨️ Activity 3: Pin a chart to a dashboard

1. Run Query #2 (Top CPU offenders).
2. Click **Pin to dashboard** (top right) → **Create new** → name it `Preservation Operations`.
3. Open **Dashboards** from the left nav → confirm your chart is pinned.
4. Add Query #1 the same way.

You now have a one-page operations view. In production, this is the page you'd open at 9am every morning.

---

## 🦾 Now your turn!

Write a query that answers: **"Which lab user uploaded the most blobs in the last 24 hours?"**

Hints:
- Table: `StorageBlobLogs`
- Operation: `PutBlob`
- `summarize count() by RequesterObjectId`
- `top 10 by count_`

Save it to your query pack as `04 - Top blob uploaders`.

---

## ✅ Success checklist

- [ ] All must-know queries return results (or zero results, where that's correct)
- [ ] All queries are saved to your workspace under category `DIA Preservation`
- [ ] The ransomware spike query (`03b`) is saved and you understand what threshold you'd alert on
- [ ] The storage capacity trend query (`03c`) is pinned as a chart to your `Preservation Operations` dashboard
- [ ] The backup failure query (`03d`) returns zero rows (meaning no backup failures in the lab)
- [ ] You've created a dashboard `Preservation Operations` with at least 2 pinned tiles
- [ ] You've written and saved your own "top uploaders" query

> [!TIP]
> The full cheat sheet — including these queries plus a few more — lives in [`assets/kql-cheatsheet.md`](./assets/kql-cheatsheet.md). Print it out. Stick it next to your monitor.

---

➡️ **Next step:** [Step 4 — Cost Management & FinOps](./step-4-cost-management.md)
