const std = @import("std");
const assert = std.debug.assert;
const testing = std.testing;
const Allocator = std.mem.Allocator;
const File = std.fs.File;

pub fn main() !void {
    var arena: std.heap.ArenaAllocator = .init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const argv = try std.process.argsAlloc(allocator);

    const cwd = std.fs.cwd();
    for (argv[1..]) |arg| {
        const file = cwd.openFile(arg, .{ .mode = .read_only }) catch |err| {
            std.debug.print("{any} \n", .{err});
            return;
        };
        defer file.close();
        std.debug.print("---Part 1---\n", .{});
        try part_1(allocator, file);
        std.debug.print("---Part 2---\n", .{});
        try part_2(allocator, file);
    }
}

pub fn part_1(arena: Allocator, file: File) !void {
    var max_rolls: usize = 0;

    var buffer: [8024]u8 = undefined;
    var file_reader = file.reader(&buffer);
    var grid: std.ArrayList([]u8) = try .initCapacity(arena, 1024);
    while (file_reader.interface.takeDelimiterExclusive('\n')) |line| {
        // Copy is needed because if the buffer size is filled, the reader makes another
        // syscall that will rewrite the current buffer resulting our appended slices to be
        // corrupted (meaning they point to a different data)
        const line_copy = try arena.dupe(u8, line);
        try grid.append(arena, line_copy);
    } else |err| switch (err) {
        error.StreamTooLong,
        error.ReadFailed,
        => |e| return e,
        else => {},
    }

    for (0..grid.items.len) |r| {
        for (0..grid.items[r].len) |c| {
            if (grid.items[r][c] != '@') continue;

            var adjacent_rolls: usize = 0;
            for (0..3) |i| {
                for (0..3) |j| {
                    if (i == 1 and j == 1) continue;

                    const nr = @as(isize, @intCast(r + i)) - 1;
                    const nc = @as(isize, @intCast(c + j)) - 1;

                    if (nr >= 0 and nr < grid.items.len and
                        nc >= 0 and nc < grid.items[r].len)
                    {
                        const neighbor_row: usize = @intCast(nr);
                        const neighbor_col: usize = @intCast(nc);

                        if (grid.items[neighbor_row][neighbor_col] == '@') {
                            adjacent_rolls += 1;
                        }
                    }
                }
            }

            if (adjacent_rolls < 4) {
                max_rolls += 1;
            }
        }
    }
    std.debug.print("Max rolls: {d}\n", .{max_rolls});
}

pub fn part_2(arena: Allocator, file: File) !void {
    var max_rolls: usize = 0;

    var buffer: [8024]u8 = undefined;
    var file_reader = file.reader(&buffer);
    var grid: std.ArrayList([]u8) = try .initCapacity(arena, 1024);
    while (file_reader.interface.takeDelimiterExclusive('\n')) |line| {
        // Copy is needed because if the buffer size is filled, the reader makes another
        // syscall that will rewrite the current buffer resulting our appended slices to be
        // corrupted (meaning they point to a different data)
        const line_copy = try arena.dupe(u8, line);
        try grid.append(arena, line_copy);
    } else |err| switch (err) {
        error.StreamTooLong,
        error.ReadFailed,
        => |e| return e,
        else => {},
    }

    var changed = true;
    while (changed) {
        changed = false;
        var removed_this_pass: usize = 0;
        for (0..grid.items.len) |r| {
            for (0..grid.items[r].len) |c| {
                if (grid.items[r][c] != '@') continue;

                var adjacent_rolls: usize = 0;
                for (0..3) |i| {
                    for (0..3) |j| {
                        if (i == 1 and j == 1) continue;

                        const nr = @as(isize, @intCast(r + i)) - 1;
                        const nc = @as(isize, @intCast(c + j)) - 1;

                        if (nr >= 0 and nr < grid.items.len and
                            nc >= 0 and nc < grid.items[r].len)
                        {
                            const neighbor_row: usize = @intCast(nr);
                            const neighbor_col: usize = @intCast(nc);

                            if (grid.items[neighbor_row][neighbor_col] == '@') {
                                adjacent_rolls += 1;
                            }
                        }
                    }
                }

                if (adjacent_rolls < 4) {
                    grid.items[r][c] = 'x';
                    removed_this_pass += 1;
                    changed = true;
                }
            }
        }
        max_rolls += removed_this_pass;
    }
    std.debug.print("Max rolls: {d}\n", .{max_rolls});
}
