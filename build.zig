const std = @import("std");
const gitVersionTag = @import("src/gitversiontag.zig").gitVersionTag;

pub fn build(b: *std.build.Builder) void {
    // write src/version.zig
    const alloc = std.heap.page_allocator;
    const gvs = gitVersionTag(alloc);
    if (std.fs.cwd().createFile("src/version.zig", .{})) |file| {
        defer file.close();
        if (std.fmt.allocPrint(alloc, "pub const version_string = \"{s}\";", .{gvs})) |strline| {
            if (file.writeAll(strline)) {} else |err| {
                std.io.getStdErr().writer().print("WARNING: could not write src/version.zig:\n   {s}\n", .{err}) catch unreachable;
            }
        } else |err| {
            std.io.getStdErr().writer().print("WARNING: could not write src/version.zig\n   {s}\n", .{err}) catch unreachable;
        }
    } else |err| {
        std.io.getStdErr().writer().print("WARNING: could not create src/version.zig:\n   {s}\n", .{err}) catch unreachable;
    }

    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable("aercbook", "src/main.zig");
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_tests = b.addTest("src/main.zig");
    exe_tests.setTarget(target);
    exe_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&exe_tests.step);
}
