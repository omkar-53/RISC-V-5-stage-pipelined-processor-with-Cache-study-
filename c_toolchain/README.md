# Compile and simulate C on the RV32IM core

The sample is freestanding C. It uses no operating system or C library and is
linked for the processor's 1 KB instruction ROM and 2 KB data RAM. The linker
reserves the last 512 bytes for the stack and places the sample result array at
RAM address `0x100` so the simulation can check it.

## Toolchain

Install xPack GNU RISC-V Embedded GCC for Windows and add its `bin` directory
to `PATH`. The build script recognizes the xPack `riscv-none-elf-` command
names and common `riscv32-unknown-elf-` / `riscv64-unknown-elf-` names. GCC and
`objcopy` must come from the same toolchain.

## Run the sample

From the project root in PowerShell:

```powershell
& .\scripts\run_c_program.ps1
```

To compile a different freestanding C source:

```powershell
& .\scripts\run_c_program.ps1 -Source .\path\to\program.c
```

The script creates the ELF, linker map, and memory images in
`build/c_program`. It checks the image capacities, generates a pipeline trace
for the browser console, then runs a self-checking Vivado simulation. The
sample must report `RV32IM_C_PROGRAM_PASS: 9 RAM checks`.

The compiler deliberately disables compressed instructions and small-data
register assumptions. Its output is RV32IM / ILP32 and matches this core's
32-bit instruction memory. The startup assembly initializes the stack, clears
`.bss`, calls `main`, then waits if `main` returns. The sample uses `ebreak` as
the simulation completion marker.
