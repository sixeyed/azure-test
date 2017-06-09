[CmdletBinding()]
Param(
  [switch] $SkipEngineUpgrade,
  [string] $ArtifactPath = ".",
  [string] $DockerVersion = "17.06.0-ce-rc2",
  [string] $DTRFQDN
)

#Variables
$Date = Get-Date -Format "yyyy-MM-dd HHmmss"
$DockerPath = "C:\Program Files\Docker"
$DockerDataPath = "C:\ProgramData\Docker"

function Disable-RealTimeMonitoring () {
    Set-MpPreference -DisableRealtimeMonitoring $true
}

function Install-LatestDockerEngine () {
    #Get Docker Engine from Master Builds
    if ((-not (Test-Path (Join-Path $ArtifactPath "docker.exe"))) -and (-not (Test-Path (Join-Path $ArtifactPath "dockerd.exe")))) {
        Invoke-WebRequest -Uri "https://download.docker.com/win/static/test/x86_64/docker-$DockerVersion-x86_64.zip" -OutFile (Join-Path $ArtifactPath "docker.zip")
    }

    #Get Docker Engine
    Expand-Archive -Path (Join-Path $ArtifactPath "docker.zip") -DestinationPath "$ArtifactPath" -Force

    #Replace Docker Engine
    Stop-Service docker
    Copy-Item "$ArtifactPath\docker\dockerd.exe" "$DockerPath\dockerd.exe" -Force
    Copy-Item "$ArtifactPath\docker\docker.exe" "$DockerPath\docker.exe" -Force
    Start-Service docker
}

function Disable-Firewall () {
    #Disable firewall (temporary)
    Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False

    #Ensure public profile is disabled (solves public profile not persisting issue)
    $data = netsh advfirewall show publicprofile
    $data = $data[3]
    if ($data -Match "ON"){
        Set-NetFirewallProfile -Profile Public -Enabled False
    }

}

function Enable-RemotePowershell () {
    #Enable remote powershell for remote management
    Enable-PSRemoting -Force
    Set-Item wsman:\localhost\client\trustedhosts * -Force
}

function Set-DtrHostnameEnvironmentVariable() {
    $DTRFQDN | Out-File (Join-Path $DockerDataPath "dtr_fqdn")
}

#Start Script
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

try
{
    Start-Transcript -path "C:\ProgramData\Docker\configure-worker $Date.log" -append

    Write-Host "Disabling Real Time Monitoring"
    Disable-RealTimeMonitoring
    
    if (-not ($SkipEngineUpgrade.IsPresent)) {
        Write-Host "Upgrading Docker Engine"
        Install-LatestDockerEngine
    }

    Write-Host "Disabling Firewall"
    Disable-Firewall

    Write-Host "Enabling Remote Powershell"
    Enable-RemotePowershell

    Write-Host "Set DTR FQDN Environment Variable"
    Set-DtrHostnameEnvironmentVariable

    Write-Host "Restarting machine"
    Stop-Transcript
}
catch
{
    Write-Error $_
}