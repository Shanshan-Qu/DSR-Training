# Step 8 — Guardrails & Governance

_What stops you from doing the wrong thing — and what you're expected to police yourself._ 🛡️ This module exists because Emma's feedback specifically asked for it: understanding the platform guardrails, the visibility you have, and the access reviews you're expected to perform.

> [!NOTE]
> Time: ~90 minutes.
> Pairs with **Module 8** of the training plan.

---

## 🧭 What you'll learn

- How to read which **Azure Policies** apply to you and why a deployment was denied
- How to read your assigned **RBAC** at the right scope (subscription / RG / resource)
- How to perform an **access review** on a Rosetta-related group
- The difference between guardrails the **platform applies to you** vs. governance **you're expected to perform**

---

## 🧩 Concept refresher — three governance primitives

| Primitive | What it does | Owned by |
|---|---|---|
| **Azure Policy** | Allow / deny / audit resource configurations | Mostly DIA Core Support; you may have read-only |
| **RBAC** (role assignments) | Who can do what on which scope | Shared — platform sets baseline, you grant team-level roles |
| **Access reviews** (Entra ID) | Periodic re-certification of group membership and roles | Group owners (often you, for Rosetta-related groups) |

---

## ⌨️ Activity 1: List the policies that apply to your subscription

1. Portal → search **Policy** → open it.
2. **Compliance** → confirm your subscription scope.
3. You'll see all policy **assignments** that apply, grouped by initiative (e.g. "Azure Security Benchmark").
4. Click into one assignment → read its **definition**. Each policy has:
   - **Effect**: `Audit`, `Deny`, `DeployIfNotExists`, `Modify`, `AuditIfNotExists`
   - **Parameters**: e.g. allowed regions, required tags
   - **Compliance state**: which of your resources match / don't match

> [!TIP]
> If a deployment fails with `RequestDisallowedByPolicy`, the error message **names the policy that blocked you**. Search the policy name in this blade to read why.

---

## ⌨️ Activity 2: Trigger a policy denial intentionally

We'll try to deploy a resource that breaks a common policy — usually an "allowed regions" policy.

```bash
# Try to create a storage account in a region that's likely blocked
az storage account create \
  --name "stdiaforbidden$RANDOM" \
  --resource-group rg-dia-azure-labs \
  --location "westus2" \
  --sku Standard_LRS
```

If a region restriction is in place, you'll see something like:

```
The resource action 'Microsoft.Storage/storageAccounts/write' is disallowed
by one or more policies. Policy identifiers: ['<policy-id>'].
```

Take that policy ID → look it up in the Policy blade → confirm what it does and at which scope it's assigned.

> [!NOTE]
> If your lab subscription doesn't enforce a region policy, this command will **succeed**. That's fine — clean it up: `az storage account delete -n <name> -g rg-dia-azure-labs --yes`.

---

## ⌨️ Activity 3: Read your own RBAC

1. Portal → `rg-dia-azure-labs` → **Access control (IAM) → Role assignments**.
2. Filter to **your account**. Note: you might inherit roles from a higher scope.
3. **Check access** tab → enter your account → see the **effective** roles at this scope.

Things to look for:

- Are you `Owner` (probably too much in production) or `Contributor` + `User Access Administrator` (more typical)?
- Are any roles assigned at **subscription** scope when they could be RG-scoped? (Least privilege says scope down.)

---

## ⌨️ Activity 4: Grant least-privilege roles on the storage account

We'll grant **Storage Blob Data Contributor** to a colleague at the storage-account scope only — exactly the role they need for Rosetta operations, no more.

1. Portal → `stdialabsXXXX` → **Access control (IAM) → + Add → Add role assignment**.
2. Role: **Storage Blob Data Contributor**.
3. Members: pick a colleague from your team (or yourself for the lab).
4. Save.
5. Verify with:

```bash
az role assignment list \
  --assignee "<their-email>" \
  --scope $(az storage account show -g rg-dia-azure-labs --query "[0].id" -o tsv) \
  --output table
```

> [!TIP]
> **Storage Blob Data Contributor** ≠ **Storage Account Contributor**. The first lets you read/write data; the second lets you change account settings. Use the data role for day-to-day operators.

---

## ⌨️ Activity 5: Schedule an access review

Access reviews live in **Microsoft Entra ID** (formerly Azure AD).

1. Portal → search **Identity Governance** → **Access reviews → + New access review**.
2. Resource: pick a security group (in production, `sg-rosetta-operators` or similar; in the lab, any group you own).
3. Reviewers: **Group owners** (you).
4. Frequency: **Quarterly**.
5. Duration: 14 days.
6. Settings:
   - Auto-apply results: **Yes**
   - If reviewers don't respond: **Remove access**
   - Justification required: **Yes**
7. Create.

You've just committed yourself (and any other group owner) to confirming every quarter that each member still belongs in the group. **This is what "performing an access review" looks like in practice.**

---

## 🦾 Now your turn!

In your Module 8 deliverable, draft a **one-page Plain-English Policy Summary** for the team. For each policy assigned to your training subscription:

- What does it actually prevent or require?
- When would a preservation operator hit it?
- If you hit it, who do you contact?

Share the doc with Shanshan and Emma.

---

## ✅ Success checklist

- [ ] You can list every policy assigned to your training subscription, with its effect
- [ ] You've intentionally triggered (or attempted) a policy denial and read the error message
- [ ] You can recite your own RBAC at the lab RG scope
- [ ] You've granted **Storage Blob Data Contributor** to a colleague at storage-account scope only
- [ ] An access review is scheduled on a group you own, with auto-apply on
- [ ] You've drafted a Plain-English Policy Summary

---

➡️ **Next step:** [Step 9 — Azure portal foundations](./step-9-portal.md)
