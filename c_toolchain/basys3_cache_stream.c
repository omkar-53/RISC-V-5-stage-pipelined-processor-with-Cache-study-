#include <stdint.h>

volatile uint32_t values[32] = {
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16,
    17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32
};
volatile uint32_t results[2] __attribute__((section(".results")));

int main(void) {
    uint32_t sum = 0;
    for (uint32_t pass = 0; pass < 2; ++pass)
        for (uint32_t i = 0; i < 32; ++i)
            sum += values[i];

    results[0] = sum;
    if (sum == 1056)
        __asm__ volatile("li t6, 0x5a5" ::: "t6");
    else
        __asm__ volatile("li t6, 0xbad" ::: "t6");
    __asm__ volatile("ebreak");
    for (;;) __asm__ volatile("nop");
}
