OUTPUT_ARCH( "riscv" )
ENTRY(_start)

__STACK_SIZE = DEFINED(_STACK_SIZE) ? _STACK_SIZE : 0x2000;

/* Memory regions, mapped according to codasip unified memory map */
MEMORY
{
  /* Main memory (RAM) interface - write, execute, allocatable */
  if_ram (wxa) : org = 0x20000000, len = 512m
  /* Verification peripherals interface */
  if_verif : org = 0x6f010000, len = 512k
}

SECTIONS
{
  /* Boot Address */
  . = 0x20000000;

  /* Sections in main memory starting at boot address */

  /* Program memory */
  .text : { *(.text) } >if_ram

  /* Stack */
  .stack ALIGN(16) (NOLOAD) : {
    _stack_end = .;
    . += __STACK_SIZE;
    . = ALIGN(16);
    _stack = .;
  } >if_ram

  /* Compile-time global variables */
  .data : {
    __global_pointer$ = . + 0x800;
    *(.data)
  } >if_ram

  /* Uninitialized global variables */
  .bss (NOLOAD) : { *(.bss) } >if_ram
  _end = .;

  /* Verif MMIO devices. PMA must make this uncacheable */
  .verif : { *(.verif) } >if_verif
}
