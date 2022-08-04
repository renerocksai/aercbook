const std = @import("std");
const edit_distance = @import("levenshtein.zig").edit_distance;
const sort = std.sort.sort;

var input: []const u8 = undefined;

fn score(input_word: []const u8, compared_to: []const u8) i32 {
    var dist: i32 = @intCast(i32, edit_distance(input_word, compared_to));
    if (std.mem.startsWith(u8, compared_to, input_word)) {
        // if the input matches beginning of compared_to, we decrease the
        // distance to rank it higher at the top
        dist -= @intCast(i32, input_word.len);
    }
    return dist;
}

fn comp_levenshtein(comptime T: type) fn (void, T, T) bool {
    const impl = struct {
        fn inner(context: void, a: T, b: T) bool {
            _ = context;
            const distance_a = score(input, a);
            const distance_b = score(input, b);
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
            var itt = std.mem.split(u8, line, ":");
            if (itt.next()) |key| {
                if (itt.next()) |value| {
                    const trimmed_key = std.mem.trim(u8, key, " ");
                    const trimmed_value = std.mem.trim(u8, value, " ");
                    try map.put(trimmed_key, trimmed_value);
                    try list.append(trimmed_key);
                }
            }
        }
    } else |err| {
        const errwriter = std.io.getStdErr().writer();
        try errwriter.print("Error {s}: {s}\n", .{ err, filn });
        return;
    }

    //
    // search
    //
    if (input[0] == '*') {
        // we output everything
        var it = map.valueIterator();
        while (it.next()) |value| {
            try std.io.getStdOut().writer().print("{s}\n", .{value.*});
        }
        return;
    }

    if (std.mem.indexOf(u8, input, "*")) |index| {
        // search for keys starting with input
        sort([]const u8, list.items, {}, comptime comp_levenshtein([]const u8));
        for (list.items) |key| {
            if (std.mem.startsWith(u8, key, input[0..index])) {
                if (map.get(key)) |v| {
                    try std.io.getStdOut().writer().print("{s}\n", .{v});
                }
            }
        }
        return;
    }

    // default: levenshtein search
    sort([]const u8, list.items, {}, comptime comp_levenshtein([]const u8));
    for (list.items[0..std.math.min(5, list.items.len)]) |key| {
        if (map.get(key)) |v| {
            // bug in aerc.conf: tab separated lines are NOT supported
            // std.debug.print("{s}\t{s}\n", .{ v, key });
            try std.io.getStdOut().writer().print("{s}\n", .{v});
        }
    }
}
