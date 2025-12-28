const std = @import("std");
const assert = std.debug.assert;

const Allocator = std.mem.Allocator;
const File = std.fs.File;

const read_buffer_size: u32 = 8024;

const Coordinate = struct {
    x: i32,
    y: i32,
    z: i32,
};

const Pair = struct {
    first: usize,
    second: usize,
    distance_squared: u64,
};

const UnionFind = struct {
    /// Parent index for each element.
    /// If parent[index] == index, then index is a root.
    parent: []usize,

    /// Count of elements in the tree rooted at each index.
    /// - Only valid for root elements
    element_count: []usize,
    disjoint_set_count: usize,
    capacity: usize,

    /// Initialize a union-find structure where each element is its own set.
    fn init(allocator: Allocator, capacity: usize) !UnionFind {
        assert(capacity > 0);

        const parent = try allocator.alloc(usize, capacity);
        const element_count = try allocator.alloc(usize, capacity);

        for (0..capacity) |index| {
            parent[index] = index;
            element_count[index] = 1;
        }

        return .{
            .parent = parent,
            .element_count = element_count,
            .disjoint_set_count = capacity,
            .capacity = capacity,
        };
    }

    fn deinit(allocator: Allocator, self: *UnionFind) void {
        allocator.free(self.parent);
        allocator.free(self.element_count);
    }

    /// Find the representative (root) of the set containing the element at index.
    fn find(self: *UnionFind, index: usize) usize {
        assert(index < self.capacity);

        if (self.parent[index] == index) {
            return index;
        }

        const root_index = self.find(self.parent[index]);

        // Path compression: point directly to root.
        self.parent[index] = root_index;

        return root_index;
    }

    /// Union the sets containing elements at index_x and index_y.
    /// Uses union by count to keep trees balanced (smaller tree attaches to larger).
    /// Returns true if a merge occurred, false if already in the same set.
    fn merge(self: *UnionFind, index_x: usize, index_y: usize) bool {
        assert(index_x < self.capacity);
        assert(index_y < self.capacity);

        if (self.connected(index_x, index_y)) {
            return false;
        }

        const root_x = self.find(index_x);
        const root_y = self.find(index_y);

        const count_x = self.element_count[root_x];
        const count_y = self.element_count[root_y];
        const merged_count = count_x + count_y;

        if (count_x < count_y) {
            self.parent[root_x] = root_y;
            self.element_count[root_y] = merged_count;
        } else {
            self.parent[root_y] = root_x;
            self.element_count[root_x] = merged_count;
        }
        self.disjoint_set_count -= 1;

        return true;
    }

    fn connected(self: *UnionFind, index_x: usize, index_y: usize) bool {
        assert(index_x < self.capacity);
        assert(index_y < self.capacity);

        return self.find(index_x) == self.find(index_y);
    }

    fn set_element_count(self: *UnionFind, index: usize) usize {
        assert(index < self.capacity);

        const root_index = self.find(index);
        return self.element_count[root_index];
    }
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

    var coordinates: std.ArrayList(Coordinate) = .empty;
    while (file_reader.interface.takeDelimiterExclusive('\n')) |line| {
        var it = std.mem.tokenizeScalar(u8, line, ',');
        try coordinates.append(arena, .{
            .x = try std.fmt.parseInt(i32, it.next().?, 10),
            .y = try std.fmt.parseInt(i32, it.next().?, 10),
            .z = try std.fmt.parseInt(i32, it.next().?, 10),
        });
    } else |err| switch (err) {
        error.StreamTooLong,
        error.ReadFailed,
        => |e| return e,
        else => {},
    }
    const coordinate_count = coordinates.items.len;

    var pairs: std.ArrayList(Pair) = .empty;
    for (0..coordinate_count) |i| {
        for (i + 1..coordinate_count) |j| {
            const first = coordinates.items[i];
            const second = coordinates.items[j];
            try pairs.append(arena, .{
                .first = i,
                .second = j,
                .distance_squared = calculate_distance_squared(first, second),
            });
        }
    }
    std.mem.sort(Pair, pairs.items, {}, struct {
        fn compare(_: void, a: Pair, b: Pair) bool {
            return a.distance_squared < b.distance_squared;
        }
    }.compare);

    var union_find: UnionFind = try .init(arena, coordinate_count);
    var connection_count: usize = undefined;

    // sample data vs input data
    if (coordinate_count > 20) {
        connection_count = @min(1000, pairs.items.len);
    } else {
        connection_count = @min(10, pairs.items.len);
    }

    for (pairs.items[0..connection_count]) |pair| {
        _ = union_find.merge(pair.first, pair.second);
    }

    var circuit_count: std.ArrayList(usize) = .empty;
    for (0..connection_count) |index| {
        if (union_find.parent[index] == index) {
            try circuit_count.append(arena, union_find.set_element_count(index));
        }
    }
    std.mem.sort(usize, circuit_count.items, {}, std.sort.desc(usize));

    var result: usize = 1;
    const top_three = circuit_count.items[0..@min(3, circuit_count.items.len)];
    for (top_three) |count| {
        result *= count;
    }

    std.debug.print("Multiple of largest circuit: {d}\n", .{result});
}

pub fn part_2(allocator: Allocator, file: File) !void {
    var read_buffer: [read_buffer_size]u8 = undefined;
    var file_reader = file.reader(&read_buffer);

    var coordinates: std.ArrayList(Coordinate) = .empty;
    while (file_reader.interface.takeDelimiterExclusive('\n')) |line| {
        var it = std.mem.tokenizeScalar(u8, line, ',');
        try coordinates.append(allocator, .{
            .x = try std.fmt.parseInt(i32, it.next().?, 10),
            .y = try std.fmt.parseInt(i32, it.next().?, 10),
            .z = try std.fmt.parseInt(i32, it.next().?, 10),
        });
    } else |err| switch (err) {
        error.StreamTooLong,
        error.ReadFailed,
        => |e| return e,
        else => {},
    }
    const coordinate_count = coordinates.items.len;

    var pairs: std.ArrayList(Pair) = .empty;
    for (0..coordinate_count) |i| {
        for (i + 1..coordinate_count) |j| {
            const first = coordinates.items[i];
            const second = coordinates.items[j];
            try pairs.append(allocator, .{
                .first = i,
                .second = j,
                .distance_squared = calculate_distance_squared(first, second),
            });
        }
    }
    std.mem.sort(Pair, pairs.items, {}, struct {
        fn compare(_: void, a: Pair, b: Pair) bool {
            return a.distance_squared < b.distance_squared;
        }
    }.compare);

    var union_find: UnionFind = try .init(allocator, coordinate_count);

    var result: i64 = 1;
    for (pairs.items) |pair| {
        const merged = union_find.merge(pair.first, pair.second);

        if (merged and union_find.disjoint_set_count == 1) {
            const first_coordinate = coordinates.items[pair.first];
            const second_coordinate = coordinates.items[pair.second];
            result = first_coordinate.x * second_coordinate.x;
            break;
        }
    }

    std.debug.print("Product of the x coordinates: {d}\n", .{result});
}

fn calculate_distance_squared(first: Coordinate, second: Coordinate) u64 {
    const dx: i64 = first.x - second.x;
    const dy: i64 = first.y - second.y;
    const dz: i64 = first.z - second.z;

    return @intCast((dx * dx) + (dy * dy) + (dz * dz));
}

test "day_08" {}
