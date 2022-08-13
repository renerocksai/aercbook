const std = @import("std");
const edit_distance = @import("levenshtein.zig").edit_distance;
const sort = std.sort.sort;
const version_string = @import("version.zig").version_string;
const argsParser = @import("args.zig");

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
    std.debug.print("aercbook {s}\n", .{version_string});
    std.debug.print("Usage: {s} inputfile [search-term] | [-a key [value]]\n", .{exe});
    std.debug.print(
        \\ Search in inputfile's keys for provided search-term.
        \\ Or add to inputfile.
        \\
        \\ search-term may be:
        \\     * : dump entire address book (values)
        \\   xx* : search for keys that start with xx, dump their values
        \\   xxx : fuzzy-search for keys that match xx, dump their values
        \\
        \\ Adding only a key will set the value identical to the key:
        \\   -a mykey        ->  will add "mykey : mykey" to the inputfile
        \\   -a mykey  value ->  will add "mykey : value" to the inputfile
        \\
    , .{});
}

fn readAddressBook(alloc: std.mem.Allocator, filn: []const u8, max_fs: usize, keylist: *std.ArrayList([]const u8), kvmap: *std.StringHashMap([]const u8)) !void {
    var file = try std.fs.cwd().openFile(filn, .{});
    defer file.close();
    const buffer = try file.readToEndAlloc(alloc, max_fs);
    var it = std.mem.split(u8, buffer, "\n");
    var index: usize = 0;
    while (it.next()) |line_untrimmed| {
        index += 1;
        const line = std.mem.trimRight(u8, line_untrimmed, " \t\n");
        var itt = std.mem.split(u8, line, ":");
        var trimmed_key: []const u8 = undefined;
        var trimmed_value: []const u8 = undefined;
        if (itt.next()) |k| {
            trimmed_key = std.mem.trim(u8, k, " ");
            if (trimmed_key.len == 0) continue;
            if (itt.next()) |value| {
                trimmed_value = std.mem.trim(u8, value, " ");
            } else {
                trimmed_value = trimmed_key;
            }
            try kvmap.put(trimmed_key, trimmed_value);
            try keylist.append(trimmed_key);
        }
    }
}

fn addToAddressBook(filn: []const u8, key: []const u8, value: []const u8) !void {
    var file = try std.fs.cwd().openFile(filn, .{ .write = true });
    defer file.close();
    try file.seekFromEnd(0);
    try file.writer().print("\n{s} : {s}", .{ key, value });
}

pub fn main() anyerror!void {
    const alloc = std.heap.page_allocator;

    //
    // get cmd line args
    //

    if (argsParser.parseForCurrentProcess(struct {
        // This declares long options for double hyphen
        // @"add-from": bool = false,
        // @"add-cc": bool = false,
        // @"add-to": bool = false,
        add: bool = false,
        help: bool = false,

        // This declares short-hand options for single hyphen
        pub const shorthands = .{
            .a = "add",
        };
    }, alloc, .print)) |options| {
        defer options.deinit();

        const o = options.options;
        const prog_name = options.executable_name orelse "aercbook";

        var filn: []const u8 = undefined;
        var search: []const u8 = undefined;
        const add_mode: bool = o.add; // o.@"add-from" or o.@"add-cc" or o.@"add-to" or o.add != null;

        // no args at all or --help
        if (o.help or (options.positionals.len == 0 and !add_mode)) {
            help(prog_name);
            return;
        }

        const max_file_size = 1024 * 1024;
        var list = std.ArrayList([]const u8).init(alloc);
        defer list.deinit();

        var map = std.StringHashMap([]const u8).init(alloc);
        defer map.deinit();

        //
        // basic add-mode
        //
        if (o.add) {
            // we need an addr-book
            if (options.positionals.len < 2) {
                help(prog_name);
                return;
            }
            filn = options.positionals[0];
            var key: []const u8 = options.positionals[1];
            var value: []const u8 = undefined;
            if (options.positionals.len >= 3) {
                value = options.positionals[2];
            } else {
                value = key;
            }

            if (readAddressBook(alloc, filn, max_file_size, &list, &map)) {} else |err| {
                const errwriter = std.io.getStdErr().writer();
                try errwriter.print("Error {s}: {s}\n", .{ err, filn });
                return;
            }
            // check if key exists
            if (map.contains(key)) {
                std.debug.print("key exists: `{s}`\n", .{key});
                return;
            }
            try addToAddressBook(filn, key, value);
            return;
        }

        //
        // search mode
        //
        if (options.positionals.len < 2) {
            help(options.executable_name orelse "aercbook");
            return;
        }

        filn = options.positionals[0];
        search = options.positionals[1];

        input = search;

        //
        // parse input file
        //

        if (readAddressBook(alloc, filn, max_file_size, &list, &map)) {} else |err| {
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
    } else |err| {
        std.debug.print("{s}", .{err});
        help("aercbook");
    }
}
