##-----------------------------------------------------------------------
## <copyright file="Create-ReleaseNotes.ps1">(c) Richard Fennell. </copyright>
##-----------------------------------------------------------------------
# Create as a Markdown Release notes file for a build froma template file
#
# Where the format of the template file is as follows
# Note the use of @@WILOOP@@ and @@CSLOOP@@ marker to denotes areas to be expended 
# based on the number of work items or change sets
# Other fields can be added to the report by accessing the $build, $wiDetail and $csdetail objects
#
# #Release notes for build $defname  `n
# **Build Number**  : $($build.buildnumber)   `n
# **Build completed** $("{0:dd/MM/yy HH:mm:ss}" -f [datetime]$build.finishTime)   `n   
# **Source Branch** $($build.sourceBranch)   `n
# 
# ###Associated work items   `n
# @@WILOOP@@
# * **$($widetail.fields.'System.WorkItemType') $($widetail.id)** [Assigned by: $($widetail.fields.'System.AssignedTo')] $($widetail.fields.'System.Title')
# @@WILOOP@@
# `n
# ###Associated change sets/commits `n
# @@CSLOOP@@
# * **ID $($csdetail.id)** $($csdetail.message)
# @@CSLOOP@@


#Enable -Verbose option
[CmdletBinding()]
param (

    [parameter(Mandatory=$true,HelpMessage="URL of the Team Project Collection e.g. 'http://myserver:8080/tfs/defaultcollection'")]
    $collectionUrl,
    
    [parameter(Mandatory=$true,HelpMessage="Team Project name e.g. 'My Team project'")]
    $teamproject  ,
  
    [parameter(Mandatory=$true,HelpMessage="Build definition name")]
    $defname ,

    [parameter(Mandatory=$true,HelpMessage="The markdown output file")]
    $outputfile ,

    [parameter(Mandatory=$true,HelpMessage="The markdown template file")]
    $templatefile ,

    [parameter(Mandatory=$false,HelpMessage="Specific build to create report for. If blank last successful build used")]
    $buildnumber,

    [parameter(Mandatory=$false,HelpMessage="Username for use with Password (should be blank if using Personal Access Token or default credentials)")]
    $username,
    
    [parameter(Mandatory=$false,HelpMessage="Password or Personal Access Token (if blank default credentials are used)")]
    $password  

    
)

# Set a flag to force verbose as a default
$VerbosePreference ='Continue' # equiv to -verbose

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
       # This is the form for basic creds so either basic cred (in TFS/IIS) or alternate creds (in VSTS) are required"
       # or just pass a personal access token in place of a password
       $pair = "${username}:${password}"
       $bytes = [System.Text.Encoding]::ASCII.GetBytes($pair)
       $base64 = [System.Convert]::ToBase64String($bytes)
       $wc.Headers.Add("Authorization","Basic $base64");
    }
 
    $wc
}


function Get-BuildDefinitionId
{

    param
    (
    $tfsUri,
    $teamproject,
    $defname,
    $username,
    $password
    )

    $wc = Get-WebClient -username $username -password $password
    $uri = "$($tfsUri)/$($teamproject)/_apis/build/definitions?api-version=2.0&name=$($defname)"
    $jsondata = $wc.DownloadString($uri) | ConvertFrom-Json 
    $jsondata.value.id 

}

function Get-LastSuccessfulBuild
{
    param
    (
    $tfsUri,
    $teamproject,
    $defid,
    $username,
    $password
    )

    $wc = Get-WebClient -username $username -password $password
    $uri = "$($tfsUri)/$($teamproject)/_apis/build/builds?api-version=2.0&definitions=$($defid)&statusFilter=completed&`$top=1"
    $jsondata = $wc.DownloadString($uri) | ConvertFrom-Json 
    $jsondata.value
}

function Get-Build
{

    param
    (
    $tfsUri,
    $teamproject,
    $defid,
    $buildnumber,
    $username,
    $password
    )

    $wc = Get-WebClient -username $username -password $password
    $uri = "$($tfsUri)/$($teamproject)/_apis/build/builds?api-version=2.0&definitions=$($defid)&buildnumber=$($buildnumber)"
    $jsondata = $wc.DownloadString($uri) | ConvertFrom-Json 
    $jsondata.value
}


