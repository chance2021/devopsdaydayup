iHere’s a detailed document for creating Azure automation to start/stop VMs for Lab 22.

Lab 22: Automating VM Start/Stop Using Azure Automation

Objective

Learn how to create an Azure Automation workflow to start and stop Virtual Machines (VMs) using Azure Automation Account and Runbooks.

Prerequisites
	1.	Azure Subscription: Ensure you have an active Azure subscription.
	2.	Virtual Machines: Have at least one VM deployed in your Azure environment.
	3.	Permissions: Ensure you have sufficient permissions to create Automation Accounts and Runbooks.
	4.	Azure Automation Module: The Az PowerShell module should be imported into your Automation Account.

Steps to Create Automation

Step 1: Create an Azure Automation Account
	1.	Navigate to the Azure Portal.
	2.	In the search bar, type Automation Accounts and select it.
	3.	Click + Create.
	•	Name: Provide a name for your Automation Account (e.g., Lab22Automation).
	•	Resource Group: Select or create a resource group.
	•	Location: Choose the location of the Automation Account.
	•	Click Review + Create, and then Create.

Step 2: Import Required Modules
	1.	Go to your Automation Account.
	2.	Under Shared Resources, select Modules.
	3.	Click Browse Gallery and search for the Az.Accounts and Az.Compute modules.
	4.	Import the modules into your Automation Account.

Step 3: Create a Runbook
	1.	Under your Automation Account, select Runbooks.
	2.	Click + Create a Runbook.
	•	Name: Provide a name (e.g., StartStopVM).
	•	Runbook Type: Select PowerShell.
	•	Runtime Version: Choose Az PowerShell.
	•	Click Create.

Step 4: Add PowerShell Script

Edit the runbook and add the following script:

param(
    [Parameter(Mandatory=$true)]
    [string]$Action, # Specify "Start" or "Stop"
    
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$true)]
    [string]$VMName
)

# Authenticate with Azure
Connect-AzAccount -Identity

# Perform the action based on input
if ($Action -eq "Start") {
    Write-Output "Starting VM: $VMName"
    Start-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName -NoWait
} elseif ($Action -eq "Stop") {
    Write-Output "Stopping VM: $VMName"
    Stop-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName -Force -NoWait
} else {
    Write-Error "Invalid Action. Please specify 'Start' or 'Stop'."
}

Click Save and then Publish the runbook.

Step 5: Test the Runbook
	1.	Navigate to your Runbook and click Start.
	2.	Provide the parameters:
	•	Action: Enter Start or Stop.
	•	ResourceGroupName: Enter the resource group containing the VM.
	•	VMName: Enter the name of the VM.
	3.	Click OK to execute the Runbook.
	4.	Monitor the output and ensure the VM starts or stops as expected.

Step 6: Schedule the Runbook
	1.	Go to the Runbook you created.
	2.	Click Schedules under the Runbook menu.
	3.	Select + Add a schedule.
	4.	Either create a new schedule or link to an existing one:
	•	Start Time: Specify when the schedule should trigger.
	•	Recurrence: Choose One-Time or Recurring.
	5.	Link the schedule to your Runbook and specify parameters for the VM action.

Validation
	•	Ensure the VM is starting or stopping as scheduled.
	•	Check the Jobs section under the Runbook to view execution details and troubleshoot errors if any.

Conclusion

In this lab, you created an Azure Automation workflow using Runbooks to automate the start and stop of Azure VMs. This automation reduces manual intervention and optimizes resource usage, especially for non-production workloads.

Feel free to test this automation further and extend its functionality, such as managing multiple VMs or adding notifications for execution results.