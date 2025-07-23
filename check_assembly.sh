#!/bin/bash

set -e

./build_simulators.sh

cd build

MARCH="$(./c_emulator/riscv_sim_rv64d --print-isa-string)"

# Generate all possible instructions.
./c_emulator/riscv_sim_rv64d --print-all-assembly > asm.s

# Ignore errors so we can run both.
# set +e

# Assemble to ELF using GCC and Clang.
riscv64-unknown-elf-as -march="$MARCH" asm.s -o asm.gas.elf 2> err.gas.txt
clang --target=riscv64 -march="$MARCH" -menable-experimental-extensions asm.s -o asm.llvm.elf 2> err.llvm.txt

# Extract the raw instructions from the reference and test sections.
# TODO: Can probably extract both sections with one command?
objcopy --dump-section .text.test=asm.gas.test.bin asm.gas.elf
objcopy --dump-section .text.reference=asm.gas.reference.bin asm.gas.elf

objcopy --dump-section .text.test=asm.llvm.test.bin asm.llvm.elf
objcopy --dump-section .text.reference=asm.llvm.reference.bin asm.llvm.elf

# Verify they are all identical.
cmp asm.gas.test.bin asm.gas.reference.bin
cmp asm.llvm.test.bin asm.llvm.reference.bin
cmp asm.gas.reference.bin asm.llvm.reference.bin
