const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Node = struct {
    value: i32,
    height: u32,
    left: ?*Node = null,
    right: ?*Node = null,
};

pub const Tree = struct {
    allocator: Allocator,
    root: ?*Node = null,
    size: usize = 0,

    pub fn init(allocator: Allocator) Tree {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *Tree) void {
        freeSubtree(self.allocator, self.root);
        self.root = null;
        self.size = 0;
    }

    pub fn insert(self: *Tree, value: i32) !void {
        var inserted = false;
        self.root = try insertNode(self.allocator, self.root, value, &inserted);
        if (inserted) self.size += 1;
    }

    pub fn remove(self: *Tree, value: i32) bool {
        var removed = false;
        self.root = removeNode(self.allocator, self.root, value, &removed);
        if (removed) self.size -= 1;
        return removed;
    }

    pub fn contains(self: *const Tree, value: i32) bool {
        var cur = self.root;
        while (cur) |n| {
            if (value == n.value) return true;
            cur = if (value < n.value) n.left else n.right;
        }
        return false;
    }

    pub fn height(self: *const Tree) u32 {
        return nodeHeight(self.root);
    }

    pub fn inOrder(self: *const Tree, allocator: Allocator) ![]i32 {
        var list: std.ArrayList(i32) = .empty;
        errdefer list.deinit(allocator);
        try collectInOrder(allocator, self.root, &list);
        return list.toOwnedSlice(allocator);
    }
};

fn nodeHeight(node: ?*Node) u32 {
    return if (node) |n| n.height else 0;
}

fn updateHeight(n: *Node) void {
    const lh = nodeHeight(n.left);
    const rh = nodeHeight(n.right);
    n.height = @max(lh, rh) + 1;
}

fn balanceFactor(n: *Node) i32 {
    const lh: i32 = @intCast(nodeHeight(n.left));
    const rh: i32 = @intCast(nodeHeight(n.right));
    return lh - rh;
}

fn rotateRight(n: *Node) *Node {
    const pivot = n.left.?;
    n.left = pivot.right;
    pivot.right = n;
    updateHeight(n);
    updateHeight(pivot);
    return pivot;
}

fn rotateLeft(n: *Node) *Node {
    const pivot = n.right.?;
    n.right = pivot.left;
    pivot.left = n;
    updateHeight(n);
    updateHeight(pivot);
    return pivot;
}

fn rebalance(n: *Node) *Node {
    updateHeight(n);
    const bf = balanceFactor(n);

    if (bf > 1) {
        if (balanceFactor(n.left.?) < 0) {
            n.left = rotateLeft(n.left.?);
        }
        return rotateRight(n);
    }
    if (bf < -1) {
        if (balanceFactor(n.right.?) > 0) {
            n.right = rotateRight(n.right.?);
        }
        return rotateLeft(n);
    }
    return n;
}

fn insertNode(allocator: Allocator, node: ?*Node, value: i32, inserted: *bool) Allocator.Error!*Node {
    if (node) |n| {
        if (value < n.value) {
            n.left = try insertNode(allocator, n.left, value, inserted);
        } else if (value > n.value) {
            n.right = try insertNode(allocator, n.right, value, inserted);
        } else {
            return n;
        }
        return rebalance(n);
    }
    const new_node = try allocator.create(Node);
    new_node.* = .{ .value = value, .height = 1 };
    inserted.* = true;
    return new_node;
}

fn minNode(n: *Node) *Node {
    var cur = n;
    while (cur.left) |l| cur = l;
    return cur;
}

fn removeNode(allocator: Allocator, node: ?*Node, value: i32, removed: *bool) ?*Node {
    const n = node orelse return null;

    if (value < n.value) {
        n.left = removeNode(allocator, n.left, value, removed);
    } else if (value > n.value) {
        n.right = removeNode(allocator, n.right, value, removed);
    } else {
        removed.* = true;
        if (n.left == null or n.right == null) {
            const child = if (n.left) |l| l else n.right;
            allocator.destroy(n);
            return child;
        }
        const succ = minNode(n.right.?);
        n.value = succ.value;
        var dummy = false;
        n.right = removeNode(allocator, n.right, succ.value, &dummy);
    }
    return rebalance(n);
}

fn freeSubtree(allocator: Allocator, node: ?*Node) void {
    if (node) |n| {
        freeSubtree(allocator, n.left);
        freeSubtree(allocator, n.right);
        allocator.destroy(n);
    }
}

fn collectInOrder(allocator: Allocator, node: ?*Node, list: *std.ArrayList(i32)) !void {
    if (node) |n| {
        try collectInOrder(allocator, n.left, list);
        try list.append(allocator, n.value);
        try collectInOrder(allocator, n.right, list);
    }
}

fn isBalanced(node: ?*Node) bool {
    const n = node orelse return true;
    const bf = balanceFactor(n);
    if (bf < -1 or bf > 1) return false;
    return isBalanced(n.left) and isBalanced(n.right);
}

const testing = std.testing;

test "empty tree" {
    var t = Tree.init(testing.allocator);
    defer t.deinit();

    try testing.expectEqual(@as(usize, 0), t.size);
    try testing.expectEqual(@as(u32, 0), t.height());
    try testing.expect(!t.contains(42));
}

