const std = @import("std");
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;

pub const BinarytreesObj = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    n: i64,
    result_val: u32,

    const TreeNode = struct {
        item: i32,
        left: ?*TreeNode,
        right: ?*TreeNode,

        fn create(allocator: std.mem.Allocator, item: i32, depth: i32) !*TreeNode {
            const node = try allocator.create(TreeNode);
            node.* = TreeNode{
                .item = item,
                .left = null,
                .right = null,
            };

            const shift: i32 = @as(i32, 1) << @intCast(depth - 1);
            if (depth > 0) {
                node.left = try TreeNode.create(allocator, item - shift, depth - 1);
                node.right = try TreeNode.create(allocator, item + shift, depth - 1);
            }

            return node;
        }

        fn sum(self: *const TreeNode) i32 {
            var total: i32 = self.item +% 1;
            if (self.left) |left| total +%= left.sum();
            if (self.right) |right| total +%= right.sum();
            return total;
        }
    };

    const vtable = Benchmark.VTable{
        .run = runImpl,
        .checksum = resultImpl,
        .deinit = deinitImpl,
    };

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*BinarytreesObj {
        const n = helper.config_i64("Binarytrees::Obj", "depth");

        const self = try allocator.create(BinarytreesObj);
        errdefer allocator.destroy(self);

        self.* = BinarytreesObj{
            .allocator = allocator,
            .helper = helper,
            .n = n,
            .result_val = 0,
        };
        return self;
    }

    pub fn deinit(self: *BinarytreesObj) void {
        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *BinarytreesObj) Benchmark {
        return Benchmark.init(self, &vtable, self.helper, "Binarytrees::Obj");
    }

    fn runImpl(ptr: *anyopaque, iteration_id: i64) void {
        _ = iteration_id;
        const self: *BinarytreesObj = @ptrCast(@alignCast(ptr));

        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();

        const arena_alloc = arena.allocator();

        const root = TreeNode.create(arena_alloc, 0, @intCast(self.n)) catch return;

        self.result_val +%= @as(u32, @bitCast(root.sum()));
    }

    fn resultImpl(ptr: *anyopaque) u32 {
        const self: *BinarytreesObj = @ptrCast(@alignCast(ptr));
        return self.result_val;
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *BinarytreesObj = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};

pub const BinarytreesArena = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    n: i64,
    result_val: u32,
    arena: std.ArrayList(TreeNodeArena),

    const TreeNodeArena = struct {
        item: i32,
        left: i32,
        right: i32,

        fn new(item: i32) TreeNodeArena {
            return .{
                .item = item,
                .left = -1,
                .right = -1,
            };
        }
    };

    const vtable = Benchmark.VTable{
        .run = runImpl,
        .checksum = resultImpl,
        .deinit = deinitImpl,
    };

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*BinarytreesArena {
        const n = helper.config_i64("Binarytrees::Arena", "depth");

        const self = try allocator.create(BinarytreesArena);
        errdefer allocator.destroy(self);

        self.* = BinarytreesArena{
            .allocator = allocator,
            .helper = helper,
            .n = n,
            .result_val = 0,
            .arena = .empty,
        };
        return self;
    }

    pub fn deinit(self: *BinarytreesArena) void {
        self.arena.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *BinarytreesArena) Benchmark {
        return Benchmark.init(self, &vtable, self.helper, "Binarytrees::Arena");
    }

    fn buildTree(self: *BinarytreesArena, item: i32, depth: i32) !i32 {
        const idx: i32 = @intCast(self.arena.items.len);
        try self.arena.append(self.allocator, TreeNodeArena.new(item));

        if (depth > 0) {
            const shift: i32 = @as(i32, 1) << @intCast(depth - 1);
            const left_idx = try self.buildTree(item - shift, depth - 1);
            const right_idx = try self.buildTree(item + shift, depth - 1);

            self.arena.items[@intCast(idx)].left = left_idx;
            self.arena.items[@intCast(idx)].right = right_idx;
        }

        return idx;
    }

    fn sum(self: *const BinarytreesArena, idx: i32) i32 {
        const node = self.arena.items[@intCast(idx)];
        var total: i32 = node.item +% 1;

        if (node.left >= 0) total +%= self.sum(node.left);
        if (node.right >= 0) total +%= self.sum(node.right);

        return total;
    }

    fn runImpl(ptr: *anyopaque, iteration_id: i64) void {
        _ = iteration_id;
        const self: *BinarytreesArena = @ptrCast(@alignCast(ptr));

        self.arena.deinit(self.allocator);

        self.arena = .empty;

        const root_idx = self.buildTree(0, @intCast(self.n)) catch return;
        self.result_val +%= @as(u32, @bitCast(self.sum(root_idx)));
    }

    fn resultImpl(ptr: *anyopaque) u32 {
        const self: *BinarytreesArena = @ptrCast(@alignCast(ptr));
        return self.result_val;
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *BinarytreesArena = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};
