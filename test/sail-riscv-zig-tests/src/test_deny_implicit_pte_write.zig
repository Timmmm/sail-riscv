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

const PAGE_SIZE = 4096;
const PTE_V = 1 << 0; // Valid
const PTE_R = 1 << 1; // Readable
const PTE_W = 1 << 2; // Writable
const PTE_X = 1 << 3; // Executable
const PTE_U = 1 << 4; // User
const MSTATUS_MPP_MASK = 0b11 << 11;
const MSTATUS_MPRV_MASK = 0b1 << 17;

var root_page_table: [PAGE_SIZE / @sizeOf(usize)]usize align(PAGE_SIZE) = undefined;

fn make_pte(ppn: usize, flags: u32) usize {
    return (ppn << 10) | flags;
}

fn setup_page_table() void {
    // Identity-map the first gigapage.
    root_page_table[0] = make_pte(0, PTE_V | PTE_R | PTE_W | PTE_X);

    // Write SATP
    const root_ppn: usize = @intFromPtr(&root_page_table) / PAGE_SIZE;
    // TODO: Sv32.
    const satp_value: usize = (8 << 60) | root_ppn; // Mode = 8 (Sv39), PPN
    asm volatile ("csrw satp, %[satp]"
        :
        : [satp] "r" (satp_value),
    );
    // Ensure page table changes take effect.
    asm volatile ("sfence.vma");
}

fn read_page() void {
    var value: usize = undefined;
    var mstatus_tmp: usize = undefined;
    asm volatile (
    // Clear MPP (User mode).
        \\ csrrci %[mstatus], mstatus %[mpp]
        // Set MPRV (enable address translation in MPP mode).
        \\ csrsi mstatus %[mprv]
        // Load a value from address 0.
        \\ lw %[value], 0(zero)
        // Restore original mstatus.
        \\ csrw mstatus %[mstatus]
        : [mstatus] "+r" (mstatus_tmp),
          [value] "=r" (value),
        : [mpp] "i" (MSTATUS_MPP_MASK),
    );
}

fn write_page() void {
    const value: usize = 0;
    var mstatus_tmp: usize = undefined;
    asm volatile (
    // Clear MPP (User mode).
        \\ csrrci %[mstatus], mstatus %[mpp]
        // Set MPRV (enable address translation in MPP mode).
        \\ csrsi mstatus %[mprv]
        // Store a value to address 0.
        \\ sw %[value], 0(zero)
        // Restore original mstatus.
        \\ csrw mstatus %[mstatus]
        : [mstatus] "+r" (mstatus_tmp),
        : [mpp] "i" (MSTATUS_MPP_MASK),
          [value] "r" (value),
    );
}

const PMPCFG_NA4 = 0b10 << 3;
const PMPCFG_NAPOT = 0b11 << 3;
const PMPCFG_X = 0b1 << 2;
const PMPCFG_W = 0b1 << 1;
const PMPCFG_R = 0b1 << 0;

fn deny_pmp() void {
    // Deny access to the PTE using PMPs.
    const root_page_table_address: usize = @intFromPtr(&root_page_table);

    // Match the 4 bytes at root_page_table_address. It doesn't matter
    // that PTEs might be 8 bytes - the partial match should cause
    // a failure anyway.
    const pmpaddr0: usize = root_page_table_address >> 2;
    const pmpcfg0: usize = PMPCFG_NA4;
    // Rest of memory can be accessed still.
    const pmpaddr1: usize = std.math.maxInt(usize);
    const pmpcfg1: usize = PMPCFG_NAPOT | PMPCFG_X | PMPCFG_W | PMPCFG_R;

    asm volatile ("csrw pmpaddr0 %[pmpaddr0]"
        : [pmpaddr0] "r" (pmpaddr0),
    );
    asm volatile ("csrw pmpcfg0 %[pmpcfg0]"
        : [pmpcfg0] "r" (pmpcfg0),
    );
    asm volatile ("csrw pmpaddr1 %[pmpaddr1]"
        : [pmpaddr1] "r" (pmpaddr1),
    );
    asm volatile ("csrw pmpcfg1 %[pmpcfg1]"
        : [pmpcfg1] "r" (pmpcfg1),
    );
}

fn test_main() !void {
    const stdout = runtime.htif.getHtifWriter();

    try stdout.print("PMA test\n", .{});

    // 1. Map a virtual page.
    setup_page_table();
    // 2. Enable Virtual memory.
    read_page();
    // 3. Use PMAs to deny access to one of the PTEs.
    deny_pmp();
    // 4. Enable address translation in machine mode via mstatus.MPRV (Modify Privilege) and .MPP (Machine Previous Privilege).
    //    and access the page corresponding to the mapped page.
    write_page();
}
