Param(
	#Root directory of the GIT checkout on the webapp
	[parameter(Mandatory=$True)]
	$GitDirectory,
	
	#Git content branch name (for example content/Test)
	[parameter(Mandatory=$True)]
	$ContentBranch,
	
	#Other wise the Kudu connection details need to be provided
	[parameter(Mandatory=$True)]
	[String]$AzureResourceGroupName,
	[parameter(Mandatory=$True)]
	[String]$AzureWebAppName,
	[parameter(Mandatory=$False)]
	[String]$AzureWebAppSlot
)

#ZCSAzureScriptModule containing functions to perform actions within an Azuze context 
#This means that the Azure Powershell Modules should be imported/loaded, which is the case when running powershell scripts as
# 1) Azure Powershell step template context in Octopus, or
# 2) Azure Powershell script step context in Azure Devops
Import-Module -Name "$PSScriptRoot\ZCSAzureScriptModule.psm1"

if([string]::IsNullOrEmpty($AzureWebAppSlot)){
	$KuduConnectionDetails = GetKuduConnectionDetailsFromAzurePublishProfile -AzureResourceGroupName $AzureResourceGroupName -AzureWebAppName $AzureWebAppName
}else{
	$KuduConnectionDetails = GetKuduConnectionDetailsFromAzurePublishProfile -AzureResourceGroupName $AzureResourceGroupName -AzureWebAppName $AzureWebAppName -AzureWebAppSlot $AzureWebAppSlot
}
	
Write-Output "Retrieved PublishProfile: $($KuduConnectionDetails.ProfileName)"

$KuduUsername = $KuduConnectionDetails.Username
$KuduPassword = $KuduConnectionDetails.Password
$KuduHostname = $KuduConnectionDetails.Hostname

& "$PSScriptRoot\CSResetCheckoutWithoutAzurePSModules.ps1" -GitDirectory $GitDirectory -ContentBranch $ContentBranch -KuduUsername $KuduUsername -KuduPassword $KuduPassword -KuduHostname $KuduHostname