function Get-BuildWorkItems
{
    param
    (
    $tfsUri,
    $teamproject,
    $buildid,
    $username,
    $password
    )

    $wc = Get-WebClient -username $username -password $password
    $uri = "$($tfsUri)/$($teamproject)/_apis/build/builds/$($buildid)/workitems?api-version=2.0"
    $jsondata = $wc.DownloadString($uri) | ConvertFrom-Json 
    $jsondata.value 
}

function Get-BuildChangeSets
{
    param
    (
    $tfsUri,
    $teamproject,
    $buildid,
    $username,
    $password
    )

    $wc = Get-WebClient -username $username -password $password
    $uri = "$($tfsUri)/$($teamproject)/_apis/build/builds/$($buildid)/changes?api-version=2.0"
    $jsondata = $wc.DownloadString($uri) | ConvertFrom-Json 
    $jsondata.value 
}


function Get-WorkItemDetail
{
    param
    (
    $url,
    $username,
    $password
    )

    $wc = Get-WebClient -username $username -password $password
    $jsondata = $wc.DownloadString($url) | ConvertFrom-Json 
    $jsondata 
}

function render() {
    [CmdletBinding()]
    param ( [parameter(ValueFromPipeline = $true)] [string] $str)

    #buggy in V4 seems ok in older and newer
    #$ExecutionContext.InvokeCommand.ExpandString($str)

    "@`"`n$str`n`"@" | iex
}

Write-Verbose "Getting details of build [$defname] from server [$collectionUrl/$teamproject]"
$defId = Get-BuildDefinitionId -tfsUri $collectionUrl -teamproject $teamproject -defname $defname -username $username -password $password

if (([System.String]::IsNullOrEmpty($buildnumber)) -or ($buildnumber -eq "<Lastest Build>"))
{
    write-verbose "Getting lastest completed build"    
    $build = Get-LastSuccessfulBuild -tfsUri $collectionUrl -teamproject $teamproject -defid $defid -username $username -password $password
} else 
{
    write-verbose "Getting build number [$buildnumber]"    
    $build = Get-Build -tfsUri $collectionUrl -teamproject $teamproject -defid $defid -buildnumber $buildnumber -username $username -password $password
}

$workitems = Get-BuildWorkItems -tfsUri $collectionUrl -teamproject $teamproject -buildid $build.id -username $username -password $password
$changesets = Get-BuildChangeSets -tfsUri $collectionUrl -teamproject $teamproject -buildid $build.id -username $username -password $password

$template = Get-Content $templatefile
Add-Type -TypeDefinition @"
   public enum Mode
   {
      BODY,
      WI,
      CS
   }
"@
$mode = [Mode]::BODY
#process each line
ForEach ($line in $template)
{
    #Write-Verbose "Processing line [$line]"
    # work out if we need to loop on a blog
    if ($mode -eq [Mode]::BODY)
    {
        if ($line.Trim() -eq "@@WILOOP@@") {$mode = [Mode]::WI; continue}
        if ($line.Trim() -eq "@@CSLOOP@@") {$mode = [Mode]::CS; continue}
    } else {
        if ($line.Trim() -eq "@@WILOOP@@") {$mode = [Mode]::BODY; continue}
        if ($line.Trim() -eq "@@CSLOOP@@") {$mode = [Mode]::BODY; continue}
    }

    switch ($mode)
    {
      "WI" {
        foreach ($wi in $workItems)
        {
           # Get the work item details
           Write-Verbose "   Get details of workitem $($wi.id)"
           $widetail = Get-WorkItemDetail -url $wi.url -username $username -password $password 
           $out += $line | render
           $out += "`n"
        }
        continue
        }
      "CS" {
        foreach ($csdetail in $changesets)
        {
           # we can get enough detail from the list of changes
           Write-Verbose "   Get details of changeset/commit $($csdetail.id)"
           $out += $line | render
           $out += "`n"
        }
        continue
        }
     "BODY" {
           # nothing to expand just process the line
           $out += $line | render
           $out += "`n"
        }
    }
}
write-Verbose "Writing output file $reportname for build [$defname] [$($build.buildNumber)]."
Set-Content $outputfile $out



