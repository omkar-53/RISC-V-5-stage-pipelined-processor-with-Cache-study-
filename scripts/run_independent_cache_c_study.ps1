param([string]$ToolchainBin)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$vivadoBin = 'D:\2026.1\Vivado\bin'
$rtlRoot = Join-Path $projectRoot 'rtl_independent'
$buildRoot = Join-Path $projectRoot 'build\independent_cache_c_study'
$runnerTb = Join-Path $rtlRoot 'cache_c_study_tb.sv'
$compiler = Join-Path $projectRoot 'c_toolchain\compile.py'
$workloads = @(
    @{ Name='reuse4'; Source='c_toolchain\cache_reuse.c'; Expected=416; WorkingSet=4 },
    @{ Name='stream32'; Source='c_toolchain\cache_stream.c'; Expected=1056; WorkingSet=32 }
)
$variants = @(
    @{ Name='bypass_immediate'; Enable=0; Lines=16; Victim=0; Wait=0; Miss=3 }
)
# Main capacity/victim comparison at the current four-edge miss model.
$variants += @(
    @{ Name='bypass_equal_wait_4'; Enable=0; Lines=16; Victim=0; Wait=4; Miss=3 },
    @{ Name='cache4_wait4'; Enable=1; Lines=4; Victim=0; Wait=0; Miss=3 },
    @{ Name='cache16_wait4'; Enable=1; Lines=16; Victim=0; Wait=0; Miss=3 },
    @{ Name='cache32_wait4'; Enable=1; Lines=32; Victim=0; Wait=0; Miss=3 },
    @{ Name='cache16_victim_wait4'; Enable=1; Lines=16; Victim=1; Wait=0; Miss=3 }
)
# Latency sensitivity: compare bypass and cache on the same per-load wait.
# Cache MISS_PENALTY contributes that many extra edges after the request edge.
foreach ($wait in @(3, 5, 10, 20)) {
    $variants += @(
        @{ Name="bypass_equal_wait_$wait"; Enable=0; Lines=16; Victim=0; Wait=$wait; Miss=($wait - 1) },
        @{ Name="cache16_wait$wait"; Enable=1; Lines=16; Victim=0; Wait=0; Miss=($wait - 1) },
        @{ Name="cache16_victim_wait$wait"; Enable=1; Lines=16; Victim=1; Wait=0; Miss=($wait - 1) }
    )
}

foreach ($tool in @('xvlog.bat','xelab.bat','xsim.bat')) {
    if (-not (Test-Path -LiteralPath (Join-Path $vivadoBin $tool))) { throw "Vivado simulator not found: $tool" }
}
if ($ToolchainBin) { $ToolchainBin = (Resolve-Path -LiteralPath $ToolchainBin).Path }
New-Item -ItemType Directory -Force -Path $buildRoot | Out-Null
$results = Join-Path $buildRoot 'results.csv'
'workload,working_set_words,configuration,cache_lines,victim,equal_load_wait_edges,program_cycles,loads,stores,hits,misses,wait_edges,load_use_stalls,expected_result,full_state_match,status' |
    Set-Content -LiteralPath $results -Encoding ascii
$rtlFiles = Get-ChildItem -LiteralPath $rtlRoot -Filter '*.sv' |
    Where-Object { $_.Name -notin @('cache_c_study_tb.sv','cache_overlap_tb.sv','act4_tb.sv','alu_signed_smoke_tb.sv') } |
    Select-Object -ExpandProperty FullName

