// =======================================================================================
// This Sail RISC-V architecture model, comprising all files and
// directories except where otherwise noted is subject the BSD
// two-clause license in the LICENSE file.
//
// SPDX-License-Identifier: BSD-2-Clause
// =======================================================================================

// Basic terminal character I/O.

val plat_term_write = impure {cpp: "plat_term_write", lem: "plat_term_write"} : bits(8) -> unit
val plat_term_read  = impure {cpp: "plat_term_read", lem: "plat_term_read"}  : unit -> bits(8)
