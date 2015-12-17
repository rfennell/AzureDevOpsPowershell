param
(
    [parameter(Mandatory=$true,HelpMessage="URL of the source Team Project Collection e.g. 'http://myserver:8080/tfs/defaultcollection'")]
    $sourceCollectionUrl ,

    [parameter(Mandatory=$true,HelpMessage="URL of the target Team Project Collection e.g. 'https://myinstance.visualstudio.com/defaultcollection'")]
    $targetCollectionUrl ,

    [parameter(Mandatory=$true,HelpMessage="Source Team Project name e.g. 'My old Team project'")]
    $sourceteamproject ,

    [parameter(Mandatory=$true,HelpMessage="Target Team Project name e.g. 'My new Team project'")]
    $targetteamproject ,

    # There are three possible means of authentication or both the source and target
    # 1. If no UID and PWD provided then default windows credentials are used (usually OK for on premises)
    # 2. User name and password if basic auth is in use
    # 3. Blank UID and a Personal Access Token see http://roadtoalm.com/2015/07/22/using-personal-access-tokens-to-access-visual-studio-online/

    [parameter(Mandatory=$false,HelpMessage="Source server Username if default credentials are not in use")]
    $sourceusername,

    [parameter(Mandatory=$false,HelpMessage="Source server Password if default credentials are not in use")]
    $sourcepassword , 

    [parameter(Mandatory=$false,HelpMessage="Target server Username if default credentials are not in use")]
    $targetusername,
    
    [parameter(Mandatory=$false,HelpMessage="Target server Password if default credentials are not in use")]
    $targetpassword 

)

