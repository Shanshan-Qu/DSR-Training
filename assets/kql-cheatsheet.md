# KQL cheat sheet — preservation operator's edition

A one-page reference for the queries you'll run most often. All queries assume your default scope is `law-dia-labs` (the lab Log Analytics workspace).

> [!TIP]
> In the portal, every query you save here can be **pinned to a dashboard** as a chart or table tile.

---

## 🩺 Health & heartbeat

```kusto
// Are my VMs alive?
Heartbeat
| where TimeGenerated > ago(15m)
| summarize LastSeen = max(TimeGenerated) by Computer
| extend MinutesAgo = datetime_diff('minute', now(), LastSeen)
| order by MinutesAgo desc
```

```kusto
// Which VMs have stopped sending heartbeats in the last hour?
Heartbeat
| summarize LastSeen = max(TimeGenerated) by Computer
| where LastSeen < ago(1h)
```

---

## 🖥 Performance

```kusto
// Top CPU over the last hour
Perf
| where TimeGenerated > ago(1h)
| where ObjectName == "Processor" and CounterName == "% Processor Time"
| summarize AvgCPU = avg(CounterValue) by Computer, bin(TimeGenerated, 5m)
| render timechart
```

```kusto
// Memory available, last 24h
Perf
| where TimeGenerated > ago(24h)
| where CounterName == "Available MBytes" or CounterName == "% Used Memory"
| summarize Avg = avg(CounterValue) by Computer, CounterName, bin(TimeGenerated, 30m)
| render timechart
```

```kusto
// Disk space — anything below 10% free
Perf
| where CounterName == "% Free Space"
| where TimeGenerated > ago(15m)
| summarize FreePct = avg(CounterValue) by Computer, InstanceName
| where FreePct < 10
```

---

## 🗂 Storage operations

```kusto
// Who deleted that blob?
StorageBlobLogs
| where TimeGenerated > ago(24h)
| where OperationName == "DeleteBlob"
| project TimeGenerated, AccountName, ObjectKey, RequesterObjectId, UserAgentHeader, CallerIpAddress
| order by TimeGenerated desc
```

```kusto
// Top blob writers (last 24h)
StorageBlobLogs
| where TimeGenerated > ago(24h)
| where OperationName in ("PutBlob","PutBlock","AppendBlock","CopyBlob")
| summarize Operations = count() by RequesterObjectId, AccountName
| order by Operations desc
| take 20
```

```kusto
// Failed storage operations
StorageBlobLogs
| where StatusCode >= 400
| summarize Failures = count(), Sample = any(StatusText)
        by AccountName, OperationName, StatusCode
| order by Failures desc
```

---

## 🛂 Activity log — change tracking

```kusto
// What changed in the lab RG today?
AzureActivity
| where TimeGenerated > ago(24h)
| where ResourceGroup == "rg-dia-azure-labs"
| where ActivityStatusValue == "Success"
| project TimeGenerated, Caller, OperationNameValue, ResourceProviderValue, _ResourceId
| order by TimeGenerated desc
```

```kusto
// Policy denials (failed deployments due to policy)
AzureActivity
| where ActivityStatusValue == "Failed"
| where OperationNameValue contains "policy" or Properties contains "RequestDisallowedByPolicy"
| project TimeGenerated, Caller, OperationNameValue, ResourceGroup, Properties
| order by TimeGenerated desc
```

```kusto
// Role assignment changes — who got Owner / Contributor?
AzureActivity
| where OperationNameValue == "Microsoft.Authorization/roleAssignments/write"
| project TimeGenerated, Caller, ResourceId = _ResourceId, ActivityStatusValue
| order by TimeGenerated desc
```

---

## 🔔 Alert investigation

```kusto
// Why did my alert fire? Replay the data the alert evaluated.
// (Replace bin window and metric to match the alert rule.)
Heartbeat
| where TimeGenerated between (datetime(2026-04-29T09:00:00Z) .. datetime(2026-04-29T10:00:00Z))
| summarize LastSeen = max(TimeGenerated) by Computer
| extend MinutesAgo = datetime_diff('minute', datetime(2026-04-29T10:00:00Z), LastSeen)
| where MinutesAgo > 10
```

---

## 💾 Backup status

```kusto
// Backup jobs in the last 24h, by status
AddonAzureBackupJobs
| where TimeGenerated > ago(24h)
| summarize Count = count() by JobStatus, BackupItemFriendlyName
| order by JobStatus asc
```

```kusto
// Anything that's failed or warned in the last week
AddonAzureBackupJobs
| where TimeGenerated > ago(7d)
| where JobStatus in ("Failed","CompletedWithWarnings")
| project TimeGenerated, BackupItemFriendlyName, JobStatus, JobFailureCode
| order by TimeGenerated desc
```

---

## 🔧 Shortcut keys (KQL editor)

| Key | Action |
|---|---|
| `Shift+Enter` | Run query |
| `Ctrl+/` | Comment / uncomment line |
| `Ctrl+Space` | Suggest column / table |
| `F1` | KQL command palette |

---

## 🧩 KQL operators you'll use 80% of the time

| Operator | Does what |
|---|---|
| `where` | Filter rows |
| `project` | Pick / rename columns |
| `extend` | Add a calculated column |
| `summarize ... by ...` | Group & aggregate (like SQL `GROUP BY`) |
| `join kind=inner` | Join two tables |
| `order by ... desc` | Sort |
| `take N` | Top N rows (no order guarantee) |
| `top N by X` | Top N rows by column X |
| `render timechart` | Chart it |
| `bin(TimeGenerated, 5m)` | Bucket time into 5-minute bins |
| `ago(1h)` | Relative time — 1 hour ago |
| `datetime_diff('minute', a, b)` | Time difference in minutes |

---

_Last updated: 2026-04-30 — keep this file alongside your runbooks, not buried in the labs folder._
