const std = @import("std");
const edit_distance = @import("levenshtein.zig").edit_distance;
const sort = std.sort.sort;

var input: []const u8 = undefined;

pub fn comp_levenshtein(comptime T: type) fn (void, T, T) bool {
    const impl = struct {
        fn inner(context: void, a: T, b: T) bool {
            _ = context;
            const distance_a = edit_distance(input, a);
            const distance_b = edit_distance(input, b);
            return distance_a < distance_b;
        }
    };
    return impl.inner;
}

fn help(exe: []const u8) void {
    std.debug.print("Usage: {s} inputfile search-term\n", .{exe});
}

pub fn main() anyerror!void {
    const alloc = std.heap.page_allocator;

    //
    // get cmd line args
    //
    var arg_it = std.process.args();

    const prog_name = try arg_it.next(alloc) orelse "aercbook";

    var filn: []const u8 = try arg_it.next(alloc) orelse "";
    if (filn.len == 0) {
        help(prog_name);
        return;
    }

    var search: []const u8 = try arg_it.next(alloc) orelse "";
    if (search.len == 0) {
        help(prog_name);
        return;
    }

    input = search;

    //
    // parse input file
    //

    const max_file_size = 1024 * 1024;
    var list = std.ArrayList([]const u8).init(alloc);
    defer list.deinit();

    var map = std.StringHashMap([]const u8).init(alloc);
    defer map.deinit();
    if (std.fs.cwd().openFile(filn, .{ .read = true })) |f| {
        defer f.close();
        const buffer = try f.readToEndAlloc(alloc, max_file_size);
        var it = std.mem.split(u8, buffer, "\n");
        var index: usize = 0;
        while (it.next()) |line_untrimmed| {
            index += 1;
            const line = std.mem.trimRight(u8, line_untrimmed, " \t\n");
            // std.debug.print("Processing line {} : {s}\n", .{ index, line });
            var itt = std.mem.split(u8, line, ":");
            if (itt.next()) |key| {
                if (itt.next()) |value| {
                    const trimmed_key = std.mem.trim(u8, key, " ");
                    const trimmed_value = std.mem.trim(u8, value, " ");
                    try map.put(trimmed_key, trimmed_value);
                    try list.append(trimmed_key);
                    // bug in aerc.conf: tab separated lines are NOT supported
                    // std.debug.print("   ==> {s} : {s}\n", .{ trimmed_key, trimmed_value });
                }
            }
        }
    } else |err| {
        std.debug.print("{s} : {s}", .{ err, filn });
        return;
    }

    //
    // search
    //
    sort([]const u8, list.items, {}, comptime comp_levenshtein([]const u8));
    for (list.items[0..std.math.min(5, list.items.len)]) |key| {
        const value = map.get(key);
        if (value) |v| {
            // std.debug.print("{s}\t{s}\n", .{ v, key });
            try std.io.getStdOut().writer().print("{s}\n", .{v});
        }
    }
}
