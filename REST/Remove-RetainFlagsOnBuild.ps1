##-----------------------------------------------------------------------
## <copyright file="Remove-RetainFlagsOnBuild.ps1.ps1">(c) Richard Fennell. </copyright>
##-----------------------------------------------------------------------
# Removes the flags on a build even if the release that set them is removed

param
(
    [parameter(Mandatory=$true,HelpMessage="URL of the Azure DevOps Instance e.g. 'https://dev.azure.com/mycompany'")]
    $uri,
    
    [parameter(Mandatory=$true,HelpMessage="Team Project name e.g. 'My Team project'")]
    $teamproject,
    
    [parameter(Mandatory=$false,HelpMessage="Username for use with Password (should be blank if using Personal Access Toekn or default credentials)")]
    $username,
    
    [parameter(Mandatory=$false,HelpMessage="Password or Personal Access Token (if blank default credentials are used)")]
    $password,  

    [parameter(Mandatory=$true,HelpMessage="Build number")]
    [string]$id
)

function Get-WebClient
{
 param
    (
        [string]$username, 
        [string]$password,
        [string]$contentType = "application/json"
    )

    $wc = New-Object System.Net.WebClient
    $wc.Headers["Content-Type"] = $contentType
    
    if ([System.String]::IsNullOrEmpty($password))
    {
        $wc.UseDefaultCredentials = $true
    } else 
    {
       # This is the form for basic creds so either basic cred (in TFS/IIS) or alternate creds (in VSTS) are required"
       $pair = "${username}:${password}"
       $bytes = [System.Text.Encoding]::ASCII.GetBytes($pair)
       $base64 = [System.Convert]::ToBase64String($bytes)
       $wc.Headers.Add("Authorization","Basic $base64");
    }
 
    $wc
}

function Remove-Flags
{
    param
    (
        $uri,
        $teamproject,
        $id,
        [string]$username, 
        [string]$password
    )

    $webclient = Get-WebClient -username $username -password $password

    write-verbose "Removing retension flags"

    $uri = "$($uri)/$($teamproject)/_apis/build/builds/$($id)?api-version=4.1"
    $uri

    $data = 
    @{
      keepForever= "false";
      RetainedByRelease = "false"
    }
    $jsondata = $data | ConvertTo-Json

    $response = $webclient.UploadString($uri,"PATCH", $jsondata )| ConvertFrom-Json
    $response

}


Remove-Flags -uri $uri -teamproject $teamproject -id $id -password $password -username $username 