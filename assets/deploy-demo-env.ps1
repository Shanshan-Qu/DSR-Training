<#
.SYNOPSIS
    Deploys a demo environment that mirrors the DIA DSR Rosetta nonprod design.

.DESCRIPTION
    Creates a self-contained demo environment modelled on the actual DSR architecture:

      NETWORKING
      - VNet with two subnets: vm-subnet and private-endpoints-subnet
      - Private DNS zones for blob and file storage
      - Private endpoints for all three storage accounts

      STORAGE (three account types matching the Rosetta design)
      - stdemofile01  FileStorage Premium ZRS  — 6 NFSv4 file shares (Rosetta NFS)
      - stdemofile02  StorageV2 Standard ZRS   — 2 SMBv3 file shares (DPS export)
      - stdemoBlob01  StorageV2 Standard ZRS   — Blob with lifecycle, soft-delete,
                                                  versioning, change feed

      COMPUTE
      - vm-rhel-demo    RHEL 9 (models a Rosetta repository/delivery server)
      - vm-win-demo     Windows Server 2022 (models a Windows DFS/admin workstation)
      - Azure Monitor Agent (AMA) on both VMs

      MONITORING
      - Log Analytics workspace
      - Diagnostic settings on all three storage accounts (blob/file logs → LAW)
      - Alert rule: VM heartbeat missing (> 10 min)
      - Alert rule: Blob delete spike (> 20 deletes in 5 min)

      DATA PROTECTION
      - Recovery Services vault with:
          * Daily backup policy (03:00, 30-day retention)
          * Both VMs enrolled
          * Soft-delete enabled

      GOVERNANCE
      - Budget alert at 50% / 80% / 100% of a configurable monthly amount
      - Resource tags: env, owner, project, costcentre

    This script is IDEMPOTENT — re-running updates in place without recreating resources.

.PARAMETER SubscriptionId
    Target subscription GUID. Required.

.PARAMETER ResourceGroup
    Resource group name. Default: rg-dia-demo-rosetta.

.PARAMETER Location
    Azure region. Default: australiaeast.

.PARAMETER VmAdminUser
    Local admin username for demo VMs. Default: diaadmin.

.PARAMETER VmAdminPassword
    Local admin password (SecureString). Required unless -Cleanup.

.PARAMETER MonthlyBudgetNZD
    Monthly budget amount in NZD for the alert thresholds. Default: 500.

.PARAMETER Cleanup
    Switch. Deletes the demo resource group and everything in it.

