param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('reuse4','stream32')]
    [string]$Workload,
    [switch]$InstallIntoVivadoProject
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$imageDir = Join-Path $projectRoot "build\basys3_cache_profiles\${Workload}_image"
$vivadoMemDir = Join-Path $projectRoot 'vivado\RV32IM_Basys3'
$expected = if ($Workload -eq 'reuse4') { 416 } else { 1056 }

foreach ($name in @('instructions.mem','data_mem.mem')) {
    if (-not (Test-Path -LiteralPath (Join-Path $imageDir $name))) {
        throw "Missing generated $name in $imageDir. Run scripts\run_basys3_cache_profiles.ps1 first."
    }
}
Write-Host "Prepared workload: $Workload; expected result stored at data RAM word 64 = $expected."
Write-Host "Image folder: $imageDir"
if (-not $InstallIntoVivadoProject) {
    Write-Host 'No Vivado project files changed. Re-run with -InstallIntoVivadoProject to back up and stage these images.'
    exit 0
}

$backupRoot = Join-Path $projectRoot 'build\basys3_cache_profiles\vivado_image_backups'
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$backupDir = Join-Path $backupRoot $stamp
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
foreach ($name in @('instructions.mem','data_mem.mem')) {
    $target = Join-Path $vivadoMemDir $name
    if (Test-Path -LiteralPath $target) {
        Copy-Item -LiteralPath $target -Destination (Join-Path $backupDir $name)
    }
    Copy-Item -LiteralPath (Join-Path $imageDir $name) -Destination $target -Force
}
$manifest = [ordered]@{
    workload = $Workload
    expected_result_ram_word_64 = $expected
    installed_at = (Get-Date).ToString('o')
    image_source = $imageDir
    vivado_memory_folder = $vivadoMemDir
    backup_folder = $backupDir
}
$manifest | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $backupDir 'manifest.json') -Encoding utf8
Write-Host "Staged safely. Previous images are backed up at: $backupDir"
Write-Host 'Close and reopen the Vivado project if it was open while the files changed. Then select the matching basys3_*_top, reset Synthesis, and rebuild.'
