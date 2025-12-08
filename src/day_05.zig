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
        std.debug.print("{s}\n", .{arg});
        std.debug.print("---Part 1---\n", .{});
        try part_1(allocator, file);
        std.debug.print("---Part 2---\n", .{});
        try part_2(allocator, file);
    }
}

pub fn part_1(arena: Allocator, file: File) !void {
    var fresh_count: usize = 0;

    var buffer: [8024]u8 = undefined;
    var file_reader = file.reader(&buffer);
    // Range
    var fresh_range: std.ArrayList([2]u64) = .empty;
    while (file_reader.interface.takeDelimiterExclusive('\n')) |line| {
        if (line.len == 0) break;
        var it = std.mem.tokenizeScalar(u8, line, '-');
        var range = [2]u64{ 0, 0 };
        range[0] = try std.fmt.parseInt(u64, it.next().?, 10);
        range[1] = try std.fmt.parseInt(u64, it.next().?, 10);

        try fresh_range.append(arena, range);
    } else |err| switch (err) {
        error.StreamTooLong,
        error.ReadFailed,
        => |e| return e,
        else => {},
    }

    // Ingredient IDs
    while (file_reader.interface.takeDelimiterExclusive('\n')) |line| {
        const id = try std.fmt.parseInt(u64, line, 10);
        if (is_fresh(id, fresh_range.items)) {
            fresh_count += 1;
        }
    } else |err| switch (err) {
        error.StreamTooLong,
        error.ReadFailed,
        => |e| return e,
        else => {},
    }
    std.debug.print("Fresh Count: {d}\n", .{fresh_count});
}

pub fn part_2(arena: Allocator, file: File) !void {
    var possible_fresh_count: usize = 0;

    const Range = struct {
        start: u64,
        end: u64,
    };

    var buffer: [8024]u8 = undefined;
    var file_reader = file.reader(&buffer);
    var fresh_range: std.ArrayList(Range) = .empty;
    while (file_reader.interface.takeDelimiterExclusive('\n')) |line| {
        if (line.len == 0) break;
        var it = std.mem.tokenizeScalar(u8, line, '-');
        const range: Range = .{
            .start = try std.fmt.parseInt(u64, it.next().?, 10),
            .end = try std.fmt.parseInt(u64, it.next().?, 10),
        };

        try fresh_range.append(arena, range);
    } else |err| switch (err) {
        error.StreamTooLong,
        error.ReadFailed,
        => |e| return e,
        else => {},
    }

    // Sort ranges by start point
    std.mem.sort(Range, fresh_range.items, {}, struct {
        fn lessThan(_: void, a: Range, b: Range) bool {
            return a.start < b.start;
        }
    }.lessThan);

    assert(fresh_range.items.len > 0);
    var current_start = fresh_range.items[0].start;
    var current_end = fresh_range.items[0].end;

    for (fresh_range.items[1..]) |range| {
        if (range.start <= current_end + 1) {
            current_end = @max(current_end, range.end);
        } else {
            possible_fresh_count += current_end - current_start + 1;
            current_start = range.start;
            current_end = range.end;
        }
    }
    possible_fresh_count += current_end - current_start + 1;

    std.debug.print("Fresh Count: {d}\n", .{possible_fresh_count});
}

fn is_fresh(id: u64, range: [][2]u64) bool {
    for (range) |item| {
        if (id >= item[0] and id <= item[1]) {
            return true;
        }
    }
    return false;
}
