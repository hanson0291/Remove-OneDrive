[CmdletBinding()]
param(
    [switch]$PostReboot,
    [switch]$Reboot,
    [switch]$BlockReinstall,
    [string]$UserProfilePath
)
$ErrorActionPreference = 'Stop'
$TaskName = 'OneDrivePostUninstallCleanup'
function Write-Step {
    param([string]$Message)
    Write-Host "[*] $Message" -ForegroundColor Cyan
}
function Assert-Admin {
    $current = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($current)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'Run this script from an elevated PowerShell window (Run as Administrator).'
    }
}
function Remove-PathIfExists {
    param([string]$Path)
    if (Test-Path -LiteralPath $Path) {
        Write-Step "Removing $Path"
        Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue
    }
}
if (-not $UserProfilePath) {
    $UserProfilePath = $env:USERPROFILE
}
if ($PostReboot) {
    Assert-Admin
    Write-Step 'Running post-reboot OneDrive cleanup'
    Remove-PathIfExists -Path (Join-Path $UserProfilePath 'OneDrive')
    Remove-PathIfExists -Path (Join-Path $UserProfilePath 'AppData\Local\Microsoft\OneDrive')
    Remove-PathIfExists -Path "$env:ProgramData\Microsoft OneDrive"
    Write-Step 'Removing scheduled startup task'
    schtasks /Delete /TN $TaskName /F | Out-Null
    Write-Host 'OneDrive post-reboot cleanup completed.' -ForegroundColor Green
    exit 0
}
Assert-Admin
Write-Step 'Stopping OneDrive process'
Get-Process -Name OneDrive -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
$setupPaths = @(
    "$env:SystemRoot\System32\OneDriveSetup.exe",
    "$env:SystemRoot\SysWOW64\OneDriveSetup.exe"
) | Select-Object -Unique
foreach ($setup in $setupPaths) {
    if (Test-Path -LiteralPath $setup) {
        Write-Step "Running uninstall: $setup /uninstall"
        Start-Process -FilePath $setup -ArgumentList '/uninstall' -Wait -NoNewWindow
    }
}
if ($BlockReinstall) {
    $policyPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive'
    Write-Step 'Setting policy to block OneDrive reinstall'
    New-Item -Path $policyPath -Force | Out-Null
    New-ItemProperty -Path $policyPath -Name DisableFileSyncNGSC -Value 1 -PropertyType DWord -Force | Out-Null
}
$scriptPath = $MyInvocation.MyCommand.Path
if (-not $scriptPath) {
    throw 'Unable to determine script path. Save and run this script from a .ps1 file.'
}
$taskCommand = "PowerShell.exe -NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" -PostReboot -UserProfilePath `"$UserProfilePath`""
Write-Step 'Creating startup task for post-reboot cleanup'
schtasks /Create /TN $TaskName /SC ONSTART /RU SYSTEM /RL HIGHEST /TR $taskCommand /F | Out-Null
Write-Host 'Uninstall step is complete. Post-reboot cleanup has been scheduled.' -ForegroundColor Green
if ($Reboot) {
    Write-Step 'Rebooting now'
    Restart-Computer -Force
}
$answer = Read-Host 'Reboot now to finish cleanup? (Y/N)'
if ($answer -match '^(y|yes)$') {
    Restart-Computer -Force
}
Write-Host 'No reboot triggered. Reboot later to run cleanup automatically.' -ForegroundColor Yellow
