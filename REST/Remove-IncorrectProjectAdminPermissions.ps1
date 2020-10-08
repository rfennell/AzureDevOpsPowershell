<#
.SYNOPSIS
  Removes excess permissions for Project Administrators
.DESCRIPTION
  Script to make sure the '[My project]Project Administrators' groups only have permissions in their own project
  Used to correct permissions for projects that have been migrated to Azure DevOps Services and are missing this permission
.PARAMETER Pat
    An Azure DevOps PAT with administrator permissions for all projects in the organisation
.PARAMETER Organisation
    the Azure DevOps organisation e.g. 'myorg' from 'https://dev.azure.com/myorg'
.PARAMETER ProjectName
    A single project name to limit the scope of the script e.g. 'myproj'
.PARAMETER WhatIf
    if set will only list the identities without updating permissions
.INPUTS
  None
.OUTPUTS
  None
.NOTES
  Version:        1.0
  Author:         Richard Fennell, Black Marble
  Creation Date:  7th Oct 2020
  Purpose/Change: Initial script development
  Version:        1.1
  Author:         Richard Fennell, Black Marble
  Creation Date:  8th Oct 2020
  Purpose/Change: Add a filter for a single project
  
.EXAMPLE
  Remove-IncorrectProjectAdminPermissions -pat a1b2c3d4e5f6g7h8i9j0k1l2m3 -organisation MyOrg -projectName myproj-Whatif
#>

[CmdletBinding(SupportsShouldProcess=$true)]
param
(
  [parameter(Mandatory=$true,HelpMessage="An Azure DevOps PAT with administrator permissions for all projects in the organisation")] 
  [string]$Pat,
    
  [parameter(Mandatory=$true,HelpMessage="The Azure DevOps organisation e.g. 'myorg' from 'https://dev.azure.com/myorg'")]
  [string]$Organisation,

  [parameter(Mandatory=$false,HelpMessage="A single project name to limit the scope of the script")]
  [string]$ProjectName = ""

)

# Creates a REST client
function New-WebClient {
param
(
  $pat
)
        
  $webclient = new-object System.Net.WebClient
  $webclient.Encoding = [System.Text.Encoding]::UTF8

  $encodedPat = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes(":$pat"))
  $webclient.Headers.Add("Authorization", "Basic $encodedPat")
  $webclient.Encoding = [System.Text.Encoding]::UTF8
  $webclient.Headers["Content-Type"] = "application/json"
    
  $webclient
}

# Gets a list of all the '[My project]Project Administrators'
function Get-ProjectAdmins {
param
(
  $pat,
  $organisation
)

  $uri = "https://vssps.dev.azure.com/$organisation/_apis/identities?searchFilter=General&filterValue=Project%20Administrators&queryMembership=None&api-version=6.0"
  $wc = New-WebClient -pat $pat

  write-host "Getting list of the 'Project Administrator' objects for all projects in the organisation '$organisation'"
  $response = $wc.DownloadString($uri) | ConvertFrom-Json

  return $response.value 
}

# Updates the permissions for the 'All Repositories' namespace
# The code for this function was discovered by editing the 'All Respositories' permissions in the Azure DevOps UI and monitoring the network traffic with Browser F12 dev tools
function Update-AllRepositoriesPermissions {
param
(
  $pat,
  $organisation,
  $descriptor,
  $name,
  $projectId
)

  # The namespace guid for 'All Git Repository' Permissions is fixed for all Azure DevOps instances
  # You can use the Azure DevOps CLI https://github.com/Azure/azure-devops-cli-extension to get the list of namespaces
  # using the command https://github.com/Azure/azure-devops-cli-extension/blob/86317bac0e7e5a9dcde4c75aa0a5fc150b442fe3/doc/permissions.md
  # Or use network trace tools on a browser when performing the required operation
  $uri = "https://dev.azure.com/$organisation/_apis/AccessControlEntries/2e9eb7ed-3c0a-47d4-87c1-0ffdd275fd87?api-version=6.0"
 
 $body = @{
    token = "repoV2/$projectId/";  # the token is based on the project ID see https://github.com/Azure/azure-devops-cli-extension/blob/master/doc/security_tokens.md
    merge = 'false';  # needs to be false to remove permission.
    accessControlEntries = @(@{
       descriptor = "$descriptor"; # the descriptor defines the account to add permissions for
       allow = 0;  # a bit flag representation of all the permissions (found using F12 tools) zero removes the permission
       deny = 0;
    })
  }
  $jsonBody = ConvertTo-Json $body
  $wc = New-WebClient -pat $pat

  $response = $wc.UploadString($uri, "POST", $jsonBody) 
}

# Gets a list of all the projects in the organisation
function Get-Projects {
param
(
  $pat,
  $organisation
)

  $uri = "https://dev.azure.com/$organisation/_apis/projects?api-version=6.0"

  $wc = New-WebClient -pat $pat

  write-host "Getting list of the projects in the organisation '$organisation'"
  $response = $wc.DownloadString($uri) | ConvertFrom-Json

  return $response.value 

}

function Get-ActivePermissionsInProject {
param
(
  $pat,
  $organisation,
  $project
)

  $uri = "https://dev.azure.com/$organisation/_apis/accesscontrollists/2e9eb7ed-3c0a-47d4-87c1-0ffdd275fd87?token=repoV2/$($project.id)&api-version=6.0"

  $wc = New-WebClient -pat $pat

  write-host "Getting list of the permissions for project '$($project.name)' in the organisation '$organisation'"
  $response = $wc.DownloadString($uri) | ConvertFrom-Json

  return $response.value 

}

$projects =  Get-Projects -pat $pat -organisation $organisation

if ($ProjectName.Length -gt 0 ) {
    $projects = $projects | Where-Object { $_.name -eq $ProjectName}

    # check we found it
    if ($projects.name -eq $projectname) {
       write-host "Limiting the project to update to the single project '$projectname'"
    } else {
       write-host "Cannot find the requested project'$projectname'"
       return
    }
}

# Get the list of `Project Administrators` security objects
$projectAdmins = Get-ProjectAdmins -pat $pat -organisation $organisation


ForEach( $project in $projects) {
    
    $perms = Get-ActivePermissionsInProject -pat $pat -organisation $organisation -project $project

    # find the admins who should not be in this project
    $invalidAdminsForProject = $projectAdmins | where-object { $_.providerDisplayName -ne "[$($project.name)]\Project Administrators"}  
    
    foreach ($perm in $perms.acesDictionary.PsObject.Properties.value) {
        $extraPermissions = $invalidAdminsForProject | Where-Object {$_.descriptor -eq  $perm.descriptor} 
        foreach ($extraPermission in $extraPermissions) {
           if($PSCmdlet.ShouldProcess($extraPermission.providerDisplayName, "Remove permissions for identity")){
               # comment out this line if you only want to view the excess permissions
               Update-AllRepositoriesPermissions -pat $pat -organisation $organisation -descriptor $extraPermission.descriptor -name $extraPermission.providerDisplayname -projectId $project.id
               write-host "The permission '$($extraPermission.providerDisplayName)' has been removed"
           }
        }
    }
    
}

