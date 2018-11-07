##-----------------------------------------------------------------------
## <copyright file="Get-BuildContainingChangeset.ps1">(c) Richard Fennell. </copyright>
##-----------------------------------------------------------------------
# From a changeset/commit numver find any builds that are associated

param (
    [parameter(Mandatory=$true,HelpMessage="URL of the Team Project Collection e.g. 'http://myserver:8080/tfs/defaultcollection'")]
    [string] $serverName,

    [parameter(Mandatory=$true,HelpMessage="Team Project name e.g. 'My Team project'")]
    [string] $teamproject,

    [parameter(Mandatory=$false,HelpMessage="Username for use with Password (should be blank if using Personal Access Toekn or default credentials)")]
    $username,
    
    [parameter(Mandatory=$false,HelpMessage="Password or Personal Access Token (if blank default credentials are used)")]
    $password,  

    [parameter(Mandatory=$true,HelpMessage="Changeset/Commit number")]
    [string]$id
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
       $wc.Headers.Add("Authorization","Basic $base64");
    }
    $wc
}
function Get-BuildDefinitions
{
    param (
        [string]$username, 
        [string]$password, 
        [string]$tfsUri)

    $wc = Get-WebClient -username $username -password $password
    $uri = "$($tfsUri)/_apis/build/definitions?api-version=4.1"
    $wc.DownloadString($uri) | ConvertFrom-Json
}

function Get-BuildByDefinition
{
    param (
        [string]$username, 
        [string]$password, 
        [string]$tfsUri, 
        [string]$id, 
        [string]$token)

    $wc = Get-WebClient -username $username -password $password
    $uri = "$($tfsUri)/_apis/build/builds?definitions=$id&deletedFilter=includeDeleted&continuationToken=$token&api-version=4.1"
    $wc.DownloadString($uri) | ConvertFrom-Json
}



$builddefs = Get-BuildDefinitions -tfsUri $serverName/$teamproject -password $password -username $username
write-verbose "Found $($builddefs.Count) build definitions"
foreach ($def in $builddefs.value)
{
    $builds = Get-BuildByDefinition -tfsUri  $serverName/$teamproject -password $password -username $username -id $def.id
    write-verbose "Found $($builds.count) builds using definition $($def.Name)"
    foreach ($build in $builds.value)
    {
        if ($build.sourceVersion -contains $id)
        {
            write-host "Changeset/Commit $id was found in the build '$($build.buildNumber)' with ID '$($build.id)'"
        }
    }
}




