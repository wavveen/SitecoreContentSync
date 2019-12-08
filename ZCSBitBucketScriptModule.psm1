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
		"description": "PR for ' + $Source + ' to ' + $Target + '",
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
		
        $Response = $_.Exception.Response.GetResponseStream()
        $Reader = New-Object System.IO.StreamReader($Response)
        $Reader.BaseStream.Position = 0
        $Reader.DiscardBufferedData()
        $ResponseBody = $Reader.ReadToEnd();
		
		return ($ResponseBody | ConvertFrom-Json)
	}
}