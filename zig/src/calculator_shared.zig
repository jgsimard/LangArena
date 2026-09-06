const std = @import("std");
const Helper = @import("helper.zig").Helper;

const CHAR_EOF: u8 = 0;
const CHAR_PLUS: u8 = '+';
const CHAR_MINUS: u8 = '-';
const CHAR_STAR: u8 = '*';
const CHAR_SLASH: u8 = '/';
const CHAR_PERCENT: u8 = '%';
const CHAR_LPAREN: u8 = '(';
const CHAR_RPAREN: u8 = ')';
const CHAR_EQUALS: u8 = '=';
const CHAR_ZERO: u8 = '0';
const CHAR_NINE: u8 = '9';
const CHAR_A_LOWER: u8 = 'a';
const CHAR_Z_LOWER: u8 = 'z';
const CHAR_A_UPPER: u8 = 'A';
const CHAR_Z_UPPER: u8 = 'Z';
const CHAR_SPACE: u8 = ' ';
const CHAR_TAB: u8 = '\t';
const CHAR_NEWLINE: u8 = '\n';
const CHAR_CR: u8 = '\r';

pub const Number = struct {
    value: i64,
};

pub const Variable = struct {
    name: []const u8,
};

pub const BinaryOp = struct {
    op: u8,
    left: *Node,
    right: *Node,
};

pub const Assignment = struct {
    var_name: []const u8,
    expr: *Node,
};

pub const Node = union(enum) {
    number: Number,
    variable: Variable,
    binary_op: *BinaryOp,
    assignment: *Assignment,
};

pub const ParserError = error{OutOfMemory} || std.mem.Allocator.Error;

pub const Parser = struct {
    arena_allocator: std.mem.Allocator,
    input: []const u8,
    pos: usize = 0,
    len: usize,
    current_byte: u8 = CHAR_EOF,

    pub fn init(arena_allocator: std.mem.Allocator, input: []const u8) Parser {
        return Parser{
            .arena_allocator = arena_allocator,
            .input = input,
            .pos = 0,
            .len = input.len,
            .current_byte = if (input.len > 0) input[0] else CHAR_EOF,
        };
    }

    pub fn deinit(self: *Parser) void {
        _ = self;
    }

    pub fn advance(self: *Parser) void {
        self.pos += 1;
        if (self.pos >= self.len) {
            self.current_byte = CHAR_EOF;
        } else {
            self.current_byte = self.input[self.pos];
        }
    }

    pub fn skipWhitespace(self: *Parser) void {
        while (self.isWhitespace(self.current_byte)) {
            self.advance();
        }
    }

    pub fn parseNumber(self: *Parser) ParserError!*Node {
        var value: i64 = 0;
        while (self.isDigit(self.current_byte)) {
            value = value * 10 + @as(i64, self.current_byte - CHAR_ZERO);
            self.advance();
        }
        const node = try self.arena_allocator.create(Node);
        node.* = Node{ .number = Number{ .value = value } };
        return node;
    }

    pub fn parseVariable(self: *Parser) ParserError!*Node {
        const start = self.pos;
        while (self.isLetter(self.current_byte) or self.isDigit(self.current_byte)) {
            self.advance();
        }

        const var_name = self.input[start..self.pos];
        const name_copy = try self.arena_allocator.dupe(u8, var_name);

        self.skipWhitespace();
        if (self.current_byte == CHAR_EQUALS) {
            self.advance();
            self.skipWhitespace();
            const expr = try self.parseExpression();
            const assignment = try self.arena_allocator.create(Assignment);
            assignment.* = Assignment{
                .var_name = name_copy,
                .expr = expr,
            };
            const node = try self.arena_allocator.create(Node);
            node.* = Node{ .assignment = assignment };
            return node;
        }

        const node = try self.arena_allocator.create(Node);
        node.* = Node{ .variable = Variable{ .name = name_copy } };
        return node;
    }

    pub fn parseFactor(self: *Parser) ParserError!*Node {
        self.skipWhitespace();

        if (self.isDigit(self.current_byte)) {
            return try self.parseNumber();
        }

        if (self.isLetter(self.current_byte)) {
            return try self.parseVariable();
        }

        if (self.current_byte == CHAR_LPAREN) {
            self.advance();
            self.skipWhitespace();
            const node = try self.parseExpression();
            self.skipWhitespace();
            if (self.current_byte == CHAR_RPAREN) {
                self.advance();
            }
            return node;
        }

        self.advance();
        const node = try self.arena_allocator.create(Node);
        node.* = Node{ .number = Number{ .value = 0 } };
        return node;
    }

    pub fn parseTerm(self: *Parser) ParserError!*Node {
        var node = try self.parseFactor();

        while (true) {
            self.skipWhitespace();

            if (self.current_byte == CHAR_STAR or self.current_byte == CHAR_SLASH or self.current_byte == CHAR_PERCENT) {
                const op = self.current_byte;
                self.advance();
                self.skipWhitespace();
                const right = try self.parseFactor();
                const binary_op = try self.arena_allocator.create(BinaryOp);
                binary_op.* = BinaryOp{
                    .op = op,
                    .left = node,
                    .right = right,
                };
                const new_node = try self.arena_allocator.create(Node);
                new_node.* = Node{ .binary_op = binary_op };
                node = new_node;
            } else {
                break;
            }
        }

        return node;
    }

    pub fn parseExpression(self: *Parser) ParserError!*Node {
        var node = try self.parseTerm();

        while (true) {
            self.skipWhitespace();

            if (self.current_byte == CHAR_PLUS or self.current_byte == CHAR_MINUS) {
                const op = self.current_byte;
                self.advance();
                self.skipWhitespace();
                const right = try self.parseTerm();
                const binary_op = try self.arena_allocator.create(BinaryOp);
                binary_op.* = BinaryOp{
                    .op = op,
                    .left = node,
                    .right = right,
                };
                const new_node = try self.arena_allocator.create(Node);
                new_node.* = Node{ .binary_op = binary_op };
                node = new_node;
            } else {
                break;
            }
        }

        return node;
    }

    pub fn parse(self: *Parser, out_expressions: *std.ArrayListUnmanaged(*Node)) ParserError!void {
        out_expressions.clearRetainingCapacity();

        while (self.current_byte != CHAR_EOF) {
            self.skipWhitespace();
            if (self.current_byte == CHAR_EOF) break;

            const expr = try self.parseExpression();
            try out_expressions.append(self.arena_allocator, expr);

            self.skipWhitespace();
            while (self.current_byte == CHAR_NEWLINE) {
                self.advance();
                self.skipWhitespace();
            }
        }
    }

    fn isDigit(_: *Parser, byte: u8) bool {
        return byte >= CHAR_ZERO and byte <= CHAR_NINE;
    }

    fn isLetter(_: *Parser, byte: u8) bool {
        return (byte >= CHAR_A_LOWER and byte <= CHAR_Z_LOWER) or
            (byte >= CHAR_A_UPPER and byte <= CHAR_Z_UPPER);
    }

    fn isWhitespace(_: *Parser, byte: u8) bool {
        return byte == CHAR_SPACE or byte == CHAR_TAB or byte == CHAR_NEWLINE or byte == CHAR_CR;
    }
};

