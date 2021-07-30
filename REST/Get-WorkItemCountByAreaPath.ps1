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

function Get-Areas
{
    param
    (
        $org ,
        $teamproject,
        $pat
    )

    $wc = Get-WebClient -pat $pat

    # write-host "Getting areas in '$teamproject'" -ForegroundColor Green

    $uri = "https://dev.azure.com/$org/$teamproject/_apis/wit/classificationnodes/Areas?`$depth=1000&api-version=6.0"

    $wc.DownloadString($uri) | ConvertFrom-Json

}
function Get-WorkItemsByQuery
{
    param
    (
        $org ,
        $teamproject,
        $pat,
        $areapath
    )

    $wc = Get-WebClient -pat $pat

    # write-host "Getting all Work Items in project '$teamproject' in areapath '$areapath'" -ForegroundColor Green

    $uri = "https://dev.azure.com/$org/$teamproject/_apis/wit/wiql?api-version=6.0"
    $wiq = "SELECT [System.Id], [System.WorkItemType], [System.Title] FROM WorkItems WHERE [System.TeamProject] = @project and [System.AreaPath] = '$Areapath' ORDER BY [System.Id]"
    $data = @{query = $wiq } | ConvertTo-Json
    $jsondata = $wc.UploadString($uri,"POST", $data) | ConvertFrom-Json 
    $jsondata
}

$rootarea = Get-Areas -pat $pat -org $org -teamproject $teamproject
write-host "$($rootarea.name), $((Get-WorkItemsByQuery -pat $pat -org $org -teamproject $teamproject -areapath $rootarea.name).workitems.count)"

$rootarea.children | ForEach-Object {
    $fixedAreaPath = $_.path.substring(1).replace("\Area", "") # builld the areapath
    try {
        $itemcount = (Get-WorkItemsByQuery -pat $pat -org $org -teamproject $teamproject -areapath $fixedAreaPath).workitems.count
    } catch {
        $itemcount = 20000 ## the max number of work items in a query
    }
    write-host "$fixedAreaPath, $itemcount"
}

