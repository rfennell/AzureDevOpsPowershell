param
(
     [string]$instance,
     [string]$teamproject,
     [string]$username,
     [string]$password,
     $definitionID
   
)


function Get-WebClient {
    param
    (
        [string]$username,
        [string]$password,
        [string]$ContentType = "application/json"
    )

    $wc = New-Object System.Net.WebClient
    $wc.Headers["Content-Type"] = $ContentType

    if ([System.String]::IsNullOrEmpty($password)) {
        $wc.UseDefaultCredentials = $true
    }
    else {
        $pair = "${username}:${password}"
        $bytes = [System.Text.Encoding]::ASCII.GetBytes($pair)
        $base64 = [System.Convert]::ToBase64String($bytes)
        $wc.Headers.Add("Authorization", "Basic $base64");
    }
    $wc
}

function Get-RunningBuildsByDefintion {
    param
    (  
        [string]$username,
        [string]$password,
        $instance,
        $teamproject,
        $defintionID
    )

    $wc = Get-WebClient -username $username -password $password 
    $uri = "https://dev.azure.com/$instance/$teamproject/_apis/build/builds?defintions=$($defintionID)&statusFilter=InProgress,notStarted&api-version=4.1"
    $jsondata = $wc.DownloadString($uri) | ConvertFrom-Json
    $jsondata.value
}


function Cancel-Build {
    param
    (  
        [string]$username,
        [string]$password,
        $instance,
        $teamproject,
        $buildid
    )

    $wc = Get-WebClient -username $username -password $password
    
    Write-Host "Cancelling build $buildid"
    $uri = "https://dev.azure.com/$instance/$teamproject/_apis/build/builds/$($buildid)?api-version=4.1"
    $data = @(@{status = "Cancelling"}   ) | ConvertTo-Json
    $jsondata = $wc.UploadString($uri,"PATCH", $data) | ConvertFrom-Json
    #$jsondata
}

foreach ($build in Get-RunningBuildsByDefintion -Build -username $username -password $password -instance $instance -teamproject $teamproject -defintionID $definitionid)
{
    Cancel-Build -username $username -password $password -instance $instance -teamproject $teamproject -buildid $build.id
}