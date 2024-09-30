#include "encoding.h"

#define WRITE_SYSCALL 64

#define STDOUT 1
#define STDERR 2

.section .verif

// axi_uart_lite must be 4-byte aligned.
.balign 4
.global axi_uart_lite
axi_uart_lite:
    .4byte 0, 0, 0, 0

// end_of_test_device must be 4-byte aligned.
.balign 4
.global end_of_test_device
end_of_test_device:
    .4byte 0

// Entry point / boot address.
.section .text

.global _start
_start:
    j _reset_handler

// Trap handler is stored in mtvec and must be 4-byte aligned.
.balign 4
.global _trap_handler
_trap_handler:
    // For some reason when compiling with riscv64-unknown-elf-gcc it
    // will happily compile `printf()` etc and just assume it's running
    // on Linux. This means it does a `write()` syscall which means
    // writing the syscall number to a7, and then `ecall`. We can
    // emulate Linux for `write()` to stdout or stderr so that
    // `printf()` works.
    csrr t5, mcause
    li t6, CAUSE_USER_ECALL
    beq t5, t6, _ecall_handler
    li t6, CAUSE_SUPERVISOR_ECALL
    beq t5, t6, _ecall_handler
    li t6, CAUSE_MACHINE_ECALL
    beq t5, t6, _ecall_handler

    // Unhandled trap.
    li a0, 1001
    j _exit_test

.global _exit_test
_exit_test:
    la t0, end_of_test_device
    sw a0, 0(t0)
    fence
    // Loop forever.
1:
    j 1b

.global _ecall_handler
_ecall_handler:
    // Handle syscalls. The only one we'll handle for now is write to stdout
    // or stderr.

    // We're going to mret from this so mret to the following instructions.
    csrr t6, mepc
    addi t6, t6, 4
    csrw mepc, t6

    // Syscall number is in a7, arguments are in a0..a6, return values in
    // a0, a1. See https://man7.org/linux/man-pages/man2/syscall.2.html

    li t5, WRITE_SYSCALL
    beq a7, t5, _ecall_syscall_write

    // syscalls return -1 on failure.
    li a0, -1
    mret

.global _ecall_syscall_write
_ecall_syscall_write:
    // Write arguments are: a0: file descriptor, a1: data pointer, a2: data count.
    // Return value (a0) is -1 for failure, number of bytes written on success.

    // Check file descriptor is stdout or stderr.
    li t0, STDOUT
    beq a0, t0, 1f
    li t0, STDERR
    beq a0, t0, 1f
    // Unknown file descriptor; return -1.
    li a0, -1
    mret
1:
    // Write the bytes.
    // End pointer.
    add t2, a1, a2
    la t1, axi_uart_lite
1:
    lbu t0, 0(a1)
    sw t0, 4(t1)
    addi a1, a1, 1
    // Loop if the pointer is not at the end.
    bne a1, t2, 1b
    // Set return value to all bytes written.
    mv a0, a2
    // Return.
    mret

// Write a null-terminated string to UART. a0 is a pointer to the string.
.global putstr
putstr:
    la t1, axi_uart_lite      // Load address of UART.
    1:
    lbu t0, 0(a0)            // Load byte.
    beq t0, zero, 2f         // If zero, exit.
    sw t0, 4(t1)             // Print it.
    addi a0, a0, 1           // Go to next character.
    j 1b                     // Loop.
    2:
    li a0, 0                 // Return 0.
    ret

.global _reset_handler
_reset_handler:
    // Initialise registers (otherwise you get issues with X's in simulation).
    li x1, 0
    li x2, 0
    li x3, 0
    li x4, 0
    li x5, 0
    li x6, 0
    li x7, 0
    li x8, 0
    li x9, 0
    li x10, 0
    li x11, 0
    li x12, 0
    li x13, 0
    li x14, 0
    li x15, 0
    li x16, 0
    li x17, 0
    li x18, 0
    li x19, 0
    li x20, 0
    li x21, 0
    li x22, 0
    li x23, 0
    li x24, 0
    li x25, 0
    li x26, 0
    li x27, 0
    li x28, 0
    li x29, 0
    li x30, 0
    li x31, 0

    // Initialise trap handler.
    la t0, _trap_handler
    csrw mtvec, t0

    // Initialise stack pointer.
    csrr a0, mhartid

    lui tp, %hi(_stack)
    addi tp, tp, %lo(_stack)

    // Give each core 128KB of stack + Thread Local Storage.
#define STKSHIFT 17
    add sp, a0, 1
    sll sp, sp, STKSHIFT
    add sp, sp, tp
    sll a2, a0, STKSHIFT
    add tp, tp, a2

    // Initialize global pointer
    .option push
    .option norelax
    la gp, __global_pointer$
    .option pop

    // Store a frame pointer on the stack. This is necessary if you don't use
    // -fomit-frame-pointer because main() will load it.
    // For simplicity unconditionally store 8 bytes even on RV32.
    addi sp, sp, -8
    sw zero, 0(sp)
    sw zero, 4(sp)

    call main

    // Main return value is in a0 which we pass straight to _exit_test.

    // Need a far jump for big tests because this may be more than j's
    // offset limit (+/- 1MB) away from the target. `tail` uses t1 as
    // a scratch to jump up to +/- 2GB away.
    tail _exit_test
