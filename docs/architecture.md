# Architecture decisions

- ISA: RV32IM — base integer (I) + hardware multiply/divide (M) extension
- M-extension: MUL, MULH, MULHSU, MULHU, DIV, DIVU, REM, REMU (funct7=0x01)
- Register file: 32 registers, two asynchronous reads, one synchronous write
- `x0`: permanently zero
- Memories: 2KB instruction memory, 2KB data memory
- L1 Data Cache: Direct-mapped, 16 lines, 1 word per line, write-through, 3-cycle miss penalty
- Addressing: byte addressed, little endian
- Pipeline: IF/ID, ID/EX, EX/MEM, MEM/WB
- Data hazards: EX/MEM and MEM/WB forwarding; one bubble after load-use
- Control hazards: static not-taken; branch and jump resolved in EX
- Reset PC: `0x00000000`
- Misaligned accesses: detected as unsupported in the initial core
- `FENCE`: architecturally harmless NOP for the simulation memory model
- `ECALL`/`EBREAK`: reported through a trap indication