pub fn generateRandomProgram(allocator: std.mem.Allocator, helper: *Helper, operations: i64) ![]const u8 {
    var w: std.Io.Writer.Allocating = .init(allocator);
    errdefer w.deinit();

    try w.writer.writeAll("v0 = 1\n");
    for (0..10) |i| {
        const v = i + 1;
        try w.writer.print("v{} = v{} + {}\n", .{ v, v - 1, v });
    }

    for (0..@as(usize, @intCast(operations))) |i| {
        const v = @as(i32, @intCast(i + 10));
        try w.writer.print("v{} = v{} + ", .{ v, v - 1 });

        const choice = helper.nextInt(10);
        switch (choice) {
            0 => try w.writer.print("(v{} / 3) * 4 - {} / (3 + (18 - v{})) % v{} + 2 * ((9 - v{}) * (v{} + 7))", .{ v - 1, i, v - 2, v - 3, v - 6, v - 5 }),
            1 => try w.writer.print("v{} + (v{} + v{}) * v{} - (v{} / v{})", .{ v - 1, v - 2, v - 3, v - 4, v - 5, v - 6 }),
            2 => try w.writer.print("(3789 - (((v{})))) + 1", .{v - 7}),
            3 => try w.writer.print("4/2 * (1-3) + v{}/v{}", .{ v - 9, v - 5 }),
            4 => try w.writer.print("1+2+3+4+5+6+v{}", .{v - 1}),
            5 => try w.writer.print("(99999 / v{})", .{v - 3}),
            6 => try w.writer.print("0 + 0 - v{}", .{v - 8}),
            7 => try w.writer.print("((((((((((v{})))))))))) * 2", .{v - 6}),
            8 => try w.writer.print("{} * (v{}%6)%7", .{ i, v - 1 }),
            9 => try w.writer.print("(1)/(0-v{}) + (v{})", .{ v - 5, v - 7 }),
            else => unreachable,
        }
        try w.writer.writeAll("\n");
    }

    return w.toOwnedSlice();
}