foreach ($workload in $workloads) {
    $imageDir = Join-Path $buildRoot "$($workload.Name)_image"
    New-Item -ItemType Directory -Force -Path $imageDir | Out-Null
    $compilerArgs = @($compiler, (Join-Path $projectRoot $workload.Source), '--output-dir', $imageDir)
    if ($ToolchainBin) { $compilerArgs += @('--toolchain-bin', $ToolchainBin) }
    & python @compilerArgs *> (Join-Path $imageDir 'compiler.log')
    if ($LASTEXITCODE -ne 0) { throw "C compilation failed for $($workload.Name); see $imageDir\compiler.log" }

    $referenceState = $null
    foreach ($variant in $variants) {
        $caseName = "$($workload.Name)_$($variant.Name)"
        $caseDir = Join-Path $buildRoot $caseName
        New-Item -ItemType Directory -Force -Path $caseDir | Out-Null
        Copy-Item -LiteralPath (Join-Path $imageDir 'instructions.mem'),
            (Join-Path $imageDir 'data_mem.mem'), (Join-Path $imageDir 'reg_init.mem') -Destination $caseDir -Force
        @(
            ('`define C_CACHE_ENABLE ' + $variant.Enable)
            ('`define C_CACHE_LINES ' + $variant.Lines)
            ('`define C_CACHE_VICTIM_ENABLE ' + $variant.Victim)
            ('`define C_BYPASS_WAIT ' + $variant.Wait)
            ('`define C_MISS_PENALTY ' + $variant.Miss)
            ('`define C_EXPECTED_RESULT ' + $workload.Expected)
            ('`define C_WORKING_SET_WORDS ' + $workload.WorkingSet)
        ) | Set-Content -LiteralPath (Join-Path $caseDir 'cache_c_config.svh') -Encoding ascii

        Push-Location $caseDir
        try {
            & (Join-Path $vivadoBin 'xvlog.bat') -sv @rtlFiles $runnerTb *> compile.log
            if ($LASTEXITCODE -ne 0) { throw "$caseName compile failed; see $caseDir\compile.log" }
            & (Join-Path $vivadoBin 'xelab.bat') cache_c_study_tb -s $caseName -debug typical *> elaborate.log
            if ($LASTEXITCODE -ne 0) { throw "$caseName elaboration failed; see $caseDir\elaborate.log" }
            & (Join-Path $vivadoBin 'xsim.bat') $caseName -testplusarg LOAD_INST_MEM -testplusarg LOAD_DATA_MEM -testplusarg LOAD_REG_INIT -runall *> console.log
            if ($LASTEXITCODE -ne 0) { throw "$caseName simulation failed; see $caseDir\console.log" }
            $simLog = Get-Content -LiteralPath (Join-Path $caseDir 'xsim.log') -Raw
            if ($simLog -notmatch 'CACHE_C_PASS' -or
                ($variant.Enable -or $variant.Wait -gt 0) -and $simLog -notmatch 'CACHE_C_SERIALIZATION_PASS,max_outstanding=1' -or
                $simLog -match '\bFatal:') { throw "$caseName missing pass/serialization marker; see $caseDir\xsim.log" }
            $resultMatch = [regex]::Match($simLog, 'CACHE_C_RESULT,([^\r\n]+)')
            if (-not $resultMatch.Success) { throw "$caseName missing result metrics" }
            $statePath = Join-Path $caseDir 'final_state.txt'
            if (-not (Test-Path -LiteralPath $statePath)) { throw "$caseName did not write full architectural state" }
            $state = Get-Content -LiteralPath $statePath -Raw
            if ($null -eq $referenceState) {
                $referenceState = $state
                $stateMatch = 'reference'
            } elseif ($state -cne $referenceState) {
                throw "$caseName architectural register/RAM state differs from immediate-bypass reference"
            } else { $stateMatch = 'MATCH' }
            $fields = $resultMatch.Groups[1].Value.Split(',')
            if ($fields.Count -ne 12) { throw "$caseName malformed result record" }
            $waitEdges = if ($variant.Enable) { $variant.Miss + 1 } else { $variant.Wait }
            "{0},{1},{2},{3},{4},{5},{6},{7},{8},{9},{10},{11},{12},{13},{14},PASS" -f `
                $workload.Name,$workload.WorkingSet,$variant.Name,$variant.Lines,$variant.Victim,
                $waitEdges,$fields[5],$fields[6],$fields[7],$fields[8],$fields[9],$fields[10],$fields[11],$workload.Expected,$stateMatch |
                Add-Content -LiteralPath $results -Encoding ascii
            Write-Host "PASS ${caseName}: result=$($workload.Expected), full register/RAM state matches"
        } finally { Pop-Location }
    }
}
Write-Host "Independent-RTL C cache study complete: $results"
