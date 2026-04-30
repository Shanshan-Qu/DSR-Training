# Step 9 — Azure portal foundations

_Tying it all together._ 🧰 You've used the portal in nearly every previous step. This final lab steps back and turns those one-off clicks into a **personalised operations console** — the home page you'll open every morning to check on Rosetta.

> [!NOTE]
> Time: ~60 minutes.
> Pairs with **Module 9** of the training plan.

---

## 🧭 What you'll learn

- How to build and pin a **dashboard** for the preservation team
- How to use **Resource Graph Explorer** to query across every resource you can see
- How to make **bookmarks / favourites** in the portal so the things you need are one click away
- How to use **Cloud Shell** as your default place to run `az`, `kubectl`, and `terraform`

---

## 🧩 Concept refresher — the four "find your stuff" tools

| Tool | Best for |
|---|---|
| **Top search bar** | "I know its name" — jumps straight to a resource |
| **Favourites (left rail)** | Services you open daily (Storage accounts, Monitor, Cost Management) |
| **Dashboards** | A pinned, shared visual snapshot — KPIs, charts, alerts |
| **Resource Graph Explorer** | "Find every resource where X is true" across many subscriptions |

Use all four. The home page is just the surface — you can completely re-shape it.

---

## ⌨️ Activity 1: Curate your favourites

1. Portal → left rail → **All services**.
2. Hover over each service → click the **star** to favourite:
   - Storage accounts
   - Virtual machines
   - Recovery Services vaults
   - Monitor
   - Log Analytics workspaces
   - Cost Management + Billing
   - Resource Graph Explorer
   - Policy
   - Microsoft Entra ID
3. Drag them into the order you want.

That's now your default left rail across every Azure session — independent of which subscription you're working in.

---

## ⌨️ Activity 2: Build the Preservation Operations dashboard

You started this in Step 3. Now finish it.

1. Portal home → **Dashboard** (top) → **+ New dashboard → Blank dashboard** → name it `Preservation Operations`.
2. Add the following tiles by going to each blade and clicking **Pin to dashboard**:

| Tile | Source blade |
|---|---|
| Heartbeat health (KQL) | Log Analytics workspace → query → Pin |
| Storage account capacity | `stdialabsXXXX` → Metrics → Used capacity |
| Cost — daily with forecast | Cost Management → your saved view |
| Cost — by owner | Cost Management → your saved view |
| Backup jobs (last 24 h) | Backup Center → Backup jobs |
| Recent alerts | Monitor → Alerts → all severities |
| Active policy denials (KQL) | LAW → query: `AzureActivity \| where ActivityStatusValue == "Failed" and OperationNameValue contains "policy"` |

3. Arrange them in a logical reading order — top-left = "is the system alive?" → bottom-right = "is it expensive?".
4. **Share** the dashboard with the team via **Share → Publish**. Pick a resource group (`rg-dia-azure-labs` or a shared one) for it to live in.

> [!TIP]
> Shared dashboards are themselves Azure resources (`Microsoft.Portal/dashboards`). They're versioned in JSON and can be deployed via Bicep / Terraform. Once you've got a layout the team likes, ask DIA Core Support to commit it to the platform repo.

---

## ⌨️ Activity 3: Resource Graph Explorer

This is the single most under-used portal feature. It lets you query every resource across every subscription you can see, with a SQL-like language.

1. Portal → **Resource Graph Explorer**.
2. Run:

```kusto
Resources
| where type == "microsoft.storage/storageaccounts"
| project name, resourceGroup, location, sku.name, properties.allowBlobPublicAccess
| order by name asc
```

You'll see every storage account you have access to, including which ones still allow public blob access (a common audit finding).

A few more useful ones:

```kusto
// All VMs and their power state
Resources
| where type == "microsoft.compute/virtualmachines"
| project name, resourceGroup, location, properties.hardwareProfile.vmSize
| order by name asc

// Resources missing a required tag
Resources
| where tags['owner'] == "" or isnull(tags['owner'])
| project name, type, resourceGroup
```

> [!TIP]
> Resource Graph queries are cached and **fast**. They're the right tool for "show me everything that…" questions. Activity Log queries (Step 3 KQL) are the right tool for "what happened…" questions.

---

## ⌨️ Activity 4: Cloud Shell as your default terminal

1. Portal top bar → click the **Cloud Shell** icon (`>_`).
2. First time only: it asks you to attach a storage account for your `~/clouddrive`. Pick `stdialabsXXXX` → it creates a small file share for you.
3. Pick **Bash** (you can switch later). Inside, run:

```bash
az --version
terraform version
kubectl version --client
pwsh --version
```

All four are pre-installed. You can write small scripts, drop them in `~/clouddrive`, and they'll be there next session.

> [!TIP]
> Cloud Shell sessions time out after 20 minutes of inactivity, but anything in `~/clouddrive` survives. Use it for the lab; in production, prefer your own laptop with `az login` so you have proper version control of your scripts.

---

## ⌨️ Activity 5: One-click access — keyboard shortcuts

The portal's keyboard shortcuts will save you minutes a day:

| Shortcut | What it does |
|---|---|
| `G + /` | Focus the search bar |
| `G + N` | Open notifications |
| `G + D` | Open dashboard |
| `G + A` | All resources |
| `G + R` | Resource groups |
| `G + B` | Open the Cloud Shell |
| `G + .` | Settings |

Try them. They work on every page.

---

## 🦾 Now your turn!

Take screenshots of:

1. Your finished `Preservation Operations` dashboard.
2. A Resource Graph Explorer query that finds **anything in your training subscription that doesn't have an `owner` tag**.

Drop both into your Module 9 deliverable doc and share with Shanshan.

---

## ✅ Success checklist

- [ ] Your portal favourites list reflects what you actually use daily
- [ ] `Preservation Operations` dashboard exists, with at least 5 tiles, and is shared with the team
- [ ] You can write and run a Resource Graph Explorer query
- [ ] You've used Cloud Shell at least once and have `~/clouddrive` set up
- [ ] You know at least three portal keyboard shortcuts by heart

---

## 🎓 You're done!

You've now completed all nine labs. Together they cover everything in the **DIA Azure Training Plan v2**. From here:

- Apply the lessons to a small piece of real Rosetta-related work — e.g. write a one-page runbook for a real incident scenario, using your dashboard, KQL queries, and Backup Center.
- Schedule your **Module 9 → AZ-104** prep window with Shanshan.
- Keep iterating on your dashboard — the best operators have one that's evolved over months.

Welcome to running cloud workloads at DIA. 🛡️

---

⬅️ **Back to:** [Lab index](./README.md)
