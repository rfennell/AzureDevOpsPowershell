<# Usage 
Update-TfsCommentWithMigratedId -SourceCollectionUri "http://localhost:8080/tfs/defaultcollection" -TargetCollectionUri "http://localhost:8080/tfs/defaultcollection" -SourceTeamProject "Old team project"

#>

  function Update-TfsCommentWithMigratedId
        {

        <#
        .SYNOPSIS
        This function is used as part of the migration for TFVC to Git to help retain checkin associations to work items

        .DESCRIPTION
        This function takes two team project references and looks up changset association in the source team project, it then looks for 
        the revised work itme IT in the new team project and updates the source changeset

        .PARAMETER SourceCollectionUri
        Source TFS Collection URI

        .PARAMETER TargetCollectionUri
        Target TFS Collection URI

        .PARAMETER SourceTeamProject
        Source Team Project Name

        .EXAMPLE

        Update-TfsCommentWithMigratedId -SourceCollectionUri "http://server1:8080/tfs/defaultcollection" -TargetCollectionUri "http://server2:8080/tfs/defaultcollection" -SourceTeamProject "Scrumproject"

        #>

            Param
            (
            [Parameter(Mandatory=$true)]
            [uri] $SourceCollectionUri, 

            [Parameter(Mandatory=$true)]
            [uri] $TargetCollectionUri,

            [Parameter(Mandatory=$true)]
            [string] $SourceTeamProject

            )

            # get the source TPC
            $sourceTeamProjectCollection = New-Object Microsoft.TeamFoundation.Client.TfsTeamProjectCollection($sourceCollectionUri)
            # get the TFVC repository
            $vcService = $sourceTeamProjectCollection.GetService([Microsoft.TeamFoundation.VersionControl.Client.VersionControlServer])
            # get the target TPC
            $targetTeamProjectCollection = New-Object Microsoft.TeamFoundation.Client.TfsTeamProjectCollection($targetCollectionUri)
            #Get the work item store
            $wiService = $targetTeamProjectCollection.GetService([Microsoft.TeamFoundation.WorkItemTracking.Client.WorkItemStore])
    
            # Find all the changesets for the selected team project on the source server
            foreach ($cs in $vcService.QueryHistory(�$/$SourceTeamProject�, [Microsoft.TeamFoundation.VersionControl.Client.RecursionType]::Full, [Int32]::MaxValue))
            {
                if ($cs.WorkItems.Count -gt 0)
                {
                    foreach ($wi in $cs.WorkItems)
                    {
                        "Changeset {0} linked to workitem {1}" -f $cs.ChangesetId, $wi.Id
                        # find new id for each changeset on the target server
                        foreach ($newwi in $wiService.Query("select id  FROM WorkItems WHERE [TfsMigrationTool.ReflectedWorkItemId] = '" + $wi.id + "'"))
                        {
                            # if ID found update the source server if the tag has not already been added
                            # we have to esc the [ as gets treated as a regular expression
                            # we need the white space around between the [] else the TFS agent does not find the tags 
                            if ($cs.Comment -match "\[ Migrated ID #{0} \]" -f $newwi.Id)
                            {
                                Write-Output ("New Id {0} already associated with changeset {1}" -f $newwi.Id , $cs.ChangesetId)
                            } else {
                                Write-Output ("New Id {0} being associated with changeset {1}" -f $newwi.Id, $cs.ChangesetId )
                                $cs.Comment += "[ Migrated ID #{0} ]" -f $newwi.Id
                            }
                        }
                    }
                    $cs.Update()
                }
            }
        }
