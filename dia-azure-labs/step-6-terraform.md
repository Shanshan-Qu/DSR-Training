# Step 6 — Terraform on Azure (read-only)

_The infrastructure is code._ 🧱 You won't be writing a lot of Terraform day-to-day — DIA Core Support owns the platform repo. But you **will** read plan output, raise small change requests, and need to know the difference between **AzureRM** and **AzAPI** when something looks unfamiliar.

> [!NOTE]
> Time: ~60 minutes.
> Pairs with **Module 6** of the training plan.
> **Pre-req self-paced reading**: [Terraform on Azure](https://learn.microsoft.com/en-us/azure/developer/terraform/) and [HashiCorp – Terraform fundamentals](https://developer.hashicorp.com/terraform/tutorials/azure-get-started). Do these *before* the live session.

---

## 🧭 What you'll learn

- The structure of a typical Azure Terraform module
- How to read a `terraform plan` safely — without running an apply
- The difference between the **AzureRM** and **AzAPI** providers, and why DIA uses both
- Where the **remote state** lives and why you don't touch it directly

---

## 🧩 Concept refresher — providers

| Provider | Maintained by | Coverage | When you'll see it |
|---|---|---|---|
| `azurerm` | HashiCorp | Most stable Azure resources | 90% of the DIA codebase |
| `azapi` | Microsoft | Anything with an ARM REST API, including preview features | New / preview services where AzureRM hasn't caught up |

In a single module you may see both: AzureRM for the storage account, AzAPI for a brand-new feature on it.

---

## ⌨️ Activity 1: Set up Terraform locally

You can do this in Cloud Shell (Terraform is pre-installed) or locally.

```bash
# Cloud Shell already has it
terraform version

# Local (Windows / Mac):
# winget install Hashicorp.Terraform     ← Windows
# brew install terraform                 ← Mac
```

Make a working folder:

```bash
mkdir ~/dia-tf-lab && cd ~/dia-tf-lab
```

---

## ⌨️ Activity 2: A tiny mixed-provider module

Create `main.tf`:

```hcl
terraform {
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 3.110" }
    azapi   = { source = "Azure/azapi",       version = "~> 1.13"  }
  }
}

provider "azurerm" { features {} }
provider "azapi"   {}

variable "rg_name"     { default = "rg-dia-azure-labs" }
variable "location"    { default = "australiaeast" }
variable "container_name" { default = "tf-demo" }

# AzureRM — looks up the storage account the deployment script created
data "azurerm_storage_account" "lab" {
  name                = "<replace-with-your-stdialabs-account>"
  resource_group_name = var.rg_name
}

# AzureRM — creates a new container
resource "azurerm_storage_container" "demo" {
  name                  = var.container_name
  storage_account_name  = data.azurerm_storage_account.lab.name
  container_access_type = "private"
}

# AzAPI — applies a tag using the raw ARM API
resource "azapi_update_resource" "tag" {
  type        = "Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01"
  resource_id = azurerm_storage_container.demo.resource_manager_id

  body = jsonencode({
    properties = {
      metadata = {
        purpose = "terraform-lab"
        owner   = "preservation-team"
      }
    }
  })
}

output "container_url" {
  value = "https://${data.azurerm_storage_account.lab.name}.blob.core.windows.net/${azurerm_storage_container.demo.name}"
}
```

> [!TIP]
> Replace `<replace-with-your-stdialabs-account>` with the actual storage-account name from your `lab-output.json`.

---

## ⌨️ Activity 3: `init` and `plan` — but **not** `apply`

```bash
az login
az account set --subscription "<your-sub-guid>"

terraform init
terraform plan -out=lab.tfplan
```

Read the plan output carefully. You should see:

- `+` `azurerm_storage_container.demo` → **Plan to create**
- `+` `azapi_update_resource.tag` → **Plan to create**
- `Plan: 2 to add, 0 to change, 0 to destroy.`

> [!IMPORTANT]
> A safe code review looks for **destroy** lines. `0 to destroy` = safe. Anything else, **stop and ask** what's about to be deleted before approving the change.

If you want to actually apply (optional):

```bash
terraform apply lab.tfplan
```

…and at the end:

```bash
terraform destroy -auto-approve
```

---

## ⌨️ Activity 4: Inspect what the state file looks like

Terraform stores its understanding of "what exists" in a state file. **Never edit the state file by hand.**

```bash
# Local file in your lab
cat terraform.tfstate | head -40
```

In production, the DIA platform repo uses **remote state** in an Azure Storage account, with state-locking via the same storage account. The relevant `backend` block looks like:

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-tfstate"
    storage_account_name = "stdiatfstate"
    container_name       = "tfstate"
    key                  = "rosetta/prod.terraform.tfstate"
  }
}
```

- The `key` is the **path to the state file** within the container.
- State-locking prevents two engineers running `apply` at the same time.
- **DIA Core Support owns this storage account** — you don't write to it directly.

---

## 🦾 Now your turn!

Open the **DIA platform Terraform repo** (your colleague will share the URL — it's not public).

1. Find the module that defines the Rosetta production storage account.
2. Identify which provider is used to create the storage account (AzureRM or AzAPI).
3. Identify any `data` resource (read-only lookup) vs. `resource` (managed) blocks.
4. Find where the **lifecycle** rules live — are they in the same file, or imported from a shared module?

Bring your findings to the live session — we'll walk through them together.

---

## ✅ Success checklist

- [ ] You can run `terraform version`, `terraform init`, `terraform plan`
- [ ] Your `plan` output for the lab module shows `2 to add, 0 to destroy`
- [ ] You can describe in one sentence the difference between AzureRM and AzAPI
- [ ] You know where DIA's remote state lives and that you **don't** modify it directly
- [ ] You've located the Rosetta storage-account module in the DIA repo and noted what provider it uses

---

➡️ **Next step:** [Step 7 — Backup & Recovery Services vault](./step-7-backup.md)
