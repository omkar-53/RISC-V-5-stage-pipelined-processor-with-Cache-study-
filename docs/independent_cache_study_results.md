# Independent RV32IM Cache Study: Reproducible Results

## Scope and claim boundary

This experiment evaluates the cache in `rtl_independent/`, the project's independently maintained processor RTL. It is separate from the earlier cache study of the imported core. The workloads are two small freestanding C programs compiled to RV32IM machine code and run in Vivado XSim against the independent RTL. The experiment does not claim that a cache organization is new, that the processor is fully RISC-V compliant, or that the modeled cycles are FPGA timing, power, or silicon measurements.

The research question is deliberately bounded: **when the backing-memory wait is held equal, how do reuse, working-set size, cache capacity, and a one-entry victim buffer affect simulated completion cycles in this blocking-cache implementation?**

## RTL configuration and comparison rules

The independent top now exposes default-preserving experiment parameters for cache enable, number of one-word lines, miss wait, optional one-entry victim storage, and bypass load wait. The defaults retain the prior independent-RTL behavior: enabled 16-line cache, three extra miss edges (four stalled rising edges total), and no victim entry.

The study uses three bypass/cache comparisons:

1. **Immediate bypass:** cache disabled and no load wait. This preserves the original fast-memory baseline, but it is not a latency-equivalent comparison.
2. **Latency-matched bypass:** cache disabled, and every load is held for the same configured number of rising edges as a cache miss. This models a blocking memory of the same per-load latency, without cache hits.
3. **Cache:** enabled, with a miss held for the same total number of rising edges. A hit completes without the modeled miss wait.

The latency sweep uses 3, 4, 5, 10, and 20 stalled rising edges per backing-memory access. In the cache parameter, this is represented by the initiating request edge plus `MISS_PENALTY` additional edges. Loads remain in the EX/MEM request stage while `pipeline_hold` is asserted; this blocking interface permits at most one outstanding data-load request. The testbench counts loads, hit/miss events, and wait edges and asserts exact accounting (`hits + misses = loads` for cache runs; wait edges equal misses times the configured miss wait, or loads times the matched bypass wait). The per-cycle trace records the PC/stage fields, memory address, cache events, and pipeline hold. Thus the reported total cycle counts are measured from the simulation, not inferred by multiplying a load count by latency.

## Workloads

| Workload | C behavior | Read working set | Dynamic data loads | Stores | Expected output |
|---|---|---:|---:|---:|---:|
| `reuse4` | Reads the same four-word array for 16 passes and sums it | 4 words | 64 | 3 | 416 |
| `stream32` | Scans a 32-word array twice and sums it | 32 words | 64 | 3 | 1056 |

The arrays and result are volatile so the compiler retains the data accesses. The result is written to RAM word 64 and checked at EBREAK. The runner compiles each source with xPack GCC using `-march=rv32im -mabi=ilp32 -O1 -ffreestanding -nostdlib`, the project's startup assembly, and its linker script. It converts the ELF text/data sections into the instruction and data-memory images loaded by XSim. For each run, the testbench dumps all 32 integer registers and all 512 data-memory words. Each configured run's complete dump is compared byte-for-byte with its workload's immediate-bypass reference.

## C-workload results

### Latency-matched 4-edge comparison and capacity sweep

| Workload | Configuration | Cycles | Loads | Hits | Misses | Wait edges | Cycle change vs. matched bypass |
|---|---|---:|---:|---:|---:|---:|---:|
| Reuse4 | Bypass, immediate | 294 | 64 | — | — | 0 | — |
| Reuse4 | Bypass, matched 4-edge | 550 | 64 | — | — | 256 | Reference |
| Reuse4 | 4-line cache, 4-edge miss | 310 | 64 | 60 | 4 | 16 | 43.6% fewer |
| Reuse4 | 16-line cache, 4-edge miss | 310 | 64 | 60 | 4 | 16 | 43.6% fewer |
| Reuse4 | 32-line cache, 4-edge miss | 310 | 64 | 60 | 4 | 16 | 43.6% fewer |
| Reuse4 | 16-line + victim, 4-edge miss | 310 | 64 | 60 | 4 | 16 | 43.6% fewer |
| Stream32 | Bypass, immediate | 617 | 64 | — | — | 0 | — |
| Stream32 | Bypass, matched 4-edge | 873 | 64 | — | — | 256 | Reference |
| Stream32 | 4-line cache, 4-edge miss | 873 | 64 | 0 | 64 | 256 | No change |
| Stream32 | 16-line cache, 4-edge miss | 873 | 64 | 0 | 64 | 256 | No change |
| Stream32 | 32-line cache, 4-edge miss | 745 | 64 | 32 | 32 | 128 | 14.7% fewer |
| Stream32 | 16-line + victim, 4-edge miss | 873 | 64 | 0 | 64 | 256 | No change |

At the 4-edge setting, `reuse4` therefore has a 6.25% miss rate (4/64) and a 93.75% hit rate (60/64). `stream32` has a 100% miss rate in the 4-line, 16-line, and 16-line-plus-victim cases, and a 50% miss rate in the 32-line case (32/64).

