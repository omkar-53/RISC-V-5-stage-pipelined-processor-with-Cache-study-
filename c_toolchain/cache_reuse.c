/* Cache workload: repeatedly reads a four-word working set. */
volatile int values[4] = {3, 5, 7, 11};
volatile int results[2] __attribute__((section(".results")));

int main(void) {
    int sum = 0;
    for (int pass = 0; pass < 16; ++pass) {
        for (int i = 0; i < 4; ++i)
            sum += values[i];
    }
    results[0] = sum;
    __asm__ volatile("ebreak");
    for (;;) __asm__ volatile("nop");
}