function Get-WebClient
{
 param
    (
        [string]$username, 
        [string]$password
    )

    $wc = New-Object System.Net.WebClient
    $wc.Headers["Content-Type"] = "application/json"
    
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


function Get-GitRepos
{
 param
    (
        $tfsUri ,
        $teamproject,
        $username, 
        $password
    )
    
    write-host "Getting Git repo details for $tfsUri " -ForegroundColor Green

    $wc = Get-WebClient -username $username -password $password
      
    $uri = "$($tfsUri)/$($teamproject)/_apis/git/repositories?api-version=1.0"

    $jsondata = $wc.DownloadString($uri) | ConvertFrom-Json 
    
    $jsondata.value | select-object -property @{Name="Name"; Expression = {$_.name}},@{Name="RepoID"; Expression = {$_.id}},@{Name="ProjectID"; Expression = {$_.project.id}}
}



function Update-WorkItemWithCommits
{
    param
    (
        $tfsUri ,
        $id,
        $username, 
        $password,
        $sourceLookup,
        $targetLookup
    )

    write-verbose "Getting details for WI $id on $tfsUri " 

    $wc = Get-WebClient -username $username -password $password
  
    $uri = "$($tfsUri)/_apis/wit/workitems/$($id)?api-version=1.0&`$expand=relations"
    
    $wi = $wc.DownloadString($uri) | ConvertFrom-Json 

    $commitsToUpdate = @()

    # as we are deleting the relations we have replaced we need to know their index hence the for loop
    for ($i =0 ; $i -lt $wi.relations.Length; $i++)
    {
       # get the commit links 
       if ($wi.relations[$i].rel -eq 'ArtifactLink')
       {
            # extract the guids from the URL and put them in an object 
            $sections =$wi.relations[$i].url.Substring(20) -split '%2F' 
            $commit = [PSCustomObject]@{
                    TeamProjectID = $sections[0]
                    RepoID = $sections[1]
                    CommitID = $sections[2]
                    Index = $i
                    }
            # we have a link to potentially update
            # check the lookup tables to see if the repo has been cloned i.e. in both tables
            write-host "Commits links found for WI $id)"
            $sourceRepo = $sourceLookup | Where-Object { $_.RepoID -eq $commit.RepoID }
            if ($sourceRepo)
            {
                write-host "Found '$($sourceRepo.Name)', need to find new IDs to update"
                $targetRepo = $targetLookup | Where-Object { $_.Name -eq $sourceRepo.Name }
                # add the replacement object to the list to update
                $commitsToUpdate += [PSCustomObject]@{
                       Index = $commit.Index
                       RepoID = $targetRepo.RepoID 
                       ProjectId = $targetRepo.Projectid
                       CommitID = $commit.CommitID
                       }
            } else
            {
                write-host "Could not find source Git repo in source list, this commit $($commit.CommitID) does not need updating"
            }
                  
       }
    }
    if ($commitsToUpdate)
    {
       Add-WorkItemsCommitLink -tfsUri $tfsUri -username $username -password $password -CommitsToUpdate $commitsToUpdate -id $wi.id -rev $wi.rev
    }
}


function Get-WorkItemsInProject
{
    param
    (
        $tfsUri ,
        $teamproject,
        $username, 
        $password
    )

    $wc = Get-WebClient -username $username -password $password
    
    write-host "Getting all Work Items under '$teamproject' via '$tfsUri' " -ForegroundColor Green

    $uri = "$($tfsUri)/_apis/wit/wiql?api-version=1.0"
    $wiq = "SELECT [System.Id], [System.WorkItemType], [System.Title] FROM WorkItems WHERE [System.AreaPath] UNDER '$teamproject' ORDER BY [System.Id]"
    $data = @{query = $wiq } | ConvertTo-Json

    $jsondata = $wc.UploadString($uri,"POST", $data) | ConvertFrom-Json 
    
    $jsondata.workitems
}

function Add-WorkItemsCommitLink
{
    param
    (
        $tfsUri ,
        $id,
        $rev,
        $CommitsToUpdate,
        $username, 
        $password
    )

    $wc = Get-WebClient -username $username -password $password
    
    write-host "Updating commit $commitId for Work Item '$id' via '$tfsUri' " -ForegroundColor Green

    $uri = "$($tfsUri)/_apis/wit/workitems/$($id)?api-version=1.0"

    # we seem to have to add a new link and remove the old
    # you only seem to be able to edit the attributes not the basic link

    # we have to build the batch of operations in an order what does not cause the array indexes to change
 
     $data = @()

     # first the test of the revision to make sure the item has not been edited since we checked it
     # if this is left off the json data is considered invalid
     $data +=  @{ 
         op = "test";
         path = "/rev";
         value = $rev
      }

      # add the add new link operations
      foreach ($item in $CommitsToUpdate)
      {
        $data +=  @{ 
         op = "add"; 
         path = "/relations/-"; 
         value = @{ 
             rel = "ArtifactLink"; 
             url = "vstfs:///Git/Commit/$($item.projectID)%2F$($item.repoid)%2F$($item.commitID)" ;
             attributes = @{ 
                name = "Fixed in Commit" 
             }
          }
        }
      }
      
      # add the remove link operations, these have to be done in reverse order
      for ($i = $CommitsToUpdate.Length -1; $i -gt -1; $i-- ) 
      {
        $data +=
        @{
            op = "remove";
            path = "/relations/$($CommitsToUpdate[$i].index)"
        }
       }
       
       $jsondatain = $data | ConvertTo-Json -Depth 5 # 5 needed to handle nested hashtables, default is 2

       try
       {
          $jsondata = $wc.UploadString($uri,"PATCH", $jsondatain) | ConvertFrom-Json 

       } catch
       {
           write-warning "Cannot add the link, probably a duplicate of an existing entry"
       }
    
}



write-host "Getting source server Git repos"
$sourceLookup = Get-GitRepos -tfsUri $sourceCollectionUrl -teamproject $sourceteamproject -username $sourceusername -password $sourcepassword
$sourceLookup | Format-Table
write-host "Getting target server Git repos"
$targetLookup = Get-GitRepos -tfsUri $targetCollectionUrl -teamproject $targetteamproject -username $targetusername -password $targetpassword
$targetLookup | Format-Table

write-host "Get the work items that have been migrated"
$workItems = Get-WorkItemsInProject -tfsUri $targetCollectionUrl -teamproject $targetteamproject -username $targetusername -password $targetpassword

write-host "Process the work items that have been migrated"
$workItems | ForEach-Object {   `
    Update-WorkItemWithCommits -tfsUri $targetCollectionUrl -id $_.id -username $targetusername -password $targetpassword -sourceLookup $sourceLookup -targetLookup $targetLookup
       
}


