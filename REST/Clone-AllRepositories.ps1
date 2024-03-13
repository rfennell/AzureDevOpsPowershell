##-----------------------------------------------------------------------
## <copyright file="Clone-AllRepositories.ps1">(c) Richard Fennell. </copyright>
##-----------------------------------------------------------------------
# Finds all the repos in a Azure DevOps in a team project and clones them

param (

    # can be the system.accesstoken in the pipeline
    $pat,
    # in format https://dev.azure.com/org/project
    $url
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



$wc = Get-WebClient($pat)

# get the repo list
$uri = "$url/_apis/git/repositories"
$jsondata = $wc.DownloadString($uri) | ConvertFrom-Json
$repos = $jsondata.value

# this is the dataset, uncomment to see all fields
# $repos

write-host "Found $($repos.Count) repos"

# clone each repo into the current folder
foreach ($repo in $repos) {
    write-host "Cloning $($repo.name)"
    write-host "Using command 'git clone $($repo.remoteurl)'"
    & git clone $repo.remoteurl
}
