<#
.SYNOPSIS
    Deploys the DIA Azure training lab environment (no VMs).

.DESCRIPTION
    Creates a self-contained training lab in your Azure subscription:
      - Resource group (rg-dia-azure-labs)
      - Log Analytics workspace + Application Insights
      - Storage account with two containers (rosetta-objects, rosetta-manifests)
      - Recovery Services vault

    VMs are NOT created by this script. If you want VMs (for Step 2 AMA / heartbeat
    activities or for the optional Backup lab), run 'deploy-vms.ps1' as a separate
    step. See 'step-optional-vm-setup.md' for full instructions.

    Uses your existing Azure CLI / PowerShell login. Does not change subscription
    defaults outside the run.

.PARAMETER SubscriptionId
    Target subscription GUID. Required.

.PARAMETER ResourceGroup
    Resource group name. Default: rg-dia-azure-labs.

.PARAMETER Location
    Azure region. Default: australiaeast.

.PARAMETER Cleanup
    Switch. Deletes the lab resource group and everything in it (including any VMs
    deployed by deploy-vms.ps1). No deploy.

.EXAMPLE
    # Deploy the core lab (no VMs)
    ./deploy-lab.ps1 -SubscriptionId 00000000-0000-0000-0000-000000000000

.EXAMPLE
    # Clean up everything in the lab RG (storage, LAW, vault, AND VMs if any)
    ./deploy-lab.ps1 -SubscriptionId 00000000-0000-0000-0000-000000000000 -Cleanup

.NOTES
    Idempotent: re-running over an existing lab updates in place.
    Output: writes ./lab-output.json with all resource names, IDs, and the workspace ID.
    Send that file to Shanshan once your lab is up.
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory=$true)]
    [string]$SubscriptionId,

    [string]$ResourceGroup = "rg-dia-azure-labs",
    [string]$Location      = "australiaeast",

    [switch]$Cleanup
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

#--------------------------------------------------------------------
# Module check
#--------------------------------------------------------------------
$required = @('Az.Accounts','Az.Resources','Az.Storage','Az.OperationalInsights',
              'Az.ApplicationInsights','Az.RecoveryServices')
foreach ($m in $required) {
    if (-not (Get-Module -ListAvailable -Name $m)) {
        throw "Required module '$m' is missing. Install with: Install-Module $m -Scope CurrentUser"
    }
}

#--------------------------------------------------------------------
# Sign-in
#--------------------------------------------------------------------
$ctx = Get-AzContext -ErrorAction SilentlyContinue
if (-not $ctx -or $ctx.Subscription.Id -ne $SubscriptionId) {
    Connect-AzAccount -SubscriptionId $SubscriptionId | Out-Null
}
Set-AzContext -SubscriptionId $SubscriptionId | Out-Null
Write-Host "Subscription: $((Get-AzContext).Subscription.Name)"

#--------------------------------------------------------------------
# Cleanup path
#--------------------------------------------------------------------
if ($Cleanup) {
    if (Get-AzResourceGroup -Name $ResourceGroup -ErrorAction SilentlyContinue) {
        if ($PSCmdlet.ShouldProcess($ResourceGroup, "Delete resource group and ALL resources (including VMs)")) {
            Write-Host "Deleting $ResourceGroup ..."
            Remove-AzResourceGroup -Name $ResourceGroup -Force | Out-Null
            Write-Host "Done."
        }
    } else {
        Write-Host "Resource group $ResourceGroup not found. Nothing to do."
    }
    return
}

#--------------------------------------------------------------------
# Naming + standard tags (CAF + DIA tagging standard, see step-1-foundations.md)
#--------------------------------------------------------------------
$suffix    = -join ((48..57) + (97..122) | Get-Random -Count 4 | ForEach-Object {[char]$_})
$staName   = "stdialabs$suffix"
$lawName   = "law-dia-labs"
$aiName    = "appi-dia-labs"
$rsvName   = "rsv-dia-labs"
$tags      = @{
    app_name    = "anl"
    org_name    = "dia"
    cost_centre = "training"
    env         = "trn"
    owner       = (Get-AzContext).Account.Id
    severity    = "low"
}

