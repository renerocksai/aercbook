const std = @import("std");
const gitVersionTag = @import("src/gitversiontag.zig").gitVersionTag;

pub fn build(b: *std.Build) void {
    // write src/version.zig
    const alloc = std.heap.page_allocator;
    const gvs = gitVersionTag(alloc);
    const efmt = "WARNING: could not write src/version.zig:\n   {!}\n";
    if (std.fs.cwd().createFile("src/version.zig", .{})) |file| {
        defer file.close();
        const zigfmt = "pub const version_string = \"{s}\";";
        if (std.fmt.allocPrint(alloc, zigfmt, .{gvs})) |strline| {
            if (file.writeAll(strline)) {} else |e| {
                std.io.getStdErr().writer().print(efmt, .{e}) catch unreachable;
            }
        } else |err| {
            std.io.getStdErr().writer().print(efmt, .{err}) catch unreachable;
        }
    } else |err| {
        std.io.getStdErr().writer().print(efmt, .{err}) catch unreachable;
    }

    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "aercbook",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    const unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/email_iterator.zig" },
        .target = target,
        .optimize = optimize,
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}
