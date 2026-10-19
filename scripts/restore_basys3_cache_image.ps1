param([Parameter(Mandatory=$true)][string]$BackupPath)
$ErrorActionPreference = 'Stop'
$backup = (Resolve-Path -LiteralPath $BackupPath).Path
$manifestPath = Join-Path $backup 'manifest.json'
if (-not (Test-Path -LiteralPath $manifestPath)) { throw "No manifest.json found in $backup" }
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$targetDir = [System.IO.Path]::GetFullPath([string]$manifest.vivado_memory_folder)
foreach ($name in @('instructions.mem','data_mem.mem')) {
    $saved = Join-Path $backup $name
    if (-not (Test-Path -LiteralPath $saved)) { throw "Backup is incomplete: $saved" }
    Copy-Item -LiteralPath $saved -Destination (Join-Path $targetDir $name) -Force
}
Write-Host "Restored the memory images from $backup to $targetDir"
Write-Host 'Close and reopen Vivado (if open) before rebuilding.'
