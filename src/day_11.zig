const std = @import("std");
const assert = std.debug.assert;

const Allocator = std.mem.Allocator;
const File = std.fs.File;

const read_buffer_size: u32 = 8024;

const NodeMemo = struct {
    both: ?usize = null,
    fft_only: ?usize = null,
    dac_only: ?usize = null,
    neither: ?usize = null,
};

pub fn main() !void {
    var arena_instance: std.heap.ArenaAllocator = .init(std.heap.page_allocator);
    defer arena_instance.deinit();
    const arena = arena_instance.allocator();

    const argv = try std.process.argsAlloc(arena);
    const cwd = std.fs.cwd();

    for (argv[1..]) |arg| {
        const file = cwd.openFile(arg, .{ .mode = .read_only }) catch |err| {
            std.debug.print("{any}\n", .{err});
            continue;
        };
        defer file.close();

        std.debug.print("{s}\n", .{arg});
        std.debug.print("---Part 1---\n", .{});
        try part_1(arena, file);
        std.debug.print("---Part 2---\n", .{});
        try part_2(arena, file);
    }
}

pub fn part_1(arena: Allocator, file: File) !void {
    var read_buffer: [read_buffer_size]u8 = undefined;
    var file_reader = file.reader(&read_buffer);

    var visited: std.StringHashMap(void) = .init(arena);
    var graph: std.StringHashMap(std.ArrayList([]const u8)) = .init(arena);
    while (file_reader.interface.takeDelimiterExclusive('\n')) |line| {
        const line_copy = try arena.dupe(u8, line);

        var it = std.mem.splitSequence(u8, line_copy, ": ");
        const source = it.next().?;
        const targets = it.next().?;

        const result = try graph.getOrPut(source);
        if (!result.found_existing) {
            result.value_ptr.* = std.ArrayList([]const u8).empty;
        }

        var targets_iterator = std.mem.tokenizeScalar(u8, targets, ' ');
        while (targets_iterator.next()) |target| {
            try result.value_ptr.append(arena, target);
        }
    } else |err| switch (err) {
        error.StreamTooLong,
        error.ReadFailed,
        => |e| return e,
        else => {},
    }

    const total_graph_count = count_path("you", "out", &graph, &visited);
    std.debug.print("Total: {d}\n", .{total_graph_count});
}

pub fn part_2(arena: Allocator, file: File) !void {
    var read_buffer: [read_buffer_size]u8 = undefined;
    var file_reader = file.reader(&read_buffer);

    var graph: std.StringHashMap(std.ArrayList([]const u8)) = .init(arena);
    while (file_reader.interface.takeDelimiterExclusive('\n')) |line| {
        const line_copy = try arena.dupe(u8, line);

        var it = std.mem.splitSequence(u8, line_copy, ": ");
        const source = it.next().?;
        const targets = it.next().?;

        const result = try graph.getOrPut(source);
        if (!result.found_existing) {
            result.value_ptr.* = std.ArrayList([]const u8).empty;
        }

        var targets_iterator = std.mem.tokenizeScalar(u8, targets, ' ');
        while (targets_iterator.next()) |target| {
            try result.value_ptr.append(arena, target);
        }
    } else |err| switch (err) {
        error.StreamTooLong,
        error.ReadFailed,
        => |e| return e,
        else => {},
    }

    var memo_map: std.StringHashMap(NodeMemo) = .init(arena);
    const total_graph_count = count_visiting_path(
        "svr",
        "out",
        false,
        false,
        &graph,
        &memo_map,
    );
    std.debug.print("Total: {d}\n", .{total_graph_count});
}

fn count_visiting_path(
    source: []const u8,
    target: []const u8,
    visited_fft: bool,
    visited_dac: bool,
    graph: *std.StringHashMap(std.ArrayList([]const u8)),
    memo_map: *std.StringHashMap(NodeMemo),
) usize {
    const now_fft = visited_fft or std.mem.eql(u8, source, "fft");
    const now_dac = visited_dac or std.mem.eql(u8, source, "dac");

    if (std.mem.eql(u8, source, target)) {
        return if (now_fft and now_dac) 1 else 0;
    }

    const gop = memo_map.getOrPut(source) catch unreachable;
    if (!gop.found_existing) {
        gop.value_ptr.* = NodeMemo{};
    }

    const cached_val = if (now_fft and now_dac)
        gop.value_ptr.both
    else if (now_fft)
        gop.value_ptr.fft_only
    else if (now_dac)
        gop.value_ptr.dac_only
    else
        gop.value_ptr.neither;

    if (cached_val) |res| {
        return res;
    }

    var total_graph_count: usize = 0;
    if (graph.get(source)) |neighbors| {
        for (neighbors.items) |neighbor| {
            total_graph_count += count_visiting_path(
                neighbor,
                target,
                now_fft,
                now_dac,
                graph,
                memo_map,
            );
        }
    }

    const memo_entry = memo_map.getPtr(source).?;
    if (now_fft and now_dac) {
        memo_entry.both = total_graph_count;
    } else if (now_fft) {
        memo_entry.fft_only = total_graph_count;
    } else if (now_dac) {
        memo_entry.dac_only = total_graph_count;
    } else {
        memo_entry.neither = total_graph_count;
    }

    return total_graph_count;
}

fn count_path(
    source: []const u8,
    target: []const u8,
    graph: *std.StringHashMap(std.ArrayList([]const u8)),
    visited: *std.StringHashMap(void),
) usize {
    if (std.mem.eql(u8, source, target)) {
        return 1;
    }

    visited.put(source, {}) catch unreachable;
    defer _ = visited.remove(source);

    var total_graph_count: usize = 0;
    if (graph.get(source)) |neighbors| {
        for (neighbors.items) |neighbor| {
            if (!visited.contains(neighbor)) {
                total_graph_count += count_path(neighbor, target, graph, visited);
            }
        }
    }

    return total_graph_count;
}

test "day_11" {}
