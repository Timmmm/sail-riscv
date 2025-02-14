# Tests

* `riscv-tests` - a collection of very old pre-compiled ELFs from [the `riscv-tests` repo](https://github.com/riscv-software-src/riscv-tests). These are bare minimum tests; not very exhaustive at all.
* `sail-riscv-zig-tests` - tests specifically designed for this Sail model. They are written in Zig because a) Zig is nicer than C, and b) installing the Zig compiler is a lot easier than installing a RISC-V GCC cross-compiler, and we want to keep the barrier to contribution low. These tests are not designed to test all the features of RISC-V. Rather they are for testing new code that we add, and bug fixes.
