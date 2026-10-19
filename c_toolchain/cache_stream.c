/* Cache workload: scans a 32-word array twice (working set exceeds small caches). */
volatile int values[32] = {
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16,
    17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32
};
volatile int results[2] __attribute__((section(".results")));

int main(void) {
    int sum = 0;
    for (int pass = 0; pass < 2; ++pass) {
        for (int i = 0; i < 32; ++i)
            sum += values[i];
    }
    results[0] = sum;
    __asm__ volatile("ebreak");
    for (;;) __asm__ volatile("nop");
}
