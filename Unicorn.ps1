Param(
	#URL to the instance running the Sitecore CMS
	[parameter(Mandatory=$True)]
	[string]$SitecoreCMInstanceUrl,
	
	#URL which returns a JSON array containing the configurations that need to be processed
	[parameter(Mandatory=$True, ParameterSetName = 'ConfigurationsByUrl')]
	[string]$UrlConfigurations,
	
	#Array containing the configurations that need to be processed
	[parameter(Mandatory=$True, ParameterSetName = 'ConfigurationsByArray')]
	[string[]]$Configurations,
	
	#Action to be perform (Sync/Reserialize)
	[Parameter(Mandatory=$True)]
	[string]$Verb,
	
	#Shared secret for running Unicorn
	[Parameter(Mandatory=$True)]
	[string]$SharedSecret
)

if($PSCmdlet.ParameterSetName -eq 'ConfigurationsByUrl')
{
	Write-Host "Unicorn: Requesting $UrlConfigurations to get the unicorn configurations that need to be processed"
	$Configurations = Invoke-RestMethod -Uri $UrlConfigurations
}

#KuduScriptModule containing functions to perform unicorn actions on a webapp
Import-Module "$PSScriptRoot\modules\UnicornScriptModule.psm1"

$UrlUnicorn = $SitecoreCMInstanceUrl + "/unicorn.aspx"

Unicorn -ControlPanelUrl $UrlUnicorn -Configurations $Configurations -Verb $Verb -SharedSecret $SharedSecret -NoDebug:$False