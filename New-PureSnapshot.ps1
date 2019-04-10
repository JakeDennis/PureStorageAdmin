<#
 NAME: New-PureSnapshot.ps1
 AUTHOR: Jake Dennis
 DATE  : 4/8/2019
 DESCRIPTION
    This script will take a volume snapshot on a Pure flash array. The user must provide the array name, valid storage admin credentials, and name of the volume that resides on the array.
#>

function New-PureSnapshot{
    function Connect-PureArray{
        if(Get-Module -ListAvailable -Name PureStoragePowerShellSDK){
            Write-Output ""
            Write-Output "Verified Pure PowerShell Module is installed."
            Write-Output ""
            Get-Module -Name PureStoragePowerShellSDK
        }
        else{
            Write-Host "There was a problem finding the PureStoragePowerShellSDK module."
            Write-Host "Consult Pure Support's documentation regarding installation of the binary."
            Start-Sleep -Seconds 10
            Exit
        }
        $tries = 0
        do{
            #attempt login to Pure flash array
            try{
                $Array = Read-Host -Prompt "Enter the array hostname or IP address that needs to be connected to"  
                $Creds = Get-Credential -Message "Enter administrative credentials for $($Array). Example: sa_account or svc.account"
                $Global:ArrayConnection = New-PfaArray -EndPoint $Array -Credential $Creds -IgnoreCertificateError -HttpTimeOutInMilliSeconds 8000 -ErrorAction Stop
                $Success=$true
            }
            catch{
                $tries++
                Write-Output ""
                Write-Output $_
                Write-Output ""
                Write-Output "Try again."
                Start-Sleep -Seconds 2
            }
        #allow for 5 attempts
        }until($tries -eq 5 -or $success)
        if(-not($success)){
            Write-Host ""
            Write-Output "Error limit reached. Terminating script."
            Start-Sleep -Seconds 10
            Exit
        }
        $ArrayConnection
    } #end Connect-PureArray

    function Take-PureSnapshot{
        $tries = 0
        do{
            #attempt to take snapshot of user provided volume
            try{
                $PureVolume = Read-Host "Enter the name of the Pure volume needing a snapshot taken"
                $Suffix = "Backup-$((Get-Date).ToString("MM-dd-yyyy-HHmm"))"
                Write-Output ""
                Write-Output "Taking snapshot for volume named $($PureVolume)..."
                New-PfaVolumeSnapshots -Array $ArrayConnection -Sources $PureVolume -Suffix $Suffix
                $Success=$true
            }
            catch{
                $tries++
                Write-Output ""
                Write-Output $_
                Write-Output ""
                Write-Output "Error encountered. Please check the name of the volume and try again."
                Start-Sleep -Seconds 2
            }
            #allow for 5 attempts
        }until($tries -eq 5 -or $success)
        if(($success)){
            Write-Output "Snapshot taken."
            Get-PfaVolumeSnapshots -Array $ArrayConnection -VolumeName $PureVolume
            Start-Sleep -Seconds 10
        }
        if(-not($success)){
            Write-Host ""
            Write-Host "Maximum attempts reached. Terminating script."
            Start-Sleep -Seconds 10
            Exit
        }
    } #end Take-PureSnapshot
Connect-PureArray
Take-PureSnapshot
}

#Run parent function
New-PureSnapshot