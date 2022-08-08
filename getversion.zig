const std = @import("std");
const gitVersionTag = @import("src/gitversiontag.zig").gitVersionTag;

pub fn main() !void {
    const alloc = std.heap.page_allocator;
    const gvs = gitVersionTag(alloc);
    try std.io.getStdOut().writer().print("{s}", .{gvs});
}
