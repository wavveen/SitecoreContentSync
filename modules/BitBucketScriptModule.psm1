#https://docs.atlassian.com/bitbucket-server/rest/5.16.0/bitbucket-rest.html

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
	
	$Bearer = "Bearer $Token"
	
	$Headers = @{
		Authorization = $Bearer
	}
	
	$EndPoint = "$BaseUrl/projects/$Project/repos/$Repository/branches?filterText=$Branch"		
	$Response = Invoke-RestMethod -Uri $EndPoint -Method GET -Headers $Headers
	
	if($Response.size -gt 0) {
		Return $($Response.values[0].id)
	} else {
		Return $null
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
	
	$Bearer = "Bearer $Token"
	
	$Headers = @{
		Authorization = $Bearer
	}
	
	$Body = '{
		"title": "' + $Source + ' to ' + $Target + '",
		"description": "PR for ' + $Source + ' to ' + $Target + ' as part of content synchronization during Continuous Delivery",
		"state": "OPEN",
		"open": true,
		"closed": false,
		"fromRef": {
			"id": "' + $Source + '",
			"repository": {
				"slug": "' + $Repository + '",
				"name": null,
				"project": {
					"key": "' + $Project + '"
				}
			}
		},
		"toRef": {
			"id": "' + $Target + '",
			"repository": {
				"slug": "' + $Repository + '",
				"name": null,
				"project": {
					"key": "' + $Project + '"
				}
			}
		},
		"locked": false
	}'
	
	$EndPoint = "$BaseUrl/projects/$Project/repos/$Repository/pull-requests"
	
	try {
		$Response = Invoke-RestMethod -Uri $EndPoint -Method POST -Headers $Headers -Body $Body -ContentType "application/json"
		return $Response
	} catch {
		Write-Host "!Exception: $_.Exception.Message"
        $Exception = $_.Exception.Response.GetResponseStream()
        $Reader = New-Object System.IO.StreamReader($Exception)
        $Reader.BaseStream.Position = 0
        $Reader.DiscardBufferedData()
		$Response = $Reader.ReadToEnd()
        $JsonResponse = ($Response | ConvertFrom-Json)
	}
	
	if($($JsonResponse.errors) -And $($JsonResponse.errors.length) -eq 1){
		if($($JsonResponse.errors[0].message) -match "is already up-to-date with branch"){
			Write-Host $($JsonResponse.errors[0].message)
			return "already up-to-date"
		} elseif($($JsonResponse.errors[0].message) -match "Only one pull request may be open for a given source and target branch") {
			Write-Host $($JsonResponse.errors[0].message)
			return $($JsonResponse.errors[0].existingPullRequest)
		}
	} elseif ($($JsonResponse.errors) -And $($JsonResponse.errors.length) -gt 1) {
		Write-Host $Response
		throw "Something went wrong"
		exit 1
	} else {
		return $Response 
	}
}