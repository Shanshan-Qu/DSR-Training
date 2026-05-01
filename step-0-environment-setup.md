# Step 0 — Environment setup

_Welcome!_ 👋 Before any of the live training sessions, we deploy a small **lab environment** so we can spend session time on what matters — the Azure capabilities that support Rosetta — instead of clicking through provisioning wizards.

> [!NOTE]
> Time: ~30 minutes (mostly waiting for Azure to provision resources).
> You only need to do this **once** for the whole training series.
>
> **💰 Lab cost:** ~NZD $5 / day while the two B2s VMs are running. **Stop both VMs between sessions** (portal → VM → Stop) to drop cost to ~$0.30/day (storage only). Run `deploy-lab.ps1 -Cleanup` at the end of the series to delete everything. Total cost across the whole series stays under NZD $30 if you stop VMs between sessions.

---

## 🎯 What you'll build

A self-contained sandbox in your training subscription:

```
rg-dia-azure-labs/
├── Log Analytics workspace          (la-dia-labs)
├── Application Insights             (appi-dia-labs)
├── Storage account (Blob, LRS)      (stdialabsXXXX)
│   ├── container: rosetta-objects   (Hot)
│   └── container: rosetta-archive   (Cool — lifecycle target)
├── Recovery Services vault          (rsv-dia-labs)
└── Tags: app_name=anl, org_name=dia, env=trn, owner=<you>, severity=low, cost_centre=training
```

> [!NOTE]
> **VMs are NOT created by the core deployment script** — they are optional and live in a separate `deploy-vms.ps1`.
>
> Add the VM tier (1 RHEL 9 + 1 Windows Server 2022, both with the **Azure Monitor Agent (AMA)** + a **Data Collection Rule**) only if you plan to do:
> - Step 2 — "Verify AMA is working" + the heartbeat alert
> - Step 3 — KQL queries against `Heartbeat`, `Perf`, `Syslog`, `Event`
> - Step 7 — Backup & Recovery Services vault (optional self-study)
>
> All other labs (Storage, KQL against `StorageBlobLogs`, Cost, Reporting, Governance, Portal, Nonprod review) work **without** VMs. See [step-optional-vm-setup.md](step-optional-vm-setup.md) for the VM tier instructions.

---

## ✅ Before you start

You'll need:

- [ ] A non-production Azure subscription
- [ ] `Contributor` + `User Access Administrator` at the lab resource-group scope (or the subscription)
- [ ] **PowerShell 7+** with the `Az` module, **OR** access to Azure Cloud Shell
- [ ] Approval to deploy in **Australia East** (default region — closest to NZ for latency)

If you don't have the right RBAC, raise a request with the DIA Core Support team — that's outside the Digital Preservation team's scope.

---

## ⌨️ Activity 1: Get the deployment script

1. Download `assets/deploy-lab.ps1` from this folder onto your laptop, or open it in Cloud Shell.
2. Open it in VS Code (or any editor) and read the parameters at the top — every option has a sensible default. The only thing you usually change is `-SubscriptionId` and `-Location`.

```powershell
# Top of deploy-lab.ps1 — these are the parameters you can override
param(
  [string]$SubscriptionId,
  [string]$ResourceGroup = "rg-dia-azure-labs",
  [string]$Location      = "australiaeast",
  [switch]$Cleanup
)
```

> [!TIP]
> The script is **idempotent** — if you run it twice, the second run is a no-op for resources that already exist. Safe to re-run if your laptop loses Wi-Fi mid-deploy.

---

## ⌨️ Activity 2: Sign in and run it

```powershell
# 1. Sign in (interactive)
Connect-AzAccount

# 2. Confirm you're on the right subscription
Get-AzContext

# 3. Run the core deployment (no VMs are created)
./deploy-lab.ps1 -SubscriptionId "<your-sub-guid>"
```

Expect ~3–5 minutes. The script writes progress as it goes:

```
[10:32] Creating resource group rg-dia-azure-labs in australiaeast ... done
[10:33] Ensuring Log Analytics workspace law-dia-labs ... done
[10:34] Ensuring Application Insights appi-dia-labs ... done
[10:34] Ensuring storage account stdialabs7421 ... done
[10:35] Ensuring Recovery Services vault rsv-dia-labs ... done
[10:35] Writing lab-output.json
Core lab deployed (no VMs).
```

### Optional: add VMs

If you also want the VM tier (only needed for Step 2 AMA activities, Step 3 KQL on Heartbeat/Perf, and the optional Step 7 Backup lab), run the **separate** VM script after this one finishes. Full instructions in [step-optional-vm-setup.md](step-optional-vm-setup.md):

```powershell
$pw = Read-Host -AsSecureString "Lab VM admin password"
./deploy-vms.ps1 -SubscriptionId "<your-sub-guid>" -VmAdminPassword $pw
```

---

## ⌨️ Activity 3: Send the output file to Shanshan

The script writes `lab-output.json` to the current directory. It contains the resource IDs and names — no secrets — and lets me sanity-check that everything is reachable before our first live lab.

```powershell
# Open it to see what's inside
code lab-output.json
```

Email it to **shanshanqu@microsoft.com** with subject `DIA Lab Ready - <your-name>`.

---

## 🦾 Now your turn!

Confirm the lab is healthy by clicking through the portal:

1. Go to **Resource groups → rg-dia-azure-labs**.
2. You should see ~5 resources without VMs (workspace, App Insights, storage account, vault, plus the auto-created storage for App Insights). If you also ran `deploy-vms.ps1` you'll see ~10 more (VNet, NICs, OS disks, VMs, DCR).
3. Open `la-dia-labs` → **Logs**. Run `AzureActivity | take 10` — you should get rows from the deployment itself.
4. _If you deployed VMs:_ Run `Heartbeat | take 10` — you should get rows from both VMs within ~10 minutes of `deploy-vms.ps1` finishing.

---

## ✅ Success checklist

- [ ] `rg-dia-azure-labs` exists and contains: workspace, App Insights, storage account, RSV
- [ ] Log Analytics returns rows from `AzureActivity | take 10`
- [ ] _Optional:_ if you ran `deploy-vms.ps1`, both VMs report **Running** and `Heartbeat | take 10` returns rows
- [ ] Storage account has the two containers `rosetta-objects` and `rosetta-archive`
- [ ] Recovery Services vault is created and empty (no backup items yet)
- [ ] You've emailed `lab-output.json` to Shanshan

---

## 🧹 Tearing it down

When the training series finishes, run:

```powershell
./deploy-lab.ps1 -Cleanup -SubscriptionId "<your-sub-guid>"
```

This deletes the resource group and everything in it. You'll be asked to type the RG name to confirm.

---

➡️ **Next step:** [Step 1 — Azure foundations & orientation](./step-1-foundations.md)
