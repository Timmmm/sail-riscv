// Verify that an access fault caused by making a PTE
// inaccessible (via PMP in this case) and then having
// the hardware update it works as expected.
//
// Note this test currently assumes:
//
// 1. Hardware dirty/accessed PTE bit updates are supported.
// 2. Virtual memory is supported.
// 3. PMPs are supported.

#include "common/runtime.h"

uint8_t page[4096]; // TODO: Align to 4096.

int main()
{
    // Create a root page table with one identity-mapped huge page.
    let pte_address = plat_ram_base();
    assert(pte_address[pagesize_bits - 1 .. 0] == zeros(), "PTE address must be page aligned.");
    let pte_page = pte_address[physaddrbits_len - 1 .. pagesize_bits];

    let pte_flags = [Mk_PTE_Flags(zeros()) with R=1, W=1, V=1];
    let pte_value : xlenbits = zero_extend(pte_page @ pte_flags.bits);
    X(1) = pte_address;
    X(2) = pte_value;

    let pte_width = if xlen == 32 then WORD else DOUBLE;

    // Write the PTE to memory.
    assert(execute(STORE(zeros(), 0b0010, 0b0001, pte_width, false, false)) == RETIRE_SUCCESS);

    // Enable virtual memory.
#if __riscv_xlen == 32
    uint_xlen_t satp = // Mk_Satp32(zeros()) with Mode = 0b1, PPN = pte_page]  // Sv32
#elif __riscv_xlen == 64
    uint_xlen_t satp = // Mk_Satp32(zeros()) with Mode = 0x8, PPN = pte_page]; // Sv39
#else
    #error Invalid XLEN
#endif
    asm volatile("csrw satp, %r", satp);

    // Set up PMPs so we can read all memory.
    uint_xlen_t pmpaddr0 = -1;
    asm volatile("csrw pmpaddr0, %r", pmpaddr0);

    uint_xlen_t pmpcfg0 = // [Mk_Pmpcfg_ent(zeros()) with W=1, R=1, A=pmpAddrMatchType_to_bits(NAPOT)]);
    asm volatile("csrw pmpcfg0, %r", pmpcfg0);

    // Use MPRV to do loads and stores in supervisor mode.
    asm volatile("csrw mstatus ... MPRV=... MPP=...")

    // Read from the mapped page to get it into the TLB.
    volatile uint8_t byte = mapped_page[0];

    // Now only allow access to the page above the PTE, so the PTE can't be modified.
    pmpaddr0 = pte_page + 1; // TODO: Make this into the right NAPOT form.
    asm volatile("csrw pmpaddr0, %r", pmpaddr0);

    // Try to store to the mapped page. This *should* try to update the PTE and cause an access fault.
    mapped_page[4096] = 1;
}
