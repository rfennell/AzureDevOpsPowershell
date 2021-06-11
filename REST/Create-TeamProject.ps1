##-----------------------------------------------------------------------
## <copyright file="Create-TeamProject.ps1">(c) Richard Fennell. </copyright>
##-----------------------------------------------------------------------
# Script to assist in the creation of a new team project from a template
# The script create a new team project
# Clones a repo into the project with an ARM and C# code sample
# Create a project WIKI
# Sets up a Service Connection to SonarQube
# Updates the YAML build pipeline to use the SonarQube and WIKI
# Update the main branch protection
# The Azure CLI (https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-windows?tabs=azure-cli) and Git command line must be installed
param
(
    [parameter(Mandatory=$false,HelpMessage="The target Azure DevOps Instance to create the new project in")]
    $org,

    [parameter(Mandatory=$true,HelpMessage="The new project name")]
    $projectName,

    [parameter(Mandatory=$true,HelpMessage="The new project SonarQube key e.g. ABC")]
    $projectSonarKey,

    [parameter(Mandatory=$true,HelpMessage="Azure DevOps PAT with access to target org")]
    $pat,

    [parameter(Mandatory=$false,HelpMessage="The URL to clone the the source repo e.g https://myorg@dev.azure.com/myorg/StandardProjectSample/_git/StandardProjectSample")]
    $sourceRepoUrl,

    [parameter(Mandatory=$false,HelpMessage="Azure DevOps PAT with access to source sample project, defaults to the same target PAT if not specified")]
    $sourcePat,

    [parameter(Mandatory=$true,HelpMessage="The SonarQube access token for use by the Service Endpoint")]
    $sonarQubeAccesskey,

    [parameter(Mandatory=$false,HelpMessage="The SonarQube URL e.g. https://sonarqube.mydomain.co.uk/")]
    $sonarQubeUrl ,

    [parameter(Mandatory=$false,HelpMessage="The default SonarQube key to replace in config")]
    $defaultProjectSonarKey = "BMS",

    [parameter(Mandatory=$false,HelpMessage="The default project name to replace in config")]
    $defaultProjectName = "Black Marble Sample", 

    [parameter(Mandatory=$false,HelpMessage="The default WIKI URL to replace in config")]
    $defaultWikiURL = "https://blackmarble-source@dev.azure.com/blackmarble-source/StandardProjectSample/_git/StandardProjectSample.wiki" 
)

write-host "This script uses the Azure CLI" -ForegroundColor Green

if ($sourcePat -eq $null) {
   Write-Host "Using the primary PAT for both source and target connections" -ForegroundColor Yellow
   $sourcePat = $pat
}

$fullOrgUrl = "https://dev.azure.com/$org" 
Write-host "This script used 'az devops' and 'git.exe' commands, these both throw random error messages even when they work" -ForegroundColor Yellow
Write-host "These can be suppressed by setting script used '$ErrorActionPreference = ""silentlycontinue""'" -ForegroundColor Yellow
# hide error messages
# $ErrorActionPreference = "silentlycontinue"
# show the erro messages
$ErrorActionPreference = "continue"

Write-host "Connecting to '$fullOrgUrl'" -ForegroundColor Green
$pat | az devops login --org $fullOrgUrl

write-host "Checking if project '$projectName' already exists" -ForegroundColor Green
$p = az devops project show --project $projectName --org $fullOrgUrl 
if ($p -ne $null) {
  # if we get here the project does exist
  write-host "Project '$projectName' already exists, so exiting" -ForegroundColor Green
  exit
}

Write-host "Creating new project '$projectName'" -ForegroundColor Green
$project = az devops project create --name $projectName --org $fullOrgUrl | convertfrom-json

Write-host "Import the default repo from our standard sample" -ForegroundColor Green
$env:AZURE_DEVOPS_EXT_GIT_SOURCE_PASSWORD_OR_PAT = $sourcePat
$import = az repos import create --git-source-url $sourceRepoUrl -p $projectName --repository $projectName --org $fullOrgUrl --requires-authorization | convertfrom-json

Write-host "Create the default wiki" -ForegroundColor Green
$wiki = az devops wiki create --org $fullOrgUrl -p $projectName | convertfrom-json

