$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$buildRoot = Join-Path $projectRoot 'build\rv32im_alu'
$evidenceRoot = Join-Path $projectRoot 'deliverables\verification_evidence\logs'
$vivadoBin = 'D:\2026.1\Vivado\bin'
$env:XILINXD_LICENSE_FILE = 'C:\Users\omkar\.Xilinx\Vivado.lic'
New-Item -ItemType Directory -Force -Path $buildRoot | Out-Null
Push-Location $buildRoot
try {
    & "$vivadoBin\xvlog.bat" -sv `
        (Join-Path $projectRoot 'vendor\awais-rv32i\Source Code\RTL Code\alu_logic.sv') `
        (Join-Path $projectRoot 'tb\isa\tb_rv32im_alu.sv')
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    & "$vivadoBin\xelab.bat" tb_rv32im_alu -s rv32im_alu_sim -debug typical
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    & "$vivadoBin\xsim.bat" rv32im_alu_sim -runall
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    $simLog = Get-Content -LiteralPath (Join-Path $buildRoot 'xsim.log') -Raw
    if ($simLog -notmatch 'RV32IM_ALU_PASS' -or $simLog -match '\bFatal:') {
        throw 'RV32IM ALU tests did not pass. See build\rv32im_alu\xsim.log.'
    }
    New-Item -ItemType Directory -Force -Path $evidenceRoot | Out-Null
    Copy-Item -LiteralPath (Join-Path $buildRoot 'xsim.log') -Destination (Join-Path $evidenceRoot 'vivado_alu_9216.log') -Force
} finally { Pop-Location }
