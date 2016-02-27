#Release notes for build $defname  `n
**Build Number**  : $($build.buildnumber)   `n
**Build completed** $("{0:dd/MM/yy HH:mm:ss}" -f [datetime]$build.finishTime)   `n   
**Source Branch** $($build.sourceBranch)   `n

###Associated work items   `n
@@WILOOP@@
* **$($widetail.fields.'System.WorkItemType') $($widetail.id)** [Assigned by: $($widetail.fields.'System.AssignedTo')] $($widetail.fields.'System.Title')   `n
@@WILOOP@@
`n
###Associated change sets/commits `n
@@CSLOOP@@
* **ID $($csdetail.id)** $($csdetail.message)   `n
@@CSLOOP@@