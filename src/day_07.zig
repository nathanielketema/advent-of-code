const std = @import("std");
const assert = std.debug.assert;

const Allocator = std.mem.Allocator;
const File = std.fs.File;

const read_buffer_size: u32 = 8024;

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

    var lines: std.ArrayList([]const u8) = .empty;
    while (file_reader.interface.takeDelimiterExclusive('\n')) |line| {
        const line_copy = try arena.dupe(u8, line);
        try lines.append(arena, line_copy);
    } else |err| switch (err) {
        error.StreamTooLong,
        error.ReadFailed,
        => |e| return e,
        else => {},
    }

    const grid = lines.items;
    const height = grid.len;
    const width = grid[0].len;

    const start_col = std.mem.indexOfScalar(u8, grid[0], 'S').?;

    var active_beams: std.AutoHashMap(usize, void) = .init(arena);
    var next_beams: std.AutoHashMap(usize, void) = .init(arena);

    try active_beams.put(start_col, {});

    var split_count: u64 = 0;
    var row: usize = 1;
    while (row < height) : (row += 1) {
        next_beams.clearRetainingCapacity();

        var it = active_beams.keyIterator();
        while (it.next()) |col_ptr| {
            const col = col_ptr.*;
            if (col < width and grid[row][col] == '^') {
                split_count += 1;

                if (col > 0) try next_beams.put(col - 1, {});
                if (col + 1 < width) try next_beams.put(col + 1, {});
            } else if (col < width) {
                try next_beams.put(col, {});
            }
        }
        std.mem.swap(std.AutoHashMap(usize, void), &active_beams, &next_beams);

        if (active_beams.count() == 0) break;
    }

    std.debug.print("Beam Split Count: {d}\n", .{split_count});
}

pub fn part_2(arena: Allocator, file: File) !void {
    var read_buffer: [read_buffer_size]u8 = undefined;
    var file_reader = file.reader(&read_buffer);

    var lines: std.ArrayList([]const u8) = .empty;
    while (file_reader.interface.takeDelimiterExclusive('\n')) |line| {
        const line_copy = try arena.dupe(u8, line);
        try lines.append(arena, line_copy);
    } else |err| switch (err) {
        error.StreamTooLong,
        error.ReadFailed,
        => |e| return e,
        else => {},
    }

    const grid = lines.items;
    const height = grid.len;
    const width = grid[0].len;
    const start_col = std.mem.indexOfScalar(u8, grid[0], 'S').?;

    var timeline_counts: std.AutoHashMap(usize, u64) = .init(arena);
    var next_counts: std.AutoHashMap(usize, u64) = .init(arena);

    try timeline_counts.put(start_col, 1);

    var row: usize = 1;
    while (row < height) : (row += 1) {
        next_counts.clearRetainingCapacity();

        var it = timeline_counts.iterator();
        while (it.next()) |entry| {
            const col = entry.key_ptr.*;
            const count = entry.value_ptr.*;

            if (col < width and grid[row][col] == '^') {
                if (col > 0) {
                    const gop_left = try next_counts.getOrPut(col - 1);
                    if (!gop_left.found_existing) {
                        gop_left.value_ptr.* = 0;
                    }
                    gop_left.value_ptr.* += count;
                }

                if (col + 1 < width) {
                    const gop_right = try next_counts.getOrPut(col + 1);
                    if (!gop_right.found_existing) {
                        gop_right.value_ptr.* = 0;
                    }
                    gop_right.value_ptr.* += count;
                }
            } else if (col < width) {
                const gop = try next_counts.getOrPut(col);
                if (!gop.found_existing) {
                    gop.value_ptr.* = 0;
                }
                gop.value_ptr.* += count;
            }
        }
        std.mem.swap(std.AutoHashMap(usize, u64), &timeline_counts, &next_counts);

        if (timeline_counts.count() == 0) break;
    }

    var total: u64 = 0;
    var it = timeline_counts.valueIterator();
    while (it.next()) |count_ptr| {
        total += count_ptr.*;
    }
    std.debug.print("Total timeline: {d}\n", .{total});
}

test "day_07" {}
