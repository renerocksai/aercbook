const std = @import("std");
const edit_distance = @import("levenshtein.zig").edit_distance;
const sort = std.sort.heap;
const version_string = @import("version.zig").version_string;
const argsParser = @import("args.zig");
const emailIterator = @import("email_iterator.zig");

var input: []const u8 = undefined;

fn score(input_word: []const u8, compared_to: []const u8) i32 {
    var dist: i32 = @intCast(edit_distance(input_word, compared_to));
    if (std.mem.startsWith(u8, compared_to, input_word)) {
        // if the input matches beginning of compared_to, we decrease the
        // distance to rank it higher at the top
        dist -= @intCast(input_word.len * 2);
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

fn help() void {
    std.debug.print(
        \\ aercbook {s}
        \\ Search in inputfile's keys for provided search-term.
        \\ Or add to inputfile.
        \\
        \\Usage:
        \\  Search :
        \\    aercbook inputfile search-term
        \\
        \\    search-term may be:
        \\       * : dump entire address book (values)
        \\     xx* : search for keys that start with xx, dump their values
        \\     xxx : fuzzy-search for keys that match xx, dump their values
        \\
        \\  Add by key and value :
        \\    aercbook inputfile -a key [value]
        \\
        \\    Adding only a key will set the value identical to the key:
        \\    -a mykey        ->  will add "mykey : mykey" to the inputfile
        \\    -a mykey  value ->  will add "mykey : value" to the inputfile
        \\
        \\  Add-from e-mail :
        \\  cat email | aercbook inputfile --parse [--add-all] [--add-from] [--add-to] \
        \\                                         [--add-cc]
        \\
        \\    Parses the piped-in e-mail for e-mail addresses. Specify any
        \\    combination of --add-from, --add-to, and --add-cc, or use
        \\    --add-all to add them all.
        \\
        \\    --add-from : scan the e-mail for From: addresses and add them
        \\    --add-to   : scan the e-mail for To: addresses and add them
        \\    --add-cc   : scan the e-mail for CC: addresses and add them
        \\    --add-all  : scan the e-mail for all of the above and add them
        \\
        \\    Note: e-mails like `My Name <my.name@domain.org>` will be
        \\    split into:
        \\      key  : My Name
        \\      value: My Name <my.name@domain.org>
        \\
    , .{version_string});
}

fn readAddressBook(
    alloc: std.mem.Allocator,
    filn: []const u8,
    max_fs: usize,
    keylist: *std.ArrayList([]const u8),
    kvmap: *std.StringHashMap([]const u8),
) !void {
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

fn decodeUtf8(str: []const u8, buffer: []u8) []const u8 {
    const trimmed = std.mem.trim(u8, str, " \t");
    const utf8_needle = "=?UTF-8?B?";
    if (std.ascii.indexOfIgnoreCase(trimmed, utf8_needle)) |start| {
        const end = "?=";
        if (!std.mem.endsWith(u8, trimmed[start..], end)) return str;
        const b64 = trimmed[start + utf8_needle.len .. trimmed.len - end.len];
        // std.debug.print("Decoding: {s}\n", .{b64});
        const decoder = std.base64.standard.Decoder;
        const decoded_size = decoder.calcSizeForSlice(b64) catch {
            // std.debug.print("Padding error!\n", .{});
            return str;
        };
        std.base64.standard.Decoder.decode(buffer, b64) catch return str;
        return buffer[0..decoded_size];
    }
    return str;
}

fn replaceUtf8(str: []const u8, out_buffer: []u8) []const u8 {
    var buffer: [512]u8 = undefined;
    const trimmed = std.mem.trim(u8, str, " \t");
    const utf8_needle = "=?UTF-8?B?";
    if (std.ascii.indexOfIgnoreCase(trimmed, utf8_needle)) |start| {
        const end = "?=";
        const endpos = std.mem.indexOf(u8, trimmed, end) orelse 0;
        if (endpos == 0) return str;
        const b64 = trimmed[start + utf8_needle.len .. endpos];
        // std.debug.print("Decoding: {s}\n", .{b64});
        const decoder = std.base64.standard.Decoder;
        const decoded_size = decoder.calcSizeForSlice(b64) catch {
            // std.debug.print("Padding error!\n", .{});
            return str;
        };
        std.base64.standard.Decoder.decode(&buffer, b64) catch return str;
        const what = trimmed[start .. endpos + 2];
        const with = buffer[0..decoded_size];
        const replacement_size = std.mem.replacementSize(u8, trimmed, what, with);
        _ = std.mem.replace(u8, trimmed, what, with, out_buffer);
        // std.debug.print("In `{s}`, replacing `{s}` with `{s}` -> `{s}`\n", .{ trimmed, what, with, out_buffer });
        return out_buffer[0..replacement_size];
    }
    return str;
}

fn addToAddressBook(
    filn: []const u8,
    key: []const u8,
    value: []const u8,
) !void {
    var file = try std.fs.cwd().createFile(filn, .{
        .read = true,
        .truncate = false,
    });
    defer file.close();
    try file.seekFromEnd(0);
    try file.writer().print("\n{s} : {s}", .{ key, value });
}

fn addEmailsToAddressBook(
    filn: []const u8,
    map: std.StringHashMap([]const u8),
    emails: std.StringHashMap([]const u8),
) !void {
    var file = try std.fs.cwd().createFile(filn, .{
        .read = true,
        .truncate = false,
    });
    defer file.close();
    try file.seekFromEnd(0);
    var it = emails.iterator();
    var key_buffer: [512]u8 = undefined;
    var val_buffer: [512]u8 = undefined;
    while (it.next()) |item| {
        const decoded_key = decodeUtf8(item.key_ptr.*, &key_buffer);
        if (map.contains(decoded_key)) {
            std.debug.print("key exists: `{s}`\n", .{decoded_key});
            continue;
        }
        const decoded_val = replaceUtf8(item.value_ptr.*, &val_buffer);
        try file.writer().print("\n{s} : {s}", .{
            decoded_key,
            decoded_val,
        });
        std.debug.print("Added {s} -> {s}\n", .{
            decoded_key,
            decoded_val,
        });
    }
}

const ParseMailResult = struct {
    from: std.StringHashMap([]const u8),
    to: std.StringHashMap([]const u8),
    cc: std.StringHashMap([]const u8),
    const Self = @This();
    fn init(a: std.mem.Allocator) !Self {
        return Self{
            .from = std.StringHashMap([]const u8).init(a),
            .to = std.StringHashMap([]const u8).init(a),
            .cc = std.StringHashMap([]const u8).init(a),
        };
    }
};

const EmailSplitResult = struct {
    name: []const u8,
    email: []const u8,
    all: []const u8,
};

fn splitEmailSplitResult(email: []const u8) EmailSplitResult {
    var ret = EmailSplitResult{ .name = email, .email = email, .all = email };

    var ltindex: usize = 0;
    if (std.mem.lastIndexOf(u8, email, "<")) |indexofLessthan| {
        ltindex = indexofLessthan;
        if (std.mem.lastIndexOf(u8, email, "\"")) |indexofQuote| {
            if (indexofQuote > indexofLessthan) {
                // < is within quotes, ignore
                ltindex = 0;
            }
        }
    }

    // if the email starts with <, there would be nothing as a key
    // before the <, so only split if pos of < is > 1, like in
    // `x <x@y.com`
    if (ltindex > 1) {
        ret.name = std.mem.trim(u8, email[0..ltindex], " ");
        ret.email = email[ltindex..email.len];
    }
    return ret;
}

fn parseAddresses(
    a: std.mem.Allocator,
    buf: []u8,
    map: *std.StringHashMap([]const u8),
) !void {
    // first, split by comma
    var it = emailIterator.init(buf);
    while (it.next()) |addr| {
        // split into parts separated by whitespace
        var t_it = std.mem.tokenize(u8, addr, " \t\n\r");
        var parts = std.ArrayList([]const u8).init(a);
        while (t_it.next()) |part| {
            try parts.append(part);
        }
        // join back again into nice email address without excessive
        // whitespace
        const email = try std.mem.join(a, " ", parts.items);

        // we figure out how to best split off a key
        const split = splitEmailSplitResult(email);

        try map.put(split.name, split.all);
    }
}

const ParseMailError = error{
    ReadError,
};

fn parseMailFromStdin(alloc: std.mem.Allocator) !ParseMailResult {
    const stdin = std.io.getStdIn();

    // read the 1st megabyte - we're interested in the header only
    const buffer = try alloc.alloc(u8, 1024 * 1024);

    const howmany = try stdin.reader().read(buffer);
    if (howmany <= 0) return error.ReadError;

    var ret = try ParseMailResult.init(alloc);

    // we don't tokenize, so we get \r for empty line
    var it = std.mem.split(u8, buffer, "\n");

    // first collect the headers
    var from_pos: usize = 0;
    var from_end: usize = 0;
    var to_pos: usize = 0;
    var to_end: usize = 0;
    var cc_pos: usize = 0;
    var cc_end: usize = 0;
    var current_end: ?*usize = null;

    while (it.next()) |line| {
        // end of header section will be a single \r
        if (line.len <= 1) {
            break;
        }

        if (std.ascii.startsWithIgnoreCase(line, "from:")) {
            from_pos = it.index.? - line.len + 4;
            current_end = &from_end;
            from_end = it.index.? - 2;
            if (buffer[from_end] != '\r') from_end += 1;
            continue;
        }
        if (std.ascii.startsWithIgnoreCase(line, "to:")) {
            to_pos = it.index.? - line.len + 2;
            current_end = &to_end;
            to_end = it.index.? - 2;
            if (buffer[to_end] != '\r') to_end += 1;
            continue;
        }
        if (std.ascii.startsWithIgnoreCase(line, "cc:")) {
            cc_pos = it.index.? - line.len + 2;
            current_end = &cc_end;
            cc_end = it.index.? - 2;
            if (buffer[cc_end] != '\r') cc_end += 1;
            continue;
        }

        if (std.mem.startsWith(u8, line, "\t") or std.mem.startsWith(u8, line, " ")) {
            // std.debug.print("continuation\n", .{});
            if (current_end != null) {
                current_end.?.* = it.index.? - 2;
                if (buffer[current_end.?.*] != '\r') current_end.?.* += 1;
            }
        } else {
            current_end = null;
        }
    }
    if (from_pos != 0 and from_end != 0) {
        // std.debug.print("->from: `{s}`\n", .{buffer[from_pos..from_end]});
        try parseAddresses(alloc, buffer[from_pos..from_end], &ret.from);
    }

    if (to_pos != 0 and to_end != 0) {
        // std.debug.print("->to: `{s}`\n", .{buffer[to_pos..to_end]});
        try parseAddresses(alloc, buffer[to_pos..to_end], &ret.to);
    }

    if (cc_pos != 0 and cc_end != 0) {
        // std.debug.print("->cc: `{s}`\n", .{buffer[cc_pos..cc_end]});
        try parseAddresses(alloc, buffer[cc_pos..cc_end], &ret.cc);
    }

    return ret;
}

pub fn main() anyerror!void {
    const alloc = std.heap.page_allocator;

    //
    // get cmd line args
    //

    if (argsParser.parseForCurrentProcess(struct {
        // This declares long options for double hyphen
        @"add-from": bool = false,
        @"add-to": bool = false,
        @"add-cc": bool = false,
        @"add-all": bool = false,
        add: bool = false,
        help: bool = false,
        parse: bool = false,
        interactive: bool = false,

        // This declares short-hand options for single hyphen
        pub const shorthands = .{
            .a = "add",
        };
    }, alloc, .print)) |options| {
        defer options.deinit();

        const o = options.options;

        var filn: []const u8 = undefined;
        var search: []const u8 = undefined;
        const add_mode: bool =
            o.add or o.parse or o.@"add-from" or o.@"add-to" or
            o.@"add-cc" or o.@"add-all";

        // no args at all or --help
        if (o.help or (options.positionals.len == 0 and !add_mode)) {
            help();
            return;
        }

        if (options.positionals.len == 0) {
            help();
            return;
        } else {
            filn = options.positionals[0];
        }

        const max_file_size = 1024 * 1024;
        var list = std.ArrayList([]const u8).init(alloc);
        defer list.deinit();

        var map = std.StringHashMap([]const u8).init(alloc);
        defer map.deinit();

        //
        // parse email -> add mode
        //
        if (o.parse) {
            if (!o.@"add-to" and !o.@"add-cc" and !o.@"add-from" and
                !o.@"add-all")
            {
                help();
                return;
            }

            if (readAddressBook(alloc, filn, max_file_size, &list, &map)) {
                // do nothing
            } else |err| {
                const errwriter = std.io.getStdErr().writer();
                try errwriter.print("Warning {!}: {s} --> creating it...\n", .{ err, filn });
            }
            const ret = try parseMailFromStdin(alloc);

            if (o.@"add-all" or o.@"add-from") {
                try addEmailsToAddressBook(filn, map, ret.from);
            }
            if (o.@"add-all" or o.@"add-to") {
                try addEmailsToAddressBook(filn, map, ret.to);
            }
            if (o.@"add-all" or o.@"add-cc") {
                try addEmailsToAddressBook(filn, map, ret.cc);
            }
            return;
        }

        //
        // basic add-mode
        //
        if (o.add) {
            // we need an addr-book and a term to add
            if (options.positionals.len < 2) {
                help();
                return;
            }
            var key: []const u8 = options.positionals[1];
            var value: []const u8 = undefined;
            if (options.positionals.len >= 3) {
                value = options.positionals[2];
            } else {
                value = key;
            }

            if (readAddressBook(alloc, filn, max_file_size, &list, &map)) {
                //
            } else |err| {
                const errwriter = std.io.getStdErr().writer();
                try errwriter.print("Warning {!}: {s} --> creating it...\n", .{ err, filn });
            }

            var key_buffer: [512]u8 = undefined;
            var val_buffer: [512]u8 = undefined;
            const decoded_key = decodeUtf8(key, &key_buffer);
            // check if key exists
            if (map.contains(decoded_key)) {
                std.debug.print("key exists: `{s}`\n", .{decoded_key});
                return;
            }
            const decoded_val = replaceUtf8(value, &val_buffer);
            try addToAddressBook(filn, decoded_key, decoded_val);
            return;
        }

        //
        // search mode
        //
        if (options.positionals.len < 2) {
            // we need a search term
            help();
            return;
        }

        search = options.positionals[1];

        input = search;

        //
        // parse input file
        //

        if (readAddressBook(alloc, filn, max_file_size, &list, &map)) {
            // do nothing
        } else |err| {
            const errwriter = std.io.getStdErr().writer();
            try errwriter.print("Error {!}: {s}\n", .{ err, filn });
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
            sort(
                []const u8,
                list.items,
                {},
                comptime comp_levenshtein([]const u8),
            );
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
        for (list.items[0..@min(5, list.items.len)]) |key| {
            if (map.get(key)) |v| {
                // bug in aerc.conf: tab separated lines are NOT supported
                // std.debug.print("{s}\t{s}\n", .{ v, key });
                try std.io.getStdOut().writer().print("{s}\n", .{v});
            }
        }
    } else |err| {
        std.debug.print("{!}", .{err});
        help();
    }
}
