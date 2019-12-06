Param(
	#Root directory of the GIT checkout on the webapp
	[parameter(Mandatory=$True)]
	$GitDirectory,
	
	#Git content branch name (for example content/Test)
	[parameter(Mandatory=$True)]
	$ContentBranch,
	
	#Kudu connection details
	[parameter(Mandatory=$True)]
	[String]$KuduUsername,
	[parameter(Mandatory=$True)]
	[String]$KuduPassword,
	[parameter(Mandatory=$True)]
	[String]$KuduHostname
)

#ZCSKuduScriptModule containing functions to perform Kudu commands on a webapp
Import-Module -Name "$PSScriptRoot\ZCSKuduScriptModule.psm1" -Force

RunKuduCommand -Command "git fetch origin" -Directory $GitDirectory -Username $KuduUsername -Password $KuduPassword -Hostname $KuduHostname -RetryAmount 10 -RetryTimespan 120
RunKuduCommand -Command "git clean -df" -Directory $GitDirectory -Username $KuduUsername -Password $KuduPassword -Hostname $KuduHostname -RetryAmount 10 -RetryTimespan 120
RunKuduCommand -Command "git reset --hard origin/$ContentBranch" -Directory $GitDirectory -Username $KuduUsername -Password $KuduPassword -Hostname $KuduHostname -RetryAmount 10 -RetryTimespan 120
RunKuduCommand -Command "git checkout $ContentBranch" -Directory $GitDirectory -Username $KuduUsername -Password $KuduPassword -Hostname $KuduHostname -RetryAmount 10 -RetryTimespan 120