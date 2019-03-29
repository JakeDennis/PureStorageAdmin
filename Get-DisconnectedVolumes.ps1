<#
 NAME: Get-DisconnectedVolumes.ps1
 
 AUTHOR: Jake Dennis
 DATE  : 3/12/2018

 DESCRIPTION
     This script will return any LUNs on a Pure flash array that are disconnected from all hosts and host groups for that array
 EXAMPLE
     array1 - 33.77 TB/43.55 TB (77.55% Full)
===================================================
		 Disconnected Volumes (4 of 1010)
===================================================
volume1
	 19CDCB8FB66049E500112347 
	 0.541 GB Consumed 
	 5 TB Provisioned 
	 10:1 Reduction 
volume2 
	 19CDCB8FB66049E500274C6C 
	 61.121 GB Consumed 
	 5 TB Provisioned 
	 9:1 Reduction 
volume3
	 19CDCB8FB66049E5002756A6 
	 62.983 GB Consumed 
	 5 TB Provisioned 
	 9:1 Reduction 

volume4
	 19CDCB8FB66049E5002846B1 
	 152.988 GB Consumed 
	 5 TB Provisioned 
	 8:1 Reduction 

Potential space savings for array1 is 277.633 GB.

 LINK
    https://github.com/JakeDennis/PureStorageAdmin
#>
#Reference directory for function
cd D:\StorageScripts\
Import-Module -Name PureStoragePowerShellSDK
$ErrorActionPreference = 'SilentlyContinue'

#Math values
$1GB = 1024*1024*1024
$1TB = 1024*1024*1024*1024

#Create credentials from text file in directory
$Pass = Get-Content .\Secure-Credentials.txt | ConvertTo-SecureString
$Creds = New-Object System.Management.Automation.PSCredential ("svc.pure_collector", $Pass)

#Set email parameters
$Email = @{
From = "Pure Storage Health Check <svc.account@domain.com>"
To = @("JakeJDennis@gmail.com")
Subject = "Pure Disconnected Volumes Check"
SMTPServer = "mailserver.domain.com"
Body = $EmailBody
}

#Start Function
Function Get-DisconnectedVolumes{

#Get all arrays needing to be queried from a local text file. 
    foreach($FlashArrayID in (Get-Content '.\Arrays.txt')){
        $FlashArray = New-PfaArray -EndPoint $FlashArrayID -Credentials $Creds -IgnoreCertificateError -HttpTimeOutInMilliSeconds 30000
        $FlashArraySpace = Get-PfaArraySpaceMetrics -Array $FlashArray 

        #Reset variables for each run of the loop.
        $z=0
        $AllVolumes = @($null)
        $PotentialSpaceSavings = 0
        $ConnectedVolumes = @($null)
        $DisconnectedVolumes = @($null)

        #Connect to the array.
        $Hosts = Get-PfaHosts -Array $FlashArray
        ForEach ($HostVol in $Hosts){
            $ConnectedVolumes += @(Get-PfaHostVolumeConnections -Array $FlashArray -Name $HostVol.name | select vol)
        }
    
        #Get all volumes
        $AllVolumes = @(Get-PfaVolumes -Array $FlashArray | select name)
        $hash= @{}
        foreach ($i in $ConnectedVolumes){
            $Vol = $i.vol
            $hash.Add($z, $Vol)
            $z++
        }
        foreach($j in $AllVolumes){
           if(!$hash.ContainsValue($j.name)){
                $DisconnectedVolumes += $j.name
            }
            else{
                $hash.Remove($j.name)
                }
        }
        Write-Output ""
        Write-Output "`t$($FlashArrayID) - $([math]::Round((($FlashArraySpace.total)/$1TB),2)) TB/$([math]::Round($(($FlashArraySpace.capacity)/$1TB),2)) TB ($([math]::Round((($FlashArraySpace.total)*100)/$($FlashArraySpace.capacity),2))% Full)`n"
        Write-Output "==================================================="
        Write-Output "`t`t Disconnected Volumes ($($DisconnectedVolumes.Count-1) of $($hash.Count))"
        Write-Output "==================================================="

        #If the array has a disconnected volume, gather volume space metrics
        if(($DisconnectedVolumes.Count) -gt 1 ){
            foreach($DisconnectedVolume in $DisconnectedVolumes){  
                if($DisconnectedVolume -ne $null){ 
                    $VolDetails = Get-PfaVolumeSpaceMetrics -array $FlashArray -VolumeName $DisconnectedVolume
                    $GetVol = Get-PfaVolume -Array $FlashArray -Name $DisconnectedVolume
                    $VolSerial = $GetVol.serial
                    $Space = ($($VolDetails.volumes/$1GB))
                    $Space = [math]::Round($Space,3) 
                    $Total = [math]::Round(($($VolDetails.size/$1TB)),3)
                    $Reduction = $VolDetails.data_reduction
                    $Reduction = [math]::Round($Reduction,0) 
                    Write-Output "$($DisconnectedVolume) `n`t $($VolSerial) `n`t $($Space) GB Consumed `n`t $($Total) TB Provisioned `n`t $($Reduction):1 Reduction `n" | Format-List
                    $PotentialSpaceSavings = $PotentialSpaceSavings + $($VolDetails.volumes/$1GB)
                }
            }
            Write-Output "Potential space savings for $($FlashArrayID) is $([math]::Round($PotentialSpaceSavings,3)) GB."
        }
        else{
            Write-Output "No Disconnected Volumes"
        }
    }
    Write-Output ""
    Write-Output "This script was executed from $($env:COMPUTERNAME)."
}

#Output function to string variable for email body
$EmailBody = Get-DisconnectedVolumes | Out-String

#Send email; Must be sent as plain text in current format
Send-MailMessage @Email