test "single insert" {
    var t = Tree.init(testing.allocator);
    defer t.deinit();

    try t.insert(10);
    try testing.expectEqual(@as(usize, 1), t.size);
    try testing.expect(t.contains(10));
    try testing.expect(!t.contains(11));
}

test "duplicate insert is a no-op" {
    var t = Tree.init(testing.allocator);
    defer t.deinit();

    try t.insert(5);
    try t.insert(5);
    try t.insert(5);

    try testing.expectEqual(@as(usize, 1), t.size);
}

test "left-left rotation" {
    var t = Tree.init(testing.allocator);
    defer t.deinit();

    try t.insert(30);
    try t.insert(20);
    try t.insert(10);

    try testing.expectEqual(@as(i32, 20), t.root.?.value);
    try testing.expectEqual(@as(u32, 2), t.height());
    try testing.expect(isBalanced(t.root));
}

test "right-right rotation" {
    var t = Tree.init(testing.allocator);
    defer t.deinit();

    try t.insert(10);
    try t.insert(20);
    try t.insert(30);

    try testing.expectEqual(@as(i32, 20), t.root.?.value);
    try testing.expect(isBalanced(t.root));
}

test "left-right rotation" {
    var t = Tree.init(testing.allocator);
    defer t.deinit();

    try t.insert(30);
    try t.insert(10);
    try t.insert(20);

    try testing.expectEqual(@as(i32, 20), t.root.?.value);
    try testing.expect(isBalanced(t.root));
}

test "right-left rotation" {
    var t = Tree.init(testing.allocator);
    defer t.deinit();

    try t.insert(10);
    try t.insert(30);
    try t.insert(20);

    try testing.expectEqual(@as(i32, 20), t.root.?.value);
    try testing.expect(isBalanced(t.root));
}

test "in-order returns sorted values" {
    var t = Tree.init(testing.allocator);
    defer t.deinit();

    const values = [_]i32{ 50, 30, 70, 20, 40, 60, 80, 10 };
    for (values) |v| try t.insert(v);

    const out = try t.inOrder(testing.allocator);
    defer testing.allocator.free(out);

    const expected = [_]i32{ 10, 20, 30, 40, 50, 60, 70, 80 };
    try testing.expectEqualSlices(i32, &expected, out);
}

test "remove leaf" {
    var t = Tree.init(testing.allocator);
    defer t.deinit();

    try t.insert(20);
    try t.insert(10);
    try t.insert(30);

    try testing.expect(t.remove(10));
    try testing.expect(!t.contains(10));
    try testing.expectEqual(@as(usize, 2), t.size);
    try testing.expect(isBalanced(t.root));
}

test "remove node with one child" {
    var t = Tree.init(testing.allocator);
    defer t.deinit();

    try t.insert(20);
    try t.insert(10);
    try t.insert(30);
    try t.insert(5);

    try testing.expect(t.remove(10));
    try testing.expect(!t.contains(10));
    try testing.expect(t.contains(5));
    try testing.expectEqual(@as(usize, 3), t.size);
    try testing.expect(isBalanced(t.root));
}

test "remove node with two children" {
    var t = Tree.init(testing.allocator);
    defer t.deinit();

    const values = [_]i32{ 50, 30, 70, 20, 40, 60, 80 };
    for (values) |v| try t.insert(v);

    try testing.expect(t.remove(30));
    try testing.expect(!t.contains(30));
    try testing.expectEqual(@as(usize, 6), t.size);
    try testing.expect(isBalanced(t.root));
}

test "remove missing value returns false" {
    var t = Tree.init(testing.allocator);
    defer t.deinit();

    try t.insert(1);
    try testing.expect(!t.remove(2));
    try testing.expectEqual(@as(usize, 1), t.size);
}

test "stays balanced on sequential inserts" {
    var t = Tree.init(testing.allocator);
    defer t.deinit();

    var i: i32 = 0;
    while (i < 1024) : (i += 1) try t.insert(i);

    try testing.expectEqual(@as(usize, 1024), t.size);
    try testing.expect(isBalanced(t.root));
    try testing.expect(t.height() <= 11);
}

test "stays balanced after random inserts and removes" {
    var t = Tree.init(testing.allocator);
    defer t.deinit();

    var prng = std.Random.DefaultPrng.init(0xA1B2C3);
    const rand = prng.random();

    var inserted: std.ArrayList(i32) = .empty;
    defer inserted.deinit(testing.allocator);

    var i: usize = 0;
    while (i < 500) : (i += 1) {
        const v = rand.intRangeLessThan(i32, -10_000, 10_000);
        try t.insert(v);
        try inserted.append(testing.allocator, v);
    }

    try testing.expect(isBalanced(t.root));

    const size_before = t.size;
    var removed_count: usize = 0;
    for (inserted.items[0..100]) |v| {
        if (t.remove(v)) removed_count += 1;
    }
    try testing.expect(removed_count > 0);
    try testing.expectEqual(size_before - removed_count, t.size);
    try testing.expect(isBalanced(t.root));
}
