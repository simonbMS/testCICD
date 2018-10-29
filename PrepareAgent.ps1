param(
    [string] $vstsAccount,
    [string] $personalAccessToken,
    [string] $poolName,
    $agentName
    )
    

$logDir = "C:\VSTSAgent\Logs\"
$agentTempFolderName = "C:\temp\"
$agentInstallationPath = "C:\VSTSAgent\"

####Create folders
if(!(Test-Path $logDir -PathType Container)){ md $logDir}
if(!(Test-Path $agentTempFolderName -PathType Container)){ md $agentTempFolderName}
if(!(Test-Path $agentInstallationPath -PathType Container)){ md $agentInstallationPath}
if(!(Test-Path "$agentInstallationPath\_work" -PathType Container)){ md "$agentInstallationPath\_work"}
#######


$dateTime = (Get-Date).ToString('yyyy-MM-dd-HHmm')
$logPath = "$($logDir)InstallAgent$($dateTime).txt"

# Log step and output verbose
Function Write-logAndVerbose {
    Param (
        [parameter(Mandatory = $true)] [string] $message
    )
    Write-Verbose $message -Verbose
    "$(Get-Date -Format "yyyy-MM-dd HH:mm:ss"),$message" | Out-File -FilePath $logPath -Append
}

$serverUrl = "https://$vstsAccount.visualstudio.com"
Write-logAndVerbose "`tServer URL: $serverUrl"

$retryCount = 3
$retries = 1
Write-logAndVerbose "`tDownloading Agent install files"
do {
    try {
        Write-logAndVerbose "`tTrying to get download URL for latest VSTS agent release..."
        $user = ''
        $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $user, $personalAccessToken)))
        $uri = "https://$($vstsAccount).visualstudio.com/_apis/distributedtask/packages/agent?%24top=1"
        $latestRelease = Invoke-RestMethod -Uri $uri -Method Get -ContentType "application/json" -Headers @{Authorization = ("Basic {0}" -f $base64AuthInfo)}
        $downloadUrl = $($latestRelease.value | Where-Object {$_.platform -eq 'win-x64'}).downloadUrl

        Invoke-WebRequest -Uri $downloadUrl -Method Get -OutFile "$agentTempFolderName\agent.zip"
        Write-logAndVerbose "`tDownloaded agent successfully on attempt $retries"
        break
    }
    catch {
        $exceptionText = ($_ | Out-String).Trim()
        Write-logAndVerbose "`tException occurred downloading agent: $exceptionText in try number $retries"
        $retries++
        Start-Sleep -Seconds 30 
    }
} 
while ($retries -le $retryCount)

Write-logAndVerbose "`tExtracting Agent"
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::ExtractToDirectory("$agentTempFolderName\agent.zip", $agentInstallationPath)
Write-logAndVerbose "`tAgent extracted, configuring..."
cd $agentInstallationPath

.\config.cmd --unattended --url $serverUrl --auth PAT --token $personalAccessToken --pool $poolName --agent $agentName --runasservice --work _work --replace

Write-logAndVerbose "`tConfiguration complete. Installing Azure Module"
install-module "AzureRM" -Force