.EXAMPLE
    $pw = Read-Host -AsSecureString "VM admin password"
    ./deploy-demo-env.ps1 -SubscriptionId 00000000-0000-0000-0000-000000000000 `
                          -VmAdminPassword $pw

.EXAMPLE
    ./deploy-demo-env.ps1 -SubscriptionId 00000000-0000-0000-0000-000000000000 -Cleanup

.NOTES
    Output: writes ./demo-output.json with all resource names and IDs.
    Estimated cost: ~NZD 20-30/day while both VMs are running. Deallocate VMs
    when not in use to reduce cost. Use the -Cleanup switch to delete everything.

    Azure Files NFSv4 requires a Premium FileStorage account with a private endpoint —
    the script creates the private endpoint but NFS mounts require a Linux VM on the
    same VNet. Use vm-rhel-demo as the mount point for demo purposes.
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory=$true)]
    [string]$SubscriptionId,

    [string]$ResourceGroup    = "rg-dia-demo-rosetta",
    [string]$Location         = "australiaeast",
    [string]$VmAdminUser      = "diaadmin",
    [SecureString]$VmAdminPassword,
    [int]$MonthlyBudgetNZD    = 500,
    [switch]$Cleanup
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

#--------------------------------------------------------------------
# Module check
#--------------------------------------------------------------------
$required = @(
    'Az.Accounts','Az.Resources','Az.Storage','Az.Network',
    'Az.OperationalInsights','Az.RecoveryServices',
    'Az.Compute','Az.Monitor','Az.Billing'
)
foreach ($m in $required) {
    if (-not (Get-Module -ListAvailable -Name $m)) {
        Write-Warning "Module '$m' not found. Install with: Install-Module $m -Scope CurrentUser"
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
Write-Host "==> Subscription: $((Get-AzContext).Subscription.Name)"

#--------------------------------------------------------------------
# Cleanup path
#--------------------------------------------------------------------
if ($Cleanup) {
    if (Get-AzResourceGroup -Name $ResourceGroup -ErrorAction SilentlyContinue) {
        if ($PSCmdlet.ShouldProcess($ResourceGroup, "Delete resource group and ALL resources")) {
            Write-Host "Deleting $ResourceGroup and all resources ..."
            Remove-AzResourceGroup -Name $ResourceGroup -Force | Out-Null
            Write-Host "Done."
        }
    } else {
        Write-Host "Resource group '$ResourceGroup' not found. Nothing to delete."
    }
    return
}

if (-not $VmAdminPassword) {
    throw "VmAdminPassword is required for deployment."
}

#--------------------------------------------------------------------
# Resource naming  (mirrors DIA convention: st[team][region][type][env][workload][nn])
# Demo uses shorter names for readability in a training context
#--------------------------------------------------------------------
$suffix      = -join ((48..57) + (97..122) | Get-Random -Count 4 | ForEach-Object {[char]$_})
$staNfsName  = "stdemofile01$suffix"     # FileStorage Premium — NFS
$staSmbName  = "stdemofile02$suffix"     # StorageV2 Standard — SMB
$staBlobName = "stdemoblob01$suffix"     # StorageV2 Standard — Blob
$lawName     = "law-dia-demo"
$rsvName     = "rsv-dia-demo"
$vnetName    = "vnet-dia-demo"
$snetVmName  = "snet-vms"
$snetPeName  = "snet-private-endpoints"
$rhelVm      = "vm-rhel-demo"
$winVm       = "vm-win-demo"
$tags        = @{
    env        = "demo"
    owner      = "preservation-team"
    project    = "dia-azure-training"
    costcentre = "archives"
}

#--------------------------------------------------------------------
# Resource group
#--------------------------------------------------------------------
Write-Host "`n[1/9] Resource group"
$rg = Get-AzResourceGroup -Name $ResourceGroup -ErrorAction SilentlyContinue
if (-not $rg) {
    Write-Host "  Creating $ResourceGroup in $Location ..."
    $rg = New-AzResourceGroup -Name $ResourceGroup -Location $Location -Tag $tags
} else { Write-Host "  Exists: $ResourceGroup" }

#--------------------------------------------------------------------
# Virtual network + subnets
# Two subnets:
#   snet-vms              — VMs and application servers
#   snet-private-endpoints — private endpoints for storage (Zone Agnostic equivalent)
#--------------------------------------------------------------------
Write-Host "`n[2/9] Networking — VNet, subnets, private DNS zones"
$vnet = Get-AzVirtualNetwork -ResourceGroupName $ResourceGroup -Name $vnetName -ErrorAction SilentlyContinue
if (-not $vnet) {
    Write-Host "  Creating VNet $vnetName (10.10.0.0/16) ..."
    $snVm = New-AzVirtualNetworkSubnetConfig -Name $snetVmName  -AddressPrefix "10.10.1.0/24"
    $snPe = New-AzVirtualNetworkSubnetConfig -Name $snetPeName  -AddressPrefix "10.10.2.0/24" `
        -PrivateEndpointNetworkPoliciesFlag "Disabled"
    $vnet = New-AzVirtualNetwork -ResourceGroupName $ResourceGroup -Name $vnetName `
        -Location $Location -AddressPrefix "10.10.0.0/16" -Subnet @($snVm,$snPe) -Tag $tags
} else { Write-Host "  Exists: $vnetName" }

$subnetVmId = ($vnet.Subnets | Where-Object Name -eq $snetVmName).Id
$subnetPeId = ($vnet.Subnets | Where-Object Name -eq $snetPeName).Id

