Param(
	#Root directory of the GIT checkout on the webapp
	[parameter(Mandatory=$True)]
	$GitDirectory,
	
	#Git content branch name (for example content/Test)
	[parameter(Mandatory=$True)]
	$ContentBranch,
	
	#Release number of the release thats getting deployed
	[parameter(Mandatory=$True)]
	$ReleaseNumber,
	
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
	[String]$KuduHostname,
	
	#Defines if this push is part of the deploy process
	[parameter(Mandatory=$False)]
	[switch][bool]$IsDeploy,
	
	#Emailaddress for commit
	[parameter(Mandatory=$False)]
	[String]$Emailaddress = "content@sync.com",
	
	#Username for commit
	[parameter(Mandatory=$False)]
	[String]$Username = "contentsync"
)

$IsDeploy = $IsDeploy.IsPresent

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
Import-Module -Name "$PSScriptRoot\modules\KuduScriptModule.psm1" -Force
$Output = ""

#Stage all changes
RunKuduCommand -Command "git add -A" -Directory $GitDirectory -Username $KuduUsername -Password $KuduPassword -Hostname $KuduHostname -Reference ([ref]$Output)
RunKuduCommand -Command "git config --global user.email `"$Emailaddress`"" -Directory $GitDirectory -Username $KuduUsername -Password $KuduPassword -Hostname $KuduHostname -Reference ([ref]$Output)
RunKuduCommand -Command "git config --global user.name `"$Username`"" -Directory $GitDirectory -Username $KuduUsername -Password $KuduPassword -Hostname $KuduHostname -Reference ([ref]$Output)

#Check if there are changes
RunKuduCommand -Command "git diff --name-only --cached" -Directory $GitDirectory -Username $KuduUsername -Password $KuduPassword -Hostname $KuduHostname -Reference ([ref]$Output)
if([string]::IsNullOrEmpty($Output.Output)){
	Write-Host "There are no changes, so no need to commit and push"
}else{
	Write-Host "There are changes, going to commit and push"
	if($IsDeploy){
		RunKuduCommand -Command "git commit -a -m `"$ReleaseNumber pre deploy commit $ContentBranch`" --allow-empty" -Directory $GitDirectory -Username $KuduUsername -Password $KuduPassword -Hostname $KuduHostname -Reference ([ref]$Output)
	} else {
		$DateTime = Get-Date -UFormat "%Y-%m-%d %R"
		RunKuduCommand -Command "git commit -a -m  `"Content preservation $ContentBranch $DateTime`" --allow-empty" -Directory $GitDirectory -Username $KuduUsername -Password $KuduPassword -Hostname $KuduHostname -Reference ([ref]$Output)		
	}
	RunKuduCommand -Command "git push" -Directory $GitDirectory -Username $KuduUsername -Password $KuduPassword -Hostname $KuduHostname -Reference ([ref]$Output)
}