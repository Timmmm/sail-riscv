#!/bin/bash

set -e

cd ../..

./build_simulators.sh

cd build

MARCH="$(./c_emulator/sail_riscv_sim --print-isa-string --config ../test/assembly/rv64d.json)"

# Generate all possible instructions.
./c_emulator/sail_riscv_sim --print-all-assembly --config ../test/assembly/rv64d.json > asm.s

# Ignore errors so we can run both.
# set +e

# Assemble to ELF using GCC and Clang.
# riscv64-unknown-elf-as -march="$MARCH" -c asm.s -o asm.gas.elf 2> err.gas.txt
clang-20 --target=riscv64 -march="$MARCH" -menable-experimental-extensions -c asm.s -o asm.llvm.elf 2> err.llvm.txt

# Extract the raw instructions from the reference and test sections.
# TODO: Can probably extract both sections with one command?
# llvm-objcopy-20 --dump-section .text.assembly=asm.gas.assembly.bin asm.gas.elf
# llvm-objcopy-20 --dump-section .text.reference=asm.gas.reference.bin asm.gas.elf

llvm-objcopy-20 --dump-section .text.assembly=asm.llvm.assembly.bin asm.llvm.elf
llvm-objcopy-20 --dump-section .text.reference=asm.llvm.reference.bin asm.llvm.elf

# Verify they are all identical.
# cmp asm.gas.assembly.bin asm.gas.reference.bin && echo "GAS pass"
cmp asm.llvm.assembly.bin asm.llvm.reference.bin && echo "LLVM pass"
# cmp asm.gas.reference.bin asm.llvm.reference.bin && echo "GAS = LLVM"
