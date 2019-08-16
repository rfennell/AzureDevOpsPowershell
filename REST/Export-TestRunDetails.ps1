param
(

   [parameter(Mandatory=$true,HelpMessage="URL of the Team Project Collection e.g. 'http://myserver:8080/tfs/defaultcollection'")]
    $collectionUrl,

    [parameter(Mandatory=$true,HelpMessage="Team Project name e.g. 'My Team project'")]
    $teamproject ,
    
    [parameter(Mandatory=$false,HelpMessage="Username for use with Password (should be blank if using Personal Access Toekn or default credentials)")]
    $username,

    [parameter(Mandatory=$false,HelpMessage="Password or Personal Access Token (if blank default credentials are used)")]
    $password,

    [parameter(Mandatory=$true,HelpMessage="The run details to return")]
    $runid

)


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
       $wc.Headers.Add(“Authorization”,"Basic $base64");
    }

    $wc
}



function Get-TestInRun
{
    param
    (
        $tfsUri ,
        $runid,
        $username,
        $password

    )


    #write-host "Getting details for WI '$id' via '$tfsUri' " -ForegroundColor Green

    $wc = Get-WebClient -username $username -password $password

    $uri = "$($tfsUri)/$teamproject/_apis/test/Runs/$runid/results"

    $jsondata = $wc.DownloadString($uri) | ConvertFrom-Json
    $jsondata.value
}

$outfile = "$runid.csv"
$tests = Get-TestInRun -tfsUri $collectionUrl -runid $runid -username $username -password $password 
Write-Host "Exporting $($tests.count) test to '$outfile'" 
$tests | Select -ExpandProperty testcase -property outcome | Export-Csv -Path $outfile -NoTypeInformation