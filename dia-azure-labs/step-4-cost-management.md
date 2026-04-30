# Step 4 — Cost Management & FinOps

_Money in, money out._ 💰 The team's existing tier-management script already handles most optimisation, so this lab focuses on the parts you do interactively: **cost views with forecasting**, **budgets**, and **understanding the difference between Reservations and Savings Plans**.

> [!NOTE]
> Time: ~60 minutes.
> Pairs with **Module 4** of the training plan.

---

## 🧭 What you'll learn

- How to build a Cost analysis view that **forecasts** your next month's spend — including storage-specific filtering
- How to set a **budget** with multi-threshold alerts (50% / 80% / 100%)
- When to use a **Reservation** vs. a **Savings Plan** vs. on-demand pricing (for VMs)
- How to schedule a **cost export** for monthly reporting

> [!IMPORTANT]
> **How DIA manages storage tiers:** At DIA, movement of Blob data between Hot, Cool, and Cold tiers is managed automatically by **Azure Lifecycle Management policies and platform scripts** — you do not manually move data between tiers. The lifecycle policies are defined in Terraform by DIA Core Support and deploy to all Rosetta storage accounts. This lab includes a lifecycle activity (Step 5) so you understand what the policies do, but you should not add or change lifecycle rules on production accounts without a change request. The focus in this step is on **reading and forecasting costs**, not on optimising tier placement.

---

## 🧩 Concept refresher — Reservations vs. Savings Plans

Both are pre-commitments that buy you a discount on compute. The differences matter for Rosetta.

| | **Reservation** | **Savings Plan** |
|---|---|---|
| Commitment | Specific VM SKU + region (e.g. `D4s v5` in `australiaeast`) | Compute spend in $/hour, any region |
| Term | 1 or 3 years | 1 or 3 years |
| Flexibility | Low — locked to SKU | High — auto-applies to whatever you run |
| Discount | ~30–60% | ~11–28% |
| Best for | **Steady workload, known SKU** (Rosetta production VMs) | **Variable / changing workloads** |

**Plain-English rule of thumb for Rosetta:**
- The Rosetta primary VMs run 24x7 on a known SKU → **Reservation** wins on price.
- Dev/test VMs that are turned on and off → **Savings Plan** if there's enough $/hour to commit, otherwise on-demand.

---

## ⌨️ Activity 1: Build a forecasting cost view

1. Portal → search **Cost Management + Billing** → open it.
2. Pick the **Billing scope** (your training subscription).
3. **Cost analysis** → **+ New** → **Customize**.
4. Granularity: **Daily**.
5. Group by: **Resource group**.
6. Filter: `Resource group = rg-dia-azure-labs`.
7. Date range: **This month + Forecast**. ← this is what gives you the dotted forecast line.
8. Save view as **DIA Lab — daily with forecast**.
9. Pin it to the same `Preservation Operations` dashboard you started in Step 3.

> [!TIP]
> The forecast uses up to 3 months of historical data + a confidence band. With a brand-new lab subscription it'll be wobbly. In production it's surprisingly accurate for steady workloads like Rosetta.

---

## ⌨️ Activity 1b: Storage growth forecast

Forecast storage costs specifically — filtering out compute noise:

1. Cost Management → **Cost analysis → + New → Customize**.
2. Granularity: **Daily**.
3. Group by: **Resource**.
4. Filter: `Resource type = Microsoft.Storage/storageAccounts`.
5. Date range: **Last 3 months + Forecast**.
6. Save view as **DIA Lab — storage growth forecast**.
7. Pin to the `Preservation Operations` dashboard.

This view answers: "How fast is storage spend growing, and what does it look like next quarter?" In production, use this to validate that lifecycle policies are actually reducing costs as blobs age out of Hot tier.

---

## ⌨️ Activity 2: Create a budget with three alert thresholds

1. Cost Management → **Budgets → + Add**.
2. Scope: subscription. Name: `bud-rg-dia-azure-labs-monthly`.
3. Reset period: **Monthly**, start this month.
4. Amount: pick a small number that's plausible for your lab — e.g. **NZD 100**.
5. Alert conditions:
   - 50% actual → email yourself
   - 80% actual → email yourself + your team's distribution list
   - 100% **forecasted** → email + Service Desk queue
6. Save.

> [!IMPORTANT]
> Note the difference between **actual** thresholds (you've spent X already) and **forecasted** thresholds (we project you'll hit X). Forecast alerts give you time to act; actual alerts tell you the horse has already left the barn.

---

## ⌨️ Activity 3: Look at Reservation / Savings Plan recommendations

> [!NOTE]
> **Scope:** Reservations and Savings Plans apply to **compute (VMs)** at DIA — not storage. Storage costs are optimised by the automated lifecycle policies described above. This activity is relevant for the Rosetta primary VMs (which run 24x7 on a known SKU and are strong Reservation candidates).

1. Cost Management → **Reservations → Add → Browse all products**.
2. Pick **Virtual Machines**, region **Australia East**, your VM family.
3. Read the recommended quantity and the projected savings — Azure does this math for you based on the last 7 / 30 / 60 days of usage.

> [!NOTE]
> A brand-new lab won't have enough history to recommend anything. **Don't actually buy a reservation in the lab subscription.** The point is to see where the recommendations show up so you know where to look in production.

For Savings Plans:

1. Cost Management → **Savings plans → + Add → Browse all products**.
2. See the same shape of recommendation — but for committed compute spend rather than a SKU.

---

## ⌨️ Activity 4: Schedule a cost export

This satisfies the "scheduled reports" part of Emma's feedback.

1. Cost Management → **Exports → + Create**.
2. Type: **Daily export of month-to-date costs**.
3. Storage account: your lab `stdialabsXXXX` → container: create one called `cost-exports`.
4. File format: CSV. Compression: none.
5. Schedule: daily.
6. Save.

After 24 hours, browse `cost-exports/` in Storage Explorer — you'll see a CSV per day. That's the file you'd hand to Power BI or Excel for monthly reporting.

> [!TIP]
> Pair this with **Module 7's Backup Center reports** to give leadership a single monthly view of "what we spent" and "what we backed up."

---

## 🦾 Now your turn!

Build a second cost view that's grouped by **Tag → owner**. Your lab resources are tagged `owner=preservation-team`. In production, that view becomes a showback report — "this is what each team's stuff costs."

Save it as **By owner — month to date**.

---

## ✅ Success checklist

- [ ] `DIA Lab — daily with forecast` view exists, pinned to your dashboard
- [ ] `DIA Lab — storage growth forecast` view exists (filtered to storage accounts), pinned to your dashboard
- [ ] You can explain why storage tier management at DIA is automated and not done manually
- [ ] Budget `bud-rg-dia-azure-labs-monthly` exists with three alert thresholds
- [ ] You've located (not bought) the Reservation and Savings Plan recommendation pages and understand they apply to VMs, not storage
- [ ] A daily cost export is scheduled to `cost-exports/`
- [ ] You've built and saved a **By owner** cost view

---

➡️ **Next step:** [Step 5 — Storage for preservation](./step-5-storage.md)
