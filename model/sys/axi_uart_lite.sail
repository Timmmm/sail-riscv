// =======================================================================================
// This Sail RISC-V architecture model, comprising all files and
// directories except where otherwise noted is subject the BSD
// two-clause license in the LICENSE file.
//
// SPDX-License-Identifier: BSD-2-Clause
// =======================================================================================

// This implements the AXI UART Lite MMIO device. See https://docs.amd.com/v/u/en-US/pg142-axi-uartlite
//
// It has four 32-bit registers:
//
// 0: RX     Read from this to get a character in the lowest byte. Higher bytes are reserved.
//           Input data is queued (in the real device it is a 16-deep FIFO). Reading
//           when the FIFO is empty results in an access fault.
// 1: TX     Write to this to send a character. Only the lowest byte is used; higher
//           bytes are ignored. On the real device writing to a full FIFO causes
//           an access fault but that can't happen here.
// 2: CTRL   Allows enabling/disabling the input interrupt (not currently supported)
//           and clearing the FIFOs (has no effect). Reads as 0.
// 3: STAT   Allows inspecting errors, FIFO status, and whether the interrupt is enabled.

// Address to put the AXI UART Lite at, if enabled. This is obtained from a symbol in the ELF.
register uart_base : option(physaddrbits) = None()
let uart_size = 4 * 4
// This is called externally. bits(64) is used because it's easier to deal with from C.
function enable_axi_uart_lite(addr : bits(64)) -> unit = uart_base = Some(trunc(addr))

private function within_uart_writable forall 'n, 0 < 'n <= max_mem_access . (Physaddr(addr) : physaddr, width : int('n)) -> bool =
  match uart_base {
    None() => false,
    Some(base) => (addr <_u base + uart_size) & (addr + width >_u base)
  }

private function within_uart_readable forall 'n, 0 < 'n <= max_mem_access . (addr : physaddr, width : int('n)) -> bool =
  within_uart_writable(addr, width)

bitfield UartCtrl : bits(32) = {
    ENABLE_INTR   : 4,
    RESET_RX_FIFO : 1,
    RESET_TX_FIFO : 0,
}

bitfield UartStat : bits(32) = {
    PARITY_ERROR       : 7,
    FRAME_ERROR        : 6,
    OVERRUN_ERROR      : 5,
    INTR_ENABLED       : 4,
    TX_FIFO_FULL       : 3,
    TX_FIFO_EMPTY      : 2,
    RX_FIFO_FULL       : 1,
    // "VALID_DATA" means not empty.
    RX_FIFO_VALID_DATA : 0,
}

// Is the interrupt enabled. This currently isn't connected anywhere.
register uart_intr_enabled : bool = false

// TX fifo isn't used; we always send data immediately.
// RX "fifo" is only 1 deep for simplicity. A deeper FIFO can be implemented
// on the C++ side if necessary.
register uart_rx_fifo : option(bits(8)) = None()

// Call this from C++ to add a character to the RX FIFO. It returns false
// if there's no space.
function uart_rx(ch : bits(8)) -> bool =
  match uart_rx_fifo {
    Some(_) => false,
    None() => {
      uart_rx_fifo = Some(ch);
      true
    },
  }

private val uart_load : forall 'n, 'n > 0 . (MemoryAccessType(mem_payload), physaddr, int('n)) -> MemoryOpResult(bits(8 * 'n))
function uart_load(access, Physaddr(addr), width) = {
  let base : physaddrbits = match uart_base {
    Some(base) => base,
    None() => internal_error(__FILE__, __LINE__, "AXI UART Lite load while it isn't enabled"),
  };

  let addr = addr - base;

  // Only 32-bit accesses are supported.
  if 'n != 4 | addr[1 .. 0] != 0b00 then return Err(accessFaultFromAccessType(access));

  match unsigned(addr[length(addr) - 1 .. 2]) {
    // RX
    0 => {
      match uart_rx_fifo {
        Some(ch) => {
          uart_rx_fifo = None();
          Ok(zero_extend(ch))
        },
        None() => Err(accessFaultFromAccessType(access)),
      }
    },
    // TX, reads as zero.
    1 => Ok(zeros()),
    // CTRL, reads as zero.
    2 => Ok(zeros()),
    // STAT
    3 => Ok([Mk_UartStat(zeros()) with
      INTR_ENABLED = bool_to_bit(uart_intr_enabled),
      TX_FIFO_FULL = 0b0,
      TX_FIFO_EMPTY = 0b1,
      RX_FIFO_FULL = bool_to_bit(is_some(uart_rx_fifo)),
      RX_FIFO_VALID_DATA = bool_to_bit(is_some(uart_rx_fifo)),
    ].bits),
    _ => internal_error(__FILE__, __LINE__, "Read from unexpected AXI UART Lite address"),
  }
}

private val uart_store : forall 'n, 'n > 0 . (physaddr, int('n), bits(8 * 'n)) -> MemoryOpResult(bool)
function uart_store(Physaddr(addr), width, data) = {
  let base : physaddrbits = match uart_base {
    Some(base) => base,
    None() => internal_error(__FILE__, __LINE__, "AXI UART Lite store while it isn't enabled"),
  };

  let addr = addr - base;

  // Only 32-bit accesses are supported.
  if 'n != 4 | addr[1 .. 0] != 0b00 then return Err(E_SAMO_Access_Fault());

  match unsigned(addr[length(addr) - 1 .. 2]) {
    // RX, ignored.
    0 => Ok(true),
    // TX
    1 => {
      plat_term_write(data[7..0]);
      Ok(true)
    },
    // CTRL
    2 => {
      let ctrl = Mk_UartCtrl(data);
      uart_intr_enabled = bit_to_bool(ctrl[ENABLE_INTR]);
      if ctrl[RESET_RX_FIFO] == 0b1 then {
        uart_rx_fifo = None();
      };
      Ok(true)
    },
    // STAT, ignored.
    3 => Ok(true),
    _ => internal_error(__FILE__, __LINE__, "Write to unexpected AXI UART Lite address"),
  }
}
