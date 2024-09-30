#include <stdio.h>

int main()
{
  unsigned in = 18;
  unsigned out = 0;

  // Use "DIVI" instruction divide by 6.
  // 0xB is the custom-1 major opcode.
  // 0x0 is the `funct3` part, which is 3 bits and we'll just say is 0.
  asm(".insn i 0xB, 0x0, %0, %1, %2" : "=r"(out) : "r"(in), "I"(6));

  printf("%d / 6 = %d\n", in, out);

  return 0;
}
