# Comparative FPGA Implementation Analysis for the Cache Variants

## Research question

What resource and routed-timing costs result when the independent five-stage RISC-V processor is implemented with a latency-matched bypass, a 4-, 16-, or 32-line direct-mapped cache, or a 16-line cache with a one-entry victim buffer on the Basys 3 target?

The comparison treats the complete Basys 3 wrapper as the unit under test. It does not isolate cache-only area, and it does not measure execution speed or power on a physical board.

## Experimental method and evidence

Five SystemVerilog tops in `rtl_independent/basys3_cache_variants.sv` were selected individually in the same Vivado project. The variants use the same Artix-7 `xc7a35tcpg236-1` target and the same Basys 3 XDC constraints. The bypass top disables caching and inserts a four-rising-edge load wait. The cache variants use 4, 16, or 32 one-word lines with the same four-edge miss service; the final configuration adds one victim entry to the 16-line cache. The cache wait is modeled in RTL and is not a measurement of external-memory latency.

All five designs were synthesized and implemented through routing in Vivado 2026.1. No bitstream was needed for these reports, and no FPGA was connected. The report set contains a routed utilization report, timing summary, and ten-path timing report for every top (15 files total) in `vivado/cache_reports/`. Each report identifies the expected top, the same part, tool version, and `Routed` design state.

## Routed resource comparison

| Configuration | Slice LUTs | LUTs vs. bypass | Slice registers | Registers vs. bypass | BRAM tiles | DSPs |
|---|---:|---:|---:|---:|---:|---:|
| Bypass, 4-edge wait | 6,601 (31.74%) | — | 880 (2.12%) | — | 0 | 12 |
| Cache 4 | 7,001 (33.66%) | +400 (+6.1%) | 1,278 (3.07%) | +398 (+45.2%) | 0 | 12 |
| Cache 16 | 6,978 (33.55%) | +377 (+5.7%) | 1,980 (4.76%) | +1,100 (+125.0%) | 0 | 12 |
| Cache 32 | 7,356 (35.37%) | +755 (+11.4%) | 2,904 (6.98%) | +2,024 (+230.0%) | 0 | 12 |
| Cache 16 + victim | 7,952 (38.23%) | +1,351 (+20.5%) | 2,050 (4.93%) | +1,170 (+133.0%) | 0 | 12 |

Every configuration fits comfortably within the XC7A35T resource totals reported by Vivado: the largest LUT result uses 38.23% of the 20,800 available slice LUTs, and the largest register result uses 6.98% of the 41,600 available slice registers. None of the designs maps to block RAM; each uses 12 DSP slices. The consistent zero-BRAM result means the cache configurations do not obtain block-RAM capacity in this implementation. Their incremental storage and selection cost is reflected in the whole-design slice-resource totals, particularly the register increase as line count grows.

The LUT count does not increase monotonically between 4 and 16 lines: Cache 16 uses 23 fewer LUTs than Cache 4, a difference of about 0.33%, while using 702 more registers. This small LUT reversal is a synthesis/mapping result, not evidence that a larger cache is intrinsically cheaper. More robust trends are the register growth from 880 in bypass to 1,278, 1,980, and 2,904 for 4, 16, and 32 lines, and the additional LUT/register cost of the victim-enabled design over the ordinary 16-line design (+974 LUTs and +70 registers).

These deltas compare full wrappers, not cache macros. The wrapper contains the processor, instrumentation, display, and related logic. The figures therefore support a comparative implementation-cost claim for these five complete designs, but not a precise standalone cache-area claim. `LUT as Memory` is 300 in all five reports, so it does not explain the cache-dependent resource growth; the cache arrays and their selection/control logic contribute to a net change that is realized largely in slice registers and LUT logic.

## Routed timing and critical-path interpretation

The XDC defines a 100 MHz `sys_clk_pin` from the Basys 3 oscillator and a related 1 MHz `core_clk` divided by 100. The timing-summary values are:

| Configuration | Global WNS (ns) | Global TNS (ns) | Failing endpoints | 100 MHz clock WNS (ns) | 1 MHz core-clock WNS (ns) | Constraints met |
|---|---:|---:|---:|---:|---:|---|
| Bypass, 4-edge wait | 1.954 | 0.000 | 0 | 7.721 | 493.107 | Yes |
| Cache 4 | 1.292 | 0.000 | 0 | 7.574 | 492.122 | Yes |
| Cache 16 | 1.313 | 0.000 | 0 | 7.719 | 491.461 | Yes |
| Cache 32 | 1.737 | 0.000 | 0 | 7.701 | 493.905 | Yes |
| Cache 16 + victim | 1.048 | 0.000 | 0 | 7.601 | 493.593 | Yes |

All reports state that user-specified timing constraints are met, with zero total negative slack and zero failing endpoints. The global WNS is positive in every case. It ranges from 1.048 ns for Cache 16 + victim to 1.954 ns for latency-matched bypass. Those numbers show that each routed implementation meets the supplied constraints; they do not directly rank the cache datapaths.

