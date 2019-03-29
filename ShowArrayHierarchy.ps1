<#
 NAME: ShowArrayHierarchy.ps1
 
 AUTHOR: Jake Dennis
 DATE  : 3/12/2018

 DESCRIPTION
     This script will show the hierarchy of the given array by either host->volume->snapshot or volume->snapshot levels. 
     The objective of the script is to identify volumes that are not properly configured given the defined standard. 
     The current script version assumes 1 snapshot per volume is the desired standard.
 EXAMPLE
   |[V] volume1
   |   |----[S] snapshot1-1
   |[V] volume2
   |   |----There are no associated snapshots with this volume.
   |[V] volume3
   |   |----[S] snapshot3-1
   |   |----[S] snapshot3-2
   |   |----[S] snapshot3-3
   |   |----There are 3 snapshots associated with this volume consuming a total of 0.11 GB on the array. 
 LINK
    https://github.com/JakeDennis/PureStorageAdmin
#>

#Gather desired array, password, and initial data of the hosts and volumes
$FlashArrayID = Read-Host -Prompt "Enter the hostname or IP of the desired array"
$Creds = Get-Credential -UserName 'username' -Message "Login to array with storage admin credentials."
$FlashArray = New-PfaArray -EndPoint $FlashArrayID -Credentials $Creds -IgnoreCertificateError
$Initiators = Get-PfaHosts -Array $FlashArray
$Volumes = Get-PfaVolumes -Array $FlashArray
$1GB = 1024*1024*1024
Write-Host ""
Write-Host "Please indicate if you would like to see the hierarchy by host." -ForegroundColor Cyan
Write-Host "This process will take a couple minutes, but is useful to find disconnected hosts or hosts with no replication group." -ForegroundColor Cyan
Write-Host "Otherwise, the hierarchy will be shown at the volume level." -ForegroundColor Cyan
Write-Host ""
$ByHost = Read-Host -Prompt "Do you want to view hierarchy by individual hosts? (Y/N)"

Write-Host ""
Write-Host "================================================================"
Write-Host "                    $FlashArrayID Hierarchy"
Write-Host "================================================================"
#If else statement to control hierarchy displayed by host or by volume
If($ByHost -eq "Y" -or $ByHost -eq "y"){
    
    #Start at host level
    ForEach($Initiator in $Initiators){
		Write-Host "  [H] $($Initiator.name)"
		$Volumes = Get-PfaHostVolumeConnections -Array $FlashArray -Name $Initiator.name
		If (!$Volumes){
			Write-Host '   |   |----[No volumes connected]' -ForegroundColor Yellow         
		}
		Else{
			
            #Start at volume level
            ForEach ($Volume in $Volumes){
				
                #Reset variables
                $Snapshots = Get-PfaVolumeSnapshots -Array $FlashArray -VolumeName $Volume.vol
				$SnapshotDetails = Get-PfaSnapshotSpaceMetrics -Array $FlashArray -name $Volume.vol
				$SpaceConsumed = 0
				
                #Change value for snapshot count threshold
                If($Snapshots.Count -eq 0){
					Write-Host "   |   |----[V]$($Volume.vol)" -ForegroundColor Yellow
					Write-Host "   |   |----There are no associated snapshots with this volume." -ForegroundColor Red
				}
				Else{
					Write-Host "   |   |----[V]$($Volume.vol)" -ForegroundColor Green
				}
				
                #Space consumed computation for each volume
                ForEach($SnapshotDetail in $SnapshotDetails){
					$SpaceConsumed = $SpaceConsumed + $SnapshotDetail.total 
				}
                
                #Change value for snapshot count threshold
				ForEach ($Snapshot in $Snapshots){
					If($Snapshots.Count -gt 1){
						Write-Host "   |   |       |----[S] $($Snapshot.name)" -ForegroundColor Yellow 
					}
					Else{
						Write-Host "   |   |       |----[S] $($Snapshot.name)" -ForegroundColor Green
					}
				}
                
                #Display space consumed if snapshot count exceeds threshold
				If($Snapshots.Count -gt 1){
					Write-Host  "   |   |       |----There are $($Snapshots.Count) snapshots associated with this volume consuming a total of $([math]::Round($SpaceConsumed/$1GB,2)) GB on the array."
				}
			}
		}
    }
}
#If user does not want hierarchy at host level
Else{
    
    #Start volume level
    ForEach ($Volume in $Volumes){
        
        #Reset variables
        $Snapshots = Get-PfaVolumeSnapshots -Array $FlashArray -VolumeName $Volume.name
        $SnapshotDetails = Get-PfaSnapshotSpaceMetrics -Array $FlashArray -name $Volume.name
        $SpaceConsumed = 0
        
        #Change value for snapshot count threshold
        If($Snapshots.Count -eq 0){
            Write-Host "   |[V]$($Volume.name)" -ForegroundColor Yellow
            Write-Host "   |   |----There are no associated snapshots with this volume." -ForegroundColor Red
        }
        Else{
            Write-Host "   |[V]$($Volume.name)" -ForegroundColor Green
        }
        
        #Space Consumed computation for each volume
        ForEach($SnapshotDetail in $SnapshotDetails){
            $SpaceConsumed = $SpaceConsumed + $SnapshotDetail.total 
        }

        #Change value for snapshot count threshold
        ForEach ($Snapshot in $Snapshots){
            If($Snapshots.Count -gt 1){
                Write-Host "   |   |----[S] $($Snapshot.name)" -ForegroundColor Yellow 
            }
            Else{
                Write-Host "   |   |----[S] $($Snapshot.name)" -ForegroundColor Green
            }
        }
            
            #Display space consumed if snapshot count threshold is exceeded
            If($Snapshots.Count -gt 1){
				Write-Host  "   |   |----There are $($Snapshots.Count) snapshots associated with this volume consuming a total of $([math]::Round($SpaceConsumed/$1GB,2)) GB on the array."
            }
    }
}

