const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const curl = b.dependency("curl", .{});

    const zig_aur = b.addExecutable(.{
        .target = target,
        .name = "zig-aur",
        .root_source_file = .{ .path = "src/main.zig" },
    });
    zig_aur.root_module.addImport("curl", curl.module("curl"));
    zig_aur.linkLibC();
    b.installArtifact(zig_aur);
}
