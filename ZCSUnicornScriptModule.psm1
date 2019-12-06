Function Unicorn {
	Param(
		#URL to the Unicorn controlpanel {SitecoreCMInstance/unicorn.aspx}
		[Parameter(Mandatory=$True)]
		[string]$ControlPanelUrl,

		#The Unicorn configurations to perform the requested action for
		[Parameter(Mandatory=$True)]
		[string[]]$Configurations,
		
		#Action to perform (Sync/Reserialize)
		[Parameter(Mandatory=$True)]
		[string]$Verb,
		
		#Shared secret for running unicorn
		[Parameter(Mandatory=$True)]
		[string]$SharedSecret,

		#Whether to return debug info in the logs or not
		[Parameter(Mandatory=$False)]
		[switch]$NoDebug = $True
	)
	
	$MicroCHAP = $PSScriptRoot + '\MicroCHAP.dll'
	Add-Type -Path $MicroCHAP
	
	Write-Host "Unicorn: Preparing authorization"

	#Get an Auth challenge
	$challenge = Get-Challenge -ControlPanelUrl $ControlPanelUrl

	Write-Host "Unicorn: Received challenge from remote server: $challenge"

	$signatureService = New-Object MicroCHAP.SignatureService -ArgumentList $SharedSecret
	[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

	#Run action for passed configurations
	ForEach ($Configuration in $Configurations ) {		
		$url = "{0}?verb={1}&configuration={2}" -f $ControlPanelUrl, $Verb, $Configuration
	
		#Create a signature with the shared secret and challenge
		$signature = $signatureService.CreateSignature($challenge, $url, $null)

		if(-not $NoDebug) {
			Write-Host "Sync-Unicorn: MAC '$($signature.SignatureSource)'"
			Write-Host "Sync-Unicorn: HMAC '$($signature.SignatureHash)'"
			Write-Host "Sync-Unicorn: If you get authorization failures compare the values above to the Sitecore logs."
		}
	
		$result = Invoke-WebRequest -Uri $url -Headers @{ "X-MC-MAC" = $signature.SignatureHash; "X-MC-Nonce" = $challenge } -TimeoutSec 10800 -UseBasicParsing
		
		$result.Content
	
		if($result.Content -match "ERROR OCCURRED")
		{
			throw "Something went wrong"
			exit 1
		}
	}
}

Function Get-Challenge {
	Param(
		[Parameter(Mandatory=$True)]
		[string]$ControlPanelUrl
	)

	$url = "$($ControlPanelUrl)?verb=Challenge"

	[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
	$result = Invoke-WebRequest -Uri $url -TimeoutSec 360 -UseBasicParsing

	$result.Content
}

Function Invoke-StreamingWebRequest($Uri, $MAC, $Nonce) {
	$responseText = new-object -TypeName "System.Text.StringBuilder"

	$request = [System.Net.WebRequest]::Create($Uri)
	$request.Headers["X-MC-MAC"] = $MAC
	$request.Headers["X-MC-Nonce"] = $Nonce
	$request.Timeout = 10800000

	$response = $request.GetResponse()
	$responseStream = $response.GetResponseStream()
	$responseStreamReader = new-object System.IO.StreamReader $responseStream
	
	while(-not $responseStreamReader.EndOfStream) {
		$line = $responseStreamReader.ReadLine()

		if($line.StartsWith('Error:')) {
			Write-Host $line.Substring(7) -ForegroundColor Red
		}
		elseif($line.StartsWith('Warning:')) {
			Write-Host $line.Substring(9) -ForegroundColor Yellow
		}
		elseif($line.StartsWith('Debug:')) {
			Write-Host $line.Substring(7) -ForegroundColor Gray
		}
		elseif($line.StartsWith('Info:')) {
			Write-Host $line.Substring(6) -ForegroundColor White
		}
		else {
			Write-Host $line -ForegroundColor White
		}

		[void]$responseText.AppendLine($line)
	}

	return $responseText.ToString()
}