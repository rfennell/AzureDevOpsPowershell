param 
(
   $tpc = "http://localhost:8080/tfs/defaultcollection" ,
   $tp = "MyProject",
   $exe ="C:\Program Files (x86)\Microsoft Visual Studio\2017\Community\Common7\IDE\CommonExtensions\Microsoft\TeamFoundation\Team Explorer\witadmin.exe"
)

function importwitd ($basepath, $name)
{
    write-host "Importing WITD $name"  -ForegroundColor Green
    & $exe importwitd /collection:$tpc /p:$tp /f:"$basepath\$name.xml"
}

Write-Host "Updating Team Project $tp"  -ForegroundColor Green
# Import missing types
# this assume we have a sample of the current process template that is closet
# to our old one to get new work item types from
$workitemtoAddPath = "C:\Apps\TemplateEdits\CMMISample\WorkItem Tracking\TypeDefinitions"
importwitd $workitemtoAddPath "ChangeRequest"
importwitd $workitemtoAddPath "CodeReviewRequest"
importwitd $workitemtoAddPath "CodeReviewResponse"
importwitd $workitemtoAddPath "Epic"
importwitd $workitemtoAddPath "FeedbackRequest"
importwitd $workitemtoAddPath "FeedbackResponse"
importwitd $workitemtoAddPath "sharedparameter"
importwitd $workitemtoAddPath "feature"
importwitd $workitemtoAddPath "testcase"
importwitd $workitemtoAddPath "issue"
importwitd $workitemtoAddPath "sharedsteps"
importwitd $workitemtoAddPath "review"

# add a category file
# this is kept in out customised fiels folder specific to the team prject as it needs to to know about our customised witd
Write-Host "Updating categories"  -ForegroundColor Green
& $exe  importcategories /collection:$tpc /p:$tp /f:"C:\Apps\TemplateEdits\$tp\WorkItem Tracking\CATEGORIES.XML"

# note that this is edit of the old types not new replacements
$workitemtoEditPath = "C:\Apps\TemplateEdits\$tp\WorkItem Tracking\TypeDefinitions"
importwitd $workitemtoEditPath "Requirement"
importwitd $workitemtoEditPath "bug"
importwitd $workitemtoEditPath "task"
importwitd $workitemtoEditPath "SOTRBug" # only needed for nro

Write-Host "Updating process"  -ForegroundColor Green
& $exe importprocessconfig /collection:$tpc /p:$tp  /f:"C:\Apps\TemplateEdits\$tp\WorkItem Tracking\Process\ProcessConfiguration.xml"
