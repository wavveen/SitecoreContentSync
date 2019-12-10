Param(
	#URL to the instance running the Sitecore CMS
	[parameter(Mandatory=$True)]
	[string]$SitecoreCMInstanceUrl,
	
	#URL which returns a JSON array containing the configurations that need to be processed
	[parameter(Mandatory=$True, ParameterSetName = 'ConfigurationsByUrl')]
	[string]$UrlConfigurations,
	
	#URL which returns a JSON array containing the configurations that need to be excluded from being processed
	[parameter(Mandatory=$False, ParameterSetName = 'ConfigurationsByUrl')]
	[string]$UrlExcludeConfigurations,
	
	#Array containing the configurations that need to be processed
	[parameter(Mandatory=$True, ParameterSetName = 'ConfigurationsByArray')]
	[string[]]$Configurations,
	
	#Array containing the configurations that need to excluded from being processed
	[parameter(Mandatory=$False, ParameterSetName = 'ConfigurationsByArray')]
	[string[]]$ExcludeConfigurations,
	
	#Action to be perform (Sync/Reserialize)
	[Parameter(Mandatory=$True)]
	[string]$Verb,
	
	#Shared secret for running Unicorn
	[Parameter(Mandatory=$True)]
	[string]$SharedSecret
)

if($PSCmdlet.ParameterSetName -eq 'ConfigurationsByUrl')
{
	Write-Host "Unicorn: Requesting UrlConfigurations to get the unicorn configurations that need to be processed"
	$Configurations = Invoke-RestMethod -Uri $UrlConfigurations
	
	Write-Host "Unicorn: Requesting UrlExcludeConfigurations to get the unicorn configurations that need to be be excluded from being processed"
	if(![string]::IsNullOrEmpty($UrlExcludeConfigurations)){
		$ExcludeConfigurations = Invoke-RestMethod -Uri $UrlExcludeConfigurations
	}
}

#KuduScriptModule containing functions to perform unicorn actions on a webapp
Import-Module "$PSScriptRoot\modules\UnicornScriptModule.psm1" -Force

$UrlUnicorn = $SitecoreCMInstanceUrl + "/unicorn.aspx"

#Run action for passed configurations
ForEach ($Configuration in $Configurations ) {
	if($Configuration -in $ExcludeConfigurations){
		Write-Host "Unicorn: $Configuration excluded"
	}else{
		Unicorn -ControlPanelUrl $UrlUnicorn -Configuration $Configuration -Verb $Verb -SharedSecret $SharedSecret -NoDebug:$False
	}
}