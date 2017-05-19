param
(
    $url = "http://localhost:8080/tfs/defaultcollection"
)

Import-Module -Name "$PSScriptRoot\TfsLibrary.psm1" 

# Set a flag to force verbose as a default
$VerbosePreference ='Continue' # equiv to -verbose

$projects = Get-TeamProjects -tfsUri $url 

Write-Host $projects.Name -Join ","

foreach ($tp in $projects.Name)
{
    
    write-host $tp
}

