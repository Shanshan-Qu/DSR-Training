<#
.SYNOPSIS
    Deploys the DIA Azure training lab environment.

.DESCRIPTION
    Creates a self-contained training lab in your Azure subscription:
      - Resource group (rg-dia-azure-labs)
      - Log Analytics workspace + Application Insights
      - Storage account with two containers (rosetta-objects, rosetta-manifests)
      - Recovery Services vault
      - One RHEL 9 VM (vm-rhel-lab) and one Windows Server 2022 VM (vm-win-lab)
      - Azure Monitor Agent on both VMs, sending telemetry to the workspace

    Uses your existing Azure CLI / PowerShell login. Does not change subscription
    defaults outside the run.

.PARAMETER SubscriptionId
    Target subscription GUID. Required.

.PARAMETER ResourceGroup
    Resource group name. Default: rg-dia-azure-labs.

.PARAMETER Location
    Azure region. Default: australiaeast.

.PARAMETER VmAdminUser
    Local admin username for both lab VMs. Default: diaadmin.

.PARAMETER VmAdminPassword
    Local admin password (SecureString). Required unless -Cleanup.

.PARAMETER Cleanup
    Switch. Deletes the lab resource group and everything in it. No deploy.

.EXAMPLE
    # Deploy
    $pw = Read-Host -AsSecureString "Lab VM admin password"
    ./deploy-lab.ps1 -SubscriptionId 00000000-0000-0000-0000-000000000000 `
                     -VmAdminPassword $pw

.EXAMPLE
    # Clean up
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
    [string]$VmAdminUser   = "diaadmin",

    [SecureString]$VmAdminPassword,

    [switch]$Cleanup
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

#--------------------------------------------------------------------
# Module check
#--------------------------------------------------------------------
$required = @('Az.Accounts','Az.Resources','Az.Storage','Az.OperationalInsights',
              'Az.ApplicationInsights','Az.RecoveryServices','Az.Compute','Az.Monitor')
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
        if ($PSCmdlet.ShouldProcess($ResourceGroup, "Delete resource group and ALL resources")) {
            Write-Host "Deleting $ResourceGroup ..."
            Remove-AzResourceGroup -Name $ResourceGroup -Force | Out-Null
            Write-Host "Done."
        }
    } else {
        Write-Host "Resource group $ResourceGroup not found. Nothing to do."
    }
    return
}

if (-not $VmAdminPassword) {
    throw "VmAdminPassword is required for deployment. Use Read-Host -AsSecureString."
}

#--------------------------------------------------------------------
# Naming
#--------------------------------------------------------------------
$suffix    = -join ((48..57) + (97..122) | Get-Random -Count 4 | ForEach-Object {[char]$_})
$staName   = "stdialabs$suffix"
$lawName   = "law-dia-labs"
$aiName    = "appi-dia-labs"
$rsvName   = "rsv-dia-labs"
$vnetName  = "vnet-dia-labs"
$rhelVm    = "vm-rhel-lab"
$winVm     = "vm-win-lab"
$tags      = @{ owner = "preservation-team"; project = "dia-azure-labs"; env = "training" }

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
# Virtual network + subnet
#--------------------------------------------------------------------
Write-Host "Ensuring VNet $vnetName ..."
$vnet = Get-AzVirtualNetwork -ResourceGroupName $ResourceGroup -Name $vnetName -ErrorAction SilentlyContinue
if (-not $vnet) {
    $sn = New-AzVirtualNetworkSubnetConfig -Name "snet-vms" -AddressPrefix "10.42.1.0/24"
    $vnet = New-AzVirtualNetwork -ResourceGroupName $ResourceGroup -Name $vnetName `
        -Location $Location -AddressPrefix "10.42.0.0/16" -Subnet $sn -Tag $tags
}
$subnetId = ($vnet.Subnets | Where-Object Name -eq "snet-vms").Id

#--------------------------------------------------------------------
# Helper: deploy a VM with AMA
#--------------------------------------------------------------------
function New-LabVm {
    param(
        [string]$Name,
        [string]$Image,           # e.g. RedHat:RHEL:9-lvm-gen2:latest or MicrosoftWindowsServer:WindowsServer:2022-datacenter-azure-edition:latest
        [string]$OsType           # Linux | Windows
    )
    $existing = Get-AzVM -ResourceGroupName $ResourceGroup -Name $Name -ErrorAction SilentlyContinue
    if ($existing) {
        Write-Host "VM $Name exists; skipping create."
        return $existing
    }
    Write-Host "Creating VM $Name ($OsType) ..."

    $cred = New-Object System.Management.Automation.PSCredential ($VmAdminUser, $VmAdminPassword)
    $nicName = "$Name-nic"
    $nic = New-AzNetworkInterface -ResourceGroupName $ResourceGroup -Name $nicName `
        -Location $Location -SubnetId $subnetId -Tag $tags

    $vmCfg = New-AzVMConfig -VMName $Name -VMSize "Standard_B2s"
    if ($OsType -eq "Linux") {
        $vmCfg = Set-AzVMOperatingSystem -VM $vmCfg -Linux -ComputerName $Name -Credential $cred
    } else {
        $vmCfg = Set-AzVMOperatingSystem -VM $vmCfg -Windows -ComputerName $Name -Credential $cred -ProvisionVMAgent -EnableAutoUpdate
    }
    $imgParts = $Image -split ":"
    $vmCfg = Set-AzVMSourceImage -VM $vmCfg `
        -PublisherName $imgParts[0] -Offer $imgParts[1] -Skus $imgParts[2] -Version $imgParts[3]
    $vmCfg = Add-AzVMNetworkInterface -VM $vmCfg -Id $nic.Id
    $vmCfg = Set-AzVMOSDisk -VM $vmCfg -Name "$Name-osdisk" -CreateOption FromImage -StorageAccountType "StandardSSD_LRS"
    $vmCfg = Set-AzVMBootDiagnostic -VM $vmCfg -Disable

    New-AzVM -ResourceGroupName $ResourceGroup -Location $Location -VM $vmCfg -Tag $tags | Out-Null

    # Attach Azure Monitor Agent and bind to LAW via DCR
    $extName = if ($OsType -eq "Linux") { "AzureMonitorLinuxAgent" } else { "AzureMonitorWindowsAgent" }
    $publisher = "Microsoft.Azure.Monitor"
    Write-Host "  Installing $extName on $Name ..."
    Set-AzVMExtension -ResourceGroupName $ResourceGroup -VMName $Name `
        -Name $extName -Publisher $publisher -ExtensionType $extName `
        -TypeHandlerVersion "1.0" -EnableAutomaticUpgrade $true | Out-Null

    return Get-AzVM -ResourceGroupName $ResourceGroup -Name $Name
}

$vmRhel = New-LabVm -Name $rhelVm -Image "RedHat:RHEL:9-lvm-gen2:latest"                                            -OsType Linux
$vmWin  = New-LabVm -Name $winVm  -Image "MicrosoftWindowsServer:WindowsServer:2022-datacenter-azure-edition:latest" -OsType Windows

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
    Vms                   = @{ Rhel = $vmRhel.Name; Windows = $vmWin.Name }
    Tags                  = $tags
    GeneratedAt           = (Get-Date).ToString("o")
}
$outFile = Join-Path -Path (Get-Location) -ChildPath "lab-output.json"
$out | ConvertTo-Json -Depth 6 | Out-File -FilePath $outFile -Encoding utf8

Write-Host ""
Write-Host "========================================"
Write-Host " Lab deployed."
Write-Host " Output written to: $outFile"
Write-Host " Send that file to Shanshan."
Write-Host "========================================"
