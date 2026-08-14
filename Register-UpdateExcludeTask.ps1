param(
    [string]$TaskName = "Update FreeFileSync Exclude Filter",
    [string]$RunAt = "08:00"
)

$ErrorActionPreference = "Stop"

$workspace = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
$scriptPath = Join-Path -Path $workspace -ChildPath "Update-FreeFileSyncExclude.ps1"

if (-not (Test-Path -LiteralPath $scriptPath)) {
    throw "Cannot find script: $scriptPath"
}

$action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`"" `
    -WorkingDirectory $workspace

$trigger = New-ScheduledTaskTrigger -Daily -At $RunAt

Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $action `
    -Trigger $trigger `
    -Description "Update SyncSettings.ffs_batch exclude filter every day at $RunAt." `
    -Force | Out-Null

Write-Host "Registered scheduled task: $TaskName"
Write-Host "Script: $scriptPath"
Write-Host "Working directory: $workspace"
Write-Host "Run at: $RunAt"
