# Independent processor RTL

This folder is the independently implemented processor track. It is separate from the imported/reference core, which is intentionally not included in this public repository.

## Module map

- `top.sv` — five-stage core integration and pipeline control.
- `program_counter.sv`, `pipe_reg.sv` — PC and inter-stage state.
- `inst_mem.sv`, `reg_file.sv`, `data_mem.sv` — instruction storage, integer register file, and data RAM.
- `imm_gen.sv`, `control_unit.sv`, `alu_logic.sv`, `branch_comp.sv` — decode, immediate generation, execution, and comparisons.
- `fwd_logic.sv`, `hazard_detection.sv` — operand forwarding and load-use/hazard control.
- `l1_cache.sv` — project cache implementation used in the cache experiments.
- `basys3_top.sv`, `basys3_cache_variants.sv` — FPGA demonstration and measurement wrappers.
- `*_tb.sv` — directed and integration testbenches for ALU, processor, board wrapper, cache workloads, and cache/branch interaction.

## Declared implementation scope

The design targets a tested subset of RV32I plus RV32M multiply/divide operations. It is an educational project, not a claim of complete ISA compliance. Unsupported privileged/CSR behavior, architectural exception handling, and other unimplemented extensions are outside the stated scope. See `../docs/architecture.md` and `../docs/independent_cache_study_results.md` for design notes and the current independent cache/board evidence record.

## Evidence

Selected independent-RTL test logs are in `../deliverables/verification_evidence/independent/`. Cache workload and physical Basys 3 counter observations are summarized in `../docs/independent_cache_study_results.md`. Vivado implementation resource/timing results and their constraints are discussed in `../docs/cache_fpga_implementation_analysis.md`.

Some legacy runner scripts in the parent `scripts/` directory refer to a local Vivado installation or to the excluded reference-core track. Check each runner's inputs and configured tool paths before using it; the presence of a script is not itself evidence that a test passed.
