const std = @import("std");
pub fn gitVersionTag(alloc: std.mem.Allocator) ![]const u8 {
    const args = [_][]const u8{
        "git",
        "tag",
        "--sort=-creatordate",
    };

    if (std.ChildProcess.exec(.{ .argv = args[0..], .allocator = alloc })) |result| {
        // print stdout
        //std.debug.print("{s}\n", .{result.stdout});
        if (std.mem.split(u8, result.stdout, "\n").next()) |firstline| {
            return firstline;
        } else {
            return "unknown";
        }
    } else |err| {
        std.log.err("Unable to spawn and wait:  {any}", .{err});
    }
    return "unknown";
}
