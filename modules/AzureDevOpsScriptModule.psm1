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
	
	if($Response.count -eq 1) {
		Return $($Response.value[0].name)
	} elseif ($Response.count -gt 1) {
		Return "multiple branches found"
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
		$PRDetails | Add-Member -MemberType NoteProperty -Name version -Value "x"
		$PRDetails | Add-Member -MemberType NoteProperty -Name title -Value "$($Response.title)"
		$PRDetails | Add-Member -MemberType NoteProperty -Name author -Value "$($Response.createdBy.id)"
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
		$PRDetails | Add-Member -MemberType NoteProperty -Name version -Value "x"
		$PRDetails | Add-Member -MemberType NoteProperty -Name title -Value "$($Response.value[0].title)"
		$PRDetails | Add-Member -MemberType NoteProperty -Name author -Value "$($Response.value[0].createdBy.id)"
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
		[parameter(Mandatory=$True)]
		[String]$Token,
		[parameter(Mandatory=$True)]
		[String]$BaseUrl,
		[parameter(Mandatory=$True)]
		[String]$Project,
		[Parameter(Mandatory=$true)]
		[string] $VariableName,
		[Parameter(Mandatory=$true)]
		[string] $VariableValue
	)

	$Base64Token = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f "",$Token)))	
	$Bearer = "Basic $Base64Token"
	
	$Headers = @{
		Authorization = $Bearer
	}
	
	$EndPoint = "$BaseUrl/$Project/_apis/release/releases/$($env:RELEASE_RELEASEID)?api-version=5.1"
	
	#Getting release details
	Write-Host "Getting release details"
	$Response = Invoke-RestMethod -Uri $EndPoint -Headers $Headers -Method Get	

	#Updating variable in release details
	Write-Host "Updating variable '$VariableName' in release details to '$VariableValue'"
	$Response.variables.($VariableName).value = $VariableValue;
	$JsonResponse = $Response | ConvertTo-Json -Depth 100
	$JsonResponse = [Text.Encoding]::UTF8.GetBytes($JsonResponse)
	
	#Putting the release details
	Write-Host "Putting the release details"
	$JsonResponse = Invoke-RestMethod -Uri $EndPoint -Method PUT -Headers $Headers -ContentType "application/json" -Body $JsonResponse
	Start-Sleep -Seconds 1
	
	Write-Host "Release details/variable have been updated"
}

function MergePullRequest{
	Param (
		[parameter(Mandatory=$True)]
		[String]$Token,
		[parameter(Mandatory=$True)]
		[String]$BaseUrl,
		[parameter(Mandatory=$True)]
		[String]$Project,
		[parameter(Mandatory=$True)]
		[String]$Repository,
		[parameter(Mandatory=$True)]
		[String]$PullRequestId,
		[parameter(Mandatory=$True)]
		[String]$PullRequestVersion,
		[parameter(Mandatory=$True)]
		[String]$PullRequestAuthorId
	)
		
	$Base64Token = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f "",$Token)))	
	$Bearer = "Basic $Base64Token"
	
	$Headers = @{
		Authorization = $Bearer
	}
	
	$Body = '{"autoCompleteSetBy": { "id": "' + $PullRequestAuthorId + '"}}'
	
	$EndPoint = "$BaseUrl/$Project/_apis/git/repositories/$Repository/pullrequests/$($PullRequestId)?api-version=5.1"
	Invoke-RestMethod -Uri $EndPoint -Method PATCH -Headers $Headers -ContentType "application/json" -Body $Body
}