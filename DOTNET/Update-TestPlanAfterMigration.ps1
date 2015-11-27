<# Usage

Update-TestPlanAfterMigration -SourceCollectionUri "http://typhoontfs:8080/tfs/defaultcollection" -TargetCollectionUri "http://typhoontfs:8080/tfs/defaultcollection" -SourceTeamProjectName "Scrum TFVC Source" -TargetTeamProjectName "NewProject”


#>


      function Update-TestPlanAfterMigration
        {
        <#
        .SYNOPSIS
        This function migrates a test plan and all its child test suites to a different team project

        .DESCRIPTION
        This function migrates a test plan and all its child test suites to a different team project, reassign work item IDs as required

        .PARAMETER SourceCollectionUri
        Source TFS Collection URI

        .PARAMETER SourceTeamProject
        Source Team Project Name

        .PARAMETER SourceCollectionUri
        Target TFS Collection URI

        .PARAMETER SourceTeamProject
        Targe Team Project Name


        .EXAMPLE

        Update-TestPlanAfterMigration -SourceCollectionUri "http://server1:8080/tfs/defaultcollection" -TargetCollectionUri "http://serrver2:8080/tfs/defaultcollection"  -SourceTeamProjectName "Old project" -TargetTeamProjectName "New project"

        #>
            param(
            [Parameter(Mandatory=$true)]
            [uri] $SourceCollectionUri,

            [Parameter(Mandatory=$true)]
            [string] $SourceTeamProjectName,

            [Parameter(Mandatory=$true)]
            [uri] $TargetCollectionUri,

            [Parameter(Mandatory=$true)]
            [string] $TargetTeamProjectName

            )

            # Get TFS connections
            $sourcetfs = [Microsoft.TeamFoundation.Client.TfsTeamProjectCollectionFactory]::GetTeamProjectCollection($SourceCollectionUri)
            try
            {
                $Sourcetfs.EnsureAuthenticated()
            }
            catch
            {
                Write-Error "Error occurred trying to connect to project collection: $_ "
                exit 1
            }
            $targettfs = [Microsoft.TeamFoundation.Client.TfsTeamProjectCollectionFactory]::GetTeamProjectCollection($TargetCollectionUri)
            try
            {
                $Targettfs.EnsureAuthenticated()
            }
            catch
            {
                Write-Error "Error occurred trying to connect to project collection: $_ "
                exit 1
            }

            # get the actual services
            $sourcetestService = $sourcetfs.GetService("Microsoft.TeamFoundation.TestManagement.Client.ITestManagementService")
            $targettestService = $targettfs.GetService("Microsoft.TeamFoundation.TestManagement.Client.ITestManagementService")
            $sourceteamproject = $sourcetestService.GetTeamProject($sourceteamprojectname)
            $targetteamproject = $targettestService.GetTeamProject($targetteamprojectname)
            # Get the work item store
            $wiService = $targettfs.GetService([Microsoft.TeamFoundation.WorkItemTracking.Client.WorkItemStore])
   
 
            # find all the plans in the source
             foreach ($plan in $sourceteamproject.TestPlans.Query("Select * From TestPlan"))
             {
                 if ($plan.RootSuite -ne $null -and $plan.RootSuite.Entries.Count -gt 0)
                 {
                    # copy the plan to the new tp
                    Write-Host("Migrating Test Plan - {0}" -f $plan.Name) 
                    $newplan = $targetteamproject.TestPlans.Create();
                    $newplan.Name = $plan.Name
                    $newplan.AreaPath = $plan.AreaPath
                    $newplan.Description = $plan.Description
                    $newplan.EndDate = $plan.EndDate
                    $newplan.StartDate = $plan.StartDate
                    $newplan.State = $plan.State
                    $newplan.Save();
                    # we use a function as it can be recursive
                    MoveTestSuite -sourceSuite $plan.RootSuite -targetSuite $newplan.RootSuite -targetProject $targetteamproject -targetPlan $newplan -wiService $wiService
                    # and have to save the test plan again to persit the suites
                    $newplan.Save();
 
                 }
             }



        }

        # - is missing in name so this method is not exposed when module loaded
        function MoveTestSuite
        {
        <#
        .SYNOPSIS
        This function migrates a test suite and all its child test suites to a different team project

        .DESCRIPTION
        This function migrates a test suite and all its child test suites to a different team project, it is a helper function Move-TestPlan and will probably not be called directly from the command line

        .PARAMETER SourceSuite
        Source TFS test suite

        .PARAMETER TargetSuite
        Target TFS test suite

        .PARAMETER TargetPlan
        The new test plan the tests suite are being created in

        .PARAMETER targetProject
        The new team project test suite are being created in

        .PARAMETER WiService
        Work item service instance used for lookup


        .EXAMPLE

        Move-TestSuite -sourceSuite $plan.RootSuite -targetSuite $newplan.RootSuite -targetProject $targetteamproject -targetPlan $newplan -wiService $wiService

        #>
            param 
            (
                [Parameter(Mandatory=$true)]
                $sourceSuite,

                [Parameter(Mandatory=$true)]
                $targetSuite,

                [Parameter(Mandatory=$true)]
                $targetProject,

                [Parameter(Mandatory=$true)]
                $targetplan,
        
                [Parameter(Mandatory=$true)]
                $wiService
            )

            foreach ($suite_entry in $sourceSuite.Entries)
            {
               # get the suite to a local variable to make it easier to pass around
               $suite = $suite_entry.TestSuite
               if ($suite -ne $null)
               {
                   # we have to build a suite of the correct type
                   if ($suite.IsStaticTestSuite -eq $true)
                   {
                        Write-Host("    Migrating static test suite - {0}" -f $suite.Title)      
                        $newsuite = $targetProject.TestSuites.CreateStatic()
                        $newsuite.Title = $suite.Title
                        $newsuite.Description = $suite.Description 
                        $newsuite.State = $suite.State 
                        # need to add the suite to the plan else you cannot add test cases
                        $targetSuite.Entries.Add($newSuite) >$nul # sent to null as we get output
                        foreach ($test in $suite.TestCases)
                        {
                            $migratedTestCaseIds = $targetProject.TestCases.Query("Select * from [WorkItems] where [TfsMigrationTool.ReflectedWorkItemId] = '{0}'" -f $Test.Id)
                            # we assume we only get one match
                            if ($migratedTestCaseIds[0] -ne $null)
                            {
                                Write-Host ("        Test {0} has been migrated to {1} and added to suite {2}" -f $Test.Id , $migratedTestCaseIds[0].Id, $newsuite.Title)
                                $newsuite.Entries.Add($targetProject.TestCases.Find($migratedTestCaseIds[0].Id))  >$nul # sent to null as we get output
                            }
                        }
                   }

           
                   if ($suite.IsDynamicTestSuite -eq $true)
                   {
                       Write-Host("    Migrating query based test suite - {0} (Note - query may need editing)" -f $suite.Title)      
                       $newsuite = $targetProject.TestSuites.CreateDynamic()
                       $newsuite.Title = $suite.Title
                       $newsuite.Description = $suite.Description 
                       $newsuite.State = $suite.State 
                       $newsuite.Query = $suite.Query

                       $targetSuite.Entries.Add($newSuite) >$nul # sent to null as we get output
                       # we don't need to add tests as this is done dynamically
          
                   }

                   if ($suite.IsRequirementTestSuite -eq $true)
                   {
                       $newwis = $wiService.Query("select *  FROM WorkItems WHERE [TfsMigrationTool.ReflectedWorkItemId] = '{0}'" -f $suite.RequirementId)  
                       if ($newwis[0] -ne $null)
                       {
                            Write-Host("    Migrating requirement based test suite - {0} to new requirement ID {1}" -f $suite.Title, $newwis[0].Id )    
               
                            $newsuite = $targetProject.TestSuites.CreateRequirement($newwis[0])
                            $newsuite.Title = $suite.Title -replace $suite.RequirementId, $newwis[0].Id
                            $newsuite.Description = $suite.Description 
                            $newsuite.State = $suite.State 
                            $targetSuite.Entries.Add($newSuite) >$nul # sent to null as we get output
                            # we don't need to add tests as this is done dynamically
                       }
                   }
          
                   # look for child test cases
                   if ($suite.Entries.Count -gt 0)
                   {
                         MoveTestSuite -sourceSuite $suite -targetSuite $newsuite -targetProject $targetteamproject -targetPlan $newplan -wiService $wiService
                   }
                }
            }
         }

