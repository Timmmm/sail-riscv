// Verify that an access fault caused by making a PTE
// inaccessible (via PMP in this case) and then having
// the hardware update it works as expected.
$[test]
function test_pte_update_access_fault() -> unit = {
    assert(plat_enable_dirty_update(), "Test requires hardware PTE updates to be enabled.");
    assert(virtual_memory_supported(), "Test requires virtual memory support.");
    assert(sys_pmp_count() != 0, "Test requires PMPs.");

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
    X(3) = if xlen == 32
           then [Mk_Satp32(zeros()) with Mode = 0b1, PPN = pte_page]  // Sv32
           else [Mk_Satp64(zeros()) with Mode = 0x8, PPN = pte_page]; // Sv39

    assert(execute(CSRReg(csr_name_map("satp"), 0b00011, zreg, CSRRW)) == RETIRE_SUCCESS);

    // Set up PMPs so we can read all memory.
    X(3) = ones();
    assert(execute(CSRReg(csr_name_map("pmpaddr0"), 0b00011, zreg, CSRRW)) == RETIRE_SUCCESS);

    X(3) = zero_extend([Mk_Pmpcfg_ent(zeros()) with W=1, R=1, A=pmpAddrMatchType_to_bits(NAPOT)]);
    assert(execute(CSRReg(csr_name_map("pmpcfg0"), 0b00011, zreg, CSRRW)) == RETIRE_SUCCESS);

    // Magically switch to supervisor mode.
    cur_privilege = Supervisor;

    // Read from the mapped page to get it into the TLB.
    assert(execute(LOAD(zeros(), 0b0001, 0b0010, WORD, false, false)) == RETIRE_SUCCESS);

    // Now only allow access to the page above the PTE, so the PTE can't be modified.
    cur_privilege = Machine;
    X(3) = (pte_page + 1); // TODO: Make this into the right NAPOT form.
    assert(execute(CSRReg(csr_name_map("pmpaddr0"), 0b00011, zreg, CSRRW)) == RETIRE_SUCCESS);
    cur_privilege = Supervisor;

    // Try to store to the mapped page. This *should* try to update the PTE and cause an access fault.
    X(1) = pte_address;
    X(2) = pte_value;
    assert(execute(STORE(zeros(), 0b0010, 0b0001, WORD, false, false)) != RETIRE_SUCCESS);
}
