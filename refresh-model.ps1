# Runbook Script to refresh cube models
# created by nick tinsley
#
# code is pieced together from the following tutorials and issue resolutions
# https://docs.microsoft.com/en-us/azure/analysis-services/analysis-services-refresh-azure-automation ## how to setup runbook and ADF -- Code used in this document is old, the code below was pieced together using all of the links below
# https://social.msdn.microsoft.com/Forums/en-US/e9809551-7cb3-43d7-8ada-c170f67a9887/problem-with-automation-and-processing-analysis-services?forum=azureautomation ##fixing connection to cube error
# https://azure.microsoft.com/en-us/blog/automation-of-azure-analysis-services-with-service-principals-and-powershell/  ##added credential using SSMS,, using script below was easier but this is a good learning resource

# prereqs -- need to have an AAS environment, a model in AAS that is tied to a data source for refresh.  If planning on using ADF to consume API then you will need ADF Paas Environment built

#Step 1 -- Import Azure.AnalysisServices and SqlServer packages into the Automation Account from the browse gallery
#step 2 -- create Principal Connection credential in the Azure Automation Account 
#step 3 -- add the new credential into AAS as Admin so it can execute the refresh
#To add user as admin you will need to get the accounts App Id and Tenant ID. lines 17 - 18 will display the information, add remarks to the rest of the page
#and remove the remarks around code 17-18, execute runbook in Test Pane, and the output will give you the info you need.  
#------------------------------------------------------------------------------------------
# $ServicePrincipalConnection= Get-AutomationConnection -Name "AzureRunAsConnection"
# Write-Output $ServicePrincipalConnection

#lines 22 and 23 will add the Principal Connection credential to AAS. Replace the <> areas with the App ID and Tenant ID you gathered from the steps above
#If executing from Runbook remark rest of script and remove the remarks from lines 22 and 23 
#$SPAdmin = "app:<AzureRunAs Connection Application Id>@<Tenant Id>"
# Set-AzureRmAnalysisServicesServer -Name <analysisserver> -ResourceGroupName <resourcegroupname> -Administrator $SPAdmin 
#
# Step 4 - After the user has been added you should put the remarks back on the lines above and remove the remarks that you put on the rest of the code.  The code below will 
# be the runbook script that will execute the refresh

#Takes in 4 optional Params 
# Webhook -- Not needed if running directly from runbook, this is if you put a webhook on the runbook and execute it via the API.  
# DatabaseName -- Name of the Cube Database you are refreshing
# AnalysisServer -- Name of the AAS Server
# RefreshType -- Type of Refresh (full, clearValues, calculate, dataOnly, automatic, add, defragment)  Details of each type can be found here https://docs.microsoft.com/en-us/bi-reference/tmsl/refresh-command-tmsl
param
(
    [Parameter (Mandatory = $false)]
    [object] $WebhookData,
    [Parameter (Mandatory = $false)]
    [String] $DatabaseName,
    [Parameter (Mandatory = $false)]
    [String] $AnalysisServer,
    [Parameter (Mandatory = $false)]
    [String] $RefreshType
)

#get service principal information
$ServicePrincipalConnection= Get-AutomationConnection -Name "AzureRunAsConnection"  ##name can be changed, i am using default name

#add the Serivice Principal account to your cmdlet requests
Add-AzureAnalysisServicesAccount -RolloutEnvironment "aspaaseastus2.asazure.windows.net" -ServicePrincipal `
                                -ApplicationId $ServicePrincipalConnection.ApplicationId -CertificateThumbprint $ServicePrincipalConnection.CertificateThumbprint `
                                -TenantId $ServicePrincipalConnection.TenantId

#added try catch to throw an exception if connection is not made
#this will help setup Azure monitoring alerts, you can trigger the alert if the runbook fails
try{
    # If runbook was called from Webhook, WebhookData will not be null.
    if ($WebhookData)
    { 
        # Retrieve AAS details from Webhook request body
        $atmParameters = (ConvertFrom-Json -InputObject $WebhookData.RequestBody)
        Write-Output "CredentialName: $($atmParameters.CredentialName)"
        Write-Output "AnalysisServicesDatabaseName: $($atmParameters.AnalysisServicesDatabaseName)"
        Write-Output "AnalysisServicesServer: $($atmParameters.AnalysisServicesServer)"
        Write-Output "DatabaseRefreshType: $($atmParameters.DatabaseRefreshType)"
        
        # setup params from web rewquest
        $_databaseName = $atmParameters.AnalysisServicesDatabaseName
        $_analysisServer = $atmParameters.AnalysisServicesServer
        $_refreshType = $atmParameters.DatabaseRefreshType
        
        #run the refresh command on the AAS
        Invoke-ProcessASDatabase -DatabaseName $_databaseName -RefreshType $_refreshType -Server $_analysisServer -ServicePrincipal -Verbose
    }
    else ##no webhook call
    {
        #run the refresh from the manual entry or parameters provided by script
        Invoke-ProcessASDatabase -DatabaseName $DatabaseName -RefreshType $RefreshType -Server $AnalysisServer -ServicePrincipal -Verbose
    }
}
catch
{
    throw "error connecting to AAS Services"
}

#for Debugging
#Write-Output $ServicePrincipalConnection

#Step 5 setup automation
#You can run the book using an Automation Schedule or you can add a Webhook to the Runbook that will create an API that can be consumed by ADF or any other App that can
#excute an HTTP Request and pass in the JSON load
#detailso on how to setup the ADF and Webhook can be found https://docs.microsoft.com/en-us/azure/analysis-services/analysis-services-refresh-azure-automation

# Json request example
# {
#     "AnalysisServicesDatabaseName": "AdventureWorksDB",
#     "AnalysisServicesServer": "asazure://westeurope.asazure.windows.net/MyAnalysisServer",
#     "DatabaseRefreshType": "Full"
# }
