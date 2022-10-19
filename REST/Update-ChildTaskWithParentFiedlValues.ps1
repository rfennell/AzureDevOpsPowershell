##-----------------------------------------------------------------------
## <copyright file="Update-ChildTaskWithParentFiedlValues.ps1">(c) Richard Fennell. </copyright>
##-----------------------------------------------------------------------
# Update field in a child task to match a parent wi field's value

param
(
    [parameter(Mandatory=$true,HelpMessage="URL of the Team Project Collection e.g. 'http://myserver:8080/tfs/defaultcollection'")]
    $collectionUrl,

    [parameter(Mandatory=$true,HelpMessage="Team Project name e.g. 'My Team project'")]
    $teamproject ,

    [parameter(Mandatory=$true,HelpMessage="Backlog iteration e.g. 'My Team project\Backlog'")]
    $iterationPath ,

    [parameter(Mandatory=$false,HelpMessage="Only looks of parent requirement WI with these states, provided as array")]
    $states = @('New', 'Approved'),

    [parameter(Mandatory=$false,HelpMessage="Duplicates the following fields from the requirement WI to the child tasks, provided as array")]
    $fields = @('Custom.LineItem'),

    [parameter(Mandatory=$false,HelpMessage="Username for use with Password (should be blank if using Personal Access Toekn or default credentials)")]
    $username,

    [parameter(Mandatory=$false,HelpMessage="Password or Personal Access Token (if blank default credentials are used)")]
    $password,

    [parameter(Mandatory=$false,HelpMessage="If true then no confirmation messages will be provided, default to false")]
    $force = $false

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
       $wc.Headers.Add(“Authorization”,"Basic $base64");
    }

    $wc
}

function Update-TaskWorkItemFields
{
    param
    (
        $tfsUri ,
        $id,
        $fields,
        $username,
        $password

    )

    # we need to get the current values
    $wi = Get-WorkItemDetails -tfsUri $tfsUri -id $id -password $password -username $username
  
    $wc = Get-WebClient -username $username -password $password -ContentType "application/json-patch+json"
    $uri = "$($tfsUri)/_apis/wit/workitems/$id`?api-version=1.0"
    $data = @(@{op = "test"; path = "/rev"; value =  $wi.rev } ; )

    foreach ($field in $fields) {
     write-host "    Updating $($field.name) to '$($field.value)' " -ForegroundColor Green
      $data +=  @{op = "add"; path = "/fields/$($field.Name)"; value =  $field.value } ;   `
    }
        
    $jsondata = $wc.UploadString($uri,"PATCH", $($data | ConvertTo-Json)) | ConvertFrom-Json
    # $jsondata
    
}

function Get-WorkItemDetails
{
    param
    (
        $tfsUri ,
        $id,
        $username,
        $password

    )


    #write-host "Getting details for WI '$id' via '$tfsUri' " -ForegroundColor Green

    $wc = Get-WebClient -username $username -password $password

    $uri = "$($tfsUri)/_apis/wit/workitems/$id"

    $jsondata = $wc.DownloadString($uri) | ConvertFrom-Json
    $jsondata
}


function Get-WorkItemsParentChildPairs
{
    param
    (
        $tfsUri ,
        $IterationPath,
        $states,
        $username,
        $password

    )


    $wc = Get-WebClient -username $username -password $password

    write-host "Getting Backlog Item Parent/Child Pairs`n   under '$iterationpath'`n   from '$tfsUri'`n   in the state(s) of '$($states -join ', ')'" -ForegroundColor Green

    $uri = "$($tfsUri)/_apis/wit/wiql?api-version=1.0"
    $wiq = "SELECT [System.Id], [System.Links.LinkType], [System.WorkItemType], [System.Title], [System.AssignedTo], [System.State], [System.Tags] 
    FROM WorkItemLinks 
    WHERE ( 
        [Source].[System.State] IN (""$($states -join '", "')"")  AND
        [Source].[System.IterationPath] UNDER '$iterationpath' AND 
        ([Source].[System.WorkItemType] IN GROUP 'Microsoft.RequirementCategory' or [Source].[System.WorkItemType] IN GROUP 'Microsoft.BugCategory')) And 
        ([System.Links.LinkType] <> '') And 
        ([Target].[System.WorkItemType] = 'Task') 
    ORDER BY [System.Id] mode(MayContain)"

    $data = @{query = $wiq } | ConvertTo-Json

    $jsondata = $wc.UploadString($uri,"POST", $data) | ConvertFrom-Json

    # work out which root items have no child tasks
    # might be a better way to do this
    $pairs = @()
    
    # find all the items and group them
    foreach ($wi in $jsondata.workItemRelations)
    {
        if ($wi.rel -ne $null)
        {
            $pairs += [pscustomobject]@{Parent=$wi.source.id; Child =$wi.target.id}
        }
    }

    $pairs
}

# Get the work items
$workItemsPairs = Get-WorkItemsParentChildPairs -tfsUri $collectionUrl -IterationPath $iterationPath -states $states -username $username -password $password
if (@($workItemsPairs).Count -gt 0)
{
    write-host "Updating the child task fields `"$($fields -join ',')`" to make sure they have the same value as their parent WI in '$iterationPath', updating  "
    foreach ($pair in $workItemsPairs)
    {
        write-host "  Task $($pair.child)"
    }
    if (($force -eq $true) -or ((Read-Host "Are you Sure You Want To Proceed (Y/N)") -eq 'y')) {
        # proceed
        foreach ($pair in $workItemsPairs)
        {
            # find the parent
            $parent = Get-WorkItemDetails -tfsUri $collectionUrl -id $pair.parent -password $password -username $username
    
            $updatedfields = @()

            foreach ($field in $fields) {
               write-host "Updating task $($pair.child) with the value '$($parent.fields."$field")'  "
               $updatedfields += [pscustomobject]@{Name='Custom.LineItem'; Value =$($parent.fields."$field")}
            }
             
             Update-TaskWorkItemFields -tfsUri $collectionUrl/$teamproject -id $pair.child -fields $updatedfields -username $username -password $password
           
        }
    }
} else
{
    write-host "No work items in the iteration with existing tasks "
}
