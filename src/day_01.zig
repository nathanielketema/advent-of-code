const std = @import("std");
const assert = std.debug.assert;
const testing = std.testing;
const Allocator = std.mem.Allocator;
const File = std.fs.File;

const max_dial = 99;

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
    var password: usize = 0;
    var dial: isize = 50;

    var buffer: [1024]u8 = undefined;
    var file_reader = file.reader(&buffer);
    while (file_reader.interface.takeDelimiterExclusive('\n')) |rule| {
        const command = rule[0];
        const rotation = try std.fmt.parseInt(isize, rule[1..], 10);
        switch (command) {
            'L' => {
                dial -= rotation;
            },
            'R' => {
                dial += rotation;
            },
            else => unreachable,
        }
        dial = @mod(dial, max_dial + 1);

        if (dial == 0) {
            password += 1;
        }
    } else |err| switch (err) {
        error.StreamTooLong,
        error.ReadFailed,
        => |e| return e,
        else => {},
    }
    std.debug.print("Password: {d}\n", .{password});
}

pub fn part_2(file: File) !void {
    var password: isize = 0;
    var dial: isize = 50;

    var buffer: [1024]u8 = undefined;
    var file_reader = file.reader(&buffer);
    while (file_reader.interface.takeDelimiterExclusive('\n')) |rule| {
        const command = rule[0];
        const rotation = try std.fmt.parseInt(isize, rule[1..], 10);
        const change = @mod(rotation, max_dial + 1);

        password += @divFloor(rotation, max_dial + 1);
        switch (command) {
            'L' => {
                const diff = dial - change;
                if (dial != 0 and diff <= 0) {
                    password += 1;
                }
                dial = @mod(diff, max_dial + 1);
            },
            'R' => {
                const diff = dial + change;
                if (diff >= max_dial + 1) {
                    password += 1;
                }
                dial = @mod(diff, max_dial + 1);
            },
            else => unreachable,
        }
    } else |err| switch (err) {
        error.StreamTooLong,
        error.ReadFailed,
        => |e| return e,
        else => {},
    }
    std.debug.print("Password: {d}\n", .{password});
}

test "day-01" {}
