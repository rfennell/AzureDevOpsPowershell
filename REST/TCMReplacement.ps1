param
(
    [Parameter(Mandatory)]
    $collectionuri ,
    [Parameter(Mandatory)]
    $teamproject ,
    [Parameter(Mandatory)]
    $testrunname  ,
    [Parameter(Mandatory)]
    $testplanname ,
    [Parameter(Mandatory)]
    $testsuitename,
    [Parameter(Mandatory)]
    $testcontroller ,
    [Parameter(Mandatory)]
    $buildid ,
    [Parameter(Mandatory)]
    $environmentName ,
    [Parameter(Mandatory)]
    $testsettingsname,
    [Parameter(Mandatory)]
    $configurationname ,
    $pollInterval = 10,
    $releaseUri ,
    $releaseenvironmenturi 
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

function Get-TestPlanId
{
    param
    (
        $BaseUri,
        $Name

    )
    $wc = Get-WebClient
    $uri = "$baseuri/_apis/test/plans"
    $jsondata = $wc.DownloadString($uri) | ConvertFrom-Json 
    $testplan = $jsondata.value | where name -eq $name | select -ExpandProperty id
    $testplan

}

function Get-TestSuiteId
{
    param
    (
          $BaseUri,
          $testplanid,
        $Name


    )
    $wc = Get-WebClient
    $uri = "$baseuri/_apis/test/plans/$testplanid/suites"
    $jsondata = $wc.DownloadString($uri) | ConvertFrom-Json 
    $id = $jsondata.value | where name -eq $name | select -ExpandProperty id
    $id
}

function Get-TestPoints
{
    param
    (
          $BaseUri,
          $testplanid,
        $testsuiteid


    )
    $wc = Get-WebClient
    $uri = "$baseuri/_apis/test/plans/$testplanid/suites/$testsuiteid/points?api-version=1.0"
    $jsondata = $wc.DownloadString($uri) | ConvertFrom-Json 
    $testpoints = $jsondata.value | select -ExpandProperty id
    $testpoints
}

function Get-BuildDirectory
{
        param
        (
              $BaseUri,
              $buildid
   

        )
        $wc = Get-WebClient
        $uri = "$baseuri/_apis/build/builds/$buildid/artifacts?api-version=2.0"
        $jsondata = $wc.DownloadString($uri) | ConvertFrom-Json 
        $resource = $jsondata.value | where name -eq "drop" | select -ExpandProperty resource
        $resource.data
}

function Get-EnvironmentId
{
    param
    (
        $collectionUri,
        $projectName,
        $environmentName
    )

    # Load the one we have to find
    $ReferenceDllLocation = "C:\Program Files (x86)\Microsoft Visual Studio 14.0\Common7\IDE\CommonExtensions\Microsoft\TeamFoundation\Team Explorer\"
    Add-Type -Path $ReferenceDllLocation"Microsoft.TeamFoundation.Client.dll" -ErrorAction Stop -Verbose
    Add-Type -Path $ReferenceDllLocation"Microsoft.TeamFoundation.Common.dll" -ErrorAction Stop -Verbose
    Add-Type -Path $ReferenceDllLocation"Microsoft.TeamFoundation.Lab.Client.dll" -ErrorAction Stop -Verbose
    Add-Type -Path $ReferenceDllLocation"Microsoft.TeamFoundation.Lab.Common.dll" -ErrorAction Stop -Verbose

    $tfs = [Microsoft.TeamFoundation.Client.TfsTeamProjectCollectionFactory]::GetTeamProjectCollection($collectionUri)
    try
    {
        $tfs.EnsureAuthenticated()
    }
    catch
    {
        Write-Error "Error occurred trying to connect to project collection: $_ "
        exit 1
    }

    $labService = $tfs.GetService([Microsoft.TeamFoundation.Lab.Client.LabService])
    
    $labEnvironmentQuerySpec = New-Object Microsoft.TeamFoundation.Lab.Client.LabEnvironmentQuerySpec; 
    $labEnvironmentQuerySpec.Project = $projectName; 
    $labEnvironmentQuerySpec.Disposition = [Microsoft.TeamFoundation.Lab.Client.LabEnvironmentDisposition]::Active;
    $labEnvironments = $labService.QueryLabEnvironments($labEnvironmentQuerySpec)

    $labEnvironments | where name -eq $environmentName | select -ExpandProperty LabGuid
}

function Get-TestSettingsId
{
    param
    (
        $collectionUri,
        $projectName,
        $testsettingsname
    )

    # Load the one we have to find
    $ReferenceDllLocation = "C:\Program Files (x86)\Microsoft Visual Studio 14.0\Common7\IDE\CommonExtensions\Microsoft\TeamFoundation\Team Explorer\"
    Add-Type -Path $ReferenceDllLocation"Microsoft.TeamFoundation.Client.dll" -ErrorAction Stop -Verbose
    Add-Type -Path $ReferenceDllLocation"Microsoft.TeamFoundation.Common.dll" -ErrorAction Stop -Verbose
    Add-Type -Path $ReferenceDllLocation"Microsoft.TeamFoundation.TestManagement.Client.dll" -ErrorAction Stop -Verbose
    Add-Type -Path $ReferenceDllLocation"Microsoft.TeamFoundation.TestManagement.Common.dll" -ErrorAction Stop -Verbose
    
    $tfs = [Microsoft.TeamFoundation.Client.TfsTeamProjectCollectionFactory]::GetTeamProjectCollection($collectionUri)
    try
    {
        $tfs.EnsureAuthenticated()
    }
    catch
    {
        Write-Error "Error occurred trying to connect to project collection: $_ "
        exit 1
    }

    
    $testservice = $tfs.GetService([Microsoft.TeamFoundation.TestManagement.Client.ITestManagementService])
    $project = $testservice.GetTeamProject($projectName)
    $project.TestSettings.Query("Select * from TestSettings") | where Name -eq $testsettingsname | select -ExpandProperty id
}

function Get-ConfigurationId
{
    param
    (
        $collectionUri,
        $projectName,
        $configurationname
    )

    # Load the one we have to find
    $ReferenceDllLocation = "C:\Program Files (x86)\Microsoft Visual Studio 14.0\Common7\IDE\CommonExtensions\Microsoft\TeamFoundation\Team Explorer\"
    Add-Type -Path $ReferenceDllLocation"Microsoft.TeamFoundation.Client.dll" -ErrorAction Stop -Verbose
    Add-Type -Path $ReferenceDllLocation"Microsoft.TeamFoundation.Common.dll" -ErrorAction Stop -Verbose
    Add-Type -Path $ReferenceDllLocation"Microsoft.TeamFoundation.TestManagement.Client.dll" -ErrorAction Stop -Verbose
    Add-Type -Path $ReferenceDllLocation"Microsoft.TeamFoundation.TestManagement.Common.dll" -ErrorAction Stop -Verbose
    
    $tfs = [Microsoft.TeamFoundation.Client.TfsTeamProjectCollectionFactory]::GetTeamProjectCollection($collectionUri)
    try
    {
        $tfs.EnsureAuthenticated()
    }
    catch
    {
        Write-Error "Error occurred trying to connect to project collection: $_ "
        exit 1
    }

    
    $testservice = $tfs.GetService([Microsoft.TeamFoundation.TestManagement.Client.ITestManagementService])
    $project = $testservice.GetTeamProject($projectName)
    $project.TestConfigurations.Query("Select * from TestConfiguration") | where Name -eq $configurationname | select -ExpandProperty id
}


function Get-Testrun
{
    param
    (
            $BaseUri,
            $id
   
    )

    $uri = "$baseuri/_apis/test/runs/$($id)?api-version=1.0"
    $wc = Get-WebClient
    $jsondata = $wc.DownloadString($uri) | ConvertFrom-Json 
    $jsondata
}

function Create-Testrun
{
    param
    (
            $BaseUri,
            $data
   

    )
    $uri = "$baseuri/_apis/test/runs?api-version=1.0"
    $jsondatain = $data | ConvertTo-Json -Depth 5 # 5 needed to handle nested hashtables, default is 2
    $wc = Get-WebClient
    $jsondata = $wc.UploadString($uri,"POST", $jsondatain) | ConvertFrom-Json 
    $jsondata.id
}

# Set a flag to force verbose as a default
$VerbosePreference ='Continue' # equiv to -verbose

$baseuri = "$collectionuri/$teamproject"


$testplan = Get-TestPlanId -baseuri $baseuri -name $testplanname
$testsuite =Get-TestSuiteId  -baseuri $baseuri -testplanid $testplan -Name $testsuitename
$testpoints = Get-TestPoints -baseuri $baseuri -testplanid $testplan -testsuiteid $testsuite
$builddir = Get-BuildDirectory -BaseUri $baseuri -buildid $buildid
$environmentNameId = Get-EnvironmentId -collectionUri $collectionuri -projectName $teamproject -environmentName $environmentName
$testsettingsId = Get-TestSettingsId -collectionUri $collectionuri -projectName $teamproject -TestSettingsName $testsettingsname
$configId = Get-ConfigurationId -collectionUri $collectionuri -projectName $teamproject -ConfigurationName $configurationname



  $data =  @{ 
    "name"= $testrunname;
  "plan"= @{
    "id"= $testplan
  };
 # "iteration"= { string } ;
  "build" = @{
    "id"= $buildid
  };
  "isAutomated"= $true;
  "controller"= $testcontroller;
 # "errorMessage"= { string };
 # "comment"= { string };
   "testSettings"=@{
     "id"= $testsettingsId
     };
  "testEnvironmentId"= $environmentNameId;
 # "startedDate"= { DateTime };
 # "completedDate"= { DateTime };
 # "owner"= {
 #    "displayName"= { string }
 # },  
  "buildDropLocation" = $builddir;
 # "buildPlatform"= { string };
 # "buildFlavor"= { string };
  "configIds"= @($configId);
  "releaseUri"= $releaseUri;
  "releaseEnvironmentUri"= $releaseenvironmenturi;
  "pointIds"= @($testpoints)
}

Write-Verbose "Using data: "

Write-Verbose $($data | ConvertTo-Json -Depth 5)


$id = Create-Testrun -BaseUri $baseuri -data $data

Do
{
    Write-Verbose "Test run $id is in progress"
    Sleep -Seconds $pollInterval
    $run = (Get-Testrun -BaseUri $baseuri -id $id)
}
until ($run.state -ne "InProgress")

write-verbose "Test run $id, ended with state $($run.state)"

$str = "Total Tests $($run.totalTests), Passed Tests $($run.passedTests), Failed Tests $($run.unanalyzedTests)"

if ($run.unanalyzedTests -gt  0)
{
    write-error $str
} else
{
    Write-Verbose $str
}
   
 