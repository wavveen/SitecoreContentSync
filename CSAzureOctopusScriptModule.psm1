function GetKuduConnectionDetailsFromAzurePublishProfile
{
	Param(
		[parameter(Mandatory=$True)]
		[String]$AzureResourceGroupName,
		[parameter(Mandatory=$True)]
		[String]$AzureWebAppName,
		[parameter(Mandatory=$False)]
		[String]$AzureWebAppSlot
	)
	
	Get-Module azure* -ListAvailable

	#Get-AzureRmContext is available when this script is running in a Azure Powershell step template context
	$SubscriptionId = (Get-AzureRmContext).Subscription.SubscriptionId

	if([string]::IsNullOrEmpty($WebAppSlot)){
		[xml]$PublishProfile = Get-AzureRmWebAppPublishingProfile -ResourceGroupName $AzureResourceGroupName -Name $AzureWebAppName -OutputFile none
	}else{
		[xml]$PublishProfile = Get-AzureRmWebAppSlotPublishingProfile -ResourceGroupName $AzureResourceGroupName -Name $AzureWebAppName -Slot $AzureWebAppSlot -OutputFile none
	}
	
	Write-Output "Retrieved PublishProfile: $($PublishProfile.publishData.FirstChild.profileName)"
	
	$KuduCredentials = New-Object -TypeName psobject
	$KuduCredentials | Add-Member -MemberType NoteProperty -Name Username -Value "$($PublishProfile.publishData.FirstChild.userName)"
	$KuduCredentials | Add-Member -MemberType NoteProperty -Name Password -Value '$($PublishProfile.publishData.FirstChild.userPWD)'
	$KuduCredentials | Add-Member -MemberType NoteProperty -Name Hostname -Value '$($PublishProfile.publishData.FirstChild.publishUrl)'

	return $KuduCredentials
}