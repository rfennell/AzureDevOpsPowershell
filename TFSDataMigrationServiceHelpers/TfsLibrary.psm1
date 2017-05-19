function Get-WebClient
{
    param
    (
        [string]$username, 
        [string]$password,
        [string]$ContentType = "application/json"
    )

    $wc = New-Object System.Net.WebClient
    $wc.Headers["Content-Type"] = $ContentType
    
    if ([System.String]::IsNullOrEmpty($password))
    {
        $wc.UseDefaultCredentials = $true
    } else 
    {
       $pair = "${username}:${password}"
       $bytes = [System.Text.Encoding]::ASCII.GetBytes($pair)
       $base64 = [System.Convert]::ToBase64String($bytes)
       $wc.Headers.Add("Authorization","Basic $base64");
    }
    $wc    
}

function Get-TeamProjects
{

    param
    (
    $tfsUri,
    $uid,
    $pwd
    )

    $uri = "$($tfsUri)/_apis/projects?api-version=1.0"
    $wc = Get-WebClient -username $uid -password $pwd 
  	$jsondata = $wc.DownloadString($uri) | ConvertFrom-Json 
    $jsondata.value
}