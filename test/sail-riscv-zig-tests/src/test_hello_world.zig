//! Simple hello world example.

const std = @import("std");
const runtime = @import("runtime");

pub export fn main() u8 {
    if (test_main()) |_| {
        return 0;
    } else |_| {
        return 1;
    }
}

fn test_main() !void {
    const stdout = runtime.htif.getHtifWriter();

    try stdout.print("Hello {s}{c} {d} {d} {d:.6}\n", .{ "worl", 'd', 1, 2, 3.0 });
}
