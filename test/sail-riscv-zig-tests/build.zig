const std = @import("std");
const Target = @import("std").Target;

// List of tests (src/<testname>.zig files).
const TESTS = [_][]const u8{
    "test_hello_world",
    "test_max_pmp",
};

const C_TESTS = [_][]const u8{
    "test_hello_worldc",
};

// Construct the build graph in `b` (this doesn't actually build anything itself).
pub fn build(b: *std.Build) void {
    const features = Target.riscv.Feature;
    var cpu_features = Target.Cpu.Feature.Set.empty;

    cpu_features.addFeature(@intFromEnum(features.i));
    cpu_features.addFeature(@intFromEnum(features.m));
    cpu_features.addFeature(@intFromEnum(features.a));
    cpu_features.addFeature(@intFromEnum(features.f));
    cpu_features.addFeature(@intFromEnum(features.zifencei));
    cpu_features.addFeature(@intFromEnum(features.zicsr));
    // cpu_features.addFeature(@intFromEnum(features.d));

    const target = b.resolveTargetQuery(.{
        .cpu_arch = .riscv32,
        // Note, this is really the default Environment (usually the
        // 4th component of the target triple). Calling it the ABI is wrong.
        .abi = .none,
        .os_tag = .freestanding,
        .cpu_features_add = cpu_features,
    });

    const optimize = b.standardOptimizeOption(.{});

    // Module for runtime support (crt0.S etc).
    const runtime_mod = b.createModule(.{
        .root_source_file = b.path("src/runtime.zig"),
        .target = target,
        .optimize = optimize,
    });

    runtime_mod.addCSourceFile(.{ .file = b.path("src/crt0.S") });

    for (TESTS) |name| {
        var buf: [512]u8 = undefined;
        const test_path = std.fmt.bufPrint(&buf, "src/{s}.zig", .{name}) catch std.debug.panic("Test path too long: {s}", .{name});

        const exe_mod = b.createModule(.{
            .root_source_file = b.path(test_path),
            .target = target,
            .optimize = optimize,
        });

        exe_mod.addImport("runtime", runtime_mod);

        const exe_name = std.fmt.bufPrint(&buf, "{s}.elf", .{name}) catch std.debug.panic("Test path too long: {s}", .{name});

        const exe = b.addExecutable(.{
            .name = exe_name,
            .root_module = exe_mod,
        });

        exe.setLinkerScript(b.path("src/link.ld"));

        b.installArtifact(exe);
    }

    for (C_TESTS) |name| {
        var buf: [512]u8 = undefined;
        const test_path = std.fmt.bufPrint(&buf, "src/{s}.c", .{name}) catch std.debug.panic("Test path too long: {s}", .{name});

        const exe_mod = b.createModule(.{
            .root_source_file = b.path("src/c_test_root.zig"),
            .target = target,
            .optimize = optimize,
        });

        exe_mod.addCSourceFile(.{ .file = b.path(test_path) });
        exe_mod.addCSourceFile(.{ .file = b.path("src/runtime.c") });

        exe_mod.addImport("runtime", runtime_mod);

        const exe_name = std.fmt.bufPrint(&buf, "{s}.elf", .{name}) catch std.debug.panic("Test path too long: {s}", .{name});

        const exe = b.addExecutable(.{
            .name = exe_name,
            .root_module = exe_mod,
        });

        exe.setLinkerScript(b.path("src/link.ld"));

        b.installArtifact(exe);
    }
}
