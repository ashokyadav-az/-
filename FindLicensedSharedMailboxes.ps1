<#
=============================================================================================
Name:           Find shared mailboces with licenses in Office 365
Description:    This script exports licensed shared mailboxes
Website:        o365reports.com

Script Highlights: 
~~~~~~~~~~~~~~~~~
1. The script uses modern authentication to connect to Exchange Online.    
2. The script can be executed with MFA enabled account too.    
3.Exports report results to CSV file.    
4. Automatically installs the EXO V2 (if not installed already) upon your confirmation.   
5. The script is scheduler-friendly. I.e., Credential can be passed as a parameter instead of saving inside the script. 

For detailed Script execution: https://o365reports.com/2022/01/19/find-shared-mailboxes-with-license-using-powershell
============================================================================================
#>
Param
(
    [Parameter(Mandatory = $false)]
    [switch]$NoMFA,
    [string]$UserName,
    [string]$Password
)

Function Connect_Modules
{
 #Check for EXO v2 module inatallation
 $Module = Get-Module ExchangeOnlineManagement -ListAvailable
 if($Module.count -eq 0) 
 { 
  Write-Host Exchange Online PowerShell V2 module is not available  -ForegroundColor yellow  
  $Confirm= Read-Host Are you sure you want to install module? [Y] Yes [N] No 
  if($Confirm -match "[yY]") 
  { 
   Write-host "Installing Exchange Online PowerShell module"
   Install-Module ExchangeOnlineManagement -Repository PSGallery -AllowClobber -Force
   Import-Module ExchangeOnlineManagement
  } 
  else 
  { 
   Write-Host EXO V2 module is required to connect Exchange Online.Please install module using Install-Module ExchangeOnlineManagement cmdlet. 
   Exit
  }
 } 
 #Check for Azure AD module
 $Module = Get-Module MsOnline -ListAvailable
 if($Module.count -eq 0) 
 { 
  Write-Host MSOnline module is not available  -ForegroundColor yellow  
  $Confirm= Read-Host Are you sure you want to install the module? [Y] Yes [N] No 
  if($Confirm -match "[yY]") 
  { 
   Write-host "Installing MSOnline PowerShell module"
   Install-Module MSOnline -Repository PSGallery -AllowClobber -Force
   Import-Module MSOnline
  } 
  else 
  { 
   Write-Host MSOnline module is required to generate the report.Please install module using Install-Module MSOnline cmdlet. 
   Exit
  }
 }

 #Authentication using non-MFA
 if($NoMFA.IsPresent)
 {
  #Storing credential in script for scheduling purpose/ Passing credential as parameter
  if(($UserName -ne "") -and ($Password -ne ""))
  { 
   $SecuredPassword = ConvertTo-SecureString -AsPlainText $Password -Force
   $Credential  = New-Object System.Management.Automation.PSCredential $UserName,$SecuredPassword
  }
  else
  {
   $Credential=Get-Credential -Credential $null
  }
  Write-Host "Connecting Azure AD..."
  Connect-MsolService -Credential $Credential | Out-Null
  Write-Host "Connecting Exchange Online PowerShell..."
  Connect-ExchangeOnline -Credential $Credential
 }
 #Connect to Exchange Online and AzureAD module using MFA 
 else
 {
  Write-Host "Connecting Exchange Online PowerShell..."
  Connect-ExchangeOnline
  Write-Host "Connecting Azure AD..."
  Connect-MsolService | Out-Null
 }
}
Connect_Modules
$ExportCSV=".\LicensedSharedMailboxesReport_$((Get-Date -format yyyy-MMM-dd-ddd` hh-mm` tt).ToString()).csv" 
$Result="" 
$Results=@() 
$Count=0

#Get all licensed shared mailboxes
Get-Mailbox -ResultSize Unlimited -RecipientTypeDetails sharedmailbox | where {$_.SkuAssigned -eq $true} | foreach {
 $Count++
 $Name= $_.DisplayName
 Write-Progress -Activity "Found $Count licensed shared mailboxes" "Currently processing shared mailbox: $Name" 
 $UPN=$_.UserPrincipalName
 $LitigationHoldEnabled=$_.LitigationHoldEnabled
 if($_.InPlaceHolds -ne $Empty)
 {
  $InPlaceHoldEnabled="True"
 }
 else
 {
  $InPlaceHoldEnabled="False"
 }
 $MailboxItemSize=(Get-MailboxStatistics -Identity $_.UserPrincipalName).TotalItemSize.Value
 $MailboxItemSize=$MailboxItemSize.ToString().split("()")
 $MBSize=$MailboxItemSize | Select-Object -Index 0
 $MBSizeInBytes=$MailboxItemSize | Select-Object -Index 1
 $AssignedLicenses=@()
 $Licenses=(Get-MsolUser -UserPrincipalName $UPN).licenses.accountSkuId
 foreach($License in $Licenses)
 {
  $LicenseItem= $License -Split ":" | Select-Object -Last 1 
  $AssignedLicenses=$AssignedLicenses+$LicenseItem
 }
 $AssignedLicenses=$AssignedLicenses -join ","

 #Export results to CSV
 $Result = @{'Name'=$Name;'UPN'=$UPN;'Shared MB Size'=$MBSize;'MB Size (Bytes)'=$MBSizeInBytes;'Litigation Hold Enabled'=$LitigationHoldEnabled;'In-place Archive Enabled'=$InPlaceHoldEnabled ;'Assigned Licenses'=$AssignedLicenses} 
 $Results = New-Object PSObject -Property $Result 
 $Results |select-object 'Name','UPN','Shared MB Size','MB Size (Bytes)','Litigation Hold Enabled','In-place Archive Enabled','Assigned Licenses' | Export-CSV $ExportCSV  -NoTypeInformation -Append
}

#Open output file after execution
If($Count -eq 0)
{
 
 Write-Host No shared mailbox found with license
}
else
{
 Write-Host `nThe output file contains $Count licensed shared mailboxes.
 if((Test-Path -Path $ExportCSV) -eq "True") 
 {
  Write-Host `n" The Output file availble in:" -NoNewline -ForegroundColor Yellow; Write-Host $ExportCSV 
  Write-Host `n~~ Script prepared by AdminDroid Community ~~`n -ForegroundColor Green  
  Write-Host "~~ Check out " -NoNewline -ForegroundColor Green; Write-Host "admindroid.com" -ForegroundColor Yellow -NoNewline; 
  Write-Host " to get access to 1800+ Microsoft 365 reports. ~~" -ForegroundColor Green `n`n
  $Prompt = New-Object -ComObject wscript.shell   
  $UserInput = $Prompt.popup("Do you want to open output file?",`   
 0,"Open Output File",4)   
  If ($UserInput -eq 6)   
  {   
   Invoke-Item "$ExportCSV"   
  } 
 }
}