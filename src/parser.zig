const std = @import("std");
const lexer = @import("lexer.zig");
const ArrayList = std.ArrayList;

const StmtKind = enum { Insert, Select, Create };

const CTypes = enum {
    text,
    int,
};

const Statement = struct {
    kind: StmtKind,
    table: ?Table,
    schema: ?TableSchema,
};

const TableSchema = struct {
    name: []const u8,
    rows: ArrayList(Row),
};

const Row = struct {
    col: []const u8,
    ctype: CTypes,
};

const Expression = union(enum) {
    integer: u32,
    literal: []const u8,
};

const Table = struct {
    name: []const u8,
    columns: ArrayList([]const u8),
    values: ?ArrayList(Expression),
};

pub fn free_stmt(allocator: std.mem.Allocator, stmt: Statement) void {
    if (stmt.table) |t| {
        allocator.free(t.name);
        defer t.columns.deinit();
        for (t.columns.items) |elem| {
            allocator.free(elem);
        }

        if (t.values) |v| {
            defer v.deinit();
            for (v.items) |expr| {
                switch (expr) {
                    .literal => |val| allocator.free(val),
                    else => continue,
                }
            }
        }
    }

    if (stmt.schema) |schema| {
        allocator.free(schema.name);
        defer schema.rows.deinit();
        for (schema.rows.items) |row| {
            allocator.free(row.col);
        }
    }
}

const ParserError = error{
    UnrecognizedStatement,
    UnexpectedToken,
    InvalidType,
};

pub fn parse(allocator: std.mem.Allocator, input: []const u8) !Statement {
    var l = lexer.Lexer.init(input, allocator);

    const tok = try l.next_token();
    defer l.free_token(tok);
    const stmt = switch (tok.kind) {
        lexer.TokenKind.create => parse_create_stmt(allocator, &l),
        lexer.TokenKind.select => try parse_select_stmt(allocator, &l),
        lexer.TokenKind.insert => try parse_insert_stmt(allocator, &l),
        else => return ParserError.UnrecognizedStatement,
    };
    return stmt;
}

fn parse_create_stmt(allocator: std.mem.Allocator, l: *lexer.Lexer) !Statement {
    var rows = ArrayList(Row).init(allocator);

    _ = try expect_and_get(l, @tagName(lexer.TokenKind.table));
    const name = try expect_and_get(l, @tagName(lexer.TokenKind.identifier));
    _ = try expect_and_get(l, @tagName(lexer.TokenKind.oparen));
    const col = try expect_and_get(l, @tagName(lexer.TokenKind.identifier));
    const ctype = try l.next_token();
    defer l.free_token(ctype);
    _ = try expect_and_get(l, @tagName(lexer.TokenKind.cparen));
    _ = try expect_and_get(l, @tagName(lexer.TokenKind.semicolon));

    try rows.append(Row{
        .col = col.strVal(),
        .ctype = try get_ctype(ctype),
    });

    return Statement{
        .kind = StmtKind.Create,
        .table = null,
        .schema = TableSchema{
            .name = name.strVal(),
            .rows = rows,
        },
    };
}

fn get_ctype(tok: lexer.Token) !CTypes {
    switch (tok.kind) {
        .text => return CTypes.text,
        .int => return CTypes.int,
        else => return ParserError.InvalidType,
    }
}

fn parse_select_stmt(allocator: std.mem.Allocator, l: *lexer.Lexer) !Statement {
    const columns = try parse_columns(allocator, l);
    _ = try expect_and_get(l, @tagName(lexer.TokenKind.from));
    const name = try expect_and_get(l, @tagName(lexer.TokenKind.identifier));
    _ = try expect_and_get(l, @tagName(lexer.TokenKind.semicolon));

    return Statement{
        .kind = StmtKind.Select,
        .table = Table{
            .name = name.strVal(),
            .columns = columns,
            .values = null,
        },
        .schema = null,
    };
}

fn parse_insert_stmt(allocator: std.mem.Allocator, l: *lexer.Lexer) !Statement {
    _ = try expect_and_get(l, @tagName(lexer.TokenKind.into));
    const name = try expect_and_get(l, @tagName(lexer.TokenKind.identifier));
    _ = try expect_and_get(l, @tagName(lexer.TokenKind.oparen));
    const columns = try parse_columns(allocator, l);
    _ = try expect_and_get(l, @tagName(lexer.TokenKind.cparen));
    _ = try expect_and_get(l, @tagName(lexer.TokenKind.values));
    _ = try expect_and_get(l, @tagName(lexer.TokenKind.oparen));
    const values = try parse_expression(allocator, l);
    _ = try expect_and_get(l, @tagName(lexer.TokenKind.cparen));
    _ = try expect_and_get(l, @tagName(lexer.TokenKind.semicolon));

    return Statement{
        .kind = StmtKind.Insert,
        .table = Table{
            .name = name.strVal(),
            .columns = columns,
            .values = values,
        },
        .schema = null,
    };
}

fn parse_columns(allocator: std.mem.Allocator, l: *lexer.Lexer) !ArrayList([]const u8) {
    var columns = ArrayList([]const u8).init(allocator);

    const tok = try l.next_token();
    const col = switch (tok.kind) {
        .identifier => tok.strVal(),
        .string => {
            l.free_token(tok);
            return ParserError.UnexpectedToken;
        },
        else => return ParserError.UnexpectedToken,
    };
    try columns.append(col);
    return columns;
}

fn parse_expression(allocator: std.mem.Allocator, l: *lexer.Lexer) !ArrayList(Expression) {
    var values = ArrayList(Expression).init(allocator);
    const tok = try l.next_token();
    const expr = switch (tok.kind) {
        .string => Expression{ .literal = tok.strVal() },
        .numeric => Expression{ .integer = tok.numVal() },
        .identifier => {
            l.free_token(tok);
            return ParserError.UnexpectedToken;
        },
        else => return ParserError.UnexpectedToken,
    };
    try values.append(expr);
    return values;
}

fn expect_and_get(l: *lexer.Lexer, kind: []const u8) !lexer.Token {
    const tok = try l.next_token();
    if (!std.mem.eql(u8, @tagName(tok.kind), kind)) {
        l.free_token(tok);
        return ParserError.UnexpectedToken;
    }
    return tok;
}
