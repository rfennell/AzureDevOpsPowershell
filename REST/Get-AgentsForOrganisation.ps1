param
(
        $pat ,
        $instance 
)




function Get-WebClient {
    [CmdletBinding()]
    param
    (
        $pat
    )

    $webclient = new-object System.Net.WebClient
    $webclient.Encoding = [System.Text.Encoding]::UTF8
    $encodedPat = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes(":$pat"))
    $webclient.Headers.Add("Authorization", "Basic $encodedPat")
    return $webclient
}


$wc = Get-WebClient -pat $pat


Write-host "Instance: $instance" -ForegroundColor Cyan

$pools = $wc.DownloadString("https://dev.azure.com/$instance/_apis/distributedtask/pools") | ConvertFrom-Json

foreach ($pool in $pools.value)
{

    write-host "Agent Pool ID $($pool.id): $($pool.Name)" -ForegroundColor DarkYellow


    $agents = $wc.DownloadString("https://dev.azure.com/$instance/_apis/distributedtask/pools/$($pool.id)/agents") | ConvertFrom-Json

    $agentDetails = @()

    foreach ($agent in $agents.value)
    {
        $agentDetails += $wc.DownloadString("https://dev.azure.com/$instance/_apis/distributedtask/pools/$($pool.id)/agents/$($agent.id)?includeCapabilities=true") | ConvertFrom-Json

    }
    $agentDetails | Format-Table -Property id, Name, status, userCapabilities
}


