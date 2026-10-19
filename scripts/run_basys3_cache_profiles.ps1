param([string]$ToolchainBin)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$vivadoBin = 'D:\2026.1\Vivado\bin'
$rtlRoot = Join-Path $projectRoot 'rtl_independent'
$buildRoot = Join-Path $projectRoot 'build\basys3_cache_profiles'
$evidenceRoot = Join-Path $projectRoot 'deliverables\verification_evidence\basys3_cache_profiles'
$runnerTb = Join-Path $rtlRoot 'basys3_cache_metrics_tb.sv'
$compiler = Join-Path $projectRoot 'c_toolchain\compile.py'
$workloads = @(
    @{ Name='reuse4'; Source='c_toolchain\basys3_cache_reuse.c'; Expected=416; WorkingSet=4 },
    @{ Name='stream32'; Source='c_toolchain\basys3_cache_stream.c'; Expected=1056; WorkingSet=32 }
)
$variants = @(
    @{ Name='bypass_immediate'; Enable=0; Lines=16; Victim=0; Wait=0 },
    @{ Name='bypass_equal_wait4'; Enable=0; Lines=16; Victim=0; Wait=4 },
    @{ Name='cache4'; Enable=1; Lines=4; Victim=0; Wait=0 },
    @{ Name='cache16'; Enable=1; Lines=16; Victim=0; Wait=0 },
    @{ Name='cache32'; Enable=1; Lines=32; Victim=0; Wait=0 },
    @{ Name='cache16_victim'; Enable=1; Lines=16; Victim=1; Wait=0 }
)

foreach ($tool in @('xvlog.bat','xelab.bat','xsim.bat')) {
    if (-not (Test-Path -LiteralPath (Join-Path $vivadoBin $tool))) { throw "Vivado simulator not found: $tool" }
}
if ($ToolchainBin) { $ToolchainBin = (Resolve-Path -LiteralPath $ToolchainBin).Path }
New-Item -ItemType Directory -Force -Path $buildRoot, $evidenceRoot | Out-Null
$results = Join-Path $buildRoot 'basys3_wrapper_profiles.csv'
'workload,working_set_words,configuration,cache_lines,victim,backing_wait_cycles,cycles,loads,stores,hits,misses,stall_cycles,expected_result,status' |
    Set-Content -LiteralPath $results -Encoding ascii
$rtlFiles = Get-ChildItem -LiteralPath $rtlRoot -Filter '*.sv' |
    Where-Object { $_.Name -notin @('basys3_top_tb.sv','basys3_c_selfcheck_tb.sv',
        'basys3_cache_metrics_tb.sv','cache_c_study_tb.sv','cache_overlap_tb.sv',
        'act4_tb.sv','alu_signed_smoke_tb.sv','c_program_tb.sv') } |
    Select-Object -ExpandProperty FullName

foreach ($workload in $workloads) {
    $imageDir = Join-Path $buildRoot "$($workload.Name)_image"
    New-Item -ItemType Directory -Force -Path $imageDir | Out-Null
    $compilerArgs = @($compiler, (Join-Path $projectRoot $workload.Source), '--output-dir', $imageDir)
    if ($ToolchainBin) { $compilerArgs += @('--toolchain-bin', $ToolchainBin) }
    & python @compilerArgs *> (Join-Path $imageDir 'compiler.log')
    if ($LASTEXITCODE -ne 0) { throw "C compilation failed for $($workload.Name); see $imageDir\compiler.log" }

    foreach ($variant in $variants) {
        $caseName = "$($workload.Name)_$($variant.Name)"
        $caseDir = Join-Path $buildRoot $caseName
        New-Item -ItemType Directory -Force -Path $caseDir | Out-Null
        Copy-Item -LiteralPath (Join-Path $imageDir 'instructions.mem'),
            (Join-Path $imageDir 'data_mem.mem'), (Join-Path $imageDir 'reg_init.mem') -Destination $caseDir -Force
        @(
            ('`define BC_CACHE_ENABLE ' + $variant.Enable)
            ('`define BC_CACHE_LINES ' + $variant.Lines)
            ('`define BC_VICTIM_ENABLE ' + $variant.Victim)
            ('`define BC_BYPASS_WAIT ' + $variant.Wait)
            ('`define BC_EXPECTED_RESULT ' + $workload.Expected)
            ('`define BC_PROFILE_NAME "' + $caseName + '"')
        ) | Set-Content -LiteralPath (Join-Path $caseDir 'basys3_cache_metrics_config.svh') -Encoding ascii
        $localTb = Join-Path $caseDir 'basys3_cache_metrics_tb.sv'
        $tbText = Get-Content -LiteralPath $runnerTb -Raw
        $tbText = $tbText.Replace('`timescale 1ns/1ps', '`timescale 1ns/1ps' + "`r`n" + '`include "basys3_cache_metrics_config.svh"')
        Set-Content -LiteralPath $localTb -Value $tbText -Encoding ascii

        Push-Location $caseDir
        try {
            & (Join-Path $vivadoBin 'xvlog.bat') -sv @rtlFiles $localTb *> compile.log
            if ($LASTEXITCODE -ne 0) { throw "$caseName compile failed; see $caseDir\compile.log" }
            & (Join-Path $vivadoBin 'xelab.bat') basys3_cache_metrics_tb -s $caseName -debug typical *> elaborate.log
            if ($LASTEXITCODE -ne 0) { throw "$caseName elaboration failed; see $caseDir\elaborate.log" }
            & (Join-Path $vivadoBin 'xsim.bat') $caseName -testplusarg LOAD_INST_MEM -testplusarg LOAD_DATA_MEM -testplusarg LOAD_REG_INIT -runall *> console.log
            if ($LASTEXITCODE -ne 0) { throw "$caseName simulation failed; see $caseDir\console.log" }
            $simLog = Get-Content -LiteralPath (Join-Path $caseDir 'xsim.log') -Raw
            if ($simLog -match '\bFatal:' -or $simLog -notmatch 'BASYS3_CACHE_PROFILE_PASS') {
                throw "$caseName did not pass board-wrapper checks; see $caseDir\xsim.log"
            }
            $m = [regex]::Match($simLog, 'BASYS3_CACHE_PROFILE_PASS,([^\r\n]+)')
            $f = $m.Groups[1].Value.Split(',')
            if ($f.Count -ne 11) { throw "$caseName returned malformed metrics" }
            "{0},{1},{2},{3},{4},{5},{6},{7},{8},{9},{10},{11},{12},PASS" -f `
                $workload.Name,$workload.WorkingSet,$variant.Name,$variant.Lines,$variant.Victim,
                $variant.Wait,$f[4],$f[5],$f[6],$f[7],$f[8],$f[9],$workload.Expected |
                Add-Content -LiteralPath $results -Encoding ascii
            Copy-Item -LiteralPath (Join-Path $caseDir 'xsim.log') -Destination (Join-Path $caseDir 'profile.log') -Force
            Copy-Item -LiteralPath (Join-Path $caseDir 'xsim.log') -Destination (Join-Path $evidenceRoot "$caseName.log") -Force
            Write-Host "PASS ${caseName}: cycles=$($f[4]), loads=$($f[5]), hits=$($f[7]), misses=$($f[8]), stalls=$($f[9])"
        } finally { Pop-Location }
    }
}
Copy-Item -LiteralPath $results -Destination (Join-Path $evidenceRoot 'basys3_wrapper_profiles.csv') -Force
Write-Host "Basys 3 wrapper profile simulations complete (not physical-board measurements): $results"
