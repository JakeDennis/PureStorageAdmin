param(
    [switch]$Delete,
    [switch]$Eradicate
)
<#
 NAME: Get-StaleSnaps.ps1
 AUTHOR: Jake Dennis
 DATE  : 6/4/2019
 DESCRIPTION
    This script will return snapshots older than a user-given threshold in days. This script is dependent on valid credentials to a pure array and a local text file with all the arrays in the environment.
 EXAMPLE
    PS H:\> C:\Users\Documents\PureSDK\Get-StaleSnaps.ps1 -delete
    Please enter the maximum acceptable age of a snapshot in days: 14
    Filtering for snapshots older than 14 days.

    =========================================================================
                                puredev1                                
    =========================================================================
    volumename1.snapshot40 - 62.19 GB - 40.86 days
    (...)
    volumename13.snapshot14 - 3.09 GB - 14.11 days
    There are 13 snapshot(s) older than 14 days consuming a total of 1093 GB on the array.
 LINK
    https://github.com/JakeDennis/PureStorageAdmin
#>

Import-Module -Name PureStoragePowerShellSDK
Get-Module -Name PureStoragePowerShellSDK

#Set email parameters
$Email = @{
From = "Pure Storage Health Check <sender@domain.com>"
To = @("recipient@domain.com")
Subject = "[Pure] Stale Snapshot Report"
SMTPServer = "mailserver@domain.com"
Body = $EmailBody
}
Function Get-StaleSnaps{
param(
    [switch]$Delete,
    [switch]$Eradicate
)
    #Establish variables, Pure's time format, and gather current time.
    $1GB = 1024*1024*1024
    $CurrentTime = Get-Date
    $DateTimeFormat = 'yyyy-MM-ddTHH:mm:ssZ'
    [int]$SnapAgeThreshold  = 15
    $Arrays = Get-Content 'D:\StorageScripts\Arrays.txt'

    #Credentials for scheduled use
    $User = 'svc.pure_collector'
     try{
        $Pass = Get-Content D:\StorageScripts\Password.txt | ConvertTo-SecureString
        $Creds = New-Object System.Management.Automation.PSCredential ($User, $Pass)
    }
    catch{
        Write-Host ""
        Write-Host "Error processing credentials." -ForegroundColor Yellow
        Write-Host "If credentials do not exist in $($PWD), 
        consider changing your working directory or 
        creating the file to store your credentials using the following command." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Read-Host -AsSecureString | ConvertFrom-SecureString | Out-File '.\Password.txt'" -ForegroundColor Cyan
        Exit
    }
    
    #Get all arrays needing to be queried from a local text file. Establish and reset counter variables.
    [int]$SpaceConsumedTotal = 0
    [int]$SnapNumberTotal = 0
    foreach($FlashArrayID in $Arrays){
        $Timespan = $null
        [int]$SpaceConsumed = 0
        [int]$SnapNumber = 0
        try{
            $FlashArray = New-PfaArray -EndPoint $FlashArrayID -Credentials $Creds -IgnoreCertificateError -HttpTimeOutInMilliSeconds 15000
            $Snapshots = Get-PfaAllVolumeSnapshots -Array $FlashArray

            Write-Output ""
            Write-Output "========================================================================="
            Write-Output "                                                                  $FlashArrayID                                "
            Write-Output "========================================================================="
         }
         catch{
            Write-Host "Error processing $($FlashArrayID) with $($User)."
         }   
        #Get all snapshots and compute the age of them. $DateTimeFormat variable taken from above; this is needed in order to parse Pure's time format.
        foreach($Snapshot in $Snapshots){
            $SnapshotDateTime = $Snapshot.created
            $SnapshotDateTime = [datetime]::ParseExact($SnapshotDateTime,$DateTimeFormat,$null)
            $Timespan = New-TimeSpan -Start $SnapshotDateTime -End $CurrentTime
            $SnapAge = $($Timespan.Days + $($Timespan.Hours/24) + $($Timespan.Minutes/1440))
            $SnapAge = [math]::Round($SnapAge,2)
    
            #Find snaps older than given threshold and output with formatted data.
            if($SnapAge -gt $SnapAgeThreshold){
                $SnapStats = Get-PfaSnapshotSpaceMetrics -Array $FlashArray -Name $Snapshot.name
                $SnapSize = [math]::round($($SnapStats.total/$1GB),2)
                $SpaceConsumed = $SpaceConsumed + $SnapSize
                $SnapNumber = $SnapNumber + 1
                                
                #Delete snapshots
                if($Delete -eq $true -and $Eradicate -eq $true){
                    Remove-PfaVolumeOrSnapshot -Array $FlashArray -Name $Snapshot.name -Eradicate
                    Write-Output "Eradicating $($Snapshot.name) - $($SnapSize) GB."
                }
                elseif($Delete -eq $true){
                    Remove-PfaVolumeOrSnapshot -Array $FlashArray -Name $Snapshot.name
                    Write-Output "Deleting $($Snapshot.name) - $($SnapSize) GB."
                }
                else {
                    Write-Output $Snapshot.name
                    Write-Output "          $SnapSize GB"
                    Write-Output "          $SnapAge days"
                }
            } 
            
        }
        #Display final message for array results.
        Write-Output "There are $($SnapNumber) snapshot(s) older than $($SnapAgeThreshold) days consuming a total of $($SpaceConsumed) GB on the array."
        Disconnect-PfaArray -Array $FlashArray
    
        $SnapNumberTotal = $SnapNumberTotal + $SnapNumber
        $SpaceConsumedTotal = $SpaceConsumedTotal + $SpaceConsumed
    }
Write-Output "There are $($SnapNumberTotal) snapshot(s) older than $($SnapAgeThreshold) days consuming a total of $($SpaceConsumedTotal) GB for $($Arrays.Count) Arrays."
}
Get-StaleSnaps -Delete:$Delete -Eradicate:$Eradicate

#Output function to string variable for email body
#$EmailBody = Get-StaleSnaps | Out-String
#$EmailBody
#Send email; Must be sent as plain text in current format
#Send-MailMessage @Email