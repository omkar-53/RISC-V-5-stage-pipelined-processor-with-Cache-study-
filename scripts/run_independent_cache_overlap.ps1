$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$vivado = 'D:\2026.1\Vivado\bin'
$build = Join-Path $root 'build\independent_cache_overlap'
$bench = Join-Path $root 'rtl_independent\cache_overlap_tb.sv'
$rtl = Get-ChildItem -LiteralPath (Join-Path $root 'rtl_independent') -Filter '*.sv' |
    Where-Object { $_.Name -notin @('cache_c_study_tb.sv','cache_overlap_tb.sv','act4_tb.sv','alu_signed_smoke_tb.sv') } |
    Select-Object -ExpandProperty FullName
$variants = @(@{Name='bypass_immediate';Enable=0;Lines=16;Victim=0;Wait=0;Miss=3})
foreach ($latency in @(3,4,5,10,20)) {
    $variants += @(
        @{Name="bypass_wait$latency";Enable=0;Lines=16;Victim=0;Wait=$latency;Miss=($latency-1)},
        @{Name="cache16_wait$latency";Enable=1;Lines=16;Victim=0;Wait=0;Miss=($latency-1)}
    )
}
New-Item -ItemType Directory -Force -Path $build | Out-Null
$csv = Join-Path $build 'results.csv'
'configuration,cache_enable,cache_lines,victim,equal_wait_edges,miss_penalty,cycles,overlap_wait_edges,taken_redirects,overlap_observed,architectural_state,status' |
    Set-Content -LiteralPath $csv -Encoding ascii
$reference = $null
foreach ($v in $variants) {
    $name=$v.Name; $dir=Join-Path $build $name
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    @(
        ('`define O_CACHE_ENABLE ' + $v.Enable)
        ('`define O_CACHE_LINES ' + $v.Lines)
        ('`define O_VICTIM_ENABLE ' + $v.Victim)
        ('`define O_BYPASS_WAIT ' + $v.Wait)
        ('`define O_MISS_PENALTY ' + $v.Miss)
    ) | Set-Content -LiteralPath (Join-Path $dir 'cache_overlap_config.svh') -Encoding ascii
    Push-Location $dir
    try {
        & (Join-Path $vivado 'xvlog.bat') -sv @rtl $bench *> compile.log
        if ($LASTEXITCODE -ne 0) { throw "${name}: compile failed; see $dir\compile.log" }
        & (Join-Path $vivado 'xelab.bat') cache_overlap_tb -s $name -debug typical *> elaborate.log
        if ($LASTEXITCODE -ne 0) { throw "${name}: elaboration failed; see $dir\elaborate.log" }
        & (Join-Path $vivado 'xsim.bat') $name -runall *> console.log
        if ($LASTEXITCODE -ne 0) { throw "${name}: simulation failed; see $dir\console.log" }
        $log=Get-Content -LiteralPath (Join-Path $dir 'xsim.log') -Raw
        if ($log -notmatch 'CACHE_OVERLAP_PASS' -or $log -match '\bFatal:') { throw "${name}: test failed; see $dir\xsim.log" }
        $m=[regex]::Match($log,'CACHE_OVERLAP_RESULT,([^\r\n]+)')
        if (-not $m.Success) { throw "${name}: missing metrics" }
        $f=$m.Groups[1].Value.Split(',')
        $state=Get-Content -LiteralPath (Join-Path $dir 'final_state.txt') -Raw
        if ($null -eq $reference) { $reference=$state; $stateStatus='reference' }
        elseif ($state -cne $reference) { throw "${name}: final architectural state differs" }
        else { $stateStatus='MATCH' }
        "$name,$($v.Enable),$($v.Lines),$($v.Victim),$($v.Wait),$($v.Miss),$($f[5]),$($f[6]),$($f[7]),$($f[8]),$stateStatus,PASS" |
            Add-Content -LiteralPath $csv -Encoding ascii
        if ($v.Enable -or $v.Wait -gt 0) {
            Write-Host "PASS ${name}: branch/memory-wait interaction checked; full state matches"
        } else {
            Write-Host "PASS ${name}: immediate-bypass control; full state matches"
        }
    } finally { Pop-Location }
}
Write-Host "Miss/branch overlap study complete: $csv"