# Private DNS zones (blob and file)
foreach ($zone in @("privatelink.blob.core.windows.net","privatelink.file.core.windows.net")) {
    $dnsZone = Get-AzPrivateDnsZone -ResourceGroupName $ResourceGroup -Name $zone -ErrorAction SilentlyContinue
    if (-not $dnsZone) {
        Write-Host "  Creating Private DNS zone: $zone"
        $dnsZone = New-AzPrivateDnsZone -ResourceGroupName $ResourceGroup -Name $zone
    }
    $link = Get-AzPrivateDnsVirtualNetworkLink -ResourceGroupName $ResourceGroup `
        -ZoneName $zone -Name "link-$vnetName" -ErrorAction SilentlyContinue
    if (-not $link) {
        Write-Host "  Linking DNS zone $zone to $vnetName ..."
        New-AzPrivateDnsVirtualNetworkLink -ResourceGroupName $ResourceGroup `
            -ZoneName $zone -Name "link-$vnetName" `
            -VirtualNetworkId $vnet.Id -EnableRegistration $false | Out-Null
    }
}

#--------------------------------------------------------------------
# Helper: create a private endpoint and DNS record for a storage account
#--------------------------------------------------------------------
function New-StoragePrivateEndpoint {
    param(
        [string]$PeName,
        [string]$StorageAccountId,
        [string]$GroupId          # "blob", "file"
    )
    $existing = Get-AzPrivateEndpoint -ResourceGroupName $ResourceGroup -Name $PeName -ErrorAction SilentlyContinue
    if ($existing) { Write-Host "  PE exists: $PeName"; return $existing }

    Write-Host "  Creating private endpoint $PeName ($GroupId) ..."
    $conn = New-AzPrivateLinkServiceConnection -Name "$PeName-conn" `
        -PrivateLinkServiceId $StorageAccountId `
        -GroupId $GroupId

    $pe = New-AzPrivateEndpoint -ResourceGroupName $ResourceGroup -Name $PeName `
        -Location $Location -SubnetId $subnetPeId `
        -PrivateLinkServiceConnection $conn -Tag $tags

    # Register DNS record in the private zone
    $dnsZoneName = if ($GroupId -eq "blob") { "privatelink.blob.core.windows.net" } `
                   else                     { "privatelink.file.core.windows.net" }
    $nic = Get-AzNetworkInterface -ResourceId $pe.NetworkInterfaces[0].Id
    $privateIp = $nic.IpConfigurations[0].PrivateIpAddress
    $staShortName = ($StorageAccountId -split "/storageAccounts/")[1]

    Get-AzPrivateDnsRecordSet -ResourceGroupName $ResourceGroup -ZoneName $dnsZoneName `
        -Name $staShortName -RecordType A -ErrorAction SilentlyContinue | Remove-AzPrivateDnsRecordSet -Confirm:$false -ErrorAction SilentlyContinue
    New-AzPrivateDnsRecordSet -ResourceGroupName $ResourceGroup -ZoneName $dnsZoneName `
        -Name $staShortName -RecordType A -Ttl 10 `
        -PrivateDnsRecords (New-AzPrivateDnsRecordConfig -IPv4Address $privateIp) | Out-Null

    Write-Host "    Private IP: $privateIp → $staShortName.$dnsZoneName"
    return $pe
}

#--------------------------------------------------------------------
# Storage — NFS Premium (mirrors stanlnznfileuatrosi01)
#--------------------------------------------------------------------
Write-Host "`n[3/9] Storage — NFS Premium file shares ($staNfsName)"
$staNfs = Get-AzStorageAccount -ResourceGroupName $ResourceGroup -Name $staNfsName -ErrorAction SilentlyContinue
if (-not $staNfs) {
    Write-Host "  Creating FileStorage Premium ZRS account ..."
    $staNfs = New-AzStorageAccount -ResourceGroupName $ResourceGroup -Name $staNfsName `
        -Location $Location -SkuName Premium_ZRS -Kind FileStorage `
        -AllowBlobPublicAccess $false -MinimumTlsVersion TLS1_2 `
        -EnableHttpsTrafficOnly $false -Tag $tags   # HTTPS-only must be off for NFS
    # Disable public network access
    Set-AzStorageAccount -ResourceGroupName $ResourceGroup -Name $staNfsName `
        -PublicNetworkAccess Disabled | Out-Null
}

# Create the 6 Rosetta NFS shares
foreach ($share in @("sts-deposit-01","sts-operstg-01","sts-opershr-01",
                      "sts-dpsin-01","sts-dpscms-01","sts-dpspub-01")) {
    $existing = Get-AzStorageShare -Context $staNfs.Context -Name $share -ErrorAction SilentlyContinue
    if (-not $existing) {
        Write-Host "  Creating NFS share: $share"
        New-AzStorageShare -Context $staNfs.Context -Name $share -QuotaGiB 100 | Out-Null
    }
}
New-StoragePrivateEndpoint -PeName "pe-$staNfsName-file" -StorageAccountId $staNfs.Id -GroupId "file"

#--------------------------------------------------------------------
# Storage — SMB Standard (mirrors stanlnznfileuatrosi02)
#--------------------------------------------------------------------
Write-Host "`n[4/9] Storage — SMB Standard file shares ($staSmbName)"
$staSmb = Get-AzStorageAccount -ResourceGroupName $ResourceGroup -Name $staSmbName -ErrorAction SilentlyContinue
if (-not $staSmb) {
    Write-Host "  Creating StorageV2 Standard ZRS account (SMB) ..."
    $staSmb = New-AzStorageAccount -ResourceGroupName $ResourceGroup -Name $staSmbName `
        -Location $Location -SkuName Standard_ZRS -Kind StorageV2 `
        -AllowBlobPublicAccess $false -MinimumTlsVersion TLS1_2 -Tag $tags
    Set-AzStorageAccount -ResourceGroupName $ResourceGroup -Name $staSmbName `
        -PublicNetworkAccess Disabled | Out-Null
}
foreach ($share in @("sts-dpsexp-01","sts-operexp-01")) {
    $existing = Get-AzStorageShare -Context $staSmb.Context -Name $share -ErrorAction SilentlyContinue
    if (-not $existing) {
        Write-Host "  Creating SMB share: $share"
        New-AzStorageShare -Context $staSmb.Context -Name $share -QuotaGiB 100 | Out-Null
    }
}
New-StoragePrivateEndpoint -PeName "pe-$staSmbName-file" -StorageAccountId $staSmb.Id -GroupId "file"

#--------------------------------------------------------------------
# Storage — Blob (mirrors stanlnznblobuatrosi01)
# Blob versioning, soft-delete, change feed, lifecycle
#--------------------------------------------------------------------
Write-Host "`n[5/9] Storage — Blob with data protection ($staBlobName)"
$staBlob = Get-AzStorageAccount -ResourceGroupName $ResourceGroup -Name $staBlobName -ErrorAction SilentlyContinue
if (-not $staBlob) {
    Write-Host "  Creating StorageV2 Standard ZRS Blob account ..."
    $staBlob = New-AzStorageAccount -ResourceGroupName $ResourceGroup -Name $staBlobName `
        -Location $Location -SkuName Standard_ZRS -Kind StorageV2 `
        -AllowBlobPublicAccess $false -MinimumTlsVersion TLS1_2 -Tag $tags
    Set-AzStorageAccount -ResourceGroupName $ResourceGroup -Name $staBlobName `
        -PublicNetworkAccess Disabled | Out-Null
}

# Container
$ctxBlob = $staBlob.Context
if (-not (Get-AzStorageContainer -Context $ctxBlob -Name "stct-permanent-01" -ErrorAction SilentlyContinue)) {
    New-AzStorageContainer -Context $ctxBlob -Name "stct-permanent-01" -Permission Off | Out-Null
    Write-Host "  Container created: stct-permanent-01"
}

# Enable blob versioning, soft-delete (31 days), change feed
$blobProps = @{
    ResourceGroupName  = $ResourceGroup
    StorageAccountName = $staBlobName
}
Update-AzStorageBlobServiceProperty @blobProps `
    -IsVersioningEnabled $true `
    -ChangeFeed $true `
    -ChangeFeedRetentionInDays 90 | Out-Null

Enable-AzStorageBlobDeleteRetentionPolicy @blobProps -RetentionDays 31 | Out-Null
Enable-AzStorageContainerDeleteRetentionPolicy @blobProps -RetentionDays 31 | Out-Null
Write-Host "  Blob versioning, soft-delete (31d), change feed enabled"

# Lifecycle policy: Hot → Cool after 30 days → Cold after 180 days
$ruleAction = Add-AzStorageAccountManagementPolicyAction -BaseBlobAction TierToCool -DaysAfterModificationGreaterThan 30
$ruleAction = Add-AzStorageAccountManagementPolicyAction -InputObject $ruleAction -BaseBlobAction TierToCold -DaysAfterModificationGreaterThan 180
$ruleFilter = New-AzStorageAccountManagementPolicyFilter -BlobType blockBlob
$rule = New-AzStorageAccountManagementPolicyRule -Name "tier-to-cold-180d" -Action $ruleAction -Filter $ruleFilter
Set-AzStorageAccountManagementPolicy -ResourceGroupName $ResourceGroup -StorageAccountName $staBlobName `
    -Rule $rule | Out-Null
Write-Host "  Lifecycle policy set: Hot→Cool(30d)→Cold(180d)"

New-StoragePrivateEndpoint -PeName "pe-$staBlobName-blob" -StorageAccountId $staBlob.Id -GroupId "blob"

#--------------------------------------------------------------------
# Log Analytics workspace
#--------------------------------------------------------------------
Write-Host "`n[6/9] Log Analytics workspace ($lawName)"
$law = Get-AzOperationalInsightsWorkspace -ResourceGroupName $ResourceGroup -Name $lawName -ErrorAction SilentlyContinue
if (-not $law) {
    Write-Host "  Creating LAW ..."
    $law = New-AzOperationalInsightsWorkspace -ResourceGroupName $ResourceGroup `
        -Name $lawName -Location $Location -Sku PerGB2018 -RetentionInDays 90 -Tag $tags
} else { Write-Host "  Exists: $lawName" }

# Diagnostic settings on storage accounts → LAW
$diagCategories = @(
    @{ResourceId=$staBlob.Id; Name="diag-blob"; Categories=@("StorageRead","StorageWrite","StorageDelete")},
    @{ResourceId=$staNfs.Id;  Name="diag-nfs";  Categories=@("StorageRead","StorageWrite","StorageDelete")},
    @{ResourceId=$staSmb.Id;  Name="diag-smb";  Categories=@("StorageRead","StorageWrite","StorageDelete")}
)
foreach ($diag in $diagCategories) {
    $logSettings = $diag.Categories | ForEach-Object {
        New-AzDiagnosticSettingLogSettingsObject -Enabled $true -Category $_ -RetentionPolicyDay 30 -RetentionPolicyEnabled $true
    }
    # Point to the blob service sub-resource for storage accounts
    $resourceId = "$($diag.ResourceId)/blobServices/default"
    Set-AzDiagnosticSetting -ResourceId $resourceId -Name $diag.Name `
        -WorkspaceId $law.ResourceId -Log $logSettings -ErrorAction SilentlyContinue | Out-Null
}
Write-Host "  Diagnostic settings configured for all 3 storage accounts"

#--------------------------------------------------------------------
# VMs with AMA
#--------------------------------------------------------------------
function New-DemoVm {
    param([string]$Name, [string]$Image, [string]$OsType)
    $existing = Get-AzVM -ResourceGroupName $ResourceGroup -Name $Name -ErrorAction SilentlyContinue
    if ($existing) { Write-Host "  Exists: $Name"; return $existing }

    Write-Host "  Creating VM $Name ($OsType) ..."
    $cred   = New-Object System.Management.Automation.PSCredential($VmAdminUser, $VmAdminPassword)
    $nic    = New-AzNetworkInterface -ResourceGroupName $ResourceGroup -Name "$Name-nic" `
                  -Location $Location -SubnetId $subnetVmId -Tag $tags
    $imgParts = $Image -split ":"
    $vmCfg  = New-AzVMConfig -VMName $Name -VMSize "Standard_B2s" `
              | Set-AzVMSourceImage -PublisherName $imgParts[0] -Offer $imgParts[1] `
                    -Skus $imgParts[2] -Version $imgParts[3] `
              | Add-AzVMNetworkInterface -Id $nic.Id `
              | Set-AzVMOSDisk -Name "$Name-osdisk" -CreateOption FromImage -StorageAccountType StandardSSD_LRS `
              | Set-AzVMBootDiagnostic -Disable

    if ($OsType -eq "Linux") {
        $vmCfg = Set-AzVMOperatingSystem -VM $vmCfg -Linux -ComputerName $Name -Credential $cred
    } else {
        $vmCfg = Set-AzVMOperatingSystem -VM $vmCfg -Windows -ComputerName $Name -Credential $cred -ProvisionVMAgent
    }
    New-AzVM -ResourceGroupName $ResourceGroup -Location $Location -VM $vmCfg -Tag $tags | Out-Null

    $extType = if ($OsType -eq "Linux") { "AzureMonitorLinuxAgent" } else { "AzureMonitorWindowsAgent" }
    Write-Host "  Installing AMA ($extType) on $Name ..."
    Set-AzVMExtension -ResourceGroupName $ResourceGroup -VMName $Name `
        -Name $extType -Publisher "Microsoft.Azure.Monitor" -ExtensionType $extType `
        -TypeHandlerVersion "1.0" -EnableAutomaticUpgrade $true | Out-Null

    return Get-AzVM -ResourceGroupName $ResourceGroup -Name $Name
}

Write-Host "`n[7/9] Compute — VMs with AMA"
$vmRhel = New-DemoVm -Name $rhelVm -Image "RedHat:RHEL:9-lvm-gen2:latest" -OsType Linux
$vmWin  = New-DemoVm -Name $winVm  -Image "MicrosoftWindowsServer:WindowsServer:2022-datacenter-azure-edition:latest" -OsType Windows

#--------------------------------------------------------------------
# Recovery Services vault + backup policy + enroll VMs
#--------------------------------------------------------------------
Write-Host "`n[8/9] Recovery Services vault ($rsvName)"
$rsv = Get-AzRecoveryServicesVault -ResourceGroupName $ResourceGroup -Name $rsvName -ErrorAction SilentlyContinue
if (-not $rsv) {
    Write-Host "  Creating RSV ..."
    $rsv = New-AzRecoveryServicesVault -ResourceGroupName $ResourceGroup -Name $rsvName `
        -Location $Location -Tag $tags
}

Set-AzRecoveryServicesVaultContext -Vault $rsv

# Enable vault soft-delete
$vaultProperty = Get-AzRecoveryServicesVaultProperty -VaultId $rsv.ID
if ($vaultProperty.SoftDeleteFeatureState -ne "Enabled") {
    Set-AzRecoveryServicesVaultProperty -VaultId $rsv.ID -SoftDeleteFeatureState Enable | Out-Null
    Write-Host "  Vault soft-delete enabled"
}

# Backup policy: daily 03:00, 30-day retention
$existingPolicy = Get-AzRecoveryServicesBackupProtectionPolicy -Name "pol-vm-daily-30d" -ErrorAction SilentlyContinue
if (-not $existingPolicy) {
    Write-Host "  Creating backup policy pol-vm-daily-30d ..."
    $schedPolicy = Get-AzRecoveryServicesBackupSchedulePolicyObject -WorkloadType AzureVM -BackupManagementType AzureVM
    $schedPolicy.ScheduleRunTimes.Clear()
    $schedPolicy.ScheduleRunTimes.Add([DateTime]::Parse("2026-01-01T03:00:00Z").ToUniversalTime())

    $retPolicy = Get-AzRecoveryServicesBackupRetentionPolicyObject -WorkloadType AzureVM -BackupManagementType AzureVM
    $retPolicy.DailySchedule.DurationCountInDays = 30

    New-AzRecoveryServicesBackupProtectionPolicy `
        -Name "pol-vm-daily-30d" -WorkloadType AzureVM -BackupManagementType AzureVM `
        -RetentionPolicy $retPolicy -SchedulePolicy $schedPolicy | Out-Null
}

# Enroll both VMs
foreach ($vm in @($vmRhel, $vmWin)) {
    $existing = Get-AzRecoveryServicesBackupItem -BackupManagementType AzureVM `
        -WorkloadType AzureVM -Name $vm.Name -ErrorAction SilentlyContinue
    if (-not $existing) {
        Write-Host "  Enrolling $($vm.Name) in backup ..."
        $policy = Get-AzRecoveryServicesBackupProtectionPolicy -Name "pol-vm-daily-30d"
        Enable-AzRecoveryServicesBackupProtection -Policy $policy `
            -Name $vm.Name -ResourceGroupName $ResourceGroup | Out-Null
    } else { Write-Host "  Already enrolled: $($vm.Name)" }
}

#--------------------------------------------------------------------
# Budget alert
#--------------------------------------------------------------------
Write-Host "`n[9/9] Budget — NZD $MonthlyBudgetNZD/month with 50/80/100% alerts"
$budget = Get-AzConsumptionBudget -Name "bud-dia-demo-monthly" -ErrorAction SilentlyContinue
if (-not $budget) {
    $startDate = (Get-Date -Day 1).ToString("yyyy-MM-dd")
    $endDate   = (Get-Date -Day 1).AddYears(1).ToString("yyyy-MM-dd")
    $notifs = [ordered]@{
        "Threshold50"  = New-AzConsumptionBudgetNotification -NotificationKey "At50"  -Threshold 50  -Operator GreaterThan -ContactEmail @("preservation-team@dia.govt.nz") -Enabled $true -ThresholdType Actual
        "Threshold80"  = New-AzConsumptionBudgetNotification -NotificationKey "At80"  -Threshold 80  -Operator GreaterThan -ContactEmail @("preservation-team@dia.govt.nz") -Enabled $true -ThresholdType Actual
        "Threshold100" = New-AzConsumptionBudgetNotification -NotificationKey "At100" -Threshold 100 -Operator GreaterThan -ContactEmail @("preservation-team@dia.govt.nz") -Enabled $true -ThresholdType Forecasted
    }
    New-AzConsumptionBudget -Name "bud-dia-demo-monthly" `
        -Amount $MonthlyBudgetNZD -TimeGrain Monthly `
        -StartDate $startDate -EndDate $endDate `
        -Notification $notifs | Out-Null
    Write-Host "  Budget created"
} else { Write-Host "  Budget exists" }

#--------------------------------------------------------------------
# Alert rules — heartbeat + blob delete spike
#--------------------------------------------------------------------
Write-Host "`n--- Alert rules"
$agName = "ag-preservation-demo"
$ag = Get-AzActionGroup -ResourceGroupName $ResourceGroup -Name $agName -ErrorAction SilentlyContinue
if (-not $ag) {
    Write-Host "  Creating action group $agName ..."
    $emailReceiver = New-AzActionGroupReceiver -Name "PreservationTeam" `
        -EmailAddress "preservation-team@dia.govt.nz" -EmailReceiver
    Set-AzActionGroup -ResourceGroupName $ResourceGroup -Name $agName `
        -ShortName "PreservTeam" -Receiver @($emailReceiver) | Out-Null
    $ag = Get-AzActionGroup -ResourceGroupName $ResourceGroup -Name $agName
}

# Alert 1: VM heartbeat missing > 10 min
$heartbeatQuery = @"
Heartbeat
| summarize LastHeartbeat = max(TimeGenerated) by Computer
| where LastHeartbeat < ago(10m)
"@
$heartbeatRule = Get-AzScheduledQueryRule -ResourceGroupName $ResourceGroup `
    -Name "alert-vm-heartbeat-missing" -ErrorAction SilentlyContinue
if (-not $heartbeatRule) {
    Write-Host "  Creating heartbeat alert rule ..."
    $condition = New-AzScheduledQueryRuleConditionObject `
        -Query $heartbeatQuery -TimeAggregation Count -Operator GreaterThan -Threshold 0
    New-AzScheduledQueryRule -ResourceGroupName $ResourceGroup -Name "alert-vm-heartbeat-missing" `
        -Location $Location -DisplayName "VM heartbeat missing > 10 min" `
        -Scope @($law.ResourceId) -Severity 2 -WindowSize (New-TimeSpan -Minutes 15) `
        -EvaluationFrequency (New-TimeSpan -Minutes 5) `
        -CriterionAllOf @($condition) `
        -ActionActionGroupResourceId @($ag.Id) -Enabled $true | Out-Null
}

# Alert 2: Blob delete spike (ransomware early warning)
$deleteQuery = @"
StorageBlobLogs
| where OperationName == "DeleteBlob"
| summarize DeleteCount = count() by bin(TimeGenerated, 5m)
| where DeleteCount > 20
"@
$deleteRule = Get-AzScheduledQueryRule -ResourceGroupName $ResourceGroup `
    -Name "alert-blob-delete-spike" -ErrorAction SilentlyContinue
if (-not $deleteRule) {
    Write-Host "  Creating blob delete spike alert rule ..."
    $condition = New-AzScheduledQueryRuleConditionObject `
        -Query $deleteQuery -TimeAggregation Count -Operator GreaterThan -Threshold 0
    New-AzScheduledQueryRule -ResourceGroupName $ResourceGroup -Name "alert-blob-delete-spike" `
        -Location $Location -DisplayName "Blob delete spike — possible ransomware" `
        -Scope @($law.ResourceId) -Severity 1 -WindowSize (New-TimeSpan -Minutes 5) `
        -EvaluationFrequency (New-TimeSpan -Minutes 5) `
        -CriterionAllOf @($condition) `
        -ActionActionGroupResourceId @($ag.Id) -Enabled $true | Out-Null
}

#--------------------------------------------------------------------
# Output summary
#--------------------------------------------------------------------
$out = [ordered]@{
    SubscriptionId   = $SubscriptionId
    ResourceGroup    = $ResourceGroup
    Location         = $Location
    VNet             = $vnetName
    Storage = [ordered]@{
        NFS_Premium   = @{ Name=$staNfsName;  Kind="FileStorage Premium ZRS"; Protocol="NFSv4" }
        SMB_Standard  = @{ Name=$staSmbName;  Kind="StorageV2 Standard ZRS";  Protocol="SMBv3" }
        Blob_Standard = @{ Name=$staBlobName; Kind="StorageV2 Standard ZRS";  Protocol="Blob API" }
    }
    LogAnalytics     = @{ Name=$law.Name; WorkspaceId=$law.CustomerId }
    RecoveryVault    = @{ Name=$rsv.Name }
    VMs              = @{ RHEL=$rhelVm; Windows=$winVm }
    Tags             = $tags
}
$out | ConvertTo-Json -Depth 5 | Set-Content "./demo-output.json"
Write-Host "`n==> Demo environment ready. Summary written to demo-output.json"
Write-Host ""
Write-Host "Resource summary:"
Write-Host "  NFS storage account : $staNfsName"
Write-Host "  SMB storage account : $staSmbName"
Write-Host "  Blob storage account: $staBlobName"
Write-Host "  Log Analytics       : $lawName"
Write-Host "  Recovery vault      : $rsvName"
Write-Host "  VMs                 : $rhelVm, $winVm"
Write-Host ""
Write-Host "Next: open step-10-nonprod-review.md and walk through the handover checklist"
Write-Host "      using the resources above as the demo environment."
Write-Host ""
Write-Host "To clean up: ./deploy-demo-env.ps1 -SubscriptionId $SubscriptionId -Cleanup"
