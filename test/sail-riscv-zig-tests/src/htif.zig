//! Runtime, providing the entry point, syscalls, etc.

const std = @import("std");

// Defined in crt0.S.
extern fn htif_putc(char: u8) void;

fn htifWriteFn(_: void, bytes: []const u8) error{}!usize {
    for (bytes) |byte| {
        htif_putc(byte);
    }
    return bytes.len;
}

const HtifWriter = std.io.Writer(void, error{}, htifWriteFn);

pub fn getHtifWriter() HtifWriter {
    return HtifWriter{
        .context = {},
    };
}
