##-----------------------------------------------------------------------
## <copyright file="Add-StandardBacklogTasks.ps1">(c) Richard Fennell. </copyright>
##-----------------------------------------------------------------------
# Create a standard list of task to a backlog item in an iteration

param
(
    [parameter(Mandatory=$true,HelpMessage="URL of the Team Project Collection e.g. 'http://myserver:8080/tfs/defaultcollection'")]
    $collectionUrl,

    [parameter(Mandatory=$true,HelpMessage="Team Project name e.g. 'My Team project'")]
    $teamproject ,

    [parameter(Mandatory=$true,HelpMessage="Backlog iteration e.g. 'My Team project\Backlog'")]
    $iterationPath ,

    [parameter(Mandatory=$false,HelpMessage="Default work remaining for a task, could uses a strange number so it is easy to notice it is defaulted")]
	$defaultsize = 0 ,

    [parameter(Mandatory=$false,HelpMessage="Allows the replacement of the standard tasks that are generated, provided as hashtable. If you don't wish to set an activity type leave the value empty. If a specific set of tasks for WIT is not listed then the <Default> block will used'")]
    $taskTitles = @{
    "Bug" =  (@{Title = "Investigation Task for Bug {0}"; Activity = "Development"},
              @{Title = "Write test Task for Bug {0}"; Activity = "Testing"},
              @{Title = "Run tests Task for Bug {0}"; Activity = "Testing"});
    "<DEFAULT>" =  @(@{Title = "Design Task for {1} {0}"; Activity = "Design"},
                                @{Title = "Development Task for {1} {0}"; Activity = "Development"},
                                @{Title = "Write test Task for {1} {0}"; Activity = "Testing"},
                                @{Title = "Run tests Task for {1} {0}"; Activity = "Testing"},
                                @{Title = "Documentation Task {1} PBI {0}"; Activity = "Documentation"},
                                @{Title = "Deployment Task for {1} {0}"; Activity = "Deployment"});
    },

    [parameter(Mandatory=$false,HelpMessage="Allows the replacement of the standard tasks states that are considered, provided as array")]
    $states = @('New', 'Approved'),

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

function Add-TasksToWorkItems
{
    param
    (
        $tfsUri ,
        $IterationPath,
        $AreaPath,
        $id,
        $tasks,
        $size,
        $wit,
        $username,
        $password

    )


    write-host "Adding a tasks to $id via $tfsUri " -ForegroundColor Green

    foreach ($task in $tasks)
    {
        $wc = Get-WebClient -username $username -password $password -ContentType "application/json-patch+json"
        $title = [string]::Format($task.Title, $id, $wit)
        $activity = $task.Activity
        $uri = "$($tfsUri)/_apis/wit/workitems/`$Task?api-version=1.0"
        $data = @(@{op = "add"; path = "/fields/System.Title"; value = "$title" } ;   `
                  @{op = "add"; path = "/fields/System.Description"; value = "$title" };  `
                  @{op = "add"; path = "/fields/Microsoft.VSTS.Scheduling.RemainingWork"; value = "$size" }  ;  `
                  @{op = "add"; path = "/fields/System.IterationPath"; value = "$IterationPath" }  ;  `
                  @{op = "add"; path = "/fields/System.AreaPath"; value = "$AreaPath" }  ;  `
                  @{op = "add"; path = "/fields/Microsoft.VSTS.Common.Activity"; value = "$Activity" }  ;  `
                  @{op = "add"; path = "/relations/-"; value = @{ "rel" = "System.LinkTypes.Hierarchy-Reverse" ; "url" = "$($tfsUri)/_apis/wit/workItems/$id"} }   ) | ConvertTo-Json

        write-host "    Added '$title' " -ForegroundColor Green
        $jsondata = $wc.UploadString($uri,"POST", $data) | ConvertFrom-Json
        #$jsondata
    }
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


function Get-WorkItemsInIterationWithNoTask
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

    write-host "Getting Backlog Items`n   under '$iterationpath'`n   from '$tfsUri'`n   in the state(s) of '$($states -join ', ')' that have no child tasks`n" -ForegroundColor Green

    $uri = "$($tfsUri)/_apis/wit/wiql?api-version=1.0"
    # $wiq = "SELECT [System.Id], [System.Links.LinkType], [System.WorkItemType], [System.Title], [System.AssignedTo], [System.State], [System.Tags] FROM WorkItemLinks WHERE ( [Source].[System.State] IN (""$($states -join '", "')"")  AND  [Source].[System.IterationPath] UNDER '$iterationpath' AND [Source].[System.WorkItemType] IN GROUP 'Microsoft.RequirementCategory' And ([System.Links.LinkType] <> '') And ([Target].[System.WorkItemType] = 'Task') ORDER BY [System.Id] mode(MayContain)"
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
    $rootItems = @()
    $childItems = @()
    $parentItems = @()

    # find all the items and group them
    foreach ($wi in $jsondata.workItemRelations)
    {
        if ($wi.rel -eq $null)
        {
            $rootItems += $wi.target.id
        } else
        {
            $childItems += $wi.target.id
            $parentItems += $wi.source.id
        }
    }

    # Get everything with no children
    $ids = @()
    if ($rootItems -ne $null)
    {
        if ($parentItems.count -eq 0)
        {
            $ids = $rootItems
        } else
        {
            $ids = (Compare-Object -ReferenceObject ($rootItems |  Sort-Object) -DifferenceObject ($parentItems | select -uniq |  Sort-Object)).InputObject
        }
    }

    # Get the details
   $retItems = @()
   foreach ($id in $ids)
    {
        $item = Get-WorkItemDetails -tfsUri $tfsUri -id $id -username $username -password $password
        $retItems += $item | Select-Object id,
                                           @{ Name = 'WIT' ;Expression ={$_.fields.'System.WorkItemType'}} ,
                                           @{ Name = 'Title' ;Expression ={$_.fields.'System.Title'}},
                                           @{ Name = 'Fields' ; Expression ={$_.fields}}
    }

    $retItems
}

# Get the work items
$workItems = Get-WorkItemsInIterationWithNoTask -tfsUri $collectionUrl -IterationPath $iterationPath -states $states -username $username -password $password
if (@($workItems).Count -gt 0)
{
    write-host "About to add standard Task work items to the following work items in the iteration '$iterationPath' "
    $workItems|  Format-Table -Property @{ Name="ID"; Expression={$_.id}; Alignment="left"; } , WIT, Title, @{ Name="AreaPath"; Expression={$_.Fields.'System.AreaPath'}; Alignment="left"; }
    if (($force -eq $true) -or ((Read-Host "Are you Sure You Want To Proceed (Y/N)") -eq 'y')) {
        # proceed
        foreach ($wi in $workItems)
        {
            if ($taskTitles.ContainsKey($wi.WIT) -eq $false)
            {
                $taskItems =$taskTitles.$("<DEFAULT>")
            } else
            {
                $taskItems =$taskTitles.$($wi.WIT)
            }
            Add-TasksToWorkItems -tfsUri $collectionUrl/$teamproject -id $wi.id -tasks $taskItems -IterationPath $iterationPath -AreaPath $wi.Fields.'System.AreaPath' -size $defaultsize -wit $wi.WIT -username $username -password $password
        }
    }
} else
{
    write-host "No work items in the iteration without existing tasks "
}
