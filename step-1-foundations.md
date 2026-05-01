# Step 1 — Azure foundations & orientation

_Welcome to the first lab!_ 🎉 This one is short — it's a guided walk-through to make sure everyone has the same mental model of where Rosetta sits in DIA's Azure platform, and which team holds the pen for what.

> [!NOTE]
> Time: ~30 minutes.
> Pairs with **Module 1** of the training plan v3.
>
> **💰 Lab cost:** $0 — read-only portal navigation only.

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

## 🧩 Storage account naming convention

When you look at production resources you'll encounter names like `stanlnznfileprdrosi01`. They follow a deliberate pattern — decode it once and every name becomes self-explanatory:

```
st  an  lnzn  file  prd  rosi  01
│   │    │     │     │    │    └── sequence number
│   │    │     │     │    └─────── workload  (rosi = Rosetta, wod = Web of Documents)
│   │    │     │     └──────────── environment (prd / uat / dev)
│   │    │     └────────────────── service type (file = Azure Files, blob = Blob)
│   │    └────────────────── region token (lnzn = Azure NZ North, aue = Australia East)
│   └───────────────────── team/org prefix (an = **ANL = Archive National Library**)
└─────────────────────── resource type prefix (st = storage account)
```

The lab account `stdialabsXXXX` uses a simplified pattern (`st` + `dia` + `labs` + random suffix). The `XXXX` suffix is added by the deployment script to guarantee global uniqueness.

---

## 🧩 Naming conventions — the full pattern

All DSR Azure resources follow the standard defined in the **DIA DSR DPS Azure Application Landing Zone Design** document. The default format (where no DIA-specific standard already exists) is:

```
<slug>-<org_code>-<region>-<service>-<env>-<##>
```

| Token | What it means | Examples |
|---|---|---|
| `slug` | Resource type abbreviation (from DIA naming standards or Microsoft CAF) | `st` storage account, `rg` resource group, `vnet` virtual network, `agw` app gateway, `rsv` recovery services vault |
| `org_code` | Organisation / project code | `dia` (DIA), `anl` (**ANL = Archive National Library**) |
| `region` | Azure region abbreviation | `nzn` Azure NZ North, `aue` Australia East |
| `service` | Workload or application name | `rosi` Rosetta, `wod` Whole of Domain, `file` Files, `blob` Blob |
| `env` | Environment (3 lowercase chars) | `prd` Production, `uat` UAT / Test, `dev` Development, `trn` Training |
| `##` | Sequence number | `01`, `02` … |

**Resource Group naming** — resource groups follow a separate standard that groups resources by function:

| Purpose | Pattern | Example |
|---|---|---|
| Network resources | `rg-dia-anl-nzn-net-<env>` | VNets, NSGs, load balancers |
| Storage resources | `rg-dia-anl-nzn-stor-<env>` | Storage accounts, Log Analytics workspaces |
| Virtual machines | `rg-dia-anl-nzn-app-<env>` | VMs and their managed disks |
| Services | `rg-dia-anl-nzn-svc-<env>` | Function Apps, Logic Apps |
| Management | `rg-dia-anl-nzn-mgt-<env>` | Key Vaults, Recovery Services Vaults, Monitor dashboards |

> [!TIP]
> **ANL** throughout the DIA naming and resource estate stands for **Archive National Library** — the team / business unit that owns the Archives NZ and National Library workloads in the DSR landing zone. You will see `anl` in nearly every resource name you look up.

---

## 🏷️ Tagging standards

Every Azure resource in the DSR landing zone **must** carry the following six tags. Azure Policy enforces this — a resource deployed without the required tags will be flagged as non-compliant (and in Production, blocked at deploy time via Terraform validation).

| Tag key | Description | Example value | Required? |
|---|---|---|---|
| `app_name` | Application / workload name | `anl` | **Yes** |
| `org_name` | Organisation short form | `dia` | **Yes** |
| `cost_centre` | Finance cost centre number | `{number}` | **Yes** |
| `env` | Deployment environment | `dev` \| `tst` \| `uat` \| `prd` | **Yes** |
| `owner` | Responsible owner email address | `{email}` | **Yes** |
| `severity` | Business impact if unavailable | `high` \| `medium` \| `low` | **Yes** |

> [!IMPORTANT]
> **Tagging is how cost reports and governance dashboards work.** Without consistent tags:
> - The storage-cost forecast in Step 11 can't group by owner or environment.
> - Azure Policy compliance shows non-compliant.
> - Automated cost exports group everything as "untagged", making it impossible to allocate charges to the right team.
>
> Tags are applied by Terraform and enforced by Azure Policy. If you ever create a resource manually in the portal (for testing), **add the six tags immediately**.

### Lab tags (what the deployment script sets)

The `deploy-lab.ps1` script tags all lab resources with:

```json
{
  "app_name":    "anl",
  "org_name":    "dia",
  "cost_centre": "training",
  "env":         "trn",
  "owner":       "<your-email>",
  "severity":    "low"
}
```

These are intentionally lightweight for the training environment — in production the `env` would be `prd` and `severity` would be `high` for preservation-critical storage accounts.

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
