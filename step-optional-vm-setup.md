# Step (optional) — VM setup & VM monitoring

_Add VMs to the lab only if you need them._ 🖥️ This optional lab deploys two small VMs (one RHEL 9, one Windows Server 2022) into the lab subscription, installs the **Azure Monitor Agent (AMA)**, and binds them to a **Data Collection Rule (DCR)** so heartbeat, performance counters, and OS logs flow into the lab Log Analytics workspace.

> [!NOTE]
> Time: ~30 minutes (mostly Azure provisioning).
> **Optional.** Run this only if you want to do:
> - Step 2 — Activity 1 ("Verify AMA is working") and the heartbeat alert in Activity 4
> - Step 3 — KQL queries against `Heartbeat`, `Perf`, `Syslog`, `Event`
> - Step 7 — Backup & Recovery Services vault (the optional self-study lab)
>
> All other labs (Storage, KQL against `StorageBlobLogs`, Cost, Reporting, Governance, Portal, Nonprod review) work **without** VMs.
>
> **💰 Lab cost:** ~NZD $5 / day with both B2s VMs running. **Stop both VMs in the portal between sessions** — stopped/deallocated VMs cost ~$0.30/day (storage only). Use `deploy-vms.ps1 -Cleanup` to remove them entirely.

---

## 🧭 What you'll learn

- How to deploy a small VM tier on top of the existing lab
- What the **Azure Monitor Agent (AMA)** is and how it differs from the older Log Analytics Agent
- What a **Data Collection Rule (DCR)** does and why AMA needs one
- How to verify VM telemetry in the workspace (Heartbeat, Perf, Syslog, Event)
- How to stop / start VMs to control cost between sessions

---

## 🧩 Concept refresher — AMA, DCR, and LAW

```
   ┌────────────────┐         ┌───────────────────────────┐
   │  vm-rhel-lab   │  AMA    │                           │
   │  vm-win-lab    │ ──────► │ Data Collection Rule      │
   │ (Standard_B2s) │         │  - Heartbeat              │
   └────────────────┘         │  - Perf counters          │
                              │  - Syslog (Linux)         │
                              │  - Event log (Windows)    │
                              └─────────────┬─────────────┘
                                            ▼
                              ┌───────────────────────────┐
                              │  Log Analytics workspace  │
                              │  la-dia-labs              │
                              │  (queried with KQL)       │
                              └───────────────────────────┘
```

| Component | What it is | Owned by |
|---|---|---|
| **AMA** (extension on the VM) | Agent process that ships telemetry | Installed by the VM extension |
| **DCR** (Data Collection Rule) | "Collect *these* signals at *this* rate, send to *that* workspace" | An Azure resource you create once and associate with N VMs |
| **DCRA** (DCR Association) | The link between a VM and a DCR | One per VM |

> [!IMPORTANT]
> AMA without a DCR collects nothing. The agent is just a transport — the DCR is the configuration that tells it what to gather. The deployment script handles both for you.

---

## ⌨️ Activity 1: Run the VM deployment script

```powershell
# From the assets/ folder
$pw = Read-Host -AsSecureString "Lab VM admin password"

./deploy-vms.ps1 -SubscriptionId "<your-sub-guid>" -VmAdminPassword $pw
```

The script will:

1. Create `vnet-dia-labs` (10.42.0.0/16) with a `snet-vms` subnet (10.42.1.0/24).
2. Create `vm-rhel-lab` (RHEL 9, B2s) and `vm-win-lab` (Windows Server 2022, B2s).
3. Install the AMA extension on each VM.
4. Create a DCR `dcr-dia-labs-vms` collecting Heartbeat + Perf + Syslog + Windows Event Log.
5. Associate the DCR with each VM.
6. Append the VM IDs and DCR ID to `lab-output.json`.

Expected runtime: ~10–15 minutes.

### Want only one VM?

Skip the one you don't need:

```powershell
# Linux only (cheaper if you only need Step 3 KQL practice)
./deploy-vms.ps1 -SubscriptionId "<guid>" -VmAdminPassword $pw -DeployWindows:$false

# Windows only
./deploy-vms.ps1 -SubscriptionId "<guid>" -VmAdminPassword $pw -DeployRhel:$false
```

