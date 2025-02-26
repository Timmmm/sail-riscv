// Simple hello world example.

#include "nanoprintf.h"

extern void htif_putc(int c, void* ctx);

int main() {
    npf_pprintf(&htif_putc, NULL, "Hello %s%c %d %u %f\n", "worl", 'd', 1, 2, 3.f);
    return 0;
}