The reuse workload has four compulsory misses followed by 60 hits. Against a bypass that pays the same four-edge wait for every load, the 16-line cache reduces measured completion from 550 to 310 cycles (240 cycles, or 43.6%). Against immediate bypass, however, it takes 16 more cycles (310 versus 294). This is an important boundary: the cache advantage appears when backing memory is slow enough for hits to avoid waits; it does not make this modeled processor faster than zero-wait memory.

The 32-word scan does not fit in a 4- or 16-word direct-mapped cache under this access pattern: its second pass still misses on all 32 loads. A 32-line cache retains the first pass and hits on the second, reducing the run by 128 cycles (14.7%) against matched bypass. One victim entry did not improve this scan: its conflict distance exceeds what a single retained word can cover. These data support a workload-dependent result, not a universal claim that a cache always improves execution.

### Equal-wait sensitivity

The table reports full-run cycle counts for the 16-line cache and a bypass that imposes the same number of stalled rising edges on every load. The output and complete architectural state matched in every case.

| Load wait (edges) | Reuse4 matched bypass | Reuse4 cache16 | Reuse4 reduction | Stream32 matched bypass | Stream32 cache16 | Stream32 reduction |
|---:|---:|---:|---:|---:|---:|---:|
| 3 | 486 | 306 | 37.0% | 809 | 809 | 0% |
| 4 | 550 | 310 | 43.6% | 873 | 873 | 0% |
| 5 | 614 | 314 | 48.9% | 937 | 937 | 0% |
| 10 | 934 | 334 | 64.2% | 1257 | 1257 | 0% |
| 20 | 1574 | 374 | 76.2% | 1897 | 1897 | 0% |

The number of loads is fixed at 64, so the matched bypass wait-edge counts are 64 times the selected latency (192, 256, 320, 640, and 1280). The reuse cache has only four misses, so its wait-edge counts are 4 times the selected latency. The 16-line scan has 64 misses and consequently receives no cycle advantage over matched bypass. Again, these are deterministic modeled wait cycles, not an estimate of physical DRAM or FPGA block-RAM timing.

## Load-use, request serialization, and branch/miss overlap

The C simulations observed 64 load-use interlock events per workload. In the matched bypass cases the measured wait-edge count equals `64 × wait`; in the cache cases it equals `misses × wait`. The testbench also asserts that the EX/MEM load address does not change during a stalled request and that the number of wait intervals equals the number of cache misses (or delayed bypass loads). This directly checks the single-outstanding, serialized behavior of the blocking interface. The per-cycle `cycle_attribution.csv` makes the timing sequence inspectable rather than relying on a cycle formula. This is not a multiple-outstanding or nonblocking cache.

A separate hand-encoded directed program places a taken BEQ in EX while the preceding LW is waiting on a miss. The program also writes a value on the wrong path and one at the branch target. The result was:

| Configuration | Runs | Cycles | Branch/miss overlapping wait edges | Redirects | Checked architectural outcome |
|---|---:|---:|---:|---:|---|
| Immediate bypass control | 1 | 14 | 0 | 1 | load x3=5; wrong-path x2=0; target x4=7 |
| Matched bypass and cache, waits 3/4/5/10/20 | 10 | 17/18/19/24/34 per wait | exactly 3/4/5/10/20 | 1 each | identical register/RAM state in each pair |

The branch waits behind the outstanding load, then redirects once; the wrong-path write is suppressed. `overlap_cycles.csv` and `final_state.txt` are emitted per run. This checks a specific interaction and is not a general proof of all control-flow/cache cases.

## Validation and evidence

The new C matrix completed **36/36 XSim runs**, with expected program outputs (416 or 1056), exact cache hit/miss/wait accounting, and full register/RAM equality against each workload's immediate-bypass reference. The branch/miss experiment completed **11/11 runs**, with the expected overlap, wait duration, one redirect, and equal final architectural state for each latency-matched pair.

After adding the experiment controls and benches, the regular independent-RTL regression runner also passed all six existing checks: pipeline regression, selected RV32IM instruction completion, load-to-branch diagnostic, performance bench, freestanding C test, and signed ALU smoke test. Their saved logs are in `deliverables/verification_evidence/independent/`.

An earlier Basys 3 implementation snapshot is available for the default
16-line, no-victim configuration: 6,820 post-place LUTs, 1,515 registers,
0 BRAM tiles, 12 DSPs, and +1.415 ns routed WNS. A five-configuration routed
implementation comparison has since been completed in Vivado 2026.1. Those
new reports use the same part and board constraints and are analyzed in
`docs/cache_fpga_implementation_analysis.md`. Both resource snapshots describe
the whole board design, not cache-only area; the earlier snapshot is a separate
run and should not be mixed into the five-top comparison table.

## Basys 3 wrapper-counter simulation

The physical-board wrapper now freezes run counters at EBREAK and selects
them for the seven-segment display. Its simulation harness exercised two
self-checking C images across six wrapper configurations, for **12/12 passing
wrapper-profile runs**. These are still XSim checks—not observations from the
physical Basys 3.

