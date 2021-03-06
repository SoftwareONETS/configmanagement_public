$Trend_TenantID=$args[0]
$Trend_TokenID=$args[1]

$managerUrl="https://tmds-console-waf.softwareone.cloud:443/"
$env:LogPath = "$env:appdata\Trend Micro\Deep Security Agent\installer"

New-Item -path $env:LogPath -type directory
Start-Transcript -path "$env:LogPath\dsa_deploy.log" -append
Write-Host "$(Get-Date -format T) - DSA download started"

if ( [intptr]::Size -eq 8 ) { 
   $sourceUrl=-join($managerUrl, "software/agent/Windows/x86_64/") }
else {
   $sourceUrl=-join($managerUrl, "software/agent/Windows/i386/") 
   }

Write-Host "$(Get-Date -format T) - Download Deep Security Agent Package" $sourceUrl

$ACTIVATIONURL="dsm://tmds-heartbeat.softwareone.cloud:443/"
$WebClient = New-Object System.Net.WebClient

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12;
[Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}

$WebClient.DownloadFile($sourceUrl,  "$env:temp\agent.msi")

if ( (Get-Item "$env:temp\agent.msi").length -eq 0 ) {
    Write-Host "Failed to download the Deep Security Agent. Please check if the package is imported into the Deep Security Manager. "
 exit 1
}

Write-Host "$(Get-Date -format T) - Downloaded File Size:" (Get-Item "$env:temp\agent.msi").length
Write-Host "$(Get-Date -format T) - DSA install started"
Write-Host "$(Get-Date -format T) - Installer Exit Code:" (Start-Process -FilePath msiexec -ArgumentList "/i $env:temp\agent.msi /qn ADDLOCAL=ALL /l*v `"$env:LogPath\dsa_install.log`"" -Wait -PassThru).ExitCode 
Write-Host "$(Get-Date -format T) - DSA activation started"

Start-Sleep -s 50

& $Env:ProgramFiles"\Trend Micro\Deep Security Agent\dsa_control" -r
& $Env:ProgramFiles"\Trend Micro\Deep Security Agent\dsa_control" -a $ACTIVATIONURL "tenantID:$Trend_TenantID" "token:$Trend_TokenID"

Stop-Transcript
Write-Host "$(Get-Date -format T) - DSA Deployment Finished"
