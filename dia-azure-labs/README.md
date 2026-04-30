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
└── assets/
    ├── deploy-lab.ps1              ← PowerShell lab deployment
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
