/* Self-checking RV32IM test for simulation and the Basys 3 demonstration. */
volatile int results[12] __attribute__((section(".results")));
volatile int initialized_value = 7;

int main(void) {
    volatile int a = 12;
    volatile int b = 5;
    volatile int sum = 0;

    results[0] = a + b;                  /* 17 */
    results[1] = a * b;                  /* 60: RV32M MUL */
    results[2] = a / b;                  /* 2: RV32M DIV */
    results[3] = a % b;                  /* 2: RV32M REM */

    for (volatile int i = 0; i < 4; ++i) {
        sum += i;
    }
    results[4] = sum;                    /* 6: loop and branch */
    results[5] = (results[0] == 17);     /* 1: compare and branch */
    results[6] = initialized_value + a;  /* 19: initialized .data */
    results[7] = results[6] - 19;        /* 0: global .bss read/write */

    /* Force specific pipeline situations instead of relying on compiler layout:
       ALU forwarding, load-use interlock, then a taken branch with a wrong-path store. */
    __asm__ volatile(
        "sw   zero, 8(%0)\n"
        "li   t0, 10\n"
        "addi t1, t0, 5\n"       /* immediate RAW dependency */
        "add  t2, t1, t0\n"      /* chained RAW dependency: 15 + 10 = 25 */
        "sw   t2, 0(%0)\n"
        "lw   t3, 0(%0)\n"
        "addi t4, t3, 1\n"       /* immediate load-use dependency: 26 */
        "sw   t4, 4(%0)\n"
        "li   t5, 1\n"
        "beq  t5, t5, 1f\n"      /* taken branch must squash next two instructions */
        "li   t6, 99\n"
        "sw   t6, 8(%0)\n"       /* wrong-path store must not happen */
        "1: li  t6, 85\n"
        "sw   t6, 12(%0)\n"
        : : "r" (&results[8])
        : "t0", "t1", "t2", "t3", "t4", "t5", "t6", "memory");

    /* Do not report PASS unless every C and directed-pipeline result matches. */
    if (results[0] != 17 || results[1] != 60 || results[2] != 2 ||
        results[3] != 2 || results[4] != 6 || results[5] != 1 ||
        results[6] != 19 || results[7] != 0 || results[8] != 25 ||
        results[9] != 26 || results[10] != 0 || results[11] != 85) {
        __asm__ volatile("li x31, 0xbad" ::: "x31");
        __asm__ volatile("ebreak");
        for (;;) __asm__ volatile("nop");
    }

    /* Stable hardware-visible PASS marker, written only after all comparisons. */
    __asm__ volatile("li x31, 0x5a5" ::: "x31");
    __asm__ volatile("ebreak");         /* simulation completion / board demo done */
    for (;;) {
        __asm__ volatile("nop");
    }
}
