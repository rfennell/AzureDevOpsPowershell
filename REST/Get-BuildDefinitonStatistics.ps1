##-----------------------------------------------------------------------
## <copyright file="Get-BuildPipelineStats.ps1">(c) Richard Fennell. </copyright>
##-----------------------------------------------------------------------
# Get details of utilisation of build definitions  

param
(
    [parameter(Mandatory=$true,HelpMessage="URL of the Azure DevOps Server or Service Instance e.g. 'http://myserver:8080/tfs/defaultcollection' or 'https://dev.azure.com/myinstance'")]
    $serverUrl,
    [parameter(Mandatory=$true,HelpMessage="Team Project name e.g. 'My Team project'")]
    $teamproject,
    [parameter(Mandatory=$false,HelpMessage="Username for use with Password (should be blank if using Personal Access Toekn or default credentials)")]
    $username,
    [parameter(Mandatory=$false,HelpMessage="Password or Personal Access Token (if blank default credentials are used)")]
    $password,
    [parameter(Mandatory=$false,HelpMessage="Optional range start date range format 1/03/2020 00:00:00)")]
    $startDate,
    [parameter(Mandatory=$false,HelpMessage="Optional range end date range format 31/03/2020 00:00:00")]
    $endDate
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

function Get-Average
{
    param (
        $array
    )
    [Math]::Round(($array | Measure-Object -Average).Average)
}

function Get-Maximum
{
    param (
        $array
    )
    [Math]::Round(($array | Measure-Object -Maximum).Maximum)
}


function Get-Minimum
{
    param (
        $array
    )
    [Math]::Round(($array | Measure-Object -Minimum).Minimum)
}

function Get-BuildDefinitions
{
    param (
        [string]$username, 
        [string]$password, 
        [string]$serverUrl)

    $wc = Get-WebClient -username $username -password $password
    $uri = "$($serverUrl)/_apis/build/definitions?api-version=4.1"
    $wc.DownloadString($uri) | ConvertFrom-Json
}

function Get-BuildByDefinition
{
    param (
        [string]$username, 
        [string]$password, 
        [string]$serverUrl, 
        [string]$id, 
        [string]$token)

    $wc = Get-WebClient -username $username -password $password
    $uri = "$($serverUrl)/_apis/build/builds?definitions=$id&deletedFilter=includeDeleted&continuationToken=$token&api-version=4.1"
    $wc.DownloadString($uri) | ConvertFrom-Json
}

if (-not [string]::IsNullOrEmpty($startDate)) {
    $parsedStartDate = [DateTime]::Parse($startDate)
    write-host "Using startdate $parsedStartDate"
}
if (-not [string]::IsNullOrEmpty($endDate))  {
    $parsedEndDate = [DateTime]::Parse($endDate)
    write-host "Using enddate $parsedEndDate"
}

$output = @()
$builddefs = Get-BuildDefinitions -serverUrl $serverUrl/$teamproject -password $password -username $username
write-host "Found $($builddefs.Count) build definitions"
$progressBarCounter = 0
foreach ($def in $builddefs.value)
{
    $builds = Get-BuildByDefinition -serverUrl  $serverUrl/$teamproject -password $password -username $username -id $def.id
    $succeeded = 0;
    $failed = 0;
    $partiallySucceeded = 0;
    $canceled = 0;
    $buildTimes = @();
    $queueTimes = @();
    $buildInTimeRange = 0;
    foreach ($build in $builds.value)
    {
        # Use a try catch as a quick fix for timezone issues
        try {
            $parsedQueueTime = [DateTime]::Parse($build.queueTime)
        }
        catch {
            $parsedQueueTime = $build.queueTime
        }

        if (($build.status -ne "inProgress") -and `
           (([string]::IsNullOrEmpty($startDate) -or [string]::IsNullOrEmpty($endDate)) -or (($parsedQueueTime -gt $parsedStartDate) -and ($parsedQueueTime -lt $parsedEndDate))))
            {
            $buildInTimeRange ++

            # Get the duration
            $buildTimes += (New-TimeSpan $build.startTime $build.finishTime).TotalSeconds
            $queueTimes += (New-TimeSpan $build.queueTime $build.startTime).TotalSeconds
        
            # The Results
            switch ($build.result)
            {
                "succeeded" {$succeeded++}
                "failed" {$failed++}
                "canceled" {$canceled++}
                "partiallySucceeded" {$partiallySucceeded++}
                default { Write-Warning "Unexpected build result $($build.result)"}
            }
        }
    }

    $result = New-Object PSObject
    Add-Member -input $result NoteProperty 'Name' $def.Name
    Add-Member -input $result NoteProperty 'TotalBuilds' $builds.count
    Add-Member -input $result NoteProperty 'BuildsTimeRange' $buildInTimeRange
    Add-Member -input $result NoteProperty 'Succeeded' $succeeded
    Add-Member -input $result NoteProperty 'Failed' $failed
    Add-Member -input $result NoteProperty 'Canceled' $canceled
    Add-Member -input $result NoteProperty 'PartiallySucceeded' $partiallySucceeded
    Add-Member -input $result NoteProperty 'AvgBuildDuration' $(Get-Average($buildTimes))
    Add-Member -input $result NoteProperty 'MaxBuildDuration' $(Get-Maximum($buildTimes))
    Add-Member -input $result NoteProperty 'MinBuildDuration' $(Get-Minimum($buildTimes))
    Add-Member -input $result NoteProperty 'AvgQueueDuration' $(Get-Average($queueTimes))
    Add-Member -input $result NoteProperty 'MaxQueueDuration' $(Get-Maximum($queueTimes))
    Add-Member -input $result NoteProperty 'MinQueueDuration' $(Get-Minimum($queueTimes))
    $output += $result

    $progressBarCounter ++
    Write-Progress -activity "Analysing Build Definition $($def.Name)" -status "Scanned: $progressBarCounter of $($builddefs.Count) definitions" -percentComplete (($progressBarCounter / $builddefs.Count)  * 100)
}

# return the data
$output
