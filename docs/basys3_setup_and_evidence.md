# Basys 3 FPGA build: independent RV32IM RTL

## What this build is

This project builds the independent modules under `rtl_independent/` for the
Basys 3 Artix-7 part `xc7a35tcpg236-1`. It uses the existing freestanding C
demo as a fixed program image. The image is compiled with `-march=rv32im`,
then the compiler tool emits a complete 256-word instruction ROM initialized
with NOPs after the program and a complete 512-word data RAM initialized with
zeros except for `.data` values.

Vivado synthesis uses the `SYNTHESIS` branch in `inst_mem.sv` and `data_mem.sv`
to load those images with `$readmemh`. Simulation keeps its original
plusarg-controlled image loading. `reg_file.sv` initializes the architectural
registers to zero, without using simulation-only plusargs in synthesis.

## Board controls and indicators

- Press and release the center button (`btnC`) to reset/start the processor.
- `sw0` selects the four-digit hexadecimal display: 0 shows the last
  committed register value; 1 shows the live data-memory read value.
- After the self-checking C and directed-hazard test runs, the display should
  settle at `05A5` and `led[7:0]` should show `A5`. The program compares twelve
  expected result words before writing this x31 PASS marker; on a mismatch it
  writes `0xBAD`, so `led[15]` remains off.
- `led[8]` latches that a memory write occurred; `led[9]` latches a register
  write; `led[10]` latches trap/EBREAK completion; `led[11]` indicates a live
  cache hit; `led[12]` a live cache miss; `led[13]` a live cache stall;
  `led[14]` directly mirrors the active-high BTNC button; `led[15]` latches
  only after x31 commits the exact `0x000005A5` pass signature.
- The board wrapper divides the 100 MHz Basys 3 oscillator to a 1 MHz core
  clock. The processor does not meet the board's 100 MHz target in this RTL;
  the divider is a demonstration workaround, not a timing optimization.

The LEDs are live signals, not a stored summary of the individual test cases.
The PASS marker means the software comparisons completed successfully; it does
not expose internal forwarding, stall, or flush wires. Use simulation logs for
detailed signal checks; an ILA is optional if on-FPGA internal waveforms are
specifically required.

## Rebuild

1. Recompile `c_toolchain/main.c` with the installed RISC-V GCC toolchain and
   place the generated `instructions.mem` and `data_mem.mem` in
   `vivado/RV32IM_Basys3/`. The current self-check images have already been
   generated there.
2. In the existing `vivado/RV32IM_Basys3_FPGA/RV32IM_Basys3_FPGA.xpr` project,
   refresh/reload the two memory files if Vivado reports that they changed,
   then run Synthesis, Implementation, and Generate Bitstream. Do not rerun the
   build Tcl with its default project name if you want to preserve this project;
   use a new project name for a separate scripted build.
3. Review synthesis warnings and timing before programming. The RTL uses
   asynchronous instruction/data-memory reads, so Vivado may implement those
   memories as distributed logic rather than block RAM; that is expected for
   this timing model and should not be described as BRAM inference.
4. Connect the Basys 3 by USB, select the newly generated `.bit` file in Hardware
   Manager, program the device, then check reset, LEDs, and seven-segment
   output. A successful synthesis or bitstream build alone is not evidence of
   correct physical-board execution.

## Evidence boundary

This flow can demonstrate that Vivado synthesized and routed the selected
independent RTL for the Basys 3 part with the included clock and pin
constraints. It does not by itself demonstrate that the physical board ran the
program correctly. After programming, verify the `05A5` marker and sticky
completion LED, then save a board photo and a Hardware Manager “Programmed”
screenshot. The self-checking program writes the marker only after comparing
the expected results, including directed forwarding, load-use, and
wrong-path-store cases. The RTL testbench separately inspects all twelve
result words. Do not report measured power.
