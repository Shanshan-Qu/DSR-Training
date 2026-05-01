<#
.SYNOPSIS
    Deploys the OPTIONAL VM tier of the DIA Azure training lab.

.DESCRIPTION
    Adds the following to the lab resource group already created by deploy-lab.ps1:
      - Virtual network (vnet-dia-labs) with a /24 subnet
      - One RHEL 9 VM     (vm-rhel-lab, Standard_B2s) — optional
      - One Windows VM    (vm-win-lab,  Standard_B2s) — optional
      - Azure Monitor Agent (AMA) extension on each VM
      - A Data Collection Rule (DCR) bound to the workspace, collecting:
          Linux:   Heartbeat, Syslog (info+), Linux performance counters
          Windows: Heartbeat, Windows Event Log (System+Application warning+),
                   Windows performance counters

    VMs are deliberately a separate, optional script:
      - The core labs (Storage, KQL, Cost, Reporting, Governance, Portal) do NOT
        require VMs.
      - VMs are only needed for: Step 2 'Activity 1: Verify AMA is working',
        Step 3 KQL queries against Heartbeat/Perf, and the optional Step 7 Backup lab.
      - Skip this script if you only need the storage / monitoring / cost
        portion of the training and want to keep cost to a minimum.

    Run this AFTER deploy-lab.ps1 (it expects the resource group, the workspace,
    and the recovery vault to already exist).

.PARAMETER SubscriptionId
    Target subscription GUID. Required.

.PARAMETER ResourceGroup
    Resource group name. Default: rg-dia-azure-labs.

.PARAMETER Location
    Azure region. Default: australiaeast.

.PARAMETER VmAdminUser
    Local admin username for both lab VMs. Default: diaadmin.

.PARAMETER VmAdminPassword
    Local admin password (SecureString). Required.

.PARAMETER DeployRhel
    Switch. Deploy the RHEL 9 VM. Default: enabled (use -DeployRhel:$false to skip).

.PARAMETER DeployWindows
    Switch. Deploy the Windows Server 2022 VM. Default: enabled (use -DeployWindows:$false to skip).

.PARAMETER Cleanup
    Switch. Removes the VMs, NICs, OS disks, and the lab VNet. Leaves the storage
    account, workspace, vault, and resource group intact (use deploy-lab.ps1 -Cleanup
    to remove everything).

