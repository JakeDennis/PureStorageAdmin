<#
 NAME: ProtectionGroupConfigurationCheck.ps1
 
 AUTHOR: Jake Dennis
 DATE  : 3/27/2018

 DESCRIPTION
    This scripts will display all protection groups on an array and their configuration.   
 LINK
    https://github.com/JakeDennis/PureStorageAdmin
#>

#Establish Array Connection
$ErrorActionPreference = "Stop"
$FlashArrayID = Read-Host -Prompt "Enter Array name or IP address"
$Creds = Get-Credential -Message "Login to array with storage admin credentials."
$FlashArray = New-PfaArray -EndPoint $FlashArrayID -Credentials $Creds -IgnoreCertificateError -ErrorAction Stop

<# Prompt for SLA
$PGReplicateTime = Read-Host -Prompt "Provide the desired snapshot and replication interval in minutes (e.g. 45)"
$PGRetainSnaps = Read-Host -Prompt "How long should all snapshots on the target array be retained in minutes (e.g 90)"
$PGRetainSnapsPerDay = Read-Host -Prompt "Then how many more snapshots should be retained (e.g. 1)"
$PGRetainSnapsForMoreDays = Read-Host -Prompt "And for how many more days (e.g. 7)"
/#>

#Gather Protection Groups
$ProtectionGroups = Get-PfaProtectionGroups -Array $FlashArray
$ErrorActionPreference = "Continue"

#Process each Protection Group
foreach($ProtectionGroup in $ProtectionGroups){
$RetentionDetails = Get-PfaProtectionGroupRetention -Array $FlashArray -ProtectionGroupName $ProtectionGroup.name
$ScheduleDetails = Get-PfaProtectionGroupSchedule -Array $FlashArray -ProtectionGroupName $ProtectionGroup.name
    
    #Output for Enabled Protection Groups
    if($ScheduleDetails.replicate_enabled -eq "True"){
        Write-Host "=============================================================================================================================================================="
        Write-Host "                                                               $($ProtectionGroup.name)                                                                       " -ForegroundColor Green
        Write-Host "=============================================================================================================================================================="
        Write-Host "Host Groups: $($ProtectionGroup.hgroups)"
        Write-Host "Hosts: $($ProtectionGroup.hosts)"
        Write-Host "Volumes: $($ProtectionGroup.volumes)"
        Write-Host ""
        Write-Host "A snapshot is taken and replicated every $($ScheduleDetails.replicate_frequency/60) minutes."
        Write-Host "$(($RetentionDetails.target_all_for/60)/($ScheduleDetails.replicate_frequency/60)) snapshot(s) are kept on the target for $($RetentionDetails.target_all_for/60) minutes."
        Write-Host "$($RetentionDetails.target_per_day) additional snapshot(s) are kept for $($RetentionDetails.target_days) more days."
        #$RetentionDetails
        #$ScheduleDetails
    }
    
    #Output for Disabled Protection Groups
    else{
        Write-Host "=============================================================================================================================================================="
        Write-Host "                                                               $($ProtectionGroup.name)                                                                       " -ForegroundColor Yellow
        Write-Host "=============================================================================================================================================================="
        Write-Host "Host Groups: $($ProtectionGroup.hgroups)"
        Write-Host "Hosts: $($ProtectionGroup.hosts)"
        Write-Host "Volumes: $($ProtectionGroup.volumes)"
        Write-Host ""
        Write-Host "$($ProtectionGroup.name) is disabled." -ForegroundColor Yellow
        Write-Host ""
    }
}

