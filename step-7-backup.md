# Step 7 — Backup & Recovery Services vault — **OPTIONAL**

_The "if all else fails" lab._ 🛟 RSV configuration, vault hardening, and backup-policy authoring at DIA is **owned by Core Support / Datacom**, not the Digital Preservation Team. This lab is therefore **optional / self-study**. Run it any time on the lab subscription if you want hands-on familiarity for restore drills, or if the responsibility split changes.

> [!NOTE]
> Time: ~60 minutes.
> Pairs with **Module 7 (optional)** of the training plan v3.
>
> **💰 Lab cost:** ~NZD $2 if you run a single on-demand backup of `vm-rhel-lab` and remove it within 24 h. Vault storage is billed per GB/month of recovery-point data; first backup of a small VM is < $0.20 of storage + < $0.05 of restore traffic. **Disable backup on the protected item before tearing the lab down**, otherwise the recovery points keep accruing storage cost for the policy retention window (default 30 days).

---

## 🧭 What you'll learn

- How to enrol a VM into a Recovery Services vault with a backup policy
- How to trigger an **on-demand backup** and an **item-level restore**
- How to enable **soft-delete** and **immutable** vault settings
- How to use **Backup Center** for cross-vault reporting

---

## 🧩 Concept refresher — the pieces

```
Recovery Services Vault
├── Backup policy (frequency, retention, immutability)
│   └── Protected item: vm-rhel-lab
│       ├── Recovery point — 2026-04-29 03:00  (daily)
│       ├── Recovery point — 2026-04-28 03:00
│       └── ...
└── Soft-delete: 14 days (default)
```

| Concept | What it does |
|---|---|
| **Backup policy** | Defines schedule, retention, snapshot consistency |
| **Recovery point** | A point-in-time backup — what you restore from |
| **Soft-delete** | If a recovery point is deleted, it's kept for 14 extra days |
| **Immutable vault** | Stops the policy retention from being **shortened** for the immutability window — protection against ransomware |
| **Cross-region restore** | Restore from a paired region (Australia East ↔ Australia Southeast) |

---

## ⌨️ Activity 1: Harden the vault

Before backing anything up, lock the vault down.

1. Portal → `rsv-dia-labs` → **Properties → Security Settings → Update**.
2. **Soft delete**: Enabled, 14 days. (Default — confirm it's on.)
3. **Multi-User Authorization (MUA)**: leave OFF in lab. In production, **turn it on** — it requires a second person from a different team to approve destructive operations.
4. **Immutability**: set to **Locked** for production vaults. For the lab, set **Unlocked** so you can clean up afterwards.
5. Save.

> [!IMPORTANT]
> "Locked immutability" cannot be reversed. Use **Unlocked** while you're getting comfortable with the feature, then **Locked** when you're sure of your retention policy.

---

## ⌨️ Activity 2: Define a backup policy

1. Portal → `rsv-dia-labs` → **Manage → Backup policies → + Add → Azure Virtual Machine**.
2. Name: `pol-vm-daily-30d`.
3. Backup schedule: **Daily, 03:00 NZST**.
4. Retention:
   - Daily recovery points: **30 days**
   - Weekly: leave default
   - Monthly / yearly: leave default for the lab
5. Save.

This is a tiny example. Production preservation VMs typically have daily for 30 days + weekly for 12 weeks + monthly for 24 months.

---

## ⌨️ Activity 3: Enrol a VM and run an on-demand backup

1. Portal → `rsv-dia-labs` → **Backup → + Backup**.
2. Workload: **Azure**, type: **Virtual machine**.
3. Pick policy: `pol-vm-daily-30d`.
4. Add VMs: tick `vm-rhel-lab`.
5. Enable backup. Wait ~3 minutes.
6. Once enrolled, open the **Backup item** for `vm-rhel-lab` → **Backup now**.
7. Pick a retention date 7 days from now (the lab won't run long enough for the daily schedule to kick in).
8. Trigger.

Expect ~10–20 minutes for the first backup. Watch progress under **Backup jobs**.

---

## ⌨️ Activity 4: Restore a single file

This is the operation you'll do most often in production.

1. Backup item → `vm-rhel-lab` → **File recovery**.
2. **Step 1 — Select recovery point**: pick the one you just created.
3. **Step 2 — Download script**: download the script Azure generates (it's tiny, sets up an iSCSI mount).
4. Run the script on **vm-win-lab** (or your laptop). It mounts the recovery point as a drive letter (Windows) or device (Linux).
5. Browse the mounted drive → copy any file out (e.g., `/etc/hostname` on the Linux backup, or `C:\Windows\System32\drivers\etc\hosts` on a Windows VM).
6. Back in the portal, click **Unmount disks** when finished.

> [!TIP]
> The mount script **expires after 12 hours**. Don't lose track of it — if you forget to unmount, the recovery point stays "checked out" until it auto-cleans.

---

## ⌨️ Activity 5: Backup Center reporting

1. Portal → search **Backup center** → open it.
2. **Backup instances** → filter by your subscription. You see every protected item across every vault.
3. **Backup jobs** → confirm your on-demand backup completed successfully.
4. **Reports** → **+ New report** → **Summary**.
   - Time range: last 7 days
   - Vaults: `rsv-dia-labs`
   - Configure email subscription → daily.

That email is what the team / leadership receives as the "scheduled backup report" Emma asked about.

---

## 🦾 Now your turn!

Write a one-page **monthly backup health checklist** that someone on the team would run on the first business day of each month. Include:

- Are all expected items still protected?
- Have any backups failed in the last 30 days?
- Is the policy retention still appropriate? (Has anything been changed?)
- Has anyone touched soft-delete / immutability settings?

Hint: Backup Center's **Reports** view answers most of these without leaving one blade.

---

## ✅ Success checklist

- [ ] Vault soft-delete is enabled (14 days)
- [ ] Vault immutability is **Unlocked** (lab) or **Locked** (you'd do this in prod)
- [ ] Backup policy `pol-vm-daily-30d` exists
- [ ] `vm-rhel-lab` is a protected item with a successful backup
- [ ] You've performed a successful file-level restore
- [ ] You've configured a daily Backup Center summary report
- [ ] You've drafted a monthly health checklist

---

➡️ **Continue with:** [Step 8 — Guardrails & Governance](step-8-governance.md)
