<#
 NAME: Get-ArraySpace.ps1
 AUTHOR: Jake Dennis
 DATE  : 11/13/2018
 DESCRIPTION
    This script will return general array space metrics.
 EXAMPLE
    Hostname    Capacity Used (TB) Capacity Free (TB) Volume Space (TB) Shared Space (TB) System Space (TB) Total Storage (TB) Percent Used Data Reduction Thin Provisioning
    --------    ------------------ ------------------ ----------------- ----------------- ----------------- ------------------ ------------ -------------- -----------------
    array1                   40.82               1.61              23.6             12.99              2.35              42.43 96.21 %                5.99              4.06
    array2                   52.25              18.09              1.97             16.59             27.88              70.35 74.28 %                4.32              7.61
  
 LINK
    https://github.com/JakeDennis/PureStorageAdmin
#>

#Dependencies include the PureStoragePowerShellSDK module being installed on the workstation, credentials stored securely as a text file in the working directory, and the corresponding username to the password.
Function Get-ArraySpace{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [String[]]
        $ArrayUsername,
        [Parameter(Mandatory=$true,
        HelpMessage = "Enter a filepath to a file containing a list of array hostnames (e.g.'D:\StorageScripts\Arrays.txt').")]
        $ArraysFile

    )
    #Math values
    [double]$1GB = 1024*1024*1024
    [double]$1TB = 1024*1024*1024*1024

    #Find credentials
    Write-Host ""
    try{
        $Pass = Get-Content .\ArrayPassword.txt | ConvertTo-SecureString
        $Creds = New-Object System.Management.Automation.PSCredential ($ArrayUsername, $Pass)
    }
    catch{
        Write-Host ""
        Write-Host "Error processing credentials." -ForegroundColor Yellow
        Write-Host "If credentials do not exist in $($PWD), 
        consider changing your working directory or 
        creating the file to store your credentials using a similar command to this" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Read-Host -AsSecureString | ConvertFrom-SecureString | Out-File '.\ArrayPassword.txt'" -ForegroundColor Cyan
        Exit
    }
    
    #Test array connection
    try{
        New-PfaArray -EndPoint 'array1' -Credentials $Creds -IgnoreCertificateError
    }
    catch{
        Write-Host "Unable to login into test array." -ForegroundColor Yellow
        Write-Host "Please validate network connection and credentials for $($Creds.UserName)." -ForegroundColor Yellow
        Exit
    }
    
    #Verify SDK is installed
    try{
        Import-Module -Name PureStoragePowerShellSDK
    } catch {
        Write-Host "Module does not exist. Please install the PureStoragePowerShellSDK module on this workstation."
        Write-Host "https://support.purestorage.com/Solutions/Microsoft_Platform_Guide/a_Windows_PowerShell/aa1_Install_PowerShell_SDK_using_PowerShell_Gallery"
        Exit
    }
    Write-Host "Verified credentials with test array and found PureStoragePowerShellSDK module is installed:$(Get-Module -Name PureStoragePowerShellSDK | Select Version)." -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Logging into arrays and collecting data..." -ForegroundColor Cyan
    $ErrorActionPreference = 'Continue'

    #CSS values for HTML Output
    $HtmlHead = '<style>
        body {
            background-color: white;
            font-family:      "Calibri";
        }
        table {
            border-width:     1px;
            border-style:     solid;
            border-color:     black;
            border-collapse:  collapse;
            width:            60%;
        }
        th {
            border-width:     1px;
            padding:          5px;
            border-style:     solid;
            border-color:     black;
            background-color: #98C6F3;
        }
        td {
            border-width:     1px;
            padding:          5px;
            border-style:     solid;
            border-color:     black;
            background-color: White;
        }
        tr {
            text-align:       left;
        }
    </style>'

    #Create HTML table output for arrays
    $Output = @()
    &{
        foreach($FlashArrayID in (Get-Content $arrayfile)){
            #Connect to arrays and collect metrics
            $FlashArray = New-PfaArray -EndPoint $FlashArrayID -Credentials $Creds -IgnoreCertificateError -HttpTimeOutInMilliSeconds 7500 -ErrorAction Continue
            $FlashArraySpace = Get-PfaArraySpaceMetrics -Array $FlashArray

            #Table Queries
            $FlashArraySpace | Select @{name='Hostname';expr={$_.Hostname}}, 
                               @{name='Percent Used'; expr={($FlashArraySpace.total/$FlashArraySpace.capacity).ToString("P")}}, 
                               @{name='Capacity Used (TB)';expr={([math]::Round([double]($_.Total/$1TB),2))}},
                               @{name='Capacity Free (TB)';expr={([math]::Round((($FlashArraySpace.capacity-$FlashArraySpace.total)/$1TB),2))}},
                               @{name='Volume Space (TB)';expr={([math]::Round([double]($_.Volumes/$1TB),2))}}, 
                               @{name='Shared Space (TB)';expr={([math]::Round([double]($_.Shared_Space/$1TB),2))}},
                               @{name='Snapshot Space (TB)';expr={([math]::Round([double]($_.Snapshots/$1TB),2))}}, 
                               @{name='System Space (TB)';expr={([math]::Round([double]($_.System/$1TB),2))}}, 
                               @{name='Total Storage (TB)';expr={([math]::Round([double]($_.Capacity/$1TB),2))}},
                               @{name='Data Reduction'; expr={[math]::Round($_.Data_Reduction,2)}},
                               @{name='Thin Provisioning'; expr={[math]::Round($_.Thin_Provisioning*10,2)}}
         } 
     } | ConvertTo-Html -Head $HTMLHead | Out-File .\ArraySpace.html
} #End Get-ArraySpace

#Run function and open the generated file
Get-ArraySpace
$ArraySpace | Format-Table -AutoSize
Invoke-Item ".\ArraySpace.html"

Write-Host ""
Write-Host "Script has completed." -ForegroundColor Cyan