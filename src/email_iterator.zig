const std = @import("std");

const EmailIterator = struct {
    /// the buffer we work with, e.g. the FROM: line
    buffer: []const u8,
    index: usize = 0,

    const Self = @This();

    pub fn next(self: *Self) ?[]const u8 {
        const start = self.index;
        var end = self.buffer.len;
        var between_double_quotes: bool = false;
        if (self.index >= self.buffer.len) return null;
        while (self.index < self.buffer.len) : (self.index += 1) {
            switch (self.buffer[self.index]) {
                '"' => between_double_quotes = !between_double_quotes,
                ',' => if (!between_double_quotes) {
                    // we have hit a splitting comma
                    end = self.index;
                    self.index += 1; // skip the comma in next iteration
                    break;
                },
                else => {},
            }
        }
        return self.buffer[start..end];
    }
};

pub fn init(buffer: []const u8) EmailIterator {
    return .{
        .buffer = buffer,
        .index = 0,
    };
}
