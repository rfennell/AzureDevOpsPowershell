##-----------------------------------------------------------------------
## <copyright file="Add-CapabilitiesToAzureDevOpsAgent.ps1.ps1">(c) Richard Fennell. </copyright>
##-----------------------------------------------------------------------
# Adds custom capabilities to an Azure DevOps Agent

param
(
    [parameter(Mandatory=$true,HelpMessage="URL of the Azure DevOps Org e.g. 'https://dev.azure.com/myorg'")]
    $url,

    [parameter(Mandatory=$true,HelpMessage="Personal Access Token")]
    $pat,

    [parameter(Mandatory=$true,HelpMessage="Agent pool name")]
    $pool,

    [parameter(Mandatory=$true,HelpMessage="Agent name")]
    $agentName,

    [parameter(Mandatory=$true,HelpMessage='Capabilities to add e.g. "MyAgent=true, host=$env:computername"')]
    $capabilities
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
    $wc.Headers.Add("Authorization", "Basic $base64");
    $wc
}

function Get-AgentPool {
    param
    (
        $pat,
        $url ,
        $pool
    )

    $wc = Get-WebClient($pat)

    # get the pool ID from the name
    $uri = "$url/_apis/distributedtask/pools?poolName=$pool&api-version=5.1"
    $jsondata = $wc.DownloadString($uri) | ConvertFrom-Json
    $jsondata.value
}

function Get-Agent {
    param
    (
        $pat,
        $url ,
        $poolid,
        $agentName
    )

    $wc = Get-WebClient($pat)

    # get the agent, we can't use the url filter as the name has a random number
    $uri = "$url/_apis/distributedtask/pools/$poolid/agents?api-version=5.1"
    $jsondata = $wc.DownloadString($uri) | ConvertFrom-Json
    $jsondata.value | where { $_.name -eq $agentName }

}


function Update-Agent {
    param
    (
        $pat,
        $url ,
        $poolid,
        $agentid,
        $capabilities
    )

    $wc = Get-WebClient($pat)

    # The documented call in the api does not work, but I found this https://blogs.blackmarble.co.uk/rfennell/2018/12/06/programmatically-adding-user-capabilities-to-azure-devops-agents/

    $uri = "$url/_apis/distributedtask/pools/$poolid/agents/$($agentID)/usercapabilities?api-version=5.1"
    
    # have to pass the ID too else there is a 404 error
    # this is the expected format
    # $capabilities = "AAA , BBB=123"
    $capabilitiesObject = @{}
    foreach ($capability in $capabilities.Split(",")){
        $item = $capability.Split("=")
        $capabilitiesObject.Add($item[0].Trim(), $(if ($item[1] -eq $null) {""} else {$item[1].Trim()}))
    }

    $data = $capabilitiesObject | ConvertTo-Json
    $jsondata = $wc.UploadString($uri,"PUT", $data) | ConvertFrom-Json

}


if ([string]::IsNullOrEmpty($capabilities)) {
    write-host "No user capabilities passing so skipping"
} else {
    write-host "Finding Agent Pool '$pool'"
    $agentPool = Get-AgentPool -url $url -pat $pat -pool $pool
    write-host "Finding Agent '$agentname'"
    $agent = Get-Agent -url $url -pat $pat -poolid $agentPool.id -agentName $agentName 
    write-host "Found agent '$($agent.name)' adding user capabilities '$capabilities'"
    Update-Agent -url $url -pat $pat -poolid $agentPool.id -agentid $agent.id -capabilities $capabilities
    write-host "Added user capabilities"
 
}
