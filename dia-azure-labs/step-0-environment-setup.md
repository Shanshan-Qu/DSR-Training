# Step 0 — Environment setup

_Welcome!_ 👋 Before any of the live training sessions, we deploy a small **lab environment** so we can spend session time on what matters — the Azure capabilities that support Rosetta — instead of clicking through provisioning wizards.

> [!NOTE]
> Time: ~30 minutes (mostly waiting for Azure to provision resources).
> You only need to do this **once** for the whole training series.

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
├── VM: vm-rhel-lab                  (Linux, Standard_B2s)
├── VM: vm-win-lab                   (Windows, Standard_B2s)
└── Tags: env=lab, owner=preservation-team, costcentre=archives
```

Both VMs have the **Azure Monitor Agent (AMA)** installed and are linked to the Log Analytics workspace, so data flows from minute one.

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
  [string]$VmAdminUser   = "labadmin",
  [securestring]$VmAdminPassword,
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

# 3. Run the deployment (will prompt for a VM admin password)
./deploy-lab.ps1 -SubscriptionId "<your-sub-guid>"
```

Expect ~12–18 minutes. The script writes progress as it goes:

```
[10:32] Creating resource group rg-dia-azure-labs in australiaeast ... done
[10:33] Creating Log Analytics workspace la-dia-labs ... done
[10:34] Creating storage account stdialabs7421 ... done
[10:35] Creating Recovery Services vault rsv-dia-labs ... done
[10:36] Creating Linux VM vm-rhel-lab ... (this takes a while)
[10:42] Creating Windows VM vm-win-lab ...
[10:48] Installing Azure Monitor Agent on both VMs ...
[10:51] Writing lab-output.json
Done. Lab is ready.
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
2. You should see ~12 resources (VMs, NICs, disks, vault, workspace, storage, etc.).
3. Open `vm-rhel-lab` → **Monitoring → Insights**. Within 15 minutes you should see CPU and memory charts.
4. Open `la-dia-labs` → **Logs**. Run `Heartbeat | take 10` — you should get rows back from both VMs.

---

## ✅ Success checklist

- [ ] `rg-dia-azure-labs` exists and contains the resources listed above
- [ ] Both VMs report **Running**
- [ ] Log Analytics returns Heartbeat rows for both VMs
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
