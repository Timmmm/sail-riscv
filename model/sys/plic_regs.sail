// =======================================================================================
// This Sail RISC-V architecture model, comprising all files and
// directories except where otherwise noted is subject the BSD
// two-clause license in the LICENSE file.
//
// SPDX-License-Identifier: BSD-2-Clause
// =======================================================================================

// Priority for each source, indexed by id-1.
register plic_priority : vector(plic_nsrc, bits(32)) = vector_init(zeros())
// IE bit for each context and source.
register plic_interrupt_enable : vector(plic_nctx, bits(plic_nsrc + 1)) = vector_init([zeros(plic_nsrc + 1) with 0 = 0b1])
// Threshold for each context.
register plic_threshold : vector(plic_nctx, bits(32)) = vector_init(zeros())

// Pending and claimed state for each source.
register plic_pending : bits(plic_nsrc + 1) = [zeros(plic_nsrc + 1) with 0 = 0b1]
register plic_claimed : bits(plic_nsrc + 1) = [zeros(plic_nsrc + 1) with 0 = 0b1]

// Explicit External Interrupt Pending for each context. These are just copied
// into `mip` for harts, but they can be connected to other devices too.
register plic_external_interrupt_pending : bits(plic_nctx) = zeros()
