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