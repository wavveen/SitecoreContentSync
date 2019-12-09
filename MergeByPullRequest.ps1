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

#Check if a pull request is necessary. Only need to do this for the Azure DevOps platform as it will create a PR eventhoug branches are up-to-date
#already, and there is no way to delete or abandon a PR via the rest api after it's created.
#The BitBucket platform prevents from creating a PR for branches which are up-to-date already.
if($GitPlatform -eq "AzureDevOps") {
	Write-Host ("##vso[task.setvariable variable=IsAutoMergeable;]unknown")
	$AlreadyUpToDate = AlreadyUpToDate -Token $RestApiToken -BaseUrl $RestApiBaseUrl -Project $GitProjectName -Repository $GitRepositoryName -Source $SourceBranch.replace("refs/heads/","") -Target $TargetBranch.replace("refs/heads/","")
	if($AlreadyUpToDate){
		Write-Host "Branch '$TargetBranch' is already up-to-date with branch '$SourceBranch' in repository '$GitRepositoryName'. No need for a pull request"
		exit 0
	}
}

#Create pull request
Write-Host "Going to create a pull request to merge $SourceBranch into $TargetBranch"
$Response = CreatePullRequest -Token $RestApiToken -BaseUrl $RestApiBaseUrl -Project $GitProjectName -Repository $GitRepositoryName -Source $SourceBranch -Target $TargetBranch
#Cancel script execution if target is up-to-date already
if($Response -eq "already up-to-date"){
	exit 0
}
Write-Host "Pull request created"
Write-Host "PullRequestId: $($Response.id)"
Write-Host "PullRequestVersion: $($Response.version)"
Write-Host "PullRequestTitle: $($Response.title)"

#Check if the pull request can be auto merged
Write-Host "Check if pull request ($($Response.id)) is auto merge-able"
$CanMergePR = CanMergePullRequest -Token $RestApiToken -BaseUrl $RestApiBaseUrl -Project $GitProjectName -Repository $GitRepositoryName -PullRequestId $($Response.id)
if(!$CanMergePR){
	if($GitPlatform -eq "AzureDevOps") {
		SetReleaseVariable -VariableName "IsAutoMergeable" -VariableValue "no"
	}
	Write-Host "Pull request ($($Response.id)) is NOT auto merge-able, manual action required"
	Write-Host ""
	Write-Host "################################################################"
	Write-Host "#"
	Write-Host "# Something went wrong while auto merging the PR"
	Write-Host "#"
	Write-Host "# 1 Check if the PR is still present in the online interface of the GIT platform"
	Write-Host "# 2 Delete/Abandon the PR"
	Write-Host "# 3 On your local, check out the $TargetBranch branch and pull the latest"
	Write-Host "# 4 On your local, check out the $SourceBranch branch and pull the latest"
	Write-Host "# 5 Merge $TargetBranch into $SourceBranch"
	Write-Host "# 6 Resolve the merge conflicts"
    Write-Host "# 7 Commit and push the merge"
	Write-Host "#"
    Write-Host "# After that is all done, the deploy can continue"
	Write-Host "#"	
	Write-Host "################################################################"
	throw "Trigger exception to stop script execution"
	exit 1
}
SetReleaseVariable -VariableName "IsAutoMergeable" -VariableValue "yes"



