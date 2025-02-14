//! Test what happens when an implicit write to a PTE to update
//! A/D bits fails *after* it is in the TLB e.g. because PMA
//! permissions now disallow it.

const std = @import("std");
const runtime = @import("runtime");

export fn main() u8 {
    if (test_main()) |_| {
        return 0;
    } else |_| {
        return 1;
    }
}

const PMPCFG_L = 0b1 << 7;
const PMPCFG_NA4 = 0b10 << 3;
const PMPCFG_NAPOT = 0b11 << 3;
const PMPCFG_X = 0b1 << 2;
const PMPCFG_W = 0b1 << 1;
const PMPCFG_R = 0b1 << 0;

const MSTATUS_MPP_MASK = 0b11 << 11;
const MSTATUS_MPRV_MASK = 0b1 << 17;

fn test_main() !void {
    const stdout = runtime.htif.getHtifWriter();

    try stdout.print("Testing 0xFF..FF PMP addresses\n", .{});

    const ones: usize = std.math.maxInt(usize);

    asm volatile ("csrw pmpaddr0, %[ones]"
        :
        : [ones] "r" (ones),
    );

    // Set mstatus.MPP and mstatus.MPRV so that loads/stores are
    // done in user mode. If they don't match the pmp then
    // they'll fail.
    const mpp: usize = MSTATUS_MPP_MASK;
    const mprv: usize = MSTATUS_MPRV_MASK;
    asm volatile (
        \\ csrc mstatus, %[mpp]
        \\ csrs mstatus, %[mprv]
        :
        : [mpp] "r" (mpp),
          [mprv] "r" (mprv),
    );

    const pmpcfg_napot: usize = PMPCFG_NAPOT | PMPCFG_X | PMPCFG_W | PMPCFG_R;

    asm volatile ("csrw pmpcfg0, %[cfg]"
        :
        : [cfg] "r" (pmpcfg_napot),
    );

    // Access memory to test loads/stores.
    try stdout.print("Passed\n", .{});
}
