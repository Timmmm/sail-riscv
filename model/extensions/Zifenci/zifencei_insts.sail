// =======================================================================================
// This Sail RISC-V architecture model, comprising all files and
// directories except where otherwise noted is subject the BSD
// two-clause license in the LICENSE file.
//
// SPDX-License-Identifier: BSD-2-Clause
// =======================================================================================

// *****************************************************************
// This file specifies the instructions in the 'Zifencei' extension.

// *****************************************************************

function clause currentlyEnabled(Ext_Zifencei) = hartSupports(Ext_Zifencei)

union clause instruction = FENCEI : unit

union clause ast = FENCEI : (bits(12), regidx, regidx)

mapping clause encdec = FENCEI(imm, rs, rd)
  <-> imm : bits(12) @ encdec_reg(rs) @ 0b001 @ encdec_reg(rd) @ 0b0001111

// fence.i is a nop for the memory model
function clause execute FENCEI() = { /* __barrier(Barrier_RISCV_i); */ RETIRE_SUCCESS }

mapping clause assembly = FENCEI(imm, rs, rd) <-> "fence.i"
  when imm == zeros() & rs == zreg & rd == zreg
