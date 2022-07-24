const std = @import("std");

// stolen (and adapted to runtime from comptime only) from: https://zigbin.io/7e8a78
pub fn edit_distance(start: []const u8, end: []const u8) u8 {
    const maxsize = 128;
    // Figure out why x and y are switched here.
    const x_dim = start.len + 1;
    const y_dim = end.len + 1;
    var matrix: [maxsize][maxsize]u8 = .{.{0} ** maxsize} ** maxsize;

    var n: u8 = 0;
    while (n < x_dim) : (n += 1) {
        matrix[0][n] = n;
    }

    n = 0;
    while (n < y_dim) : (n += 1) {
        matrix[n][0] = n;
    }

    var i: u8 = 1;
    while (i < x_dim) : (i += 1) {
        const letter_i = start[i - 1];
        var j: u8 = 1;
        while (j < y_dim) : (j += 1) {
            const letter_j = end[j - 1];
            if (letter_i == letter_j) {
                matrix[j][i] = matrix[j - 1][i - 1];
            } else {
                const delete: u8 = matrix[j][i - 1] + 1;
                const insert: u8 = matrix[j - 1][i] + 1;
                const substitute: u8 = matrix[j - 1][i - 1] + 1;
                var minimum: u8 = delete;
                if (insert < minimum) {
                    minimum = insert;
                }
                if (substitute < minimum) {
                    minimum = substitute;
                }
                matrix[j][i] = minimum;
            }
        }
    }

    if (false) {
        for (matrix) |row| {
            for (row) |cell| {
                std.debug.print("{} ", .{cell});
            }
            std.debug.print("\n", .{});
        }
    }

    return matrix[y_dim - 1][x_dim - 1];
}
