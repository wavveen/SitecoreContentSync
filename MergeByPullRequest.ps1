Param(
	#Name of the GIT platform
	[parameter(Mandatory=$True)]
	$GitPlatform,

	#Token for the rest api
	[parameter(Mandatory=$True)]
	$RestApiToken,
	
	#Base url of the rest api of the GIT platform
	[parameter(Mandatory=$True)]
	$RestApiBaseUrl,
	
	#Project name which contains the GIT repository
	[parameter(Mandatory=$True)]
	$GitProjectName,
	
	#Name of the GIT repository
	[parameter(Mandatory=$True)]
	$GitRepositoryName,

	#Branch which will be merged
	[parameter(Mandatory=$True)]
	$GitSourceBranch,
	
	#Branch which will be merged if the SourceBranch doesn't exsist
	[parameter(Mandatory=$False)]
	$GitSourceFallbackBranch,
	
	#Branch which will be merged to
	[parameter(Mandatory=$True)]
	$GitTargetBranch,
	
	#Branch which will be merged to if the TargetBranch doesn't exsist
	[parameter(Mandatory=$False)]
	$GitTargetFallbackBranch	
)

#Resolving GIT platform
if($GitPlatform -eq "BitBucket"){
	Import-Module -Name "$PSScriptRoot\modules\BitBucketScriptModule.psm1" -Force
} elseif($GitPlatform -eq "AzureDevOps") {
	Import-Module -Name "$PSScriptRoot\modules\AzureDevOpsScriptModule.psm1" -Force
} else {
	Write-Host "GitPlatform not recognized"
	throw "Something went wrong"
	exit 1
}

#Resolving source branch
$SourceBranch = GetBranch -Token $RestApiToken -BaseUrl $RestApiBaseUrl -Project $GitProjectName -Repository $GitRepositoryName -Branch $GitSourceBranch
if($SourceBranch){
	Write-Host "Source branch: $SourceBranch"
} elseif ($GitSourceFallbackBranch) {
	Write-Host "No branch found for '$GitSourceBranch'"
	$SourceBranch = GetBranch -Token $RestApiToken -BaseUrl $RestApiBaseUrl -Project $GitProjectName -Repository $GitRepositoryName -Branch $GitSourceFallbackBranch
	if($SourceBranch){
		Write-Host "Source branch: $SourceBranch"
	} else {
		Write-Host "No branch found for '$GitSourceFallbackBranch'"
		throw "Something went wrong"
		exit 1
	}
} else {
	Write-Host "No branch found for '$GitSourceBranch'"
	throw "Something went wrong"
	exit 1
}

#Resolving target branch
$TargetBranch = GetBranch -Token $RestApiToken -BaseUrl $RestApiBaseUrl -Project $GitProjectName -Repository $GitRepositoryName -Branch $GitTargetBranch
if($TargetBranch){
	Write-Host "Target branch: $TargetBranch"
} elseif ($GitTargetFallbackBranch) {
	Write-Host "No branch found for '$GitTargetBranch'"
	$TargetBranch = GetBranch -Token $RestApiToken -BaseUrl $RestApiBaseUrl -Project $GitProjectName -Repository $GitRepositoryName -Branch $GitTargetFallbackBranch
	if($TargetBranch){
		Write-Host "Target branch: $TargetBranch"
	} else {
		Write-Host "No branch found for '$GitTargetFallbackBranch'"
		throw "Something went wrong"
		exit 1
	}
} else {
	Write-Host "No branch found for '$GitTargetBranch'"
	throw "Something went wrong"
	exit 1
}

#Create pull request
Write-Host "Going to create a pull request to merge $SourceBranch into $TargetBranch"
$Response = CreatePullRequest -Token $RestApiToken -BaseUrl $RestApiBaseUrl -Project $GitProjectName -Repository $GitRepositoryName -Source $SourceBranch -Target $TargetBranch
if($($Response.errors) -And $($Response.errors.length) -eq 1){
	if($($Response.errors[0].message) -match "is already up-to-date with branch"){
		Write-Host $($Response.errors[0].message)
		exit 0
	} elseif($($Response.errors[0].message) -match "Only one pull request may be open for a given source and target branch") {
		Write-Host $($Response.errors[0].message)
		$PullRequestId = $($Response.errors[0].existingPullRequest.id)
		$PullRequestVersion = $($Response.errors[0].existingPullRequest.version)
		$PullRequestTitle = $($Response.errors[0].existingPullRequest.title)
	}
} elseif ($($Response.errors) -And $($Response.errors.length) -gt 1) {
	Write-Host ($Response| ConvertTo-Json)
	throw "Something went wrong"
	exit 1
} else {
	Write-Host "Pull request created"
	$PullRequestId = $($Response.id)
	$PullRequestVersion = $($Response.version)
	$PullRequestTitle = $Response.title
}
