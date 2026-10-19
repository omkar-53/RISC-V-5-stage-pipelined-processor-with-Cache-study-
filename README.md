# Five-Stage RISC-V Processor and Cache Study

This repository contains the project's independently implemented SystemVerilog processor, verification benches, cache-study workloads, Basys 3 integration sources, and selected results. It is an educational processor targeting a tested RV32I/RV32M subset; it is **not claimed to be fully RISC-V compliant**.

## Main contents

- `rtl_independent/` — processor datapath, pipeline registers, decode/control, forwarding, hazard handling, memories, cache, Basys 3 wrapper, and independent testbenches.
- `c_toolchain/` — freestanding C workloads, startup code, linker script, and memory-image builder.
- `formal/` — combinational block-level equivalence harnesses. These are not a whole-processor formal proof.
- `scripts/` — simulation, cache-study, image-staging, and Vivado helper scripts. Some scripts have local Vivado installation paths that must be adjusted for another machine.
- `tests/` — assembly test programs.
- `vivado/RV32IM_Basys3/` — Basys 3 constraints, memory initialization images, and project setup inputs. Recreate generated Vivado runs locally; they are not checked in.
- `docs/` — design scope, measurement procedure, verification status, and cache/FPGA analysis.
- `deliverables/verification_evidence/independent/` and `deliverables/verification_evidence/basys3_cache_profiles/` — selected simulation logs and board-counter records.

The unrelated Awais/reference RTL tree, generated build directories, Vivado/XSim scratch files, crash dumps, presentation/report drafts, and backup archives are intentionally excluded from this repository.

## Processor organization

The core uses IF, ID, EX, MEM, and WB stages. Its tested subset includes RV32I integer operations and RV32M multiply/divide operations, with forwarding, a load-use interlock, branch/jump flushing, and data-memory/cache support. See `rtl_independent/README.md` and `docs/architecture.md` for implementation notes and limitations.

## Verification and study results

- Selected directed pipeline, instruction, memory, hazard, and C-program checks are recorded in `rtl_independent/README.md` and `deliverables/verification_evidence/independent/`.
- Cache workload, latency-matched bypass, miss/branch overlap, and Basys 3 counter results are summarized in `docs/independent_cache_study_results.md`.
- Routed resource and timing analysis is documented in `docs/cache_fpga_implementation_analysis.md`.
- Board setup and counter-selection instructions are in `docs/basys3_setup_and_evidence.md` and `docs/basys3_cache_fpga_measurement_guide.md`.

All results are bounded to the tests and configurations described in those records. Simulation counters are not FPGA timing or power measurements; Vivado implementation estimates should be reported separately from physical-board observations.

## Reproducibility

The scripts in this repository were written for the project's Windows/Vivado environment. Review their configured Vivado and toolchain paths before running them on another machine. C workloads require a compatible RV32IM bare-metal GCC toolchain. Do not infer a pass from a generated report alone; inspect the script's pass criteria and retained logs.

## Source provenance

The processor sources under `rtl_independent/` are the project's independent implementation. The separate imported/reference RTL and its regression scripts are not included here; do not attribute their results to the independent processor.