Write-host "Create the wiki home page in WIKI '$($wiki.name)'" -ForegroundColor Green
$page = az devops wiki page create --org $fullOrgUrl -p $projectName --wiki $wiki.name --path "Home" --content "Home page for project $projectName" | convertfrom-json

Write-host "Update the SonarQube setting in the build using clone of repo in '$env:TEMP'"  -ForegroundColor Green
if (test-path $env:TEMP\$projectname) {
    Write-host "Removing the temp folder '$projectname'" -ForegroundColor Yellow
    remove-item $env:TEMP\$projectname -recurse -force
}

& git clone $import.repository.remoteUrl $env:TEMP\$projectname 

$fileName = "$env:TEMP\$projectname\azure-pipelines.yml"
$filecontent = Get-Content -Path $fileName
$filecontent = $filecontent -replace $defaultProjectSonarKey, $projectSonarKey
$filecontent = $filecontent -replace $defaultProjectName , $projectName 
$filecontent = $filecontent -replace $defaultWikiURL , "https://$org@dev.azure.com/$org/$projectName/_git/$($wiki.name)" 

$filecontent | out-file $filename 

$oldLocation =  Get-Location
Set-Location $env:TEMP\$projectname
& git add $fileName
& git commit -m 'Update SonarQube settings'
& git push
Set-Location $oldLocation

Write-host "Create a default build" -ForegroundColor Green
$pipeline = az pipelines create --name $projectName --project $projectName --repository $projectName --repository-type tfsgit --branch main --org $fullOrgUrl --yml-path azure-pipelines.yml  | convertfrom-json

# setup REST client
$headers = @{ Accept="application/json" }
$headers["Accept-Charset"] = "utf-8"
$encodedPat = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes(":$pat"))
$headers["Authorization"] = "Basic $encodedPat"

# Set the branch policies used for PRs into the main branch usin the REST API
write-host "Update the branch policies" -ForegroundColor Green
$repoId = $import.repository.id

$jsonBodies = @{}
$jsonBodies.Add("Require reviewer", '{"type":{"id":"fa4e907d-c16b-4a4c-9dfa-4906e5d171dd"},"revision":1,"isDeleted":false,"isBlocking":true,"isEnabled":true,"settings":{"allowDownvotes":false,"blockLastPusherVote":false,"creatorVoteCounts":false,"requireVoteOnLastIteration":false,"resetOnSourcePush":false,"resetRejectionsOnSourcePush":false,"minimumApproverCount":2,"scope":[{"repositoryId":"'+ $repoId +'","refName":"refs/heads/main","matchKind":"Exact"}]}}')
$jsonBodies.Add("Linked work items", '{"type":{"id":"40e92b44-2fe1-4dd6-b3d8-74a9c21d0c6e"},"revision":1,"isDeleted":false,"isBlocking":true,"isEnabled":true,"settings":{"scope":[{"repositoryId":"'+ $repoId +'","refName":"refs/heads/main","matchKind":"Exact"}]}}')
$jsonBodies.Add("Check comments", '{"type":{"id":"c6a1889d-b943-4856-b76f-9e46bb6b0df2"},"revision":1,"isDeleted":false,"isBlocking":true,"isEnabled":true,"settings":{"scope":[{"repositoryId":"'+ $repoId +'","refName":"refs/heads/main","matchKind":"Exact"}]}}')
$jsonBodies.Add("Require a build", '{"type":{"id":"0609b952-1397-4640-95ec-e00a01b2c241"},"revision":1,"isDeleted":false,"isBlocking":true,"isEnabled":true,"settings":{"buildDefinitionId":"' + $($pipeline.definition.id) + '","displayName":null,"manualQueueOnly":false,"queueOnSourceUpdateOnly":true,"validDuration":720,"scope":[{"repositoryId":"'+ $repoId +'","refName":"refs/heads/main","matchKind":"Exact"}]}}')

$uri = "$fullOrgUrl/$($project.id)/_apis/policy/Configurations?api-version=6.1-preview.1"

