const std = @import("std");
const assert = std.debug.assert;
const testing = std.testing;
const Allocator = std.mem.Allocator;
const File = std.fs.File;

pub fn main() !void {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
    defer assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    const argv = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, argv);

    const cwd = std.fs.cwd();
    for (argv[1..]) |arg| {
        const file = cwd.openFile(arg, .{ .mode = .read_only }) catch |err| {
            std.debug.print("{any} \n", .{err});
            return;
        };
        defer file.close();
        std.debug.print("---Part 1---\n", .{});
        try part_1(file);
        std.debug.print("---Part 2---\n", .{});
        try part_2(file);
    }
}

pub fn part_1(file: File) !void {
    var total_output_joltage: usize = 0;

    var buffer: [1024]u8 = undefined;
    var file_reader = file.reader(&buffer);
    while (file_reader.interface.takeDelimiterExclusive('\n')) |line| {
        var max_slice: [2]u8 = .{ 0, 0 };
        var picked_index: usize = 0;
        for (0..line.len - 1) |i| {
            if (line[i] > max_slice[0]) {
                max_slice[0] = line[i];
                picked_index = i;
            }
        }

        for (picked_index + 1..line.len) |i| {
            max_slice[1] = @max(max_slice[1], line[i]);
        }

        const line_max = try std.fmt.parseInt(usize, &max_slice, 10);
        total_output_joltage += line_max;
    } else |err| switch (err) {
        error.StreamTooLong,
        error.ReadFailed,
        => |e| return e,
        else => {},
    }
    std.debug.print("Total Output Joltage: {d}\n", .{total_output_joltage});
}

pub fn part_2(file: File) !void {
    const battery_count = 12;
    var total_output_joltage: usize = 0;

    var buffer: [1024]u8 = undefined;
    var file_reader = file.reader(&buffer);
    while (file_reader.interface.takeDelimiterExclusive('\n')) |line| {
        var max_slice: [battery_count]u8 = undefined;
        var index: usize = 0;
        for (0..battery_count) |i| {
            const start = if (i == 0) 0 else index + 1;
            const end = line.len - (battery_count - i - 1);
            var max: u8 = 0;
            for (start..end) |j| {
                if (line[j] > max) {
                    max = line[j];
                    index = j;
                }
            }
            max_slice[i] = max;
        }

        const line_max = try std.fmt.parseInt(usize, &max_slice, 10);
        total_output_joltage += line_max;
    } else |err| switch (err) {
        error.StreamTooLong,
        error.ReadFailed,
        => |e| return e,
        else => {},
    }
    std.debug.print("Total Output Joltage: {d}\n", .{total_output_joltage});
}
