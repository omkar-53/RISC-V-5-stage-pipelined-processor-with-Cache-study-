    .option norvc
    .section .text
    .globl _start
_start:
    lui   t0, 0x10
    addi  t0, t0, -4       # Reserved ACT4 pass-marker address: 0xFFFC
    li    t1, 0x41544350   # "ATCP"
    sw    t1, 0(t0)
    ebreak                 # Harness samples the marker after this stop
1:
    j     1b
