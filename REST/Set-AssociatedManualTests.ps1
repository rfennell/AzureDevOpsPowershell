##-----------------------------------------------------------------------
## <copyright file="Set-AssociatedManualTests.ps1">(c) Richard Fennell. </copyright>
##-----------------------------------------------------------------------
# Allows a manual test to be associated with a .Net Unit Test

param
(
    [parameter(Mandatory=$true,HelpMessage="URL of the Azure DevOps Organisation of TFS Collection e.g. 'https://dev.azure.com/MyOrg'")]
    $organisationUrl ,

    # There are three possible means of authentication or both the source and target
    # 1. If no UID and PWD provided then default windows credentials are used (usually OK for on premises)
    # 2. Blank UID and a Personal Access Token see https://docs.microsoft.com/en-us/azure/devops/organizations/accounts/use-personal-access-tokens-to-authenticate?view=azure-devops&tabs=preview-page

    [parameter(Mandatory=$false,HelpMessage="Username if neither PAT or default credentials are not in use")]
    $username,

    [parameter(Mandatory=$false,HelpMessage="PAT or password if default credentials are not in use")]
    $password , 

    [parameter(Mandatory=$false,HelpMessage="The ID of the test work items to associate with a unit test e.g. 123")]
    $testId,
    
    [parameter(Mandatory=$false,HelpMessage="The namespace of the test to associate with a test work item e.g. unitTestProject1.UnitTest1.TestMethod2")]
    $testNamespace ,

    [parameter(Mandatory=$false,HelpMessage="The name of the assembly that contains the  unit test e.g. unitTestProject1.dll")]
    $assemblyName 

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

function run-RestCall {
(
    $organisationUrl ,
    $username,
    $password , 
    $testId,
    $testNamespace ,
    $assemblyName ,
    $mode
)

    $wc = Get-WebClient -username $username -password $password -ContentType "application/json-patch+json"

    $uri = "$($organisationUrl)/_apis/wit/workitems/$($testid)?api-version=1.0"

    # we have to build the batch of operations in an order what does not cause the array indexes to change

    $data = @()

    # first the test of the revision to make sure the item has not been edited since we checked it
    # if this is left off the json data is considered invalid
    $data +=  @{ 
        op = "add";
        path = "/fields/Microsoft.VSTS.TCM.AutomatedTestName";
        value = "$testNamespace"
    }
    $data +=  @{ 
        op = "add";
        path = "/fields/Microsoft.VSTS.TCM.AutomatedTestStorage";
        value = "$assemblyName"
    }
    $data +=  @{ 
        op = "add";
        path = "/fields/Microsoft.VSTS.TCM.AutomatedTestId";
        value = "$(New-Guid)"
    }
    $data +=  @{ 
        op = "add";
        path = "/fields/Microsoft.VSTS.TCM.AutomatedTestType";
        value = "Unit Test"
    }
    $data +=  @{ 
        op = "add";
        path = "/fields/Microsoft.VSTS.TCM.AutomationStatus";
        value = "Automated"
    }

    $jsondatain = $data | ConvertTo-Json -Depth 5 # 5 needed to handle nested hashtables, default is 2

    $jsondata = $wc.UploadString($uri,"PATCH", $jsondatain) | ConvertFrom-Json 

    $jsondata
}

$existingValue = run-RestCall -organisationUrl $organisationUrl -username $username -password $password -testid $testId -testNamespace $testNamespace -assemblyName $assemblyName $mode "Test"

if ($existingValue.fields."Microsoft.VSTS.TCM.AutomationStatus" -eq "Automated") {
     Write-Host "The Test case [$testid] is already associated with a unit test $($existingValue.fields.'Microsoft.VSTS.TCM.AutomatedTestName')"
     $response = Read-Host -Prompt "Do you want to replace this value (y/n)"
     if ($response -eq "y" -or $response -eq "Y") {
        write-host "Updating Test Case [$testid] to be associated with unit test [$testNamespace]" -ForegroundColor Green
        $newValue = run-RestCall -organisationUrl $organisationUrl -username $username -password $password -testid $testId -testNamespace $testNamespace -assemblyName $assemblyName $mode "Add"
     }
}