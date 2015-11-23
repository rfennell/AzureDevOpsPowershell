param
(
    # top three should really be mandatory, but user experience better with the read-host
    [parameter(Mandatory=$false,HelpMessage="URL of the Team Project Collection e.g. 'http://myserver:8080/tfs/defaultcollection'")]
    $collectionUrl = $(Read-Host -prompt "URL of the Team Project Collection e.g. 'http://myserver:8080/tfs/defaultcollection'"),
    [parameter(Mandatory=$false,HelpMessage="Team Project name e.g. 'My Team project'")]
    $teamproject  = $(Read-Host -prompt "Team Project name e.g. 'My Team project'"),
    [parameter(Mandatory=$false,HelpMessage="Backlog iteration e.g. 'My Team project/Backlog'")]
    $iterationPath = $(Read-Host -prompt "Backlog iteration e.g. 'My Team project/Backlog'"),

    [parameter(Mandatory=$false,HelpMessage="Default work remaining for a task, could uses a strange number so it is easy to notice it is defaulted")]
	$defaultsize = 0 , 

    [parameter(Mandatory=$false,HelpMessage="Allows the replacement of the standard tasks that are generated, provided as hashtable")]
    $taskTitles = @{ 
    "Bug" = @("Investigation Task for Bug {0}", "Write test Task for Bug {0}", "Run tests Task for Bug {0}");
    "Product Backlog Item" =  @("Design Task for PBI {0}", "Development Task for PBI {0}", "Write test Task for PBI {0}", "Run tests Task for PBI {0}", "Documentation Task for PBI {0}", , "Deployment Task for PBI {0}")
    }, 

    [parameter(Mandatory=$false,HelpMessage="Username of default credentials are not in use")]
    $username,
    [parameter(Mandatory=$false,HelpMessage="Password of default credentials are not in use")]
    $password  

)


function Add-TasksToWorkItems
{
    param
    (
        $tfsUri ,
        $IterationPath,
        $id,
        $tasks,
        $size,
        $username, 
        $password

    )


    write-host "Adding a tasks to $id via $tfsUri " -ForegroundColor Green

    foreach ($task in $tasks)
    {
  
        $wc = New-Object System.Net.WebClient
        $wc.Headers["Content-Type"] = "application/json-patch+json"
        if ($username -eq $null)
        {
            $wc.UseDefaultCredentials = $true
        } else 
        {
            $wc.Credentials = new-object System.Net.NetworkCredential($username, $password)
        }
   

        $uri = "$($tfsUri)/_apis/wit/workitems/`$Task?api-version=1.0"
        $data = @(@{op = "add"; path = "/fields/System.Title"; value = "$task" } ; `
                  @{op = "add"; path = "/fields/System.Description"; value = "$task" };  `
                  @{op = "add"; path = "/fields/Microsoft.VSTS.Scheduling.RemainingWork"; value = "$size" }  ;  `
                  @{op = "add"; path = "/fields/System.IterationPath"; value = "$IterationPath" }  ;  `
                  @{op = "add"; path = "/relations/-"; value = @{ "rel" = "System.LinkTypes.Hierarchy-Reverse" ; "url" = "$($tfsUri)/_apis/wit/workItems/$id"} }   ) | ConvertTo-Json

        write-host "    Added '$task' " -ForegroundColor Green

        $jsondata = $wc.UploadString($uri,"PATCH", $data) | ConvertFrom-Json 
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


    write-host "Getting details for WI $id via $tfsUri " -ForegroundColor Green

    $wc = New-Object System.Net.WebClient
    $wc.Headers["Content-Type"] = "application/json"
    if ($username -eq $null)
    {
        $wc.UseDefaultCredentials = $true
    } else 
    {
        $wc.Credentials = new-object System.Net.NetworkCredential($username, $password)
    }
   

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

  
    $wc = New-Object System.Net.WebClient
    $wc.Headers["Content-Type"] = "application/json"
    if ($username -eq $null)
    {
        $wc.UseDefaultCredentials = $true
    } else 
    {
        $wc.Credentials = new-object System.Net.NetworkCredential($username, $password)
    }
    
    write-host "Getting Backlog Items under $iterationpath via $tfsUri that have no child tasks" -ForegroundColor Green

    $uri = "$($tfsUri)/_apis/wit/wiql?api-version=1.0"
    $wiq = "SELECT [System.Id], [System.Links.LinkType], [System.WorkItemType], [System.Title], [System.AssignedTo], [System.State], [System.Tags] FROM WorkItemLinks WHERE (  [Source].[System.State] IN ($states)  AND  [Source].[System.IterationPath] UNDER '$iterationpath') And ([System.Links.LinkType] <> '') And ([Target].[System.WorkItemType] = 'Task') ORDER BY [System.Id] mode(MayContain)"
    $data = @{query = $wiq } | ConvertTo-Json

    $jsondata = $wc.UploadString($uri,"POST", $data) | ConvertFrom-Json 
    
    # work out which root items have no child tasks
    # might be a better way to do this
    $rootItems = @()
    $childItems = @()
    $parentItems = @()
    
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

    $ids = (Compare-Object -ReferenceObject ($rootItems |  Sort-Object) -DifferenceObject ($parentItems | select -uniq |  Sort-Object)).InputObject
    $retItems = @()

    foreach ($id in $ids)
    {
        $item = Get-WorkItemDetails -tfsUri $tfsUri -id $id -username $username -password $password 
        $retItems += $item | Select-Object id, @{ Name = 'WIT' ;Expression ={$_.fields.'System.WorkItemType'}} , @{ Name = 'Title' ;Expression ={$_.fields.'System.Title'}}

    }

    $retItems
}


$states = "'New', 'Approved'"  # comma separated
$workItems = Get-WorkItemsInIterationWithNoTask -tfsUri $collectionUrl -IterationPath $iterationPath -states $states -username $userUid -password $userPwd

if (@($workItems).Count -gt 0)
{
    write-host "About to add standard Task work items to the following '$wit' in the iteration '$iterationPath' "
    $workItems|  Format-Table -Property @{ Name="ID"; Expression={$_.id}; Alignment="left"; } , WIT, Title
    if ((Read-Host "Are you Sure You Want To Proceed (Y/N)") -eq 'y') {
        # proceed
        foreach ($wi in $workItems)
        {
            if ($taskTitles.ContainsKey($wi.WIT) -eq $false) 
            {
                Write-Error "Unknown work item type '$($wi.WIT)' found on backlog"
                exit
            } else
            { 
                $taskItems =$taskTitles.$($wi.WIT) |  ForEach-Object { [string]::Format($_, $wi.ID) }
            }  
            Add-TasksToWorkItems -tfsUri $collectionUrl/$teamproject -id $wi.id -tasks $taskItems -IterationPath $iterationPath -size $defaultsize -username $userUid -password $userPwd
        }
    }
} else 
{
    write-host "No work items in the iteration '$iterationPath' without existing tasks "
}