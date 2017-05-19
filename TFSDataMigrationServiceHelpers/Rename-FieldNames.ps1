param 
(
   $tpc = "http://localhost:8080/tfs/defaultcollection" ,
   $exe ="C:\Program Files (x86)\Microsoft Visual Studio\2017\Community\Common7\IDE\CommonExtensions\Microsoft\TeamFoundation\Team Explorer\witadmin.exe"
)

function Rename($field, $name)
{
    Write-host "Updating field $field" -ForegroundColor Green
   & $exe changefield /collection:$tpc /n:$field /name:$name /noprompt
}

# a set of renames that are needed
Rename "System.RelatedLinkCount" "Related Link Count" 
Rename "System.AreaId" "Area ID" 
Rename "System.AttachedFileCount" "Attached File Count" 
Rename "System.HyperLinkCount" "Hyperlink Count" 
Rename "System.ExternalLinkCount" "External Link Count" 
Rename "System.IterationId" "Iteration ID" 
Rename "Microsoft.VSTS.TCM.Steps" "Steps" 

