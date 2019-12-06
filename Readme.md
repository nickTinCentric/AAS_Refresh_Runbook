# AAS Refresh for Azure Runbook
## Overview
The **AAS Refresh for Azure Runbook** is a PowerShell script that will execute any AAS refresh type on designated AAS Server and AAS DB

## Installation
This script is used on Azure using Azure Automation.  
Pre reqs before using this file
You have an Azure Environment with the following Services already setup
* Azure Analisys Services
* Azure Automation Account
* Azure Data Factory -- if you are planning on executing the Runbook via Webhook -- You can use function app, or anything else that can make a web call, for our needs we used ADF

Further instructions with Links to the tutorials used to build the script are detailed inside the script itself in the comments.