The ten-path reports explain why. The worst listed path in every configuration ends at `impl/pass_seen_reg/D`, a 100 MHz Basys 3 wrapper register, and begins at a register clocked by the generated 1 MHz `core_clk`. The path is therefore a wrapper/core-to-display-status path, not a cache-tag, cache-data, or processor ALU path. Its routed data-path delay is 5.275 ns (bypass), 5.748 ns (Cache 4), 5.721 ns (Cache 16), 4.910 ns (Cache 32), and 5.936 ns (Cache 16 + victim). Routing accounts for roughly 80–84% of each listed path delay. The small differences in global WNS are thus dominated by this cross-clock wrapper path and placement/routing, so a paper should not describe them as cache-access latency or as evidence that one cache has a faster processor clock.

The per-clock rows provide context: the 100 MHz clock-domain WNS varies only from 7.574 to 7.721 ns, a 0.147 ns range. The 1 MHz core-clock WNS is roughly 491–494 ns because its constrained period is 1,000 ns. Neither result establishes the maximum achievable processor frequency. For a cache-specific timing claim, the paper should report the path group and endpoint, distinguish the wrapper crossing from paths wholly within `core_clk`, and avoid presenting the global WNS alone as cache timing.

The cross-clock path merits a separate design review if the board wrapper is revised. The 100 MHz logic samples status and writeback-related signals originating in the generated 1 MHz processor clock domain. The clocks are related by the XDC-generated-clock constraint, so Vivado analyzes their phase relationship; the reports show the paths meet the current constraints. This is a synchronous timing statement under the supplied clock model, not proof of CDC robustness under arbitrary asynchronous clocks or reset conditions.

## Combined interpretation with the XSim cache study

The routed implementation results explain the hardware cost side; XSim supplies the behavioral side. In the measured C study, the 4-, 16-, 32-line, and 16-line-plus-victim caches all finish the four-word `reuse4` workload in 310 cycles, with 60 hits and four misses. Against the equal-four-edge bypass at 550 cycles, that is a 43.6% cycle reduction. Increasing capacity beyond four lines yields no additional benefit for this workload. Against the separate immediate-bypass result of 294 cycles, the cached run is 16 cycles slower, which reinforces that the benefit depends on paying a nonzero backing-memory wait.

For `stream32`, the 4-, 16-, and 16-line-plus-victim caches each incur 64 misses and finish in 873 cycles, equal to the matched bypass. The 32-line cache has 32 hits and 32 misses and finishes in 745 cycles, 14.7% fewer cycles than the matched bypass. The result follows the access pattern: after the first pass, a 32-line cache retains all 32 words for the second pass; a 16-line direct-mapped cache cannot retain the full working set, and a single victim entry does not rescue this sequential scan. The simulation study’s full-state comparisons and hit/miss/wait accounting are documented separately in `docs/independent_cache_study_results.md`.

Across the two tested workloads, Cache 4 is sufficient for the four-word reuse case, while Cache 32 is the only configuration that benefits the 32-word scan. Cache 16 + victim gives no additional measured cycle reduction for either workload, while adding 974 LUTs and 70 registers over Cache 16 in the routed wrapper. This makes the victim design unattractive for these tested patterns, but it does not establish that victim storage is unhelpful for other conflict-heavy address traces. The appropriately bounded conclusion is that capacity and access pattern jointly determine benefit, and the hardware cost must be considered alongside the workload’s hit behavior.

## Research-ready conclusion

The Vivado comparison demonstrates that all five independent-RTL Basys 3 configurations route and meet the supplied timing constraints on the XC7A35T. Relative to the latency-matched bypass wrapper, cache-enabled variants use 5.7–20.5% more LUTs and 45.2–230.0% more slice registers; the 16-line victim variant has the highest LUT count. No configuration uses BRAM, and all use 12 DSP slices. The 32-line cache incurs a measurable resource increase over Cache 16 and is the only tested configuration that improves the 32-word scan in both XSim and the supplied Basys 3 observations. Conversely, four lines are enough for the tested four-word reuse workload. The victim-enabled variant adds area without changing the cycle result for either tested workload.

The global routed WNS remains positive in all cases, but its worst path terminates at the wrapper’s `pass_seen` register and crosses from the generated processor clock to the 100 MHz system clock. It is not a cache datapath path. The supplied physical counter observations add on-board cycle evidence for three configuration/workload comparisons, but do not complete the physical five-top matrix. Accordingly, this study supports a design-specific area/timing-feasibility and workload-locality tradeoff, not a claim of cache-induced maximum-frequency improvement, universal board speedup, power savings, or universal cache superiority. No physical power estimates are reported. Any novelty claim also requires a separate literature review.

## Reproduction and report map

The five report triplets are stored under `vivado/cache_reports/`: `bypass_wait4_*`, `cache4_*`, `cache16_*`, `cache32_*`, and `cache16_victim_*`, with `_util.rpt`, `_timing.rpt`, and `_paths.rpt` suffixes. The design definitions are in `rtl_independent/basys3_cache_variants.sv`, and the shared Basys 3 clock constraints are in `vivado/RV32IM_Basys3/basys3.xdc`.
