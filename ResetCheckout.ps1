Param(
	#Root directory of the GIT checkout on the webapp
	[parameter(Mandatory=$True)]
	$GitDirectory,
	
	#Git content branch name (for example content/Test)
	[parameter(Mandatory=$True)]
	$ContentBranch,
	
	#Azure web app details
	[parameter(Mandatory=$True, ParameterSetName = 'AzureWebAppDetails')]
	[String]$AzureWebAppResourceGroupName,
	[parameter(Mandatory=$True, ParameterSetName = 'AzureWebAppDetails')]
	[String]$AzureWebAppName,
	[parameter(Mandatory=$False, ParameterSetName = 'AzureWebAppDetails')]
	[String]$AzureWebAppSlot,
	
	#Kudu connection details
	[parameter(Mandatory=$True, ParameterSetName = 'KuduDetails')]
	[String]$KuduUsername,
	[parameter(Mandatory=$True, ParameterSetName = 'KuduDetails')]
	[String]$KuduPassword,
	[parameter(Mandatory=$True, ParameterSetName = 'KuduDetails')]
	[String]$KuduHostname
)

if($PSCmdlet.ParameterSetName -eq 'AzureWebAppDetails')
{
	#AzureScriptModule containing functions to perform actions within an Azuze context 
	#This means that the Azure Powershell Modules should be imported/loaded, which is the case when running powershell scripts as
	# 1) Azure Powershell step template context in Octopus, or
	# 2) Azure Powershell script step context in Azure Devops
	Import-Module -Name "$PSScriptRoot\modules\AzureScriptModule.psm1"

	if([string]::IsNullOrEmpty($AzureWebAppSlot)){
		$KuduConnectionDetails = GetKuduConnectionDetailsFromAzurePublishProfile -AzureResourceGroupName $AzureResourceGroupName -AzureWebAppName $AzureWebAppName
	}else{
		$KuduConnectionDetails = GetKuduConnectionDetailsFromAzurePublishProfile -AzureResourceGroupName $AzureResourceGroupName -AzureWebAppName $AzureWebAppName -AzureWebAppSlot $AzureWebAppSlot
	}
		
	Write-Host "Retrieved PublishProfile: $($KuduConnectionDetails.ProfileName)"

	$KuduUsername = $KuduConnectionDetails.Username
	$KuduPassword = $KuduConnectionDetails.Password
	$KuduHostname = $KuduConnectionDetails.Hostname
}

#KuduScriptModule containing functions to perform Kudu commands on a webapp
Import-Module -Name "$PSScriptRoot\modules\KuduScriptModule.psm1"
$Output = ""

RunKuduCommand -Command "git fetch origin" -Directory $GitDirectory -Username $KuduUsername -Password $KuduPassword -Hostname $KuduHostname -Reference ([ref]$Output)
RunKuduCommand -Command "git clean -df" -Directory $GitDirectory -Username $KuduUsername -Password $KuduPassword -Hostname $KuduHostname -Reference ([ref]$Output)
RunKuduCommand -Command "git reset --hard origin/$ContentBranch" -Directory $GitDirectory -Username $KuduUsername -Password $KuduPassword -Hostname $KuduHostname -Reference ([ref]$Output)
RunKuduCommand -Command "git checkout $ContentBranch" -Directory $GitDirectory -Username $KuduUsername -Password $KuduPassword -Hostname $KuduHostname -Reference ([ref]$Output)