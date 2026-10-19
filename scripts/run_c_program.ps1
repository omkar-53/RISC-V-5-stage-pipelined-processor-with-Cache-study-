param(
    [string]$Source,
    [string]$ToolchainBin
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$images = Join-Path $projectRoot 'build\c_program'
$compiler = Join-Path $projectRoot 'c_toolchain\compile.py'
$simulation = Join-Path $PSScriptRoot 'build_pipeline_proof.ps1'

if(!$Source){$Source=Join-Path $projectRoot 'c_toolchain\main.c'}
$Source=(Resolve-Path -LiteralPath $Source).Path
$compilerArgs=@($compiler,$Source,'--output-dir',$images)
if($ToolchainBin){$compilerArgs+=@('--toolchain-bin',(Resolve-Path -LiteralPath $ToolchainBin).Path)}
& python @compilerArgs
if($LASTEXITCODE -ne 0){exit $LASTEXITCODE}

& $simulation -ProgramImageDir $images -RunCChecks
exit $LASTEXITCODE
