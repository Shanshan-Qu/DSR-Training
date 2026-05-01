# DIA Azure Labs — Digital Preservation Team

Hands-on labs that pair with the **DIA Azure Training Plan v3** prepared by Shanshan Qu (Microsoft NZ).
Format inspired by the [GitHub Skills](https://github.com/skills/customize-your-github-copilot-experience) tutorial style — short, opinionated, and repeatable.

> [!NOTE]
> These labs are written for the **Archives Library Digital Preservation Team** at DIA.
> They assume the **Rosetta** application context (RHEL 9.x + Windows Server 2022) inside the **Digital Storage and Resilience (DSR)** application landing zone.
>
> Source design documents (Storage Account Design v1-3, DPS Connection Detail v1-4, Application Landing Zone Design v1-4, Emma's feedback email) live in `local-docs/` on Shanshan's working copy and are git-ignored — they are not pushed to this repo.

---

## 👋 Welcome

| Item | Detail |
|------|--------|
| **Who is this for** | DIA Digital Preservation Team and new starters joining the team |
| **What you'll learn** | How to operate the Azure surface area that supports Rosetta — Monitor, KQL, Storage, Cost, Governance, the portal, and operational reporting |
| **What you'll build** | A working lab subscription with a Log Analytics workspace, two VMs, a Recovery Services vault, a storage account, alerts, a budget, saved KQL queries, an operations workbook, and a cost dashboard — all things you can re-create in production with confidence |
| **Prerequisites** | A non-production Azure subscription where you have `Contributor` and `User Access Administrator` at the resource-group scope; PowerShell 7+ or access to Cloud Shell; familiarity with the Azure portal |
| **How long** | About **14–17 hours** of hands-on time across 11 modules, plus optional Backup/RSV. You can pause between modules. |

---

## 🗺️ Lab map

| Step | Title | Lab time | Pairs with module | Est. lab cost (NZD) |
|-----:|-------|---------:|-------------------|--------------------:|
| **0** | [Environment setup](step-0-environment-setup.md) | 30 min | (run before Module 1) | $0 (no VMs by default) |
| **0b** | [Optional VM setup & monitoring](step-optional-vm-setup.md) **— OPTIONAL** | 30 min | (only if doing Step 2 AMA / Step 3 KQL on Heartbeat / Step 7 Backup) | ~$5 / day while VMs run |
| **1** | [Azure foundations & orientation](step-1-foundations.md) | 30 min | Module 1 | $0 (read-only portal) |
| **2** | [Azure Monitor fundamentals](step-2-azure-monitor.md) | 90 min | Module 2 | < $1 (LAW ingest) |
| **3** | [Must-know KQL](step-3-kql.md) | 90 min | Module 3 | < $1 (LAW queries) |
| **4** | [Cost Management & FinOps](step-4-cost-management.md) | 60 min | Module 4 | $0 (Cost Mgmt is free) |
| **5** | [Storage for preservation](step-5-storage.md) | 120 min | Module 5 | ~$2 (storage + transactions) |
| **6** | [Terraform on Azure (read-only)](step-6-terraform.md) | 60 min | Module 6 | $0 (no resource changes) |
| **7** | [Backup & Recovery Services vault](step-7-backup.md) **— OPTIONAL** | 60 min | Module 7 (optional) | ~$2 (vault storage + restore; **requires Step 0b**) |
| **8** | [Guardrails & Governance](step-8-governance.md) | 90 min | Module 8 | $0 |
| **9** | [Azure portal foundations](step-9-portal.md) | 60 min | Module 9 | $0 |
| **10** | [Nonprod environment review](step-10-nonprod-review.md) | 90 min | Module 10 | $0 (read-only review) |
| **11** | [Operational reporting & dashboards](step-11-reporting.md) **— NEW** | 90 min | Module 11 (new) | < $1 |

> [!TIP]
> **VMs are now opt-in.** The core `deploy-lab.ps1` no longer creates VMs — they live in a separate `deploy-vms.ps1`. If you skip Step 0b, the entire training series costs **under NZD $5**. With VMs included (Step 0b run, both VMs running for the full series), expect **under NZD $30** — stop the VMs in the portal between sessions and run `deploy-vms.ps1 -Cleanup` (or `deploy-lab.ps1 -Cleanup` for everything) at the end.

---

## ⏱️ EDE hours (effort estimates)

These are the EDE hours Shanshan books against the DIA engagement. They cover preparation, live delivery, lab support, Q&A, and follow-ups.

| Item | EDE hours |
|------|----------:|
| Training plan preparation, revisions, content review with Emma (one-off) | **8.0** |
| Per-module **lab preparation** buffer (slide refresh, lab dry-run, demo env validation) | **+2.5 each** |

Per-module breakdown (live delivery + 2.5 h prep, in EDE hours):

| Module | Live delivery | Prep | **EDE total per module** |
|--------|--------------:|-----:|-------------------------:|
| 1 — Foundations | 2.0 | 2.5 | **4.5** |
| 2 — Azure Monitor — Foundations | 2.0 | 2.5 | **4.5** |
| 3 — Azure Monitor — Hands-on Labs (KQL) | 3.0 | 2.5 | **5.5** |
| 4 — Visualisation for Azure Monitor | 2.0 | 2.5 | **4.5** |
| 5 — Storage for preservation | 3.0 | 2.5 | **5.5** |
| 6 — Cost Optimisation (light) | 1.5 | 2.5 | **4.0** |
| 7 — Visualisation for Cost Mgmt + Reporting (lab Step 11) | 2.0 | 2.5 | **4.5** |
| 8 — Terraform Uplifting Pt 1 | 2.0 | 2.5 | **4.5** |
| 9 — Terraform Uplifting Pt 2 | 2.0 | 2.5 | **4.5** |
| 10 — Guardrails & Governance | 2.0 | 2.5 | **4.5** |
| 11 — Azure portal foundations | 1.5 | 2.5 | **4.0** |
| 12 — Nonprod environment review | 1.5 | 2.5 | **4.0** |
| **Optional** — Backup / RSV (only billed if booked) | 1.5 | 2.5 | **4.0** |
| **Plan preparation (one-off)** | — | — | **8.0** |
| **TOTAL — core (excl. optional Backup)** | — | — | **~63 EDE hours** |
| **TOTAL — incl. optional Backup** | — | — | **~67 EDE hours** |

> Each "Prep" entry (2.5 h × 12 modules) covers slide refresh, lab dry-run on a clean subscription, validating Microsoft Learn links, and writing the per-module follow-up email. The 8 h plan preparation is the one-off planning, design, and content-review work for the whole engagement.

---

## 🧭 Backup / Recovery Services Vault — why it's optional

Per the responsibility split confirmed with Emma, **Recovery Services Vault (RSV) configuration, policy authoring, vault hardening, and backup health is owned by DIA Core Support / Datacom (Platform Landing Zone), not the Digital Preservation Team**. The Digital Preservation Team's day-to-day data protection responsibilities are:

- **Blob protective stack** — soft-delete, versioning, immutability, change feed → **fully covered in Step 5**.
- **Azure Files snapshots & soft-delete** for the 6 NFS + 2 SMB shares → **covered in Step 5**.
- **Reading backup health reports** and raising tickets when a Rosetta VM backup fails → covered in **Step 11 (Reporting)** via Backup Center scheduled email reports.

Step 7 (Backup & RSV configuration) is therefore **optional / self-study**. Recommended path for anyone who wants depth:

- Microsoft Learn — [Back up Azure VMs](https://learn.microsoft.com/training/modules/protect-virtual-machines-with-azure-backup/)
- Microsoft Learn — [Design a backup and disaster recovery strategy](https://learn.microsoft.com/training/modules/design-business-continuity-strategy/)
- The lab in [step-7-backup.md](step-7-backup.md) — runnable any time on the lab subscription.

> [!TIP]
> ❓ **Confirmation needed:** Please confirm with Emma that DIA Core Support / Datacom owns RSV. If the Preservation Team turns out to be on point for restores or backup-health sign-off, Step 7 should be moved back to **mandatory** and the EDE table updated to include the +4.0 hours.

---

## 📊 Operational reporting — what's new in v3

Emma asked for **scheduled and on-demand reporting** across cost, storage, and application health. The new [Step 11 — Operational reporting & dashboards](step-11-reporting.md) lab builds:

1. **Storage Cost & Forecast Dashboard** (Cost Management) — saved Cost analysis view grouped by storage account, 12-month forecast, scheduled CSV export to a Blob container, weekly email subscription.
2. **Data Movement Cost workbook** — Azure Monitor Workbook tracking egress, blob transactions, tier-change events (cost of the automated lifecycle moves), per Rosetta storage account.
3. **Rosetta Application Health Dashboard** — pinned tiles for VM heartbeat, blob delete spike alert state, file-share availability, key alert action-group state, recent backup job status.
4. **Backup Center scheduled email** — daily summary of vault job status, soft-deleted items, policy compliance.
5. **Recommended built-in reports** — Insights → Storage Insights, Insights → VM Insights, Azure Advisor cost recommendations, Defender for Storage alerts (if enabled).

Templates (workbook JSON, dashboard JSON, lifecycle rule JSON, KQL pack) are in `assets/`.

---

## 🔍 Gap analysis — Azure services in DSR design vs current training coverage

Reviewed against **DIA Azure Storage Account Design v1-3**, **DPS Connection Detail v1-4**, and **DSR DPS Application Landing Zone Design v1-4**. The following services appear in the design but were **not previously covered** (or only briefly mentioned). v3 of the plan addresses each.

| Service from design docs | Previous coverage | v3 status |
|---|---|---|
| Azure Files NFSv4 Premium (`stanlnznfile***rosi01`) | Step 5 — concept only | **Step 5 expanded** (snapshots, soft-delete, POSIX UID/GID auth model walked through) |
| Azure Files SMBv3 + Entra ID identity-based auth (`stanlnznfile***rosi02`) | Step 5 — concept only | **Step 5 expanded** + identity flow (DIA AD → Entra Connect Sync → domain-enabled storage account) |
| Azure Blob with Managed Identity (`stanlnznblob***rosi01`, `stanlnznblobprdwod01`) | Step 5 hands-on | ✅ Already covered |
| **Azure Blob NFSv3** (WOD container, `stct-wod-01`) — distinct from Azure Files NFS | Mentioned only | **Step 5 expanded** — explicitly contrasted with Files NFS |
| **blobfuse2** (PODMAN container mounts) | Mentioned in Step 5 | ✅ Already covered |
| **Private Endpoints + Private DNS Zones** for storage | Mentioned in Step 5 | **Optional Step 12 deep-dive — see below** |
| **Cross-subscription Private Link** (Test sub → Prod WOD blob) | Not covered | **Called out in Step 5 + Step 10 review checklist** |
| **Managed Identity** (system-assigned, on Rosetta VMs) | Mentioned | **Step 8 expanded** — RBAC deep-dive includes MI assignment patterns |
| **Microsoft Entra ID** (user auth for portal/Storage Explorer) | Mentioned | ✅ Covered in Step 1 + Step 8 |
| **Microsoft Entra Connect Sync** (DIA AD ↔ Entra ID for SMB share auth) | Not covered | **Step 5 — added concept walkthrough** (owned by Core Support; awareness only) |
| **Azure Key Vault** (Rosetta secrets, Terraform state encryption) | Mentioned in Module 7 plan | **Step 6 + Step 8 expanded** — Key Vault access policies vs RBAC, secret rotation awareness |
| **Azure Firewall** (egress control, Platform LZ) | Mentioned in Module 7 plan | **Step 8 — added as Core Support boundary** (awareness; not configured by Preservation Team) |
| **Application Gateway** (ingress to Rosetta web tiers) | Mentioned in Module 7 plan | **Step 8 — added as Core Support boundary** (awareness) |
| **Azure Recovery Services Vault** (VM backup) | Step 7 hands-on | **Marked OPTIONAL** — owned by Core Support |
| **Azure Backup Center** (cross-vault reporting) | Step 7 | **Moved to Step 11 (Reporting)** for the Preservation Team — read-only consumption |
| **Azure Cost Management + Billing** | Step 4 | ✅ Covered |
| **Cost Management exports** (scheduled to Blob, email subscription) | Briefly | **Step 11 hands-on added** |
| **Azure Monitor Workbooks** | Step 2 | **Step 11 expanded — custom storage workbook** |
| **Azure Monitor Logs / Log Analytics Workspace** | Step 2/3 | ✅ Covered |
| **Application Insights** | Step 2 | ✅ Covered |
| **Azure Monitor Agent (AMA)** on RHEL 9 + WS2022 | Step 2 | ✅ Covered |
| **Azure Policy** (compliance) | Step 8 | ✅ Covered |
| **Azure RBAC + Access Reviews** | Step 8 | ✅ Covered |
| **Resource Graph Explorer** | Step 9 | ✅ Covered |
| **Azure Storage Explorer** | Step 5 | ✅ Covered |
| **Microsoft Defender for Storage** (ransomware/malware alerts on Blob) | Not covered | **NEW — added to Step 8** as awareness (recommend Core Support enable; Preservation Team consumes alerts) |
| **Storage Insights** built-in workbook | Not covered | **NEW — added to Step 11** |
| **Network Watcher** (private endpoint connectivity diagnostics) | Not covered | Awareness only — optional Step 12 |
| **Azure Lifecycle Management** policies | Step 5 | ✅ Covered (and noted as Core Support–authored) |
| **PIM (Privileged Identity Management)** for elevation to write roles | Not covered | **NEW — added to Step 8** as awareness |

### Optional follow-on (Step 12 — Identity & Private Networking deep-dive)

Recommended but **not mandatory**. Some teams prefer Microsoft Learn self-study here. Topics:

- Private Endpoints + Private DNS Zones — how a private FQDN resolves
- Cross-subscription Private Link (Test → Prod WOD)
- Hybrid identity flow: DIA AD → Entra Connect → Entra ID → SMB share auth
- Managed Identity vs Service Principal — when to use which

Microsoft Learn substitutes:
- [Introduction to Azure Private Link](https://learn.microsoft.com/training/modules/introduction-azure-private-link/)
- [Implement hybrid identity](https://learn.microsoft.com/training/paths/implement-administer-hybrid-identity/)
- [Manage Microsoft Entra Connect](https://learn.microsoft.com/entra/identity/hybrid/connect/whatis-azure-ad-connect)

---

## 📖 Session overviews

Plain-language descriptions of each session — useful before your first session, and as a reference for new starters.

### Step 0 — Environment setup
Before any live training session, you run a small script that builds a self-contained sandbox in Azure. You only do this once and it takes about 30 minutes.

### Step 1 — Azure foundations & orientation
Where Rosetta lives in Azure, who owns what, and how to decode DIA's resource naming convention.

### Step 2 — Azure Monitor fundamentals
Logs vs metrics, the Log Analytics Workspace, AMA, alert rules, and your first Workbook — with a strong storage focus.
**Acronyms:** AMA = Azure Monitor Agent. LAW = Log Analytics Workspace. KQL = Kusto Query Language.

### Step 3 — Must-know KQL
Practical KQL library for the most common preservation scenarios: blob delete spikes (ransomware early warning), who-changed-what, backup failures, capacity trends.

### Step 4 — Cost Management & FinOps (light)
Reading cost trends, budget alerts, Reservation vs Savings Plan basics. **Tier movement is automated by DIA platform policies**, so this session is intentionally light.

### Step 5 — Storage for preservation
Blob protective stack (soft-delete, versioning, immutability, change feed), lifecycle policies, the three storage account types, Private Endpoints (concept), Azure File Share Snapshots, blobfuse2, Entra Connect Sync for SMB identity.

### Step 6 — Terraform on Azure (read-only)
Reading Terraform plan output, AzureRM vs AzAPI providers, remote state, and how the DSR codebase is structured. Self-paced Microsoft Learn alternative is fine here.

### Step 7 — Backup & Recovery Services vault — OPTIONAL
RSV is owned by Core Support. Lab is provided for self-study only — see "Backup / RSV — why it's optional" above.

### Step 8 — Guardrails & Governance
Azure Policy, RBAC, access reviews, PIM awareness, Managed Identity patterns, Defender for Storage alerts, where Core Support's boundary sits (Firewall, App Gateway, etc.).

### Step 9 — Azure portal foundations
Portal navigation, Resource Graph Explorer, dashboards, Cloud Shell — turns the portal from "click around" into an operations console.

### Step 10 — Nonprod environment review
Five-layer handover checklist (networking, storage, monitoring, data protection, governance) to use when the vendor hands over a Rosetta environment.

### Step 11 — Operational reporting & dashboards (NEW)
Builds the report set Emma asked for: storage cost & 12-month forecast, data-movement cost workbook, Rosetta application health dashboard, scheduled email exports, Backup Center daily summary, and recommended built-in Insights workbooks (Storage Insights, VM Insights).

---

## 🚀 How to start

1. Open [Step 0 — Environment setup](step-0-environment-setup.md).
2. Run `assets/deploy-lab.ps1` against your training subscription. It creates the core lab (workspace, storage, RSV) — **no VMs**.
3. _If you need VMs_ for Step 2 AMA activities, Step 3 KQL on Heartbeat/Perf, or the optional Step 7 Backup lab — run [Step 0b — Optional VM setup & monitoring](step-optional-vm-setup.md) which uses `assets/deploy-vms.ps1`. Otherwise skip it.
4. Work through the steps in order. Each step ends with a **Next step** link.
5. Slides and recordings from the live training sessions live in our DIA Teams channel — see the training plan for the link.
6. **If you ran the VM tier:** stop the VMs between sessions, and run `deploy-vms.ps1 -Cleanup` (or `deploy-lab.ps1 -Cleanup` for everything) when finished.

---

## 🧰 What's in this repo

```
DSR-Training/  (repo root)
├── README.md                       ← you are here
├── .gitignore                      ← excludes local-docs/ and loose docx/pdf
├── step-0-environment-setup.md     ← deploy the core lab (no VMs)
├── step-optional-vm-setup.md       ← OPTIONAL VM tier + AMA + DCR
├── step-1-foundations.md
├── step-2-azure-monitor.md
├── step-3-kql.md
├── step-4-cost-management.md
├── step-5-storage.md
├── step-6-terraform.md
├── step-7-backup.md                ← OPTIONAL (RSV owned by Core Support; needs Step 0b VMs)
├── step-8-governance.md
├── step-9-portal.md
├── step-10-nonprod-review.md       ← vendor handover checklist
├── step-11-reporting.md            ← NEW: dashboards, workbooks, scheduled reports
├── assets/
│   ├── deploy-lab.ps1               ← core lab (workspace + storage + RSV; NO VMs)
│   ├── deploy-vms.ps1               ← OPTIONAL VM tier (1 RHEL + 1 Windows + AMA + DCR)
│   ├── deploy-demo-env.ps1
│   └── kql-cheatsheet.md
└── local-docs/                     ← (git-ignored) source design docs, drafts, working scripts
```

---

## 🆘 Troubleshooting

| Symptom | Likely cause | First thing to try |
|---------|--------------|--------------------|
| `az login` succeeds but resources aren't visible | Wrong subscription selected | `az account set --subscription "<name>"` |
| Deployment script fails with `AuthorizationFailed` | Missing `User Access Administrator` on the lab RG | Ask DIA Core Support to add it (PIM elevation) |
| Log Analytics has no data after 15 min | AMA extension still installing on VMs | Re-check after 30 min; otherwise re-run Step 2 lab |
| Storage Explorer says "InsufficientAccountPermissions" | Missing **Storage Blob Data Contributor** | Add the role at storage-account scope, then sign out / in |
| Lab cost climbing | VMs left running between sessions | Stop both VMs in the portal, or run `deploy-lab.ps1 -Cleanup` |

---

> [!TIP]
> Every lab ends with a **Success checklist** and a **💰 Cost note**. Don't skip them — that's how you confirm the lab actually worked, and that you're not leaving cost meters running.

Happy preserving 🗄️
