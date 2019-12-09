#https://docs.microsoft.com/en-us/rest/api/azure/devops/git/?view=azure-devops-rest-5.1

function GetBranch
{
	Param(
		[parameter(Mandatory=$True)]
		[String]$Token,
		[parameter(Mandatory=$True)]
		[String]$BaseUrl,
		[parameter(Mandatory=$True)]
		[String]$Project,
		[parameter(Mandatory=$True)]
		[String]$Repository,
		[parameter(Mandatory=$True)]
		[String]$Branch
	)
	
	$Base64Token = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f "",$Token)))	
	$Bearer = "Basic $Base64Token"
	
	$Headers = @{
		Authorization = $Bearer
	}
	
	$EndPoint = "$BaseUrl/$Project/_apis/git/repositories/$Repository/refs?filterContains=$Branch"	
	$Response = Invoke-RestMethod -Uri $EndPoint -Method GET -Headers $Headers
	
	if($Response.count -gt 0) {
		Return $($Response.value[0].name)
	} else {
		Return $null
	}
}

function AlreadyUpToDate{
	Param(
		[parameter(Mandatory=$True)]
		[String]$Token,
		[parameter(Mandatory=$True)]
		[String]$BaseUrl,
		[parameter(Mandatory=$True)]
		[String]$Project,
		[parameter(Mandatory=$True)]
		[String]$Repository,
		[parameter(Mandatory=$True)]
		[String]$Source,
		[parameter(Mandatory=$True)]
		[String]$Target
	)
	
	$Base64Token = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f "",$Token)))	
	$Bearer = "Basic $Base64Token"
	
	$Headers = @{
		Authorization = $Bearer
	}
	
	$EndPoint = "$BaseUrl/$Project/_apis/git/repositories/$Repository/diffs/commits?api-version=5.1&baseVersion=$Source&targetVersion=$Target"
	$Response = Invoke-RestMethod -Uri $EndPoint -Method GET -Headers $Headers
	if($Response.aheadCount -eq 0 -And $Response.behindCount -eq 0){
		return $True
	} else {
		return $False
	}
}

function CreatePullRequest
{
	Param(
		[parameter(Mandatory=$True)]
		[String]$Token,
		[parameter(Mandatory=$True)]
		[String]$BaseUrl,
		[parameter(Mandatory=$True)]
		[String]$Project,
		[parameter(Mandatory=$True)]
		[String]$Repository,
		[parameter(Mandatory=$True)]
		[String]$Source,
		[parameter(Mandatory=$True)]
		[String]$Target
	)
	
	$Base64Token = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f "",$Token)))	
	$Bearer = "Basic $Base64Token"
	
	$Headers = @{
		Authorization = $Bearer
	}
		
	$Body = '{
		"sourceRefName": "' + $Source + '",
		"targetRefName": "' + $Target + '",
		"title": "' + $Source + ' to ' + $Target + '",
		"description": "PR for ' + $Source + ' to ' + $Target + ' as part of content synchronization during Continuous Delivery"
	}'
	
	$EndPoint = "$BaseUrl/$Project/_apis/git/repositories/$Repository/pullrequests?api-version=5.1"
	
	try {
		$Response = Invoke-RestMethod -Uri $EndPoint -Method POST -Headers $Headers -Body $Body -ContentType "application/json"
		$PRDetails = New-Object -TypeName psobject
		$PRDetails | Add-Member -MemberType NoteProperty -Name id -Value "$($Response.pullRequestId)"
		$PRDetails | Add-Member -MemberType NoteProperty -Name version -Value ""
		$PRDetails | Add-Member -MemberType NoteProperty -Name title -Value "$($Response.title)"
		return $PRDetails
	} catch {
        $Exception = $_.Exception.Response.GetResponseStream()
        $Reader = New-Object System.IO.StreamReader($Exception)
        $Reader.BaseStream.Position = 0
        $Reader.DiscardBufferedData()
		$Response = $Reader.ReadToEnd()
        $JsonResponse = ($Response | ConvertFrom-Json)
	}
	
	if($($JsonResponse)){
		if($($JsonResponse.message) -match "An active pull request for the source and target branch already exists") {								#Catch the PR already there error, and return already existing PR details
			$PRDetails = GetPullRequest -Token $Token -BaseUrl $BaseUrl -Project $Project -Repository $Repository -Source $Source -Target $Target
			return $PRDetails
		}
	}
	
	#Something went wrong if we end-up here
	Write-Host $Response
	throw "Something went wrong"
	exit 1
}

