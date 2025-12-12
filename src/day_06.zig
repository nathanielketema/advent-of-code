const std = @import("std");
const assert = std.debug.assert;

const Allocator = std.mem.Allocator;
const File = std.fs.File;

const read_buffer_size: u32 = 8024;

const Operator = enum {
    add,
    multiply,
};

const OperatorInfo = struct {
    op: Operator,
    position: usize,
};

pub fn main() !void {
    var arena: std.heap.ArenaAllocator = .init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();
    const argv = try std.process.argsAlloc(allocator);
    const cwd = std.fs.cwd();

    for (argv[1..]) |arg| {
        const file = cwd.openFile(arg, .{ .mode = .read_only }) catch |err| {
            std.debug.print("{any}\n", .{err});
            continue;
        };
        defer file.close();

        std.debug.print("{s}\n", .{arg});
        std.debug.print("---Part 1---\n", .{});
        try part_1(allocator, file);
        std.debug.print("---Part 2---\n", .{});
        try part_2(allocator, file);
    }
}

pub fn part_1(arena: Allocator, file: File) !void {
    var read_buffer: [read_buffer_size]u8 = undefined;
    var file_reader = file.reader(&read_buffer);

    // Parse input into rows of tokens (numbers or operators).
    var rows: std.ArrayList([][]const u8) = .empty;

    while (file_reader.interface.takeDelimiterExclusive('\n')) |line| {
        const line_owned = try arena.dupe(u8, line);

        var tokens: std.ArrayList([]const u8) = .empty;
        var tokenizer = std.mem.tokenizeScalar(u8, line_owned, ' ');

        while (tokenizer.next()) |token| {
            try tokens.append(arena, token);
        }

        try rows.append(arena, tokens.items);
    } else |err| switch (err) {
        error.StreamTooLong,
        error.ReadFailed,
        => |e| return e,
        else => {},
    }

    // At least one data row + operator row.
    assert(rows.items.len >= 2);

    const row_count = rows.items.len - 1; // Exclude operator row.
    const col_count = rows.items[0].len;
    const operator_row = rows.items[rows.items.len - 1];

    assert(operator_row.len == col_count);

    // Parse operators from the last row.
    var operators: std.ArrayList(Operator) = .empty;
    for (operator_row) |token| {
        if (std.mem.eql(u8, token, "*")) {
            try operators.append(arena, .multiply);
        } else if (std.mem.eql(u8, token, "+")) {
            try operators.append(arena, .add);
        } else {
            std.debug.print("Unknown operator: '{s}'\n", .{token});
            return error.InvalidOperator;
        }
    }

    var grand_total: u64 = 0;
    for (0..col_count) |col| {
        const operator = operators.items[col];
        var col_total: u64 = if (operator == .multiply) 1 else 0;

        for (0..row_count) |row| {
            const token = rows.items[row][col];
            const value = std.fmt.parseInt(u64, token, 10) catch |err| {
                std.debug.print("Failed to parse: '{s}'\n", .{token});
                return err;
            };

            switch (operator) {
                .add => col_total += value,
                .multiply => col_total *= value,
            }
        }

        grand_total += col_total;
    }

    std.debug.print("Grand total: {d}\n", .{grand_total});
}

pub fn part_2(arena: Allocator, file: File) !void {
    var read_buffer: [read_buffer_size]u8 = undefined;
    var file_reader = file.reader(&read_buffer);

    var raw_lines: std.ArrayList([]const u8) = .empty;

    while (file_reader.interface.takeDelimiterExclusive('\n')) |line| {
        const line_owned = try arena.dupe(u8, line);
        try raw_lines.append(arena, line_owned);
    } else |err| switch (err) {
        error.StreamTooLong,
        error.ReadFailed,
        => |e| return e,
        else => {},
    }

    assert(raw_lines.items.len >= 2);

    const row_count = raw_lines.items.len - 1; // Exclude operator row
    const operator_line = raw_lines.items[raw_lines.items.len - 1];

    var max_width: usize = 0;
    for (raw_lines.items) |line| {
        if (line.len > max_width) {
            max_width = line.len;
        }
    }

    var operators: std.ArrayList(OperatorInfo) = .empty;
    var char_col: usize = max_width;

    while (char_col > 0) {
        char_col -= 1;
        if (char_col < operator_line.len) {
            const c = operator_line[char_col];
            if (c == '+') {
                try operators.append(arena, .{
                    .op = .add,
                    .position = char_col,
                });
            } else if (c == '*') {
                try operators.append(arena, .{
                    .op = .multiply,
                    .position = char_col,
                });
            }
        }
    }

    var grand_total: u64 = 0;

    for (operators.items, 0..) |op_info, op_idx| {
        const end_pos: usize = if (op_idx == 0) max_width else operators.items[op_idx - 1].position;

        var col_total: u64 = if (op_info.op == .multiply) 1 else 0;

        var char_pos: usize = end_pos;
        while (char_pos > op_info.position) {
            char_pos -= 1;

            var number: u64 = 0;
            var has_digit = false;

            for (0..row_count) |row| {
                const line = raw_lines.items[row];
                if (char_pos < line.len) {
                    const c = line[char_pos];
                    if (c >= '0' and c <= '9') {
                        number = number * 10 + (c - '0');
                        has_digit = true;
                    }
                }
            }

            if (has_digit) {
                switch (op_info.op) {
                    .add => col_total += number,
                    .multiply => col_total *= number,
                }
            }
        }

        grand_total += col_total;
    }

    std.debug.print("Grand total: {d}\n", .{grand_total});
}

test "day_06" {}
