

// Call this function to indicate there is an incoming interrupt on the given
// source. For edge sensitive interrupts you just call this when you see
// the edge. For level sensitive interrupts you have to call this every cycle.
// Both implementations are allowed.
//
// If using edge sensitive interrupts then implementations can optionally
// use counters to record pending interrupts. This implementation doesn't do
// that, which I think inevitably means you can miss interrupts due to races:
//
// 1. First interrupt.
// 2. Hart claims first interrupt.
// 3. Hart services interrupt (e.g. reading buffer from MMIO device).
// 4. Second interrupt. This is lost because it's still claimed.
// 5. Hard completes first interrupt.
//
// TODO: Call this from C++, or from a "trickbox" style device.
function plic_source_interrupt(src : range(1, plic_nsrc)) -> unit =
  if plic_claimed[src-1] == 0b0 then {
    plic_pending[src-1] = 0b1;
  }

// PLIC register indices. Helpfully all PLIC registers are 32-bits so it's
// easy to convert addresses to register indices.
let PLIC_REG_PRIORITY_BASE = 0
let PLIC_REG_PRIORITY_END  = unsigned(0x1000) / 4

let PLIC_REG_PENDING_BASE = unsigned(0x1000) / 4
let PLIC_REG_PENDING_END  = unsigned(0x2000) / 4

let PLIC_REG_ENABLE_BASE = unsigned(0x2000) / 4
let PLIC_REG_ENABLE_END  = unsigned(0x1F2000) / 4

// Stride (in units of 32-bits) between contexts for the enable bits.
let PLIC_REG_ENABLE_CTX_STRIDE = 1024 / 32

// Config CSRs (priority, claim/complete).
let PLIC_REG_CONFIG_BASE = unsigned(0x200000) / 4
let PLIC_REG_CONFIG_END  = unsigned(0x4000000) / 4

// Stride (in units of 32-bits) between contexts for the config CSRs.
let PLIC_REG_CONFIG_CTX_STRIDE = unsigned(0x1000) / 4
// Offset to the registers within each context's config CSR block.
let PLIC_REG_CONFIG_THRESHOLD      = 0
let PLIC_REG_CONFIG_CLAIM_COMPLETE = 1

// Read the interrupt priority based on its interrupt ID (0 is reserved and will read zeros).
private function get_plic_priority_by_id(id : range(0, 1023)) -> bits(32) =
  if id > 0 & id <= plic_nsrc then plic_priority[id - 1] else zeros()

// Write the interrupt priority based on its interrupt ID (0 is reserved and writes are ignored).
private function set_plic_priority_by_id(id : range(0, 1023), v : bits(32)) -> unit =
  if id > 0 & id <= plic_nsrc then plic_priority[id - 1] = v

// This is not the most optimal but the indexing is kind of awkward.
private function get_plic_pending_word(word : range(0, 31)) -> bits(32) =
  zero_extend((plic_pending >> (word * 32))[min(32, length(plic_pending))-1 .. 0])

private function set_plic_pending_word(word : range(0, 31), v : bits(32)) -> unit = {
  let begin = word * 32;
  let end_ = begin + 32;
  // TODO
  // if begin < length(plic_pending) then plic_pending[min(length(plic_pending), end_) - 1 .. begin] = trunc(v);
  plic_pending[0] = 0b1;
}

private function get_plic_interrupt_enable_word(ctx : range(0, plic_nctx - 1), word : range(0, 31)) -> bits(32) =
  // TODO
  zeros()

private function set_plic_interrupt_enable_word(ctx : range(0, plic_nctx - 1), word : range(0, 31), v : bits(32)) -> unit = {
  // TODO
  plic_interrupt_enable[ctx][0] = 0b1;
}

// Get the highest priority enabled and pending interrupt for a given context.
// Returns the interrupt ID, using 0 for no interrupt.
private function plic_highest_priority_interrupt(ctx : range(0, plic_nctx-1)) -> range(0, plic_nsrc) = {
  var best_id : range(0, plic_nsrc) = 0;
  var best_priority : bits(32) = zeros();

  let threshold = plic_threshold[ctx];

  foreach (src from 1 to (plic_nsrc - 1)) {
    let priority = plic_priority[src];

    // "Ties between global interrupts of the same priority are broken by the
    // Interrupt ID; interrupts with the lowest ID have the highest effective priority."

    if priority >_u threshold &
      priority >_u best_priority &
      plic_interrupt_enable[ctx][src] == 0b1 &
      plic_pending[src] == 0b1 then {
      best_id = src;
      best_priority = priority;
    };
  };

  best_id
}

private function plic_update_eip() -> unit = {
  foreach (ctx from 0 to (plic_nctx - 1)) {
    plic_external_interrupt_pending[ctx] = bool_to_bit(plic_highest_priority_interrupt(ctx) != 0);
  }
}

private function plic_claim(ctx : range(0, plic_nctx-1)) -> range(0, plic_nsrc) = {
  // Find the highest priority interrupt for the context if any.
  let id = plic_highest_priority_interrupt(ctx);
  if id != 0 then {
    plic_claimed[id-1] = 0b1;
    plic_pending[id-1] = 0b0;
  };
  plic_update_eip();
  id
}

private function plic_complete(ctx : range(0, plic_nctx-1), src : bits(32)) -> unit = {
  let src = unsigned(src);
  if src > 0 & src < plic_nsrc then {
    // Ignored if the interrupt is not enabled for the context.
    if plic_interrupt_enable[ctx][src] == 0b1 then {
      plic_claimed[src-1] = 0b0;
      plic_update_eip();
    };
  };
}


