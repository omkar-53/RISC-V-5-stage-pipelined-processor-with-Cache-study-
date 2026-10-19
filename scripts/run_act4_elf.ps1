param(
    [Parameter(Mandatory = $true)]
    [string]$BuildRoot
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$vivadoBin = 'D:\2026.1\Vivado\bin'
$rtlFiles = Get-ChildItem -LiteralPath (Join-Path $projectRoot 'rtl_independent') -Filter '*.sv' |
    Where-Object { $_.Name -notin @('alu_signed_smoke_tb.sv', 'act4_tb.sv') } |
    Select-Object -ExpandProperty FullName

Push-Location -LiteralPath $BuildRoot
try {
    & (Join-Path $vivadoBin 'xvlog.bat') -sv @rtlFiles (Join-Path $projectRoot 'rtl_independent\act4_tb.sv') *> 'compile.log'
    if ($LASTEXITCODE -ne 0) { throw 'ACT4 harness RTL compile failed; see compile.log' }

    & (Join-Path $vivadoBin 'xelab.bat') act4_tb -s act4_rtl_sim -debug typical *> 'elaborate.log'
    if ($LASTEXITCODE -ne 0) { throw 'ACT4 harness elaboration failed; see elaborate.log' }

    & (Join-Path $vivadoBin 'xsim.bat') act4_rtl_sim `
        -testplusarg LOAD_INST_MEM `
        -testplusarg LOAD_DATA_MEM `
        -runall *> 'console.log'
    $simExit = $LASTEXITCODE
    $simLog = Get-Content -LiteralPath 'xsim.log' -Raw -ErrorAction SilentlyContinue
    $summaryPattern = 'RVCP-SUMMARY: TEST (PASSED|FAILED|SIGRUN) - Test File ".*"'
    $summary = [regex]::Match($simLog, $summaryPattern).Value
    if ($simExit -ne 0 -or $summary -notmatch 'TEST PASSED') {
        if ($summary) { Write-Output $summary }
        Get-Content -LiteralPath 'console.log' -ErrorAction SilentlyContinue
        throw 'ACT4 harness reported failure; see xsim.log and console.log'
    }
    Write-Output $summary
} finally {
    Pop-Location
}
