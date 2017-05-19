param
(
   $url = "http://localhost:8080/tfs/defaultcollection"
)

Import-Module -Name "$PSScriptRoot\TfsLibrary.psm1" 

function Remove-TeamProject
{
    param (
        $exe = "C:\Program Files (x86)\Microsoft Visual Studio 14.0\Common7\IDE\TfsDeleteProject.exe",
        $url,
        $tp
    )

  Write-Host "Deleting Team Project [$tp] on collection [$url]" -ForegroundColor Green
  & $exe /q /force /excludewss /collection:$url $tp
}

# Set a flag to force verbose as a default
$VerbosePreference ='Continue' # equiv to -verbose

# your list of projects to delete
$projectNamesToDelete = @(
     "A Project", "B project"
     "C Project", "D Project")

foreach ($tp in $projectNamesToDelete)
{
    Remove-TeamProject -url $url -tp $tp
}

