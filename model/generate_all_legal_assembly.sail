function print_legal_instruction forall 'n . (inst : instruction, opcode : bits('n)) -> unit =
  match inst {
    ILLEGAL(_) => (),
    C_ILLEGAL(_) => (),
    // Temporarily skip reserved fences because there's no assembly syntax for them.
    // See https://github.com/riscv/sail-riscv/issues/1013
    FENCE_RESERVED(_) => (),
    FENCEI_RESERVED(_) => (),
    _ => {
      print_endline(assembly(inst));
      print_endline("r " ^ bits_str(opcode));
    },
  }

function generate_all_legal_assembly() -> unit = {
  // It's slightly unfortunate that our disassembler is conflated with
  // whether instructions are enabled or not.
  mstatus[FS] = 0b01;
  mstatus[VS] = 0b01;
  vtype[vill] = 0b0;

  // Macro to output the reference data to a different .text section.
  print_endline(".macro r opcode");
  print_endline("  .previous");
  print_endline("  .insn \\opcode");
  print_endline("  .previous");
  print_endline(".endm");

  // Set up the test and reference sections. The order matters.
  print_endline(".section .text.reference");
  print_endline(".section .text.assembly");

  // 16-bit instructions.
  foreach (i from 0 to (2 ^ 14 - 1)) {
    foreach (k from 0 to 2) {
      let opcode = to_bits(14, i) @ to_bits(2, k);
      print_legal_instruction(encdec_compressed(opcode), opcode);
    }
  };

  // 32-bit instructions.
  // foreach (i from 3407899 to (2 ^ 30 - 1)) {
  //   let opcode = to_bits(30, i) @ 0b11;
  //   // print_endline("Testing opcode " ^ bits_str(opcode));
  //   print_legal_instruction(encdec(opcode), opcode);
  // };
}
