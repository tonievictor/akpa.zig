const std = @import("std");
const lexer = @import("lexer.zig");
const ArrayList = std.ArrayList;

const Statement = union(StmtKind) {
    insert: InsertStmt,
    select: SelectStmt,
    create: CreateStmt,
};

const StmtKind = enum {
    insert,
    select,
    create,
};

const InsertStmt = struct {
    name: []const u8,
    columns: ArrayList([]const u8),
    values: ArrayList(Expression),
};

const Expression = union(enum) {
    integer: u32,
    literal: []const u8,
};

const SelectStmt = struct {
    name: []const u8,
    columns: ArrayList([]const u8),
};

const CreateStmt = struct {
    name: []const u8,
    columns: ArrayList(Column),
};

const Column = struct {
    name: []const u8,
    ctype: CTypes,
};

const CTypes = enum {
    text,
    int,
};

const ParserError = error{
    UnrecognizedStatement,
    UnexpectedToken,
    InvalidType,
};

pub fn parse(allocator: std.mem.Allocator, input: []const u8) !Statement {
    var l = lexer.Lexer.init(input, allocator);

    const tok = try l.next_token();
    const stmt = switch (tok.kind) {
        lexer.TokenKind.create => parse_create_stmt(allocator, &l),
        lexer.TokenKind.select => try parse_select_stmt(allocator, &l),
        lexer.TokenKind.insert => try parse_insert_stmt(allocator, &l),
        else => return ParserError.UnrecognizedStatement,
    };
    return stmt;
}

fn parse_create_stmt(allocator: std.mem.Allocator, l: *lexer.Lexer) !Statement {
    var columns = ArrayList(Column).init(allocator);

    _ = try expect_and_get(l, @tagName(lexer.TokenKind.table));
    const name = try expect_and_get(l, @tagName(lexer.TokenKind.identifier));
    _ = try expect_and_get(l, @tagName(lexer.TokenKind.oparen));
    const col = try expect_and_get(l, @tagName(lexer.TokenKind.identifier));
    const ctype = try l.next_token();
    _ = try expect_and_get(l, @tagName(lexer.TokenKind.cparen));
    _ = try expect_and_get(l, @tagName(lexer.TokenKind.semicolon));

    try columns.append(Column{
        .name = col.strVal(),
        .ctype = try get_ctype(ctype),
    });

    return Statement{
        .create = CreateStmt{
            .name = name.strVal(),
            .columns = columns,
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
        .select = SelectStmt{
            .name = name.strVal(),
            .columns = columns,
        },
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
        .insert = InsertStmt{
            .name = name.strVal(),
            .columns = columns,
            .values = values,
        },
    };
}

fn parse_columns(allocator: std.mem.Allocator, l: *lexer.Lexer) !ArrayList([]const u8) {
    var columns = ArrayList([]const u8).init(allocator);

    const tok = try l.next_token();
    const col = switch (tok.kind) {
        .identifier => tok.strVal(),
        else => {
            return ParserError.UnexpectedToken;
        },
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
        else => {
            return ParserError.UnexpectedToken;
        },
    };
    try values.append(expr);
    return values;
}

fn expect_and_get(l: *lexer.Lexer, kind: []const u8) !lexer.Token {
    const tok = try l.next_token();
    if (!std.mem.eql(u8, @tagName(tok.kind), kind)) {
        return ParserError.UnexpectedToken;
    }
    return tok;
}
