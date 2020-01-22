#$COMMVAULT_CVD =  (Get-Process -Name cvd).Id
#$COMMVAULT_CVFWD = (Get-Process -Name cvfwd).Id

#if ($COMMVAULT_CVD -ne $null -or $COMMVAULT_CVFWD -ne $null){
#Write-Output "Commvault is already installed & Running!"
#exit 00
#}

##Code Added For Taking Blob Url & Auth Code as arguments
$WindowsBlobUrl=$args[0]
$AutoMoxAuthCode=$args[1]
if ($WindowsBlobUrl -eq $null -or $AutoMoxAuthCode -eq $null){
Write-Host "Looks Like Script Does not have Required Arguments Please check Agent Blob or AuthCode if specified" -ForegroundColor Red
exit 12345} else {
write-host "Installing Commvault Agent through blob $WindowsBlob & authcode $CommvaultAuthCode" -ForegroundColor Green
Invoke-WebRequest -Uri $WindowsBlobUrl -OutFile C:/Windows/AutomoxInstaller.msi ; C:/Windows/AutomoxInstaller.msi ACCESSKEY=$AutoMoxAuthCode
}