.EXAMPLE
    # Deploy both VMs + AMA + DCR
    $pw = Read-Host -AsSecureString "Lab VM admin password"
    ./deploy-vms.ps1 -SubscriptionId 00000000-0000-0000-0000-000000000000 `
                     -VmAdminPassword $pw

.EXAMPLE
    # Deploy only the Linux VM
    $pw = Read-Host -AsSecureString "Lab VM admin password"
    ./deploy-vms.ps1 -SubscriptionId <guid> -VmAdminPassword $pw -DeployWindows:$false

.EXAMPLE
    # Remove just the VMs (keep storage / workspace / vault)
    ./deploy-vms.ps1 -SubscriptionId <guid> -Cleanup

.NOTES
    Idempotent: re-running over an existing VM updates the AMA extension only.
    Cost: ~NZD $5/day while both VMs run; ~$0.30/day if VMs are STOPPED (deallocated).
          Stop them between sessions in the portal to save cost.
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory=$true)]
    [string]$SubscriptionId,

    [string]$ResourceGroup = "rg-dia-azure-labs",
    [string]$Location      = "australiaeast",
    [string]$VmAdminUser   = "diaadmin",

    [SecureString]$VmAdminPassword,

    [bool]$DeployRhel    = $true,
    [bool]$DeployWindows = $true,

    [switch]$Cleanup
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

#--------------------------------------------------------------------
# Module check
#--------------------------------------------------------------------
$required = @('Az.Accounts','Az.Resources','Az.Network','Az.Compute','Az.Monitor','Az.OperationalInsights')
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

$vnetName  = "vnet-dia-labs"
$rhelVm    = "vm-rhel-lab"
$winVm     = "vm-win-lab"
$dcrName   = "dcr-dia-labs-vms"
$lawName   = "law-dia-labs"

#--------------------------------------------------------------------
# Cleanup path (VM tier only)
#--------------------------------------------------------------------
if ($Cleanup) {
    Write-Host "Removing VM tier from $ResourceGroup ..."

    foreach ($vmName in @($rhelVm, $winVm)) {
        $vm = Get-AzVM -ResourceGroupName $ResourceGroup -Name $vmName -ErrorAction SilentlyContinue
        if ($vm) {
            if ($PSCmdlet.ShouldProcess($vmName, "Delete VM, NIC, OS disk")) {
                $nicId = $vm.NetworkProfile.NetworkInterfaces[0].Id
                $osDisk = $vm.StorageProfile.OsDisk.Name
                Remove-AzVM -ResourceGroupName $ResourceGroup -Name $vmName -Force | Out-Null
                if ($nicId) {
                    Remove-AzNetworkInterface -ResourceId $nicId -Force -ErrorAction SilentlyContinue | Out-Null
                }
                if ($osDisk) {
                    Remove-AzDisk -ResourceGroupName $ResourceGroup -DiskName $osDisk -Force -ErrorAction SilentlyContinue | Out-Null
                }
                Write-Host "  Removed VM $vmName"
            }
        }
    }

    # DCR
    $dcr = Get-AzDataCollectionRule -ResourceGroupName $ResourceGroup -RuleName $dcrName -ErrorAction SilentlyContinue
    if ($dcr) { Remove-AzDataCollectionRule -ResourceGroupName $ResourceGroup -RuleName $dcrName | Out-Null; Write-Host "  Removed DCR $dcrName" }

    # VNet (only if no other resources are still using it)
    $vnet = Get-AzVirtualNetwork -ResourceGroupName $ResourceGroup -Name $vnetName -ErrorAction SilentlyContinue
    if ($vnet) {
        if ($PSCmdlet.ShouldProcess($vnetName, "Delete VNet")) {
            Remove-AzVirtualNetwork -ResourceGroupName $ResourceGroup -Name $vnetName -Force | Out-Null
            Write-Host "  Removed VNet $vnetName"
        }
    }

    Write-Host "VM tier cleanup complete. Storage / workspace / vault are unchanged."
    return
}

if ((-not $DeployRhel) -and (-not $DeployWindows)) {
    Write-Host "Both -DeployRhel and -DeployWindows are false; nothing to do."
    return
}

if (-not $VmAdminPassword) {
    throw "VmAdminPassword is required for deployment. Use Read-Host -AsSecureString."
}

#--------------------------------------------------------------------
# Pre-flight: workspace must already exist (deploy-lab.ps1 should have run first)
#--------------------------------------------------------------------
$law = Get-AzOperationalInsightsWorkspace -ResourceGroupName $ResourceGroup -Name $lawName -ErrorAction SilentlyContinue
if (-not $law) {
    throw "Log Analytics workspace '$lawName' not found in '$ResourceGroup'. Run deploy-lab.ps1 first."
}

$tags = @{
    app_name    = "anl"
    org_name    = "dia"
    cost_centre = "training"
    env         = "trn"
    owner       = (Get-AzContext).Account.Id
    severity    = "low"
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
# Helper: deploy a single VM and install AMA
#--------------------------------------------------------------------
function New-LabVm {
    param(
        [string]$Name,
        [string]$Image,           # publisher:offer:sku:version
        [ValidateSet("Linux","Windows")][string]$OsType
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

    # Install AMA
    $extName = if ($OsType -eq "Linux") { "AzureMonitorLinuxAgent" } else { "AzureMonitorWindowsAgent" }
    $publisher = "Microsoft.Azure.Monitor"
    Write-Host "  Installing $extName on $Name ..."
    Set-AzVMExtension -ResourceGroupName $ResourceGroup -VMName $Name `
        -Name $extName -Publisher $publisher -ExtensionType $extName `
        -TypeHandlerVersion "1.0" -EnableAutomaticUpgrade $true | Out-Null

    return Get-AzVM -ResourceGroupName $ResourceGroup -Name $Name
}

$deployed = @()
if ($DeployRhel)    { $deployed += New-LabVm -Name $rhelVm -Image "RedHat:RHEL:9-lvm-gen2:latest"                                            -OsType Linux }
if ($DeployWindows) { $deployed += New-LabVm -Name $winVm  -Image "MicrosoftWindowsServer:WindowsServer:2022-datacenter-azure-edition:latest" -OsType Windows }

#--------------------------------------------------------------------
# Data Collection Rule (Heartbeat + Perf + Syslog/EventLog -> LAW)
# This is what makes the AMA extension actually emit data.
#--------------------------------------------------------------------
Write-Host "Ensuring Data Collection Rule $dcrName ..."
$dcr = Get-AzDataCollectionRule -ResourceGroupName $ResourceGroup -RuleName $dcrName -ErrorAction SilentlyContinue
if (-not $dcr) {
    $dcrJson = @"
{
  "location": "$Location",
  "properties": {
    "dataSources": {
      "performanceCounters": [{
        "name": "perfCountersDS",
        "streams": [ "Microsoft-Perf" ],
        "samplingFrequencyInSeconds": 60,
        "counterSpecifiers": [
          "\\\\Processor(_Total)\\\\% Processor Time",
          "\\\\Memory\\\\Available Bytes",
          "\\\\LogicalDisk(_Total)\\\\Free Megabytes",
          "Processor(*)\\\\% Processor Time",
          "Memory(*)\\\\% Used Memory",
          "Logical Disk(*)\\\\% Free Space"
        ]
      }],
      "syslog": [{
        "name": "syslogDS",
        "streams": [ "Microsoft-Syslog" ],
        "facilityNames": [ "auth","cron","daemon","kern","syslog","user" ],
        "logLevels": [ "Info","Notice","Warning","Error","Critical","Alert","Emergency" ]
      }],
      "windowsEventLogs": [{
        "name": "winEventDS",
        "streams": [ "Microsoft-Event" ],
        "xPathQueries": [
          "System!*[System[(Level=1 or Level=2 or Level=3)]]",
          "Application!*[System[(Level=1 or Level=2 or Level=3)]]"
        ]
      }]
    },
    "destinations": {
      "logAnalytics": [{
        "name": "centralLaw",
        "workspaceResourceId": "$($law.ResourceId)"
      }]
    },
    "dataFlows": [
      { "streams":["Microsoft-Perf"],   "destinations":["centralLaw"] },
      { "streams":["Microsoft-Syslog"], "destinations":["centralLaw"] },
      { "streams":["Microsoft-Event"],  "destinations":["centralLaw"] }
    ]
  }
}
"@
    $tmp = New-TemporaryFile
    $dcrJson | Out-File $tmp -Encoding utf8
    $dcr = New-AzDataCollectionRule -ResourceGroupName $ResourceGroup -RuleName $dcrName `
            -Location $Location -RuleFile $tmp.FullName
    Remove-Item $tmp -Force
}

