const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const csvzero_dep = b.dependency("csvzero", .{});
    const csvzero_mod = csvzero_dep.module("csvzero");

    const debug_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = .Debug,
        .link_libc = true,
    });
    debug_mod.addImport("csvzero", csvzero_mod);
    const debug_exe = b.addExecutable(.{ .name = "benchmarks", .root_module = debug_mod });
    debug_exe.root_module.linkSystemLibrary("pcre2-8", .{});
    b.installArtifact(debug_exe);

    const zig_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = .ReleaseSafe,
        .link_libc = true,
    });
    zig_mod.addImport("csvzero", csvzero_mod);
    const zig_exe = b.addExecutable(.{ .name = "zig", .root_module = zig_mod });
    zig_exe.root_module.linkSystemLibrary("pcre2-8", .{});
    b.installArtifact(zig_exe);

    const unchecked_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = .ReleaseFast,
        .link_libc = true,
    });
    unchecked_mod.addImport("csvzero", csvzero_mod);
    const unchecked_exe = b.addExecutable(.{ .name = "zig-unchecked", .root_module = unchecked_mod });
    unchecked_exe.root_module.linkSystemLibrary("pcre2-8", .{});
    b.installArtifact(unchecked_exe);

    const maxperf_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = .ReleaseFast,
        .link_libc = true,
    });
    maxperf_mod.addImport("csvzero", csvzero_mod);
    const maxperf_exe = b.addExecutable(.{ .name = "zig-maxperf", .root_module = maxperf_mod });
    maxperf_exe.root_module.linkSystemLibrary("pcre2-8", .{});
    b.installArtifact(maxperf_exe);

    const legacy_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = .ReleaseFast,
        .link_libc = true,
    });
    legacy_mod.addImport("csvzero", csvzero_mod);
    const legacy_exe = b.addExecutable(.{ .name = "benchmarks-release", .root_module = legacy_mod });
    legacy_exe.root_module.linkSystemLibrary("pcre2-8", .{});
    b.installArtifact(legacy_exe);

    const build_debug_step = b.step("build-debug", "Build only debug version (benchmarks)");
    const install_debug = b.addInstallArtifact(debug_exe, .{});
    build_debug_step.dependOn(&install_debug.step);

    const build_zig_step = b.step("build-zig", "Build standard Zig release (safe)");
    const install_zig = b.addInstallArtifact(zig_exe, .{});
    build_zig_step.dependOn(&install_zig.step);

    const build_unchecked_step = b.step("build-unchecked", "Build Zig without safety checks");
    const install_unchecked = b.addInstallArtifact(unchecked_exe, .{});
    build_unchecked_step.dependOn(&install_unchecked.step);

    const build_maxperf_step = b.step("build-maxperf", "Build Zig with max performance");
    const install_maxperf = b.addInstallArtifact(maxperf_exe, .{});
    build_maxperf_step.dependOn(&install_maxperf.step);

    const build_release_step = b.step("build-release", "Build release (legacy)");
    const install_release = b.addInstallArtifact(legacy_exe, .{});
    build_release_step.dependOn(&install_release.step);

    const build_all_step = b.step("build", "Build all benchmarks");
    build_all_step.dependOn(build_debug_step);
    build_all_step.dependOn(build_zig_step);
    build_all_step.dependOn(build_unchecked_step);
    build_all_step.dependOn(build_maxperf_step);
    build_all_step.dependOn(build_release_step);
}
