typedef unsigned int uint32_t;
typedef unsigned long uint64_t;

extern volatile uint64_t tohost;

// CSR
static inline uint64_t csrr_mip() {
  uint64_t x;
  asm volatile("csrr %0, mip" : "=r"(x));
  return x;
}

// mip.MEIP
// TODO: encoding.h has this already.
#define MIP_MEIP (1ull << 11)

// MMIO
static inline void write32(uint64_t addr, uint32_t val) {
  *(volatile uint32_t *)addr = val;
}
static inline uint32_t read32(uint64_t addr) {
  return *(volatile uint32_t *)addr;
}

// PLIC MMIO layout (matches Sail MVP)
#define PLIC_BASE 0x0c000000UL

#define OFF_PRIORITY 0x000000UL // 4*id
#define OFF_PENDING 0x001000UL  // pending injection (non-standard)
#define OFF_ENABLE 0x002000UL   // ctx0=M, ctx1=S (stride 0x80)
#define ENABLE_STRIDE 0x80UL

#define OFF_CTX 0x200000UL // ctx page
#define CTX_STRIDE 0x1000UL
#define OFF_THRESHOLD 0x0UL
#define OFF_CLAIM 0x4UL

// TODO: Types are wrong here. Should all be uint32_t I think.
static inline uint64_t PLIC_PRIORITY(int id) {
  return PLIC_BASE + OFF_PRIORITY + (uint64_t)id * 4;
}
static inline uint64_t PLIC_PENDING_WORD(int id) {
  return PLIC_BASE + OFF_PENDING + (uint64_t)(id / 32) * 4;
}
static inline uint64_t PLIC_ENABLE_WORD(int ctx, int id) {
  return PLIC_BASE + OFF_ENABLE + (uint64_t)ctx * ENABLE_STRIDE + (uint64_t)(id / 32) * 4;
}
static inline uint64_t PLIC_THRESHOLD(int ctx) {
  return PLIC_BASE + OFF_CTX + (uint64_t)ctx * CTX_STRIDE + OFF_THRESHOLD;
}
static inline uint64_t PLIC_CLAIM(int ctx) {
  return PLIC_BASE + OFF_CTX + (uint64_t)ctx * CTX_STRIDE + OFF_CLAIM;
}

// TODO: Use bool for `want_set` surely...
static bool wait_meip(int want_set) {
  for (int i = 0; i < 2000000; i++) {
    int is_set = (csrr_mip() & MIP_MEIP) ? 1 : 0;
    if (is_set == want_set) {
      return true;
    }
  }
  return false;
}

int main() {
  const int ctx = 0; // ctx0 = hart0/M
  const int src = 1; // IRQ ID

  // Configure: priority, threshold, enable
  write32(PLIC_PRIORITY(src), 1);
  if (read32(PLIC_PRIORITY(src)) != 1) {
    return 1;
  }

  write32(PLIC_THRESHOLD(ctx), 0);

  uint64_t en_addr = PLIC_ENABLE_WORD(ctx, src);
  uint32_t en = read32(en_addr);
  en |= (1u << (src % 32));
  write32(en_addr, en);

  // Inject pending (bring-up helper in Sail MVP)
  write32(PLIC_PENDING_WORD(src), (1u << (src % 32)));

  // External interrupt should assert
  if (!wait_meip(1)) {
    return 1;
  }

  // claim/complete
  uint32_t claim = read32(PLIC_CLAIM(ctx));
  if (claim != (uint32_t)src) {
    return 1;
  }
  write32(PLIC_CLAIM(ctx), claim);

  // External interrupt should deassert
  if (!wait_meip(0)) {
    return 1;
  }

  // Gating: threshold > priority blocks
  write32(PLIC_THRESHOLD(ctx), 2);
  write32(PLIC_PENDING_WORD(src), (1u << (src % 32)));
  for (unsigned i = 0; i < 500000; i++) {
    if (csrr_mip() & MIP_MEIP) {
      return 1;
    }
  }

  return 0;
}
