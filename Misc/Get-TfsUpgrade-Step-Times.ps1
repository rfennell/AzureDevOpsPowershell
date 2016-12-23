param
(
    $logfile = "TPC_ApplyPatch.log",
    $outfile = "out.csv"
)

 # A function to covert the start and end times to a number of minutes
 # Can't use simple timespan as we only have the time portion not the whole datetime
 # Hence the hacky added a day-1 second
 function CalcDuration
 {
    param
    (
        $startTime,
        $endTime
    )


    $diff = [dateTime]$endTime - $startTime
    if ([dateTime]$endTime -lt $startTime) 
    { 
       $diff += "23:59" # add a day as we past midnight
    }


    [int]$diff.Hours *60 + $diff.Minutes
 }


 Write-Host "Importing $logfile for processing"
 # pull out the lines we are interested in using a regular expression to extract the columns
 # the (.{8} handle the fixed width, exact matches are used for the test
 $lines = Get-Content -Path $logfile | Select-String "  Executing step:"  | Where{$_ -match "^(.)(.{8})(.{8})(Executing step:)(.{2})(.*)(')(.*)([(])(.*)([ ])([of])(.*)"} | ForEach{
    [PSCustomObject]@{
        'Step' = $Matches[10]
        'TimeStamp' = $Matches[2]
        'Action' = $Matches[6]
    }
 }
 
# We assume the upgrade started at the timestamp of the 0th step
# Not true but very close
[DateTime]$start = $lines[0].TimeStamp


Write-Host "Writing results to $outfile"
# Work out the duration
 $steps = $lines | ForEach{
    [PSCustomObject]@{
        'Step' = $_.Step
        'TimeStamp' = $_.TimeStamp
        'EplasedTime' = CalcDuration -startTime $start -endTime $_.TimeStamp 
        'Action' = $_.Action
        
    }
 } 
 $steps | export-csv $outfile -NoTypeInformation 


# and list to screen
$steps
