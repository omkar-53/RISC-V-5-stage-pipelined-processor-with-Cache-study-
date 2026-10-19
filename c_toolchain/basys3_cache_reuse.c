#include <stdint.h>

volatile uint32_t values[4] = {3, 5, 7, 11};
volatile uint32_t results[2] __attribute__((section(".results")));

int main(void) {
    uint32_t sum = 0;
    for (uint32_t pass = 0; pass < 16; ++pass)
        for (uint32_t i = 0; i < 4; ++i)
            sum += values[i];

    results[0] = sum;
    if (sum == 416)
        __asm__ volatile("li t6, 0x5a5" ::: "t6");
    else
        __asm__ volatile("li t6, 0xbad" ::: "t6");
    __asm__ volatile("ebreak");
    for (;;) __asm__ volatile("nop");
}
