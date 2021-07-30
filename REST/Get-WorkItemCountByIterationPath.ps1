param
(
        $pat ,
        $org,
        $teamproject
        
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
    $webclient.Headers["Content-Type"] = 'application/json'
    return $webclient
}

function Get-Iterations
{
    param
    (
        $org ,
        $teamproject,
        $pat
    )

    $wc = Get-WebClient -pat $pat

    # write-host "Getting iterations in '$teamproject'" -ForegroundColor Green

    $uri = "https://dev.azure.com/$org/$teamproject/_apis/work/teamsettings/iterations?api-version=6.0"
$uri
    $wc.DownloadString($uri) | ConvertFrom-Json

}

function Get-WorkItemsByQuery
{
    param
    (
        $org ,
        $teamproject,
        $pat,
        $iterationpath
    )

    $wc = Get-WebClient -pat $pat

    # write-host "Getting all Work Items in project '$teamproject' in areapath '$areapath'" -ForegroundColor Green

    $uri = "https://dev.azure.com/$org/$teamproject/_apis/wit/wiql?api-version=6.0"
    $wiq = "SELECT [System.Id], [System.WorkItemType], [System.Title] FROM WorkItems WHERE [System.TeamProject] = @project and [System.IterationPath] = '$Iterationpath' ORDER BY [System.Id]"
    $data = @{query = $wiq } | ConvertTo-Json
    $jsondata = $wc.UploadString($uri,"POST", $data) | ConvertFrom-Json 
    $jsondata
}

$iterations = Get-Iterations -pat $pat -org $org -teamproject $teamproject
$iterations.value | ForEach-Object {
    try {
        $itemcount = (Get-WorkItemsByQuery -pat $pat -org $org -teamproject $teamproject -iteration $_.path).workitems.count
    } catch {
        $itemcount = 20000 ## the max number of work items in a query
    }
    write-host "$($_.path), $itemcount"
}