private val plic_load : forall 'n, 'n > 0 . (MemoryAccessType(mem_payload), physaddr, int('n)) -> MemoryOpResult(bits(8 * 'n))
function plic_load(access, Physaddr(addr), width) = {
  // Offset within PLIC.
  let addr = addr - plat_plic_base;

  // This implementation of PLIC only supports aligned 32-bit accesses.
  // All registers in PLIC are 32-bit so that shouldn't be limiting.
  if 'n != 4 | addr[1 .. 0] != 0b00 then return Err(accessFaultFromAccessType(access));

  // Register index.
  let reg_idx = unsigned(addr) / 4;

  if reg_idx < PLIC_REG_PRIORITY_END then {
    // Priority
    let id = reg_idx - PLIC_REG_PRIORITY_BASE;
    Ok(get_plic_priority_by_id(id))

  } else if reg_idx < PLIC_REG_PENDING_END then {
    // Pending
    let word = reg_idx - PLIC_REG_PENDING_BASE;
    assert(word >= 0);
    assert(word < 32);
    Ok(get_plic_pending_word(word))

  } else if reg_idx < PLIC_REG_ENABLE_END then {
    // Enable
    let offset = reg_idx - PLIC_REG_ENABLE_BASE;
    assert(offset >= 0); // TODO: Shouldn't need this.
    let context = offset / PLIC_REG_ENABLE_CTX_STRIDE;
    let word = offset % PLIC_REG_ENABLE_CTX_STRIDE;
    Ok(get_plic_interrupt_enable_word(context, word))

  } else if reg_idx >= PLIC_REG_CONFIG_BASE & reg_idx < PLIC_REG_CONFIG_END then {
    // Config (Threshold and Claim/Complete)
    let offset = reg_idx - PLIC_REG_CONFIG_BASE;
    assert(offset >= 0); // TODO: Shouldn't need this.
    assert(PLIC_REG_CONFIG_CTX_STRIDE > 0);
    let context = offset / PLIC_REG_CONFIG_CTX_STRIDE;
    let context_offset = offset % PLIC_REG_CONFIG_CTX_STRIDE;

    if context_offset == PLIC_REG_CONFIG_THRESHOLD then {
      // Threshold. Unimplemented ones read as zero.
      // TODO: Does this handle the 0 context correctly? I'm not sure.
      Ok(if context < plic_nctx then plic_threshold[context] else zeros())
    } else if context_offset == PLIC_REG_CONFIG_CLAIM_COMPLETE then {
      // Claim/Complete. Reading this register performs the claim. It is not idempotent.
      // Unimplemented read as zero.
      // TODO: Check 0 src.
      Ok(if context < plic_nctx then to_bits(plic_claim(context)) else zeros())
    } else {
      Err(accessFaultFromAccessType(access))
    }
  } else Err(accessFaultFromAccessType(access))
}

private val plic_store : forall 'n, 'n > 0 . (physaddr, int('n), bits(8 * 'n)) -> MemoryOpResult(bool)
function plic_store(Physaddr(addr), width, data) = {
  // Offset within PLIC.
  let addr = addr - plat_plic_base;

  // This implementation of PLIC only supports aligned 32-bit accesses.
  // All registers in PLIC are 32-bit so that shouldn't be limiting.
  if 'n != 4 | addr[1 .. 0] != 0b00 then return Err(E_SAMO_Access_Fault());

  // Register index.
  let reg_idx = unsigned(addr) / 4;

  if reg_idx < PLIC_REG_PRIORITY_END then {
    // Priority
    let id = reg_idx - PLIC_REG_PRIORITY_BASE;
    assert(id >= 0);
    assert(id <= 1023); // TODO: Remove.
    set_plic_priority_by_id(id, data);
    plic_update_eip();
    Ok(true)

  } else if reg_idx < PLIC_REG_PENDING_END then {
    // The specification does not actually say what happens if you write to pending bits.
    // This implementation supports ORing the bits in (so you can set but not clear).
    // TODO.
    let word = reg_idx - PLIC_REG_PENDING_BASE;
    set_plic_pending_word(word, data);
    plic_update_eip();
    Ok(true)

  } else if reg_idx < PLIC_REG_ENABLE_END then {
    // Enable
    let offset = reg_idx - PLIC_REG_ENABLE_BASE;
    assert(offset >= 0); // TODO: Remove
    let context = offset / PLIC_REG_ENABLE_CTX_STRIDE;
    let word = offset % PLIC_REG_ENABLE_CTX_STRIDE;
    set_plic_enable_word(word, data);
    plic_update_eip();
    Ok(true)

  } else if reg_idx >= PLIC_REG_CONFIG_BASE & reg_idx < PLIC_REG_CONFIG_END then {
    // Config (Threshold and Claim/Complete)
    let offset = reg_idx - PLIC_REG_CONFIG_BASE;
    assert(offset >= 0); // TODO: Remove
    assert(PLIC_REG_CONFIG_CTX_STRIDE > 0); // TODO: Remove
    let context = offset / PLIC_REG_CONFIG_CTX_STRIDE;
    let context_offset = offset % PLIC_REG_CONFIG_CTX_STRIDE;

    if context_offset == PLIC_REG_CONFIG_THRESHOLD then {
      // Threshold. Unimplemented ones read as zero.
      if context < plic_nctx then plic_threshold[context] = data;
      Ok(true)
    } else if context_offset == PLIC_REG_CONFIG_CLAIM_COMPLETE then {
      // TODO
      // plic_complete(context, data);
      plic_update_eip();
      Ok(true)
    } else {
      Err(E_SAMO_Access_Fault())
    }
  } else Err(E_SAMO_Access_Fault())
}
