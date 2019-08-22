param
(

    [parameter(Mandatory = $true, HelpMessage = "URL of the Team Project Collection e.g. 'http://myserver:8080/tfs/defaultcollection'")]
    $tfsuri = 'https://blackmarblelabs.visualstudio.com',

    [parameter(Mandatory = $true, HelpMessage = "Team Project name e.g. 'My Team project'")]
    $teamproject ,
    
    [parameter(Mandatory = $false, HelpMessage = "Username for use with Password (should be blank if using Personal Access Toekn or default credentials)")]
    $username,

    [parameter(Mandatory = $false, HelpMessage = "Password or Personal Access Token (if blank default credentials are used)")]
    $password,

    [parameter(Mandatory = $true, HelpMessage = "The Json template for the boards")]
    $templateFile = "DefaultColumns.json"

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
        $wc.Headers.Add(“Authorization”, "Basic $base64");
    }

    $wc
}

function Get-Teams {
    param 
    (
        $tfsUri ,
        $teamproject,
        $username,
        $password
    )    
    
    # write-host "Getting teams from '$teamproject' via '$tfsUri' " -ForegroundColor Green

    $wc = Get-WebClient -username $username -password $password

    $uri = "$($tfsUri)/_apis/projects/$teamproject/teams?api-version=5.1"
    $jsondata = $wc.DownloadString($uri) | ConvertFrom-Json
    $jsondata.value
}

function Get-Boards {
    param 
    (
        $tfsUri ,
        $teamproject,
        $teamname,
        $username,
        $password
    )    
    
    #write-host "Getting boards from '$teamname' via '$tfsUri/$teamproject' " -ForegroundColor Green

    $wc = Get-WebClient -username $username -password $password

    $uri = "$($tfsUri)/$teamproject/$teamname/_apis/work/boards?api-version=5.1"
    $jsondata = $wc.DownloadString($uri) | ConvertFrom-Json
    $jsondata.value
}

function Get-BoardColumns {
    param
    (
        $tfsUri ,
        $teamproject,
        $teamname,
        $boardid,
        $username,
        $password
    )

    #write-host "Getting details for board '$boardid' via '$tfsUri/$teamproject' " -ForegroundColor Green

    $wc = Get-WebClient -username $username -password $password

    $uri = "$($tfsUri)/$teamproject/$teamname/_apis/work/boards/$boardid/columns?api-version=5.1"
    $jsondata = $wc.DownloadString($uri) | ConvertFrom-Json
    $jsondata.value
}

function Update-BoardColumns {
    param
    (
        $tfsUri ,
        $teamproject,
        $boardid,
        $teamname,
        $username,
        $password,
        $template
    )


    #write-host "Updating details for board '$boardid' via '$tfsUri/$teamproject' " -ForegroundColor Green

    $wc = Get-WebClient -username $username -password $password

    $uri = "$($tfsUri)/$teamproject/$teamname/_apis/work/boards/$boardid/columns?api-version=5.1"
    $data = $template | ConvertTo-Json
    $jsondata = $wc.UploadString($uri, "PUT", $data) | ConvertFrom-Json
  
    #$jsondata
}

$teams = Get-Teams -tfsUri $tfsuri -teamproject $teamproject -username $username -password $password
write-host "Found $($teams.count) teams in '$teamproject'"
foreach ($team in $teams) {
    $boards = Get-Boards -tfsUri $tfsuri -teamproject $teamproject -username $username -password $password -teamname $team.id   
    write-host "Found $($boards.count) boards in '$($team.name)'"
    $backlogboard = $boards | Where-Object { $_.name -eq 'Backlog items' }
    write-host "Updating backlog board"
    $OldColumns = Get-BoardColumns -tfsUri $tfsuri -teamproject $teamproject -username $username -password $password -boardid $backlogboard.id -teamname $team.id
    write-host "   Get template"
    $template = Get-Content -Raw -Path $templateFile | ConvertFrom-Json
    write-host "   Setting New and Done IDs"
    $template[0].id = $OldColumns[0].id
    $template[-1].id = $OldColumns[-1].id
    write-host "   Save changes"
    #Board id removed from params, need to pass in board id 
    Update-BoardColumns -tfsUri $tfsuri -teamproject $teamproject -username $username -password $password -boardid $backlogboard.id -template $template -teamname $team.id
}
