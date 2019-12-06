function RunKuduCommand
{
	Param(
		#Command to execute
		[parameter(Mandatory=$True)]
		[String]$Command,
		
		#Command execution directory
		[parameter(Mandatory=$True)]
		[String]$Directory,
		
		#Username to perform Kudu commands (Can be found in the MSDeploy publish profile of the webapp)
		[parameter(Mandatory=$True)]
		[String]$Username,
		
		#Password to perform Kudu commands (Can be found in the MSDeploy publish profile of the webapp)
		[parameter(Mandatory=$True)]
		[String]$Password,
		
		#Hostname to perform Kudu commands (Can be found in the MSDeploy publish profile of the webapp)
		[parameter(Mandatory=$True)]
		[String]$Hostname,
		
		#The ammount of retries of this command when execution failes
		[parameter(Mandatory=$False)]
		[Int]$RetryAmount = 0,
		
		#Timespan between command executions when retrying
		[parameter(Mandatory=$False)]
		[Int]$RetryTimespan = 15,
		
		#Suppress the errors generated by executing the command
		[parameter(Mandatory=$False)]
		[switch]$SuppressError = $False,	

		#Suppress the output generated by executing the command
		[parameter(Mandatory=$False)]
		[switch]$SuppressOutput = $False
	)
	
	#Create Base64 hash for Authorization header
	$Base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $Username,$Password)))
	
	#Create Body to post to restmethod
	$Body = "{'command': '$Command','dir':'$Directory'}"
	
	$Failed = $True
	$Retry = -1	
	do {
		$Exception = $False
		Write-Output "Executing Command with Kudu: $Command"
		Write-Output "Command execution directory: $Directory"
		
		try {
			$Output = Invoke-RestMethod -Uri "https://$Hostname/api/command" -Headers @{Authorization=("Basic {0}" -f $Base64AuthInfo)} -Method POST -Body $Body -ContentType "application/json" -TimeoutSec 1200
		}
		catch{ 
			$Exception = $True
			$result = $_.Exception.Response.GetResponseStream()
			$reader = New-Object System.IO.StreamReader($result)
			$responseBody = $reader.ReadToEnd();
			$responseMessage = $reader.ReadToEnd();
			$exceptionMessage = $_.Exception.Message;
		}	
		
		#Print output about exception
		if($Output.ExitCode -gt 0 -or $Exception -or ($Output.Error `
			-And (!$Output.Error.StartsWith("Already") -And !$Command.StartsWith("git ccheckout")) <#Somehow the info about if a checkout is up to date already gets returned as an Error, don't handle as error#> `
			-And (!$Output.Error.StartsWith("From") -And !$Command.StartsWith("git fetch")))){	  <#Somehow the fetch info gets returned as an Error, don't handle as error#> `
			if(!([string]::IsNullOrEmpty($exceptionMessage))){
				Write-Output "!Exception: $($exceptionMessage)"}
			if(!([string]::IsNullOrEmpty($Output)) -And [string]::IsNullOrEmpty($Output.Output) -And [string]::IsNullOrEmpty($Output.Error)){
				Write-Output "!Output: $($Output)"}
			if(!([string]::IsNullOrEmpty($Output.Output))){
				Write-Output "!Output.Output: $($Output.Output)"}
			if(!([string]::IsNullOrEmpty($Output.Error))){
				Write-Output "!Error: $($Output.Error)"}
			if(!([string]::IsNullOrEmpty($Output.ExitCode))){
				Write-Output "!ExitCode: $($Output.ExitCode)"}
			if(!([string]::IsNullOrEmpty($responseBody))){
				Write-Output "!Exception: $($responseBody)"}
			if([string]::IsNullOrEmpty($exceptionMessage) -And [string]::IsNullOrEmpty($Output) -And [string]::IsNullOrEmpty($Output.Output) -And [string]::IsNullOrEmpty($Output.Error) -And [string]::IsNullOrEmpty($Output.ExitCode) -And [string]::IsNullOrEmpty($responseBody)){
				Write-Output "!Exception: No excpetion details"}				
		}
		else
		{
			if(!$SuppressOutput)
			{
				if(!([string]::IsNullOrEmpty($Output.Output))){
					Write-Output "Output: $($Output.Output)"}
				if(!([string]::IsNullOrEmpty($Output.Error))){
					Write-Output "Output: $($Output.Error)"}
				if([string]::IsNullOrEmpty($Output.Output) -And [string]::IsNullOrEmpty($Output.Error)){ 
					Write-Output "Output: [none]"}
			}
			
			$Failed = $False
			break
		}
		$Retry++
		
		if($RetryAmount -eq 0){
			Write-Output "Failed, no retries"
		} 
		elseif($Retry -lt $RetryAmount){
			$NewRetryIn = ($RetryTimespan * ($($Retry)+1))
			$UpcomingRetry = $Retry + 1
			Write-Output "Failed! Retry in $NewRetryIn sec, retry $UpcomingRetry of $RetryAmount"
			Start-Sleep -s $NewRetryIn
		}
		else{
			Write-Output "Failed! Retry $Retry of $RetryAmount"
		}
		
	} while($Retry -lt $RetryAmount)
	
	if($Failed)
	{
		if(!$SuppressError){
			throw "Something went wrong"
		}
		Write-Output "Suppressing errors..."
	}
}