Param(
	#Root directory of the GIT checkout on the webapp
	[parameter(Mandatory=$True)]
	$GitDirectory,
	
	#Git content branch name (for example content/Test)
	[parameter(Mandatory=$True)]
	$ContentBranch,
	
	#Provide the AzureResourceGroupName, AzureWebAppName and (optionally) AzureWebAppSlot if this script is running in
	# 1) Azure Powershell step template context in Octopus, or
	# 2) Azure Powershell script step context in Azure Devops
	#Other wise the Kudu connection details need to be provided
	[parameter(Mandatory=$False)]
	[String]$AzureResourceGroupName,
	[parameter(Mandatory=$False)]
	[String]$AzureWebAppName,
	[parameter(Mandatory=$False)]
	[String]$AzureWebAppSlot,

	#Kudu connection details, not needed if parameters above are provided
	[parameter(Mandatory=$False)]
	[String]$KuduUsername,
	[parameter(Mandatory=$False)]
	[String]$KuduPassword,
	[parameter(Mandatory=$False)]
	[String]$KuduHostname
)

Import-Module -Name "$PSScriptRoot\ZCSAzureScriptModule.psm1"

if(![string]::IsNullOrEmpty($AzureResourceGroupName) -And ![string]::IsNullOrEmpty($AzureResourceGroupName)){
	if([string]::IsNullOrEmpty($AzureWebAppSlot)){
		$KuduConnectionDetails = GetKuduConnectionDetailsFromAzurePublishProfile -AzureResourceGroupName $AzureResourceGroupName -AzureWebAppName $AzureWebAppName
	}else{
		$KuduConnectionDetails = GetKuduConnectionDetailsFromAzurePublishProfile -AzureResourceGroupName $AzureResourceGroupName -AzureWebAppName $AzureWebAppName -AzureWebAppSlot $AzureWebAppSlot
	}
	
	Write-Output "Retrieved PublishProfile: $($KuduConnectionDetails.ProfileName)"
	
	$KuduUsername = $KuduConnectionDetails.Username
	$KuduPassword = $KuduConnectionDetails.Password
	$KuduHostname = $KuduConnectionDetails.Hostname
}

if([string]::IsNullOrEmpty($KuduUsername) -Or [string]::IsNullOrEmpty($KuduPassword) -Or [string]::IsNullOrEmpty($KuduHostname)){
	throw "Error: Both Kudu connection details and Azure environment details are not provided. Need atleast one of them..."
}

#ZCSKuduScriptFile containing functions to perform Kudu commands on a webapp
Import-Module -Name "$PSScriptRoot\ZCSKuduScriptModule.psm1" -Force

RunKuduCommand -Command "git fetch origin" -Directory $GitDirectory -Username $KuduUsername -Password $KuduPassword -Hostname $KuduHostname -RetryAmount 10 -RetryTimespan 120
RunKuduCommand -Command "git clean -df" -Directory $GitDirectory -Username $KuduUsername -Password $KuduPassword -Hostname $KuduHostname -RetryAmount 10 -RetryTimespan 120
RunKuduCommand -Command "git reset --hard origin/$ContentBranch" -Directory $GitDirectory -Username $KuduUsername -Password $KuduPassword -Hostname $KuduHostname -RetryAmount 10 -RetryTimespan 120
RunKuduCommand -Command "git checkout $ContentBranch" -Directory $GitDirectory -Username $KuduUsername -Password $KuduPassword -Hostname $KuduHostname -RetryAmount 10 -RetryTimespan 120