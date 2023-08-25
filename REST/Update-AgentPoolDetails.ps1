##-----------------------------------------------------------------------
## <copyright file="Update-AgentPoolDetails.ps1">(c) Richard Fennell. </copyright>
##-----------------------------------------------------------------------
# Updates the description of an Azure DevOps Agent Pool
param
(

    [parameter(Mandatory = $true, HelpMessage = "URL of the Azure DevOps Organisation e.g. 'https://dev.azure.com/myorg'")]
    $orgUri ,

    [parameter(Mandatory = $false, HelpMessage = "Personal Access Token")]
    $pat,

    [parameter(Mandatory = $true, HelpMessage = "The name of the AppPool to update")]
    $poolName,

    [parameter(Mandatory = $true, HelpMessage = "The new description for the VMSS based pool")]
    $description 

)

function Get-WebClient {
    param
    (
        [string]$pat,
        [string]$ContentType = "application/json"
    )

    $wc = New-Object System.Net.WebClient
    $wc.Headers["Content-Type"] = $ContentType

    $pair = ":${pat}"
    $bytes = [System.Text.Encoding]::ASCII.GetBytes($pair)
    $base64 = [System.Convert]::ToBase64String($bytes)
    $wc.Headers.Add(“Authorization”, "Basic $base64");

    $wc
}

$wc = Get-WebClient -pat $pat 
write-host "Finding the Agent Pool '$poolName' in '$orgUri' " -ForegroundColor Green
$uri = "$($orgUri)/_apis/distributedtask/pools?api-version=5.0-preview.1"
$jsondata = $wc.DownloadString($uri) | ConvertFrom-Json
$poolid = ($jsondata.value | where { $_.name -eq $poolName }).id

$wc = Get-WebClient -pat $pat -ContentType "application/octet-stream"
write-host "Updating details of pool ID '$poolid' on '$orgUri' with '$description'" -ForegroundColor Green
$uri = "$($orgUri)/_apis/distributedtask/pools/$poolid/poolmetadata?api-version=5.0-preview.1"
$wc.UploadString($uri, "PUT", $description) 