| Workload | Immediate bypass | 4-cycle matched bypass | Cache 4 | Cache 16 | Cache 32 | Cache 16 + victim |
|---|---:|---:|---:|---:|---:|---:|
| Reuse4, cycles | 232 | 488 | 248 | 248 | 248 | 248 |
| Reuse4, hits/misses | 0/0 | 0/0 | 60/4 | 60/4 | 60/4 | 60/4 |
| Stream32, cycles | 619 | 875 | 875 | 875 | 747 | 875 |
| Stream32, hits/misses | 0/0 | 0/0 | 0/64 | 0/64 | 32/32 | 0/64 |

Every run checked its result word (416 or 1056), PASS marker, frozen counter
values, and cache load accounting. Workload images, the machine-readable
counter results, and individual XSim logs are in `build/basys3_cache_profiles/`
and `deliverables/verification_evidence/basys3_cache_profiles/`. The matching
physical-board steps and switch map are in
`docs/basys3_cache_fpga_measurement_guide.md`.

## Physical Basys 3 counter observations

The following values were supplied from Basys 3 runs on 17 October 2026. The
displayed counters were hexadecimal; both the raw display value and its decimal
interpretation are retained here. These are board observations and are separate
from the XSim wrapper-profile CSV above.

| Workload/configuration | Cycles (hex → decimal) | Loads | Hits | Misses | Stall cycles | Stores | Redirects |
|---|---:|---:|---:|---:|---:|---:|---:|
| Reuse4, matched bypass wait4 | `01E8` → 488 | 64 | 0 | 0 | 256 | 3 | 21 |
| Reuse4, cache with victim entry | `00F8` → 248 | 64 | 60 | 4 | 16 | 3 | 21 |
| Stream32, cache with victim entry | `0366` → 870 | 64 | 0 | 64 | 256 | 3 | 68 |
| Stream32, matched bypass wait4 | `0366` → 870 | 64 | 0 | 64 | 256 | 3 | 68 |
| Stream32, 32-line cache | `02E6` → 742 | 64 | 32 | 32 | 128 | 3 | 68 |

The physical counters satisfy the expected accounting. For each cached run,
`hits + misses = 64 loads`; four wait edges per miss yield 16 stall cycles for
the four reuse misses and 128 stall cycles for the 32 stream misses. The
matched bypass incurs four wait edges for each of 64 loads, or 256 stalls. The
reuse comparison removes 240 stalls and 240 total cycles (488 to 248, a 49.2%
cycle reduction). The Stream32 32-line cache removes 128 stalls and 128 total
cycles (870 to 742, a 14.7% cycle reduction). Stores and redirects are identical
within each workload comparison, supporting the interpretation that the
observed cycle differences track avoided load stalls rather than a changed
program path. The victim entry did not help this particular stream: it
recorded 64 misses and matched bypass at 870 cycles.

The physical Stream32 totals are five cycles lower than the existing XSim
wrapper-profile totals (875 for bypass/victim and 747 for Cache 32), although
loads, stores, hit/miss counts, and stall cycles match. Preserve the board and
simulation numbers as separate evidence. Before describing the runs as an
exact cycle-for-cycle reproduction, record/compare the programmed instruction
image, reset/capture procedure, and cycle-counter endpoint convention. The
board observations currently cover the matched bypass, victim-enabled 16-line
cache, and 32-line cache for these workloads; they do not constitute a complete
physical five-configuration sweep. No physical power measurement is included.

Machine-readable C results and traces are in `build/independent_cache_c_study/`; overlap results and traces are in `build/independent_cache_overlap/`. The repeatable entry points are `scripts/run_independent_cache_c_study.ps1` and `scripts/run_independent_cache_overlap.ps1`. The C study runner accepts `-ToolchainBin` when GCC is not on PATH.

## Interpretation, limitations, and next step

This is now a substantive, reproducible **behavioral performance study** of the project's independent RTL: it has controlled C workloads, an immediate-memory baseline, latency-matched bypass controls, a latency sweep, cache-capacity and victim-entry comparisons, complete architectural-state checks, a branch/miss overlap test, and per-cycle evidence. The five-top routed FPGA implementation sweep is also complete; its whole-wrapper resource tradeoffs and timing-path caveats are documented in `docs/cache_fpga_implementation_analysis.md`. Together, these results support bounded claims about the tested blocking-cache locality patterns and the implementation costs of these five Basys 3 configurations.

It does **not** establish a literature-wide research gap, cache novelty, full RV32IM or RISC-V compliance, maximum clock frequency, power reduction, or physical memory latency. The five-top routed Vivado reports are implementation estimates under the documented constraints; global WNS is dominated by a wrapper path between the generated core clock and the 100 MHz system clock rather than by a cache datapath. The new physical counter observations support bounded on-board cycle comparisons for the listed variants and workloads, but not a complete physical cache sweep or a power claim. Any paper novelty statement still requires a documented literature review.