---

## ⌨️ Activity 2: Verify the extension is installed

For each VM:

1. Portal → `vm-rhel-lab` → **Settings → Extensions + applications**.
2. Confirm `AzureMonitorLinuxAgent` is **Provisioning succeeded**.
3. Repeat for `vm-win-lab` (`AzureMonitorWindowsAgent`).

---

## ⌨️ Activity 3: Verify telemetry is flowing

Open `la-dia-labs` → **Logs**. Wait ~10 minutes after the script finishes, then run:

```kql
// 1. Are both VMs alive?
Heartbeat
| where TimeGenerated > ago(1h)
| summarize LastHeartbeat = max(TimeGenerated) by Computer
```

You should see both VMs with a `LastHeartbeat` within the last 5 minutes.

```kql
// 2. CPU samples landing?
Perf
| where TimeGenerated > ago(1h)
| where ObjectName == "Processor" and CounterName == "% Processor Time"
| summarize avg(CounterValue) by Computer, bin(TimeGenerated, 5m)
| render timechart
```

```kql
// 3. Linux syslog
Syslog
| where TimeGenerated > ago(1h)
| project TimeGenerated, Computer, Facility, SeverityLevel, ProcessName, SyslogMessage
| take 50
```

```kql
// 4. Windows event log
Event
| where TimeGenerated > ago(1h)
| project TimeGenerated, Computer, EventLog, EventLevel, RenderedDescription
| take 50
```

> [!TIP]
> No data? Check (a) VM is **Running** (not stopped), (b) the DCR association exists in **Monitor → Data Collection Rules → dcr-dia-labs-vms → Resources**, (c) wait another 5 minutes — first telemetry can take up to 15 minutes from VM start.

---

## ⌨️ Activity 4: Inspect the DCR in the portal

1. Portal → **Monitor → Data Collection Rules → `dcr-dia-labs-vms`**.
2. **Resources** blade — confirms both VMs are associated.
3. **Data sources** blade — shows what's being collected:
   - Performance counters (Linux + Windows)
   - Syslog (auth, cron, daemon, kern, syslog, user — Info+)
   - Windows Event Log (System + Application — Warning, Error, Critical)
4. **Destinations** blade — confirms the workspace target.

Try editing a data source (e.g. add a counter) and saving. Within ~5 minutes the new signal appears in the workspace.

---

## ⌨️ Activity 5: Stop the VMs to save cost

Between training sessions, **stop (deallocate)** both VMs:

```powershell
# Stop both VMs
Stop-AzVM -ResourceGroupName rg-dia-azure-labs -Name vm-rhel-lab -Force
Stop-AzVM -ResourceGroupName rg-dia-azure-labs -Name vm-win-lab  -Force
```

Or in the portal: VM → **Stop**. The VM moves to **Stopped (deallocated)** — compute charges stop, storage charges (~$0.15/disk/day) continue.

To restart for the next session: **Start** in the portal, or `Start-AzVM`.

---

## 🧹 Cleanup — remove just the VM tier

To remove the VMs, NICs, OS disks, and the lab VNet (but keep the storage account, workspace, and vault):

```powershell
./deploy-vms.ps1 -SubscriptionId "<your-sub-guid>" -Cleanup
```

To remove **everything** (VMs + storage + workspace + vault + RG), use the core script:

```powershell
./deploy-lab.ps1 -SubscriptionId "<your-sub-guid>" -Cleanup
```

---

## ✅ Success checklist

- [ ] `deploy-vms.ps1` ran without errors
- [ ] Both `AzureMonitorLinuxAgent` and `AzureMonitorWindowsAgent` show **Provisioning succeeded**
- [ ] `Heartbeat` returns rows for both VMs within the last 5 minutes
- [ ] `Perf`, `Syslog`, `Event` queries return data
- [ ] You've located the DCR and confirmed both VMs are associated
- [ ] You know how to stop the VMs to save cost between sessions

---

➡️ **Continue with:** [Step 2 — Azure Monitor fundamentals](step-2-azure-monitor.md) (the AMA-related activities will now have data to work with)

⬅️ **Back to:** [README](README.md)
