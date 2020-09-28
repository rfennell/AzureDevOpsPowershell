<#
.SYNOPSIS
  Fix missing permissions for Project Administrators
.DESCRIPTION
  Script to make sure the '[My project]Project Administrators' group has permissions in their own project
  Used to correct permissions for projects that have been migrated to Azure DevOps Services and are missing this permission
.PARAMETER Pat
    An Azure DevOps PAT with administrator permissions for all projects in the organisation
.PARAMETER Organisation
    the Azure DevOps organisation e.g. 'myorg' from 'https://dev.azure.com/myorg'
.INPUTS
  None
.OUTPUTS
  None
.NOTES
  Version:        1.0
  Author:         Richard Fennell, Black Marble
  Creation Date:  28th Sep 2020
  Purpose/Change: Initial script development
  
.EXAMPLE
  Update-ProjectAdminPermissions -pat a1b2c3d4e5f6g7h8i9j0k1l2m3 -organisation MyOrg
#>


param
(
  [parameter(Mandatory=$true,HelpMessage="An Azure DevOps PAT with administrator permissions for all projects in the organisation")] 
  [string]$Pat,
    
  [parameter(Mandatory=$true,HelpMessage="The Azure DevOps organisation e.g. 'myorg' from 'https://dev.azure.com/myorg'")]
  [string]$Organisation
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
    merge = 'true';
    accessControlEntries = @(@{
       descriptor = "$descriptor"; # the descriptor defines the account to add permissions for
       allow = 32638;  # a bit flag representation of all the permissions (found using F12 tools)
       deny = 0;
    })
  }
  $jsonBody = ConvertTo-Json $body
  $wc = New-WebClient -pat $pat

  write-host "Updating permissions for: $name"
  $response = $wc.UploadString($uri, "POST", $jsonBody) 
}

# Gets a list of all the projects in the organisation
function Get-Projects {
param
(
  $pat,
  $organiation
)

  $uri = "https://dev.azure.com/$organisation/_apis/projects?api-version=6.0"

  $wc = New-WebClient -pat $pat

  write-host "Getting list of the projects in the organisation '$organisation'"
  $response = $wc.DownloadString($uri) | ConvertFrom-Json

  return $response.value 

}

# Get the list of projects in the organisation
$projects =  Get-Projects -pat $pat -organisation $organisation
# Get the list of `Project Administrators` security objects
$projectAdmins = Get-ProjectAdmins -pat $pat -organisation $organisation

ForEach( $projectAdmin in $projectAdmins) {
   # find the project id via the providerDisplayName which is in the form `[My Project]Project Adminstrators'
   $project = $projects | where-object { $_.name -eq $projectAdmin.providerDisplayName.SubString(1,$projectAdmin.providerDisplayName.IndexOf(']')-1)}
   # Update the permissions
   Update-AllRepositoriesPermissions -pat $pat -organisation $organisation -descriptor $projectAdmin.descriptor -name $projectAdmin.providerDisplayname -projectId $project.id
}