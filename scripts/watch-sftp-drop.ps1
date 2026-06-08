# Optional FileSystemWatcher: runs local-sftp-upload-to-s3.ps1 when files appear in the drop folder.
param(
    [string]$EnvFile
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "Get-S3UploadTarget.ps1")
$cfg = Get-S3UploadTarget -EnvFile $EnvFile

if (-not (Test-Path $cfg.DropPath)) {
    New-Item -ItemType Directory -Path $cfg.DropPath -Force | Out-Null
}

$bridge = Join-Path $PSScriptRoot "local-sftp-upload-to-s3.ps1"
$debounceSeconds = 2
$lastRun = [datetime]::MinValue

function Invoke-BridgeDebounced {
    $now = Get-Date
    if (($now - $lastRun).TotalSeconds -lt $debounceSeconds) { return }
    $script:lastRun = $now
    Start-Sleep -Seconds $debounceSeconds
    & $bridge -EnvFile $EnvFile -WaitForStableSize
}

Write-Host "Watching $($cfg.DropPath) — Ctrl+C to stop."
$watcher = New-Object System.IO.FileSystemWatcher $cfg.DropPath
$watcher.IncludeSubdirectories = $false
$watcher.EnableRaisingEvents = $true

Register-ObjectEvent -InputObject $watcher -EventName Created -Action { Invoke-BridgeDebounced } | Out-Null
Register-ObjectEvent -InputObject $watcher -EventName Changed -Action { Invoke-BridgeDebounced } | Out-Null
Register-ObjectEvent -InputObject $watcher -EventName Renamed -Action { Invoke-BridgeDebounced } | Out-Null

try {
    while ($true) { Start-Sleep -Seconds 1 }
} finally {
    $watcher.EnableRaisingEvents = $false
    $watcher.Dispose()
}