#--------------------------------------------------------------------
# Resource group
#--------------------------------------------------------------------
$rg = Get-AzResourceGroup -Name $ResourceGroup -ErrorAction SilentlyContinue
if (-not $rg) {
    Write-Host "Creating resource group $ResourceGroup in $Location ..."
    $rg = New-AzResourceGroup -Name $ResourceGroup -Location $Location -Tag $tags
}

#--------------------------------------------------------------------
# Log Analytics + App Insights
#--------------------------------------------------------------------
Write-Host "Ensuring Log Analytics workspace $lawName ..."
$law = Get-AzOperationalInsightsWorkspace -ResourceGroupName $ResourceGroup -Name $lawName -ErrorAction SilentlyContinue
if (-not $law) {
    $law = New-AzOperationalInsightsWorkspace -ResourceGroupName $ResourceGroup `
        -Name $lawName -Location $Location -Sku PerGB2018 -RetentionInDays 30 -Tag $tags
}

Write-Host "Ensuring Application Insights $aiName ..."
$ai = Get-AzApplicationInsights -ResourceGroupName $ResourceGroup -Name $aiName -ErrorAction SilentlyContinue
if (-not $ai) {
    $ai = New-AzApplicationInsights -ResourceGroupName $ResourceGroup -Name $aiName `
        -Location $Location -WorkspaceResourceId $law.ResourceId -Kind web -Tag $tags
}

#--------------------------------------------------------------------
# Storage account + containers
#--------------------------------------------------------------------
Write-Host "Ensuring storage account $staName ..."
$sta = Get-AzStorageAccount -ResourceGroupName $ResourceGroup -Name $staName -ErrorAction SilentlyContinue
if (-not $sta) {
    $sta = New-AzStorageAccount -ResourceGroupName $ResourceGroup -Name $staName `
        -Location $Location -SkuName Standard_LRS -Kind StorageV2 `
        -AllowBlobPublicAccess $false -MinimumTlsVersion TLS1_2 -Tag $tags
}
$ctxSta = $sta.Context
foreach ($c in @("rosetta-objects","rosetta-manifests")) {
    if (-not (Get-AzStorageContainer -Context $ctxSta -Name $c -ErrorAction SilentlyContinue)) {
        New-AzStorageContainer -Context $ctxSta -Name $c -Permission Off | Out-Null
        Write-Host "  Container created: $c"
    }
}

#--------------------------------------------------------------------
# Recovery Services vault
#--------------------------------------------------------------------
Write-Host "Ensuring Recovery Services vault $rsvName ..."
$rsv = Get-AzRecoveryServicesVault -ResourceGroupName $ResourceGroup -Name $rsvName -ErrorAction SilentlyContinue
if (-not $rsv) {
    $rsv = New-AzRecoveryServicesVault -ResourceGroupName $ResourceGroup -Name $rsvName `
        -Location $Location -Tag $tags
}

#--------------------------------------------------------------------
# Output JSON
#--------------------------------------------------------------------
$out = [ordered]@{
    SubscriptionId        = $SubscriptionId
    ResourceGroup         = $ResourceGroup
    Location              = $Location
    LogAnalyticsWorkspace = @{ Name = $law.Name; Id = $law.ResourceId; CustomerId = $law.CustomerId }
    AppInsights           = @{ Name = $ai.Name;  Id = $ai.Id }
    StorageAccount        = @{ Name = $sta.StorageAccountName; Id = $sta.Id }
    RecoveryVault         = @{ Name = $rsv.Name; Id = $rsv.ID }
    Tags                  = $tags
    GeneratedAt           = (Get-Date).ToString("o")
    Note                  = "VMs are NOT included. Run deploy-vms.ps1 if you want them."
}
$outFile = Join-Path -Path (Get-Location) -ChildPath "lab-output.json"
$out | ConvertTo-Json -Depth 6 | Out-File -FilePath $outFile -Encoding utf8

Write-Host ""
Write-Host "========================================"
Write-Host " Core lab deployed (no VMs)."
Write-Host " Output written to: $outFile"
Write-Host ""
Write-Host " Next steps:"
Write-Host "   - For VM-based labs (Step 2 AMA / heartbeat, optional Backup lab),"
Write-Host "     run: ./deploy-vms.ps1 -SubscriptionId $SubscriptionId"
Write-Host "   - Send lab-output.json to Shanshan."
Write-Host "========================================"