# cannot get ` az repos policy create` to work, cannot work out the format, so use undocumented API calls found from Chrome Dev Tools
$jsonBodies.getEnumerator() | foreach {
    write-host "  - Set the branch policy - $($_.Key)" -ForegroundColor Green
    $p1 = Invoke-RestMethod $uri -Method "POST" -Headers $headers -ContentType "application/json" -Body ([System.Text.Encoding]::UTF8.GetBytes($_.Value)) 
}

# Add a link to sonarqube using the REST API
write-host "Add a SonarQube Endpoint" -ForegroundColor Green
$jsonBody = '{"administratorsGroup":null,"authorization":{"scheme":"UsernamePassword","parameters":{"username":"' + $sonarQubeAccesskey +'"}},"createdBy":null,"data":{},"description":"","groupScopeId":null,"name":"SonarQube","operationStatus":null,"readersGroup":null,"serviceEndpointProjectReferences":[{"description":"","name":"SonarQube","projectReference":{"id":"' + $($project.id) +'","name":"' + $projectName +'"}}],"type":"sonarqube","url":"' + $sonarQubeUrl +'","isShared":true,"owner":"library"}'

$uri = "$fullOrgUrl/$($project.id)/_apis/serviceendpoint/endpoints?api-version=6.0-preview"

$p1 = Invoke-RestMethod $uri -Method "POST" -Headers $headers -ContentType "application/json" -Body ([System.Text.Encoding]::UTF8.GetBytes($jsonBody)) 

# For the release notes task to work we need to have the correct job authorisation setting and correct permissions
write-host "Set the limit job authorisation" -ForegroundColor Green
$jsonBody = '{"contributionIds":["ms.vss-build-web.pipelines-general-settings-data-provider"],"dataProviderContext":{"properties":{"enforceReferencedRepoScopedToken":"false","sourcePage":{"url":"' + $fullorg +'/' + $projectname +'/_settings/settings","routeId":"ms.vss-admin-web.project-admin-hub-route","routeValues":{"project":"' + $projectname + '","adminPivot":"settings","controller":"ContributedPage","action":"Execute"}}}}}'

$uri = "$fullOrgUrl/_apis/Contribution/HierarchyQuery?api-version=6.0-preview"

$p1 = Invoke-RestMethod $uri -Method "POST" -Headers $headers -ContentType "application/json" -Body ([System.Text.Encoding]::UTF8.GetBytes($jsonBody)) 

write-host "Grant build user WIKI access" -ForegroundColor Green
$uri = "https://vssps.dev.azure.com/$org/_apis/identities?searchFilter=General&filterValue=$projectname%20Build%20Service%20($org)&queryMembership=None&api-version=6.0"
$user = Invoke-RestMethod $uri -Method "Get" -Headers $headers -ContentType "application/json" 

$jsonBody = '{"token":"repoV2/' + $project.id +'/'+ $wiki.id + '/","merge":true,"accessControlEntries":[{"descriptor":"' + $user.value.descriptor + '","allow":4,"deny":0,"extendedInfo":{"effectiveAllow":4,"effectiveDeny":0,"inheritedAllow":4,"inheritedDeny":0}}]}'

# the 2e9eb7ed-3c0a-47d4-87c1-0ffdd275fd87 is unque identfier for the permission set
$uri = "$fullOrgUrl/_apis/AccessControlEntries/2e9eb7ed-3c0a-47d4-87c1-0ffdd275fd87?api-version=6.0-preview"

$p1 = Invoke-RestMethod $uri -Method "POST" -Headers $headers -ContentType "application/json" -Body ([System.Text.Encoding]::UTF8.GetBytes($jsonBody)) 

Write-host "The new projcts default pipeline will generate errors because the access to some areas need to be authorised"
Write-host "The following should be done to test the team project"
Write-host " - Update the repo readme.me with project details"
Write-host " - Run a test build"
Write-host "   - Authorise access to endpoints as required"
Write-host "   - Make the code is compiled and tests run"
Write-host "   - SonarQube analysis is performed"
Write-host "   - Make sure release notes are generated"
Write-host "   - Note: The ARM deployment will fail until an Azure Service Endpoint is configured"
Write-host " - [Optional] Rename the Git repo if having a name other than that of the Team Project is required"
Write-host " - [Optional] Rename the Pipeline if having a name other than that of the Team Project is required"
