# DIA Azure Labs — Digital Preservation Team

Hands-on labs that pair with the **DIA Azure Training Plan v2** prepared by Shanshan Qu (Microsoft NZ).
Format inspired by the [GitHub Skills](https://github.com/skills/customize-your-github-copilot-experience) tutorial style — short, opinionated, and repeatable.

> [!NOTE]
> These labs are written for the **Archives Library Digital Preservation Team** at DIA.
> They assume the **Rosetta** application context (RHEL 9.x + Windows Server 2022) inside the **Digital Storage and Resilience** application landing zone.

---

## 👋 Welcome

| Item | Detail |
|------|--------|
| **Who is this for** | DIA Digital Preservation Team and new starters joining the team |
| **What you'll learn** | How to operate the Azure surface area that supports Rosetta — Monitor, KQL, Storage, Cost, Backup, Terraform, Governance, and the portal itself |
| **What you'll build** | A working lab subscription with a Log Analytics workspace, two VMs, a Recovery Services vault, a storage account, alerts, a budget, and saved KQL queries — all things you can re-create in production with confidence |
| **Prerequisites** | A non-production Azure subscription where you have `Contributor` and `User Access Administrator` at the resource-group scope; PowerShell 7+ or access to Cloud Shell; familiarity with the Azure portal |
| **How long** | About 12–14 hours of hands-on time, spread across 9 modules. You can pause between modules. |

---

## 🗺️ Lab map

| Step | Title | Time | Pairs with module |
|-----:|-------|------|-------------------|
| **0** | [Environment setup](./step-0-environment-setup.md) | 30 min | (run before Module 1) |
| **1** | [Azure foundations & orientation](./step-1-foundations.md) | 30 min | Module 1 |
| **2** | [Azure Monitor fundamentals](./step-2-azure-monitor.md) | 90 min | Module 2 |
| **3** | [Must-know KQL](./step-3-kql.md) | 90 min | Module 3 |
| **4** | [Cost Management & FinOps](./step-4-cost-management.md) | 60 min | Module 4 |
| **5** | [Storage for preservation](./step-5-storage.md) | 120 min | Module 5 |
| **6** | [Terraform on Azure (read-only)](./step-6-terraform.md) | 60 min | Module 6 |
| **7** | [Backup & Recovery Services vault](./step-7-backup.md) | 60 min | Module 7 |
| **8** | [Guardrails & Governance](./step-8-governance.md) | 90 min | Module 8 |
| **9** | [Azure portal foundations](./step-9-portal.md) | 60 min | Module 9 |
| **10** | [Nonprod environment review](./step-10-nonprod-review.md) | 90 min | Module 10 |

---

## 📖 Session overviews

Plain-language descriptions of each session — useful before your first session, and as a reference for new starters.

### Step 0 — Environment setup
Before any live training session, you run a small script that builds a self-contained sandbox in Azure. Think of it as getting your workbench ready. You only do this once and it takes about 30 minutes (mostly waiting for Azure to provision things). After this step, every other lab just works.

### Step 1 — Azure foundations & orientation
This session answers the question: "Where does Rosetta live in Azure, and who owns what?" It introduces the four-level resource hierarchy (tenant → management group → subscription → resource group), shows you where the Digital Storage and Resilience (DSR) landing zone sits in that tree, and explains which tasks belong to the Digital Preservation team versus DIA Core Support. You'll also learn how to decode Azure resource names using DIA's naming convention.

### Step 2 — Azure Monitor fundamentals
This session introduces how Azure keeps track of what's happening across your systems — with a strong focus on storage and the Rosetta application. You'll learn the difference between **logs** (what happened, e.g. who deleted a blob), **metrics** (how things are performing, e.g. storage latency), and how they flow into a central **Log Analytics workspace (LAW)**. You'll turn on diagnostic settings so blob operations appear as queryable events, create an alert that emails the team when a VM goes silent, and build your first Azure Monitor Workbook — a reusable, shareable operations dashboard.

**Key acronyms:** AMA = Azure Monitor Agent (software that runs inside a VM and ships data to the Log Analytics workspace). LAW = Log Analytics Workspace (the central store where all logs live). KQL = Kusto Query Language (the query language you use to ask questions of the Log Analytics workspace — covered in depth in Step 3).

### Step 3 — Must-know KQL
KQL (Kusto Query Language) is the query language for Log Analytics — think of it like SQL for Azure logs. This session gives you a practical library of copy-paste queries for the most common preservation scenarios: detecting mass blob deletes (ransomware early warning), tracking who changed what in a storage account, finding backup job failures, and spotting capacity trends. You'll save these queries to a shared workspace so the whole team can reuse them.

### Step 4 — Cost Management & FinOps
This session shows you how to see, understand, and forecast Azure costs — specifically the storage and compute costs that matter most for Rosetta. At DIA, storage tier movement (Hot → Cool → Cold) is automated by platform policies and scripts, so you won't be manually moving blobs. The focus here is on reading cost trends, setting budget alerts so unexpected spend is caught early, and understanding when a Reservation (long-term VM commitment) makes financial sense.

### Step 5 — Storage for preservation
The session that maps most directly to your day-to-day work. You'll explore how the three production storage account types (Azure Files NFS, Azure Files SMB, and Azure Blob) each serve a different part of the Rosetta workflow. Using the lab Blob account, you'll hands-on exercise the full protective stack: soft-delete, versioning, immutability (legal hold), lifecycle policies, and the change feed audit log. You'll also learn about Private Endpoints (why production storage is locked to the VNet) and Azure File Share Snapshots (the 31-day rolling recovery point for NFS and SMB shares).

### Step 6 — Terraform on Azure (read-only)
DIA Core Support owns the Terraform codebase for the DSR landing zone. You won't be writing Terraform day-to-day, but you will need to read plan output, understand what a proposed change will do, and raise informed change requests. This session demystifies the structure of a Terraform module, explains the difference between the `azurerm` and `azapi` providers, and shows you where remote state lives. **If your team prefers self-paced learning first**, the free [Terraform on Azure](https://learn.microsoft.com/en-us/azure/developer/terraform/) path on Microsoft Learn covers the same concepts and can be done instead of (or before) this session.

### Step 7 — Backup & Recovery Services vault
This session makes you comfortable with Azure Backup as the safety net for Rosetta's VMs and file shares. You'll configure a backup policy, run an on-demand backup, restore a single file without rolling back the whole VM, and explore Backup Center — the cross-vault reporting view that shows you backup health at a glance. You'll also understand how immutable vault settings protect backup data from ransomware.

### Step 8 — Guardrails & Governance
This session directly addresses the team's three governance responsibilities: understanding which Azure Policies apply to you and why a deployment was denied; reading and verifying role assignments (RBAC) at the right scope; and performing Entra ID access reviews — the periodic process of re-certifying who still needs access to Rosetta-related groups. After this session you'll know the difference between guardrails the platform enforces on you and governance you're expected to run yourself.

### Step 9 — Azure portal foundations
A short, practical session that turns the portal from "a place you click around in" into a personalised operations console. You'll build a shared "Preservation Operations" dashboard, learn to use Resource Graph Explorer to query resources across multiple subscriptions, and set up portal favourites so the services you use daily are always one click away. You'll also learn how to use Cloud Shell as a built-in terminal without needing to install anything on your laptop.

### Step 10 — Nonprod environment review
The vendor has finished deploying the DSR nonprod environment. This session is a structured walkthrough of what was actually built — confirming the design is correctly implemented before the team takes operational ownership. You'll work through five layers (networking, storage, monitoring, data protection, governance) using a formal handover checklist, and produce a one-page sign-off report. A demo environment script (`assets/deploy-demo-env.ps1`) is provided so you can practice the review technique against a safe replica before touching the real nonprod environment.

---

## 🚀 How to start

1. Open [Step 0 — Environment setup](./step-0-environment-setup.md).
2. Run the provided PowerShell script `assets/deploy-lab.ps1` against your training subscription. It creates everything the labs need.
3. When the script finishes, work through the steps in order. Each step ends with a **Next step** link.
4. Slides and recordings from the live training sessions live in our DIA Teams channel — see the training plan for the link.

---

## 🧰 What's in this folder

```
dia-azure-labs/
├── README.md                       ← you are here
├── step-0-environment-setup.md     ← deploy the lab
├── step-1-foundations.md
├── step-2-azure-monitor.md
├── step-3-kql.md
├── step-4-cost-management.md
├── step-5-storage.md
├── step-6-terraform.md
├── step-7-backup.md
├── step-8-governance.md
├── step-9-portal.md
├── step-10-nonprod-review.md       ← vendor handover checklist
└── assets/
    ├── deploy-lab.ps1              ← PowerShell lab deployment (generic training lab)
    ├── deploy-demo-env.ps1         ← PowerShell demo env (mirrors Rosetta nonprod design)
    └── kql-cheatsheet.md           ← must-know KQL one-pager
```

---

## 🆘 Troubleshooting

| Symptom | Likely cause | First thing to try |
|---------|--------------|--------------------|
| `az login` succeeds but resources aren't visible | Wrong subscription selected | `az account set --subscription "<name>"` |
| Deployment script fails with `AuthorizationFailed` | Missing `User Access Administrator` on the lab RG | Ask your DIA Core Support contact to add it (PIM elevation) |
| Log Analytics has no data after 15 min | AMA extension still installing on VMs | Re-check after 30 min; otherwise re-run Step 2 lab |
| Storage Explorer says "InsufficientAccountPermissions" | Missing **Storage Blob Data Contributor** | Add the role at storage-account scope, then sign out / in |

If you hit something not on this list, raise it with Shanshan or via the Service Desk (Datacom) ticket queue.

---

> [!TIP]
> Every lab ends with a **Success checklist**. Don't skip it — that's how you confirm the lab actually worked, and it's what the next step builds on.

Happy preserving 🗄️