function GetPullRequest
{
	Param(
		[parameter(Mandatory=$True)]
		[String]$Token,
		[parameter(Mandatory=$True)]
		[String]$BaseUrl,
		[parameter(Mandatory=$True)]
		[String]$Project,
		[parameter(Mandatory=$True)]
		[String]$Repository,
		[parameter(Mandatory=$True)]
		[String]$Source,
		[parameter(Mandatory=$True)]
		[String]$Target
	)
	
	$Base64Token = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f "",$Token)))	
	$Bearer = "Basic $Base64Token"
	
	$Headers = @{
		Authorization = $Bearer
	}
	
	$EndPoint = "$BaseUrl/$Project/_apis/git/repositories/$Repository/pullrequests?api-version=5.1&searchCriteria.sourceRefName=$Source&searchCriteria.targetRefName=$Target&searchCriteria.status=active"
	$Response = Invoke-RestMethod -Uri $EndPoint -Method GET -Headers $Headers
	if($Response -And $Response.count -eq 1) {
		$PRDetails = New-Object -TypeName psobject
		$PRDetails | Add-Member -MemberType NoteProperty -Name id -Value "$($Response.value[0].pullRequestId)"
		$PRDetails | Add-Member -MemberType NoteProperty -Name version -Value ""
		$PRDetails | Add-Member -MemberType NoteProperty -Name title -Value "$($Response.value[0].title)"
		return $PRDetails
	} else {
		Write-Host $Response
		throw "Something went wrong"
		exit 1
	}
}

function CanMergePullRequest{
	Param(
		[parameter(Mandatory=$True)]
		[String]$Token,
		[parameter(Mandatory=$True)]
		[String]$BaseUrl,
		[parameter(Mandatory=$True)]
		[String]$Project,
		[parameter(Mandatory=$True)]
		[String]$Repository,
		[parameter(Mandatory=$True)]
		[String]$PullRequestId
	)
	$Base64Token = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f "",$Token)))	
	$Bearer = "Basic $Base64Token"
	
	$Headers = @{
		Authorization = $Bearer
	}
	
	$EndPoint = "$BaseUrl/$Project/_apis/git/repositories/$Repository/pullrequests/$($PullRequestId)?api-version=5.1"
	$Response = Invoke-RestMethod -Uri $EndPoint -Method GET -Headers $Headers
	if($Response.mergeStatus -eq "succeeded"){
		return $True
	} elseif ($Response.mergeStatus -eq "queued") {
		Write-Host "Queued! Retry in 1 sec"
		Start-Sleep -Seconds 1
		CanMergePullRequest -Token $Token -BaseUrl $BaseUrl -Project $Project -Repository $Repository -PullRequestId $PullRequestId
	} else {
		return $False
	}
}

function SetReleaseVariable{
	Param (
		[Parameter(Mandatory=$true)]
		[ValidateNotNullOrEmpty()]
		[string] $VariableName,
		[Parameter(Mandatory=$true)]
		[ValidateNotNullOrEmpty()]
		[string] $VariableValue
	)

	$h = BasicAuthHeader $env:SYSTEM_ACCESSTOKEN
	$baseRMUri = $env:SYSTEM_TEAMFOUNDATIONSERVERURI + $env:SYSTEM_TEAMPROJECT
	$releaseId = $env:RELEASE_RELEASEID

	$getReleaseUri = $baseRMUri + "/_apis/release/releases/" + $releaseId + "?api-version=5.0"

	$release = Invoke-RestMethod -Uri $getReleaseUri -Headers $h -Method Get

	# Update an existing variable named d1 to its new value d5
	Write-Host ("Setting variable value...")
	$release.variables.($VariableName).value = $VariableValue;
	Write-Host ("Completed setting variable value.")

	####****************** update the modified object **************************
	$release2 = $release | ConvertTo-Json -Depth 100
	$release2 = [Text.Encoding]::UTF8.GetBytes($release2)

	$updateReleaseUri = $baseRMUri + "/_apis/release/releases/" + $releaseId + "?api-version=5.0"
	Write-Host ("Updating release...")
	$content2 = Invoke-RestMethod -Uri $updateReleaseUri -Method Put -Headers $h -ContentType "application/json" -Body $release2 -Verbose -Debug
	write-host "=========================================================="
}

## Construct a basic auth head using PAT
function BasicAuthHeader()
{
	Param([string]$authtoken)

	$ba = (":{0}" -f $authtoken)
	$ba = [System.Text.Encoding]::UTF8.GetBytes($ba)
	$ba = [System.Convert]::ToBase64String($ba)
	$h = @{Authorization=("Basic{0}" -f $ba);ContentType="application/json"}
	return $h
}