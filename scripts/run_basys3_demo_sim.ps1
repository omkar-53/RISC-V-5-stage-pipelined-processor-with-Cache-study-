$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$vivadoBin = 'D:\2026.1\Vivado\bin'
$out = Join-Path $root 'build\basys3_demo_sim'
$evidence = Join-Path $root 'deliverables\verification_evidence\basys3_selfcheck'
New-Item -ItemType Directory -Force -Path $out | Out-Null
Copy-Item -LiteralPath (Join-Path $root 'vivado\RV32IM_Basys3\instructions.mem'),
    (Join-Path $root 'vivado\RV32IM_Basys3\data_mem.mem') -Destination $out -Force
@('`define C_CACHE_ENABLE 1', '`define C_CACHE_LINES 16',
  '`define C_CACHE_VICTIM_ENABLE 0') |
    Set-Content -LiteralPath (Join-Path $out 'cache_c_config.svh') -Encoding ascii
$rtl = Get-ChildItem -LiteralPath (Join-Path $root 'rtl_independent') -Filter '*.sv' |
    Where-Object { $_.Name -notin @('basys3_top_tb.sv', 'cache_c_study_tb.sv',
        'cache_overlap_tb.sv', 'act4_tb.sv', 'alu_signed_smoke_tb.sv', 'c_program_tb.sv',
        'basys3_c_selfcheck_tb.sv') } |
    Select-Object -ExpandProperty FullName
$tests = @((Join-Path $root 'rtl_independent\basys3_top_tb.sv'),
    (Join-Path $root 'rtl_independent\basys3_c_selfcheck_tb.sv'))
Push-Location $out
try {
    & (Join-Path $vivadoBin 'xvlog.bat') -sv @rtl @tests *> compile.log
    if ($LASTEXITCODE -ne 0) { throw "XSim compile failed; see $out\compile.log" }
    & (Join-Path $vivadoBin 'xelab.bat') basys3_top_tb -s basys3_demo_sim -debug typical *> elaborate.log
    if ($LASTEXITCODE -ne 0) { throw "XSim elaboration failed; see $out\elaborate.log" }
    & (Join-Path $vivadoBin 'xsim.bat') basys3_demo_sim -testplusarg LOAD_INST_MEM -testplusarg LOAD_DATA_MEM -runall *> console.log
    if ($LASTEXITCODE -ne 0) { throw "XSim run failed; see $out\console.log" }
    $log = Get-Content -LiteralPath (Join-Path $out 'xsim.log') -Raw
    if ($log -notmatch 'BASYS3_DEMO_PASS,marker=000005a5' -or
        $log -notmatch 'BASYS3_METRICS_MUX_PASS' -or $log -match '\bFatal:') {
        throw "Board-wrapper demo did not pass; see $out\xsim.log"
    }
    Copy-Item -LiteralPath (Join-Path $out 'xsim.log') -Destination (Join-Path $out 'basys3_wrapper_xsim.log') -Force

    & (Join-Path $vivadoBin 'xelab.bat') basys3_c_selfcheck_tb -s basys3_selfcheck_sim -debug typical *> selfcheck_elaborate.log
    if ($LASTEXITCODE -ne 0) { throw "Self-check elaboration failed; see $out\selfcheck_elaborate.log" }
    & (Join-Path $vivadoBin 'xsim.bat') basys3_selfcheck_sim -testplusarg LOAD_INST_MEM -testplusarg LOAD_DATA_MEM -runall *> selfcheck_console.log
    if ($LASTEXITCODE -ne 0) { throw "Self-check simulation failed; see $out\selfcheck_console.log" }
    $checkLog = Get-Content -LiteralPath (Join-Path $out 'xsim.log') -Raw
    if ($checkLog -notmatch 'BASYS3_RV32IM_SELFCHECK_PASS: 13 RAM checks' -or $checkLog -match '\bFatal:') {
        throw "Self-checking program did not pass all expected-value checks; see $out\xsim.log"
    }
    Copy-Item -LiteralPath (Join-Path $out 'xsim.log') -Destination (Join-Path $out 'selfcheck_xsim.log') -Force
    New-Item -ItemType Directory -Force -Path $evidence | Out-Null
    Copy-Item -LiteralPath (Join-Path $out 'basys3_wrapper_xsim.log'),
        (Join-Path $out 'selfcheck_xsim.log'), (Join-Path $out 'compile.log'),
        (Join-Path $out 'selfcheck_elaborate.log') -Destination $evidence -Force
    Write-Host "PASS: board wrapper and 13-memory-value self-check passed; evidence: $evidence"
} finally { Pop-Location }
