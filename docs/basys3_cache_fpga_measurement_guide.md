# Basys 3 Cache Measurement Guide

## What is ready

The board wrapper counts cycles, completed loads and stores, cache hits,
misses, cache-stall cycles, and redirects. It freezes these counts at the
program's EBREAK and displays one selected count on the four-digit display.
LED15 is the program PASS marker; LED10 indicates that EBREAK was observed.
The default display (switch selection `000`) shows `05A5` after a passing
workload. The board wrapper simulation checks the frozen counters and the
metric-selection mux.

Selectable Vivado top modules are in `rtl_independent/basys3_cache_variants.sv`:

| Vivado top module | Configuration |
|---|---|
| `basys3_bypass_top` | Cache bypass, no added wait |
| `basys3_bypass_wait4_top` | Cache bypass, emulated four-cycle wait per load |
| `basys3_cache4_top` | 4 direct-mapped one-word lines, 3 extra miss edges |
| `basys3_cache16_top` | 16 lines, 3 extra miss edges |
| `basys3_cache32_top` | 32 lines, 3 extra miss edges |
| `basys3_cache16_victim_top` | 16 lines plus one victim entry, 3 extra miss edges |

All top modules keep the same Basys 3 pins and board wrapper. The four-cycle
bypass is a controlled emulation to compare against cache misses; it is not a
measurement of physical external-memory latency.

## Select the metric on the Basys 3

`SW[3:1]` selects the displayed 32-bit value. `SW0` selects which half is
shown: OFF displays bits 15:0, ON displays bits 31:16.

| `SW[3:1]` | Display |
|---|---|
| `000` | PASS marker / most recent writeback |
| `001` | Total processor cycles |
| `010` | Completed loads |
| `011` | Cache hits |
| `100` | Cache misses |
| `101` | Cache-stall cycles |
| `110` | Completed stores |
| `111` | Redirects (taken branch/jump flush events) |

For example, to read cycles, set SW1 ON, SW2 OFF, SW3 OFF, and SW0 OFF. The
seven-segment display shows four hexadecimal digits. If a count exceeds 65535,
turn SW0 ON to read the upper four hexadecimal digits. Change switches only
after LED15 and LED10 are ON; the frozen results remain stable until reset.

## Run simulation first

From PowerShell in the project folder, run:

```powershell
& .\scripts\run_basys3_demo_sim.ps1
& .\scripts\run_basys3_cache_profiles.ps1 -ToolchainBin 'C:\Users\omkar\Downloads\xpack-riscv-none-elf-gcc-15.2.0-1-win32-x64\xpack-riscv-none-elf-gcc-15.2.0-1\bin'
```

The first command checks the existing board self-check image and display
counter-selection logic. The second compiles two self-checking C programs and
simulates each with all six cache/bypass configurations. Expected arithmetic
results are 416 for `reuse4` and 1056 for `stream32`. Results and logs are in
`deliverables/verification_evidence/basys3_cache_profiles/`. These are XSim
results, not FPGA board measurements.

## Stage a workload for Vivado

Close the Vivado project first so it does not hold stale memory-file contents.
The workload image is already compiled under
`build/basys3_cache_profiles/<workload>_image/`. To install the 4-word reuse
program into the memory-file paths used by the Basys 3 project, run:

```powershell
& .\scripts\stage_basys3_cache_image.ps1 -Workload reuse4 -InstallIntoVivadoProject
```

Use `-Workload stream32` for the 32-word scan. The script backs up the current
instruction and data images under `build/basys3_cache_profiles/vivado_image_backups/`
before replacing them. It does not change the chosen cache variant. Reopen the
project after staging.

## Physical board procedure

1. Open `vivado\RV32IM_Basys3_FPGA\RV32IM_Basys3_FPGA.xpr`.
2. In Sources → Design Sources, right-click the selected module above and choose
   **Set as Top**. Keep the same Basys 3 XDC and device for every run.
3. Reset the synthesis/implementation runs if Vivado reports stale results,
   then run Synthesis, Implementation, and Generate Bitstream.
4. Program the Basys 3. Press BTN-C once to reset, then release it. Wait until
   LED15 (PASS) and LED10 (program complete) are ON.
5. Photograph the board at each switch setting in the metric table. Record each
   four-hex-digit value; if needed, take a second photo with SW0 ON for upper
   bits. Do not press reset between reading metrics.
6. For each cache configuration, save Vivado's utilization and routed timing
   reports. Record LUTs, registers, BRAM, DSP, WNS, and timing pass/fail. Keep
   the same tool version, FPGA part, constraints, and program image.
7. Repeat with the other workload image. Then restore the previous ROM/RAM
   images using the backup path printed by the staging script:

   ```powershell
   & .\scripts\restore_basys3_cache_image.ps1 -BackupPath 'PASTE_BACKUP_PATH_HERE'
   ```

   Replace the quoted text with the exact backup folder printed by the staging
   script. Or leave the cache workload staged if that is what you want the
   project to run.

The no-wait bypass is the real on-chip-memory baseline. A cache may take more
cycles than this baseline because the modeled miss wait is extra work. The
matched four-cycle bypass answers a different question: whether hits help when
the uncached backing-memory model would otherwise impose the same wait on every
load. Keep both comparisons separate in the report; do not describe the
emulated wait as measured RAM latency or the cycle count as MHz/speed.
