Param(
	#URL to the instance running the Sitecore CMS
	[parameter(Mandatory=$True)]
	$SitecoreCMInstanceUrl,
	
	#URL which returns a JSON array containing the configurations that need to be reserialized
	[parameter(Mandatory=$True)]
	$UrlReserializeConfigurations,
	
	#Shared secret for running Unicorn
	[Parameter(Mandatory=$True)]
	[string]$SharedSecret
)

#ZCSKuduScriptModule containing functions to perform unicorn actions on a webapp
Import-Module "$PSScriptRoot\ZCSUnicornScriptFile.psm1"

$UrlConfigurations = $UrlReserializeConfigurations
Write-Host "Unicorn: Requesting $UrlConfigurations to get the unicorn configurations that need to be reserialized"

$Configurations = Invoke-RestMethod -Uri $UrlConfigurations

$UrlUnicorn = $SitecoreCMInstanceUrl + "/unicorn.aspx"

Unicorn -ControlPanelUrl $UrlUnicorn -Configurations $Configurations -Verb Reserialize -SharedSecret $SharedSecret -NoDebug $False