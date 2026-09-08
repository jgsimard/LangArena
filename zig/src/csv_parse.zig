const std = @import("std");
const csvz = @import("csvzero");
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;

pub const CsvParse = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    rows: usize,
    data: []const u8,
    result_val: u32,

    const vtable = Benchmark.VTable{
        .run = runImpl,
        .checksum = checksumImpl,
        .deinit = deinitImpl,
        .prepare = prepareImpl,
    };

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*CsvParse {
        const self = try allocator.create(CsvParse);
        errdefer allocator.destroy(self);

        const rows = @as(usize, @intCast(helper.config_i64("CSV::Parse", "rows")));

        self.* = CsvParse{
            .allocator = allocator,
            .helper = helper,
            .rows = rows,
            .data = "",
            .result_val = 0,
        };

        return self;
    }

    pub fn deinit(self: *CsvParse) void {
        if (self.data.len > 0) {
            self.allocator.free(self.data);
        }
        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *CsvParse) Benchmark {
        return Benchmark.init(self, &vtable, self.helper, "CSV::Parse");
    }

    fn prepareImpl(ptr: *anyopaque) void {
        const self: *CsvParse = @ptrCast(@alignCast(ptr));

        var list = std.ArrayList(u8).empty;
        defer list.deinit(self.allocator);

        var i: usize = 0;
        while (i < self.rows) : (i += 1) {
            const c = @as(u8, @intCast('A' + @mod(i, 26)));
            const x = self.helper.nextFloat(1.0);
            const z = self.helper.nextFloat(1.0);
            const y = self.helper.nextFloat(1.0);

            var buf: [512]u8 = undefined;
            const line = std.fmt.bufPrint(&buf, "\"point {c}\\n, \"\"{d}\"\"\",{d:.10},,{d:.10},\"[{s}\\n, {d}]\",{d:.10}\n", .{
                c,
                @as(i32, @intCast(@mod(i, 100))),
                x,
                z,
                if (i % 2 == 0) "true" else "false",
                @as(i32, @intCast(@mod(i, 100))),
                y,
            }) catch continue;

            list.appendSlice(self.allocator, line) catch continue;
        }

        self.data = list.toOwnedSlice(self.allocator) catch "";
    }

    const Point = struct {
        x: f64,
        y: f64,
        z: f64,
    };

    fn parse_points(self: *CsvParse, points: *std.ArrayList(Point)) !void {
        var reader = std.Io.Reader.fixed(self.data);
        var it = csvz.Iterator.init(&reader);

        var col_idx: usize = 0;
        var current_x: f64 = 0.0;
        var current_z: f64 = 0.0;
        var current_y: f64 = 0.0;

        while (true) {
            const field = it.next() catch |err| switch (err) {
                error.EOF => break,
                else => return err,
            };

            switch (col_idx) {
                1 => current_x = std.fmt.parseFloat(f64, field.data) catch 0.0,
                3 => current_z = std.fmt.parseFloat(f64, field.data) catch 0.0,
                5 => current_y = std.fmt.parseFloat(f64, field.data) catch 0.0,
                else => {},
            }

            col_idx += 1;

            if (field.last_column) {
                try points.append(self.allocator, .{
                    .x = current_x,
                    .y = current_y,
                    .z = current_z,
                });

                col_idx = 0;
            }
        }
    }

    fn runImpl(ptr: *anyopaque, iteration_id: i64) void {
        const self: *CsvParse = @ptrCast(@alignCast(ptr));
        _ = iteration_id;

        if (self.data.len == 0) return;

        var points: std.ArrayList(Point) = .empty;
        defer points.deinit(self.allocator);

        self.parse_points(&points) catch return;

        if (points.items.len == 0) return;

        var x_sum: f64 = 0.0;
        var y_sum: f64 = 0.0;
        var z_sum: f64 = 0.0;

        for (points.items) |p| {
            x_sum += p.x;
            y_sum += p.y;
            z_sum += p.z;
        }

        const len = @as(f64, @floatFromInt(points.items.len));
        const avg_x = x_sum / len;
        const avg_y = y_sum / len;
        const avg_z = z_sum / len;

        self.result_val +%= self.helper.checksumFloat(avg_x);
        self.result_val +%= self.helper.checksumFloat(avg_y);
        self.result_val +%= self.helper.checksumFloat(avg_z);
    }

    fn checksumImpl(ptr: *anyopaque) u32 {
        const self: *CsvParse = @ptrCast(@alignCast(ptr));
        return self.result_val +% self.helper.checksumString(self.data);
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *CsvParse = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};
