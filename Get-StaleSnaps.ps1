<#
 NAME: Get-StaleSnaps.ps1
 
 AUTHOR: Jake Dennis
 DATE  : 5/1/2018
 DESCRIPTION
    This script will return snapshots older than a user-given threshold in days. This script is dependent on valid credentials to a pure array and a local text file with all the arrays in the environment.
 EXAMPLE
    PS H:\> C:\Users\uyrd2b6\Documents\PureSDK\Get-StaleSnaps.ps1
    Please enter the maximum acceptable age of a snapshot in days: 14
    Filtering for snapshots older than 14 days.

    =========================================================================
                                puredev1                                
    =========================================================================
    pureprod1cs:pureprod1cs-LDC-ORADEV-SNAPSHOT-test.20.esx_linux_oradev_lun010-DCDRCopy-51110 - 62.19 GB - 40.86 days
    pureprod1cs:pureprod1cs-LDC-ORADEV-SNAPSHOT-test.20.esx_linux_oradev_lun011-DCDRCopy-48674 - 479.76 GB - 40.86 days
    pureprod1cs:pureprod1cs-LDC-ORADEV-SNAPSHOT-test.20.esx_linux_oradev_lun012-DCDRCopy-77646 - 76.93 GB - 40.86 days
    pureprod1cs:pureprod1cs-LDC-ORADEV-SNAPSHOT-test.20.esx_linux_oradev_lun013-DCDRCopy-40243 - 0.35 GB - 40.86 days
    pureprod1cs:pureprod1cs-LDC-ORADEV-SNAPSHOT-test.20.esx_linux_oradev_lun014-DCDRCopy-10366 - 56.77 GB - 40.86 days
    pureprod1cs:pureprod1cs-LDC-ORADEV-SNAPSHOT-test.20.esx_linux_oradev_lun015-DCDRCopy-44987 - 20.51 GB - 40.86 days
    pureprod1cs:pureprod1cs-LDC-ORADEV-SNAPSHOT-test.20.esx_linux_oradev_lun016-DCDRCopy-86439 - 128.92 GB - 40.86 days
    pureprod1cs:pureprod1cs-LDC-ORADEV-SNAPSHOT-test.20.esx_linux_oradev_lun017-DCDRCopy-98979 - 42.79 GB - 40.86 days
    esx_win_dev_sql_lun015-DCDRCopy-97677-DCDRCopy-74780.SP-2-905804-1523874766 - 109.91 GB - 17.65 days
    esx_win_dev_sql_lun018-DCDRCopy-11385-DCDRCopy-50693.SP-2-905900-1523880244 - 110.67 GB - 17.59 days
    pureprod2dr:LDC-DEV-SNAPSHOT-test-2.24.esx_win_dev_TEST_lun150-DCDRCopy-26924 - 0.4 GB - 16.14 days
    pureprod2dr:LDC-DEV-SNAPSHOT-test-2.24.esx_win_dev_TEST_lun151-DCDRCopy-97530 - 0.21 GB - 16.14 days
    esx_win_dev_sql_corp_lun024-DCDRCopy-42125-DCDRCopy-14760.SP-2-907305-1524180723 - 3.09 GB - 14.11 days
    There are 13 snapshot(s) older than 14 days consuming a total of 1093 GB on the array.
 LINK
    https://yvmunix.yellowcorp.com/git/uyrd2b6/PureStorageScripts
#>

Import-Module -Name PureStoragePowerShellSDK
Get-Module -Name PureStoragePowerShellSDK

Function Get-StaleSnaps{
    #Establish math variables, Pure's time format, and gather current time.
    $1GB = 1024*1024*1024
    $1TB = 1024*1024*1024*1024
    $CurrentTime = Get-Date
    $DateTimeFormat = 'yyyy-MM-ddTHH:mm:ssZ'
    [int]$SnapAgeThreshold  = 15

    #Plain Text Credentials for scheduled use
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
    foreach($FlashArrayID in (Get-Content 'D:\StorageScripts\Arrays.txt')){
        $Timespan = $null
        [int]$SpaceConsumed = 0
        [int]$SnapNumber = 0
        try{
            $FlashArray = New-PfaArray -EndPoint $FlashArrayID -Credentials $Creds -IgnoreCertificateError   
            $Snapshots = Get-PfaAllVolumeSnapshots -Array $FlashArray

            Write-Output ""
            Write-Output "========================================================================="
            Write-Output "                                                                  $FlashArrayID                                "
            Write-Output "========================================================================="

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
                    Write-Output $Snapshot.name
                    Write-Output "          $SnapSize GB"
                    Write-Output "          $SnapAge days"
                }
        
            }
            #Display final message for array results.
            Write-Output "There are $($SnapNumber) snapshot(s) older than $($SnapAgeThreshold) days consuming a total of $($SpaceConsumed) GB on the array."
            Disconnect-PfaArray -Array $FlashArray
        }
        catch{
        Write-Host "Error processing $($FlashArrayID) with $($User)."
        }
    }
#Repeat for dev server
$FlashArrayID = "puredev1"
     
#Get all arrays needing to be queried from a local text file. Establish and reset counter variables.
    $Timespan = $null
    [int]$SpaceConsumed = 0
    [int]$SnapNumber = 0
    $FlashArray = New-PfaArray -EndPoint $FlashArrayID -Credentials $Creds -IgnoreCertificateError
    $Snapshots = Get-PfaAllVolumeSnapshots -Array $FlashArray

    Write-Output ""
    Write-Output "========================================================================="
    Write-Output "                                                                  $FlashArrayID                                "
    Write-Output "========================================================================="

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
            Write-Output $Snapshot.name 
            Write-Output "          $SnapSize GB consumed"
            Write-Output "          $SnapAge days old"
        }
        
    }
    #Display final message for array results.
    Write-Output "There are $($SnapNumber) snapshot(s) older than $($SnapAgeThreshold) days consuming a total of $($SpaceConsumed) GB on the array."
    Disconnect-PfaArray -Array $FlashArray
    
}


#Output function to string variable for email body
$EmailBody = Get-StaleSnaps | Out-String

#Set email parameters
$Email = @{
From = "Pure Storage Health Check <ykcgpwssadmin01@YRCW.com>"
To = @("Jake.Dennis@yrcw.com")
Subject = "[Pure] Stale Snapshot Report"
SMTPServer = "mailbag.yellowcorp.com"
Body = $EmailBody
}

#Send email; Must be sent as plain text in current format
Send-MailMessage @Email