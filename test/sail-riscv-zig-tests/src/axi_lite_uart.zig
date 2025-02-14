//! Runtime, providing the entry point, syscalls, etc.

const std = @import("std");

const AxiLiteUart = extern struct {
    rx: u32,
    tx: u32,
    stat: u32,
    ctrl: u32,
};

// Defined in crt0.S.
extern var mmio_axi_lite_uart: AxiLiteUart;

fn axiLiteWriteFn(_: void, bytes: []const u8) error{}!usize {
    const uart: *volatile AxiLiteUart = &mmio_axi_lite_uart;
    for (bytes) |byte| {
        while (uart.stat & (1 << 3) == 0) {}
        uart.tx = byte;
    }
    return bytes.len;
}

const UartWriter = std.io.Writer(void, error{}, axiLiteWriteFn);

pub fn getAxiLiteUartWriter() UartWriter {
    return UartWriter{
        .context = {},
    };
}