# Associate DCR with each deployed VM
foreach ($vm in $deployed) {
    $assocName = "$($vm.Name)-dcra"
    $existingAssoc = Get-AzDataCollectionRuleAssociation -TargetResourceId $vm.Id -AssociationName $assocName -ErrorAction SilentlyContinue
    if (-not $existingAssoc) {
        Write-Host "  Associating DCR with $($vm.Name) ..."
        New-AzDataCollectionRuleAssociation -TargetResourceId $vm.Id `
            -AssociationName $assocName -RuleId $dcr.Id | Out-Null
    }
}

#--------------------------------------------------------------------
# Append VM info to lab-output.json (if it exists)
#--------------------------------------------------------------------
$outFile = Join-Path -Path (Get-Location) -ChildPath "lab-output.json"
$out = if (Test-Path $outFile) { Get-Content $outFile -Raw | ConvertFrom-Json } else { [pscustomobject]@{} }
$vmInfo = @{}
foreach ($vm in $deployed) { $vmInfo[$vm.Name] = $vm.Id }
$out | Add-Member -NotePropertyName Vms -NotePropertyValue $vmInfo -Force
$out | Add-Member -NotePropertyName Dcr -NotePropertyValue @{ Name = $dcrName; Id = $dcr.Id } -Force
$out | ConvertTo-Json -Depth 6 | Out-File -FilePath $outFile -Encoding utf8

Write-Host ""
Write-Host "========================================"
Write-Host " VM tier deployed."
Write-Host " VMs: $($deployed.Name -join ', ')"
Write-Host " DCR: $dcrName -> $($law.Name)"
Write-Host ""
Write-Host " Heartbeat will appear in the workspace within ~10 minutes."
Write-Host " Verify with the KQL in step-optional-vm-setup.md (Activity 3)."
Write-Host ""
Write-Host " IMPORTANT: stop the VMs from the portal between sessions to keep cost low."
Write-Host "========================================"
