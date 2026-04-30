# Step 1 — Azure foundations & orientation

_Welcome to the first lab!_ 🎉 This one is short — it's a guided walk-through to make sure everyone has the same mental model of where Rosetta sits in DIA's Azure platform, and which team holds the pen for what.

> [!NOTE]
> Time: ~30 minutes.
> Pairs with **Module 1** of the training plan.

---

## 🧭 What you'll learn

- How **Management groups → Subscriptions → Resource groups → Resources** stack up at DIA
- Where the **Digital Storage and Resilience** application landing zone sits in that tree
- Which Azure operations the **Digital Preservation team owns directly**, and which go to **DIA Core Support** or **Service Desk (Datacom)**
- How to find help when you're stuck

---

## 🧩 Concept refresher

Azure resources live in a four-level hierarchy. From the top:

```
Tenant (microsoft.com / dia.govt.nz)
└── Management groups          ← policy & guardrails applied here
    └── Subscriptions          ← billing boundary
        └── Resource groups    ← lifecycle boundary (deploy / delete together)
            └── Resources      ← the actual VM, storage account, etc.
```

For Rosetta:

| Level | Owned by | Example |
|-------|----------|---------|
| Management group | DIA Core Support | `mg-dia-app-platform` |
| Subscription | DIA Core Support | `sub-dia-dsr-prod` |
| Resource group | Shared (you operate, they provision) | `rg-rosetta-prod` |
| Resources | Digital Preservation team (day-to-day) | Storage accounts, VMs |

> [!TIP]
> If a request involves changing the structure (a new subscription, a new policy, network peering), it's a **Core Support** task. If it involves changing what's *inside* a resource group (a new container, a tag, a backup policy), that's likely **yours**.

---

## ⌨️ Activity 1: Map your way around the portal

1. Open **portal.azure.com**.
2. Use the search box at the top to find **Management groups**. Open it.
3. Note where your lab subscription sits in the tree. (Expect: under a tenant root → an org-wide group → a "non-prod" or "sandbox" group.)
4. Now find **Subscriptions** → pick your training subscription → **Resource groups** → `rg-dia-azure-labs`.
5. Pin **Resource groups** to your portal favourites (the ⭐ at the left edge).

---

## ⌨️ Activity 2: Spot the team boundary

For each resource in `rg-dia-azure-labs`, decide who would normally own changes to it in **production** (not the lab). Fill in the table mentally — we'll review answers in the live session.

| Resource | Day-to-day operation owner | Provisioning / structural changes |
|----------|---------------------------|-----------------------------------|
| Storage account `stdialabsXXXX` | ? | ? |
| Container `rosetta-objects` | ? | ? |
| Recovery Services vault `rsv-dia-labs` | ? | ? |
| VNet / subnet (look in the RG) | ? | ? |
| Azure Policy assignment on the subscription | ? | ? |

> [!TIP]
> A useful rule: "I can change it in the portal without raising a ticket" usually means the team owns it. "I can see it but every change needs a Terraform PR" usually means Core Support owns the source of truth.

---

## ⌨️ Activity 3: Find the right help channel

Bookmark these — you'll use them throughout the labs.

| Need | Channel |
|------|---------|
| Production incident or pager-style alert | DIA Service Desk (Datacom) ticket — they route to L2/L3 |
| Question about a policy / RBAC / subscription structure | DIA Core Support team |
| "How do I do X with Rosetta on Azure?" during this training | The DIA Teams channel for the training series |
| Microsoft documentation | [https://learn.microsoft.com/en-us/azure/](https://learn.microsoft.com/en-us/azure/) |

---

## 🦾 Now your turn!

Pick **one** real Rosetta-on-Azure task you've done in the last month (e.g. "I rotated a container access key", "I asked someone to change a backup retention").
Decide which team owns it. Bring the example to the live session — we'll walk through the boundary together.

---

## ✅ Success checklist

- [ ] You can navigate Management groups → Subscriptions → Resource groups in the portal
- [ ] You've pinned **Resource groups** to your favourites
- [ ] You can articulate which lab resource you "own" vs. who provisions / structurally manages it
- [ ] You know which channel to use for: an incident, a structural change request, a "how do I" question

---

➡️ **Next step:** [Step 2 — Azure Monitor fundamentals](./step-2-azure-monitor.md)
