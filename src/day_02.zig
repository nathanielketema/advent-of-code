const std = @import("std");
const assert = std.debug.assert;
const testing = std.testing;
const Allocator = std.mem.Allocator;
const File = std.fs.File;
const pow = std.math.pow;

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
        std.debug.print("---Part 1---\n", .{});
        try part_1(file);
        std.debug.print("---Part 2---\n", .{});
        try part_2(file);
    }
}

pub fn part_1(file: File) !void {
    var total_invalid: usize = 0;

    var buffer: [1024]u8 = undefined;
    var file_reader = file.reader(&buffer);
    while (file_reader.interface.takeDelimiterExclusive(',')) |range| {
        assert(range.len > 0);
        var it = std.mem.tokenizeAny(u8, range, "-\n");
        const start = try std.fmt.parseInt(usize, it.next().?, 10);
        const end = try std.fmt.parseInt(usize, it.next().?, 10);

        assert(start <= end);
        for (start..end + 1) |num| {
            if (num_is_repeating_twice(num)) {
                total_invalid += num;
            }
        }
    } else |err| switch (err) {
        error.StreamTooLong,
        error.ReadFailed,
        => |e| return e,
        else => {},
    }
    std.debug.print("Total Invalid IDs: {d}\n", .{total_invalid});
}

pub fn part_2(file: File) !void {
    var total_invalid: usize = 0;

    var buffer: [1024]u8 = undefined;
    var file_reader = file.reader(&buffer);
    while (file_reader.interface.takeDelimiterExclusive(',')) |range| {
        var it = std.mem.tokenizeAny(u8, range, "-\n");
        const start = try std.fmt.parseInt(usize, it.next().?, 10);
        const end = try std.fmt.parseInt(usize, it.next().?, 10);

        for (start..end + 1) |num| {
            if (num_is_repeating(num)) {
                total_invalid += num;
            }
        }
    } else |err| switch (err) {
        error.StreamTooLong,
        error.ReadFailed,
        => |e| return e,
        else => {},
    }
    std.debug.print("Total Invalid IDs: {d}\n", .{total_invalid});
}

fn num_is_repeating(num: usize) bool {
    const digit_count: usize = count_digits(num);
    if (digit_count < 2) {
        return false;
    }

    var token_count: usize = 1;
    while (token_count * 2 <= digit_count) : (token_count += 1) {
        if (digit_count % token_count == 0) {
            const divisor = pow(usize, 10, digit_count - token_count);
            assert(divisor != 0);
            const pattern = @divTrunc(num, divisor);

            var reconstructed_num: usize = 0;
            const repetitions = digit_count / token_count;
            for (0..repetitions) |_| {
                reconstructed_num = pattern + reconstructed_num * pow(usize, 10, token_count);
            }

            if (reconstructed_num == num) {
                return true;
            }
        }
    }

    return false;
}

fn num_is_repeating_twice(num: usize) bool {
    const digit_count: usize = count_digits(num);
    if (digit_count % 2 != 0 and digit_count < 2) {
        return false;
    }

    const divisor = pow(usize, 10, digit_count / 2);
    assert(divisor != 0);
    const first_half = @divTrunc(num, divisor);
    const second_half = @mod(num, divisor);

    return first_half == second_half;
}

fn count_digits(num: usize) usize {
    if (num == 0) {
        return 1;
    }

    var temp = num;
    var count: usize = 0;
    while (temp > 0) : (temp /= 10) {
        count += 1;
    }
    return count;
}

test "day-02" {
    try testing.expect(num_is_repeating(222));
    try testing.expect(num_is_repeating(22222));
    try testing.expect(num_is_repeating(121212));
    try testing.expect(num_is_repeating(123123123));
}
