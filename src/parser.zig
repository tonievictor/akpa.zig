const std = @import("std");
const lexer = @import("lexer.zig");

const StmtKind = enum { Insert, Select, Create };
const Statement = struct {
    kind: StmtKind,
    row: ?Row,
};

pub fn free_row(allocator: std.mem.Allocator, stmt: Statement) void {
    allocator.free(stmt.row.?.email);
    allocator.free(stmt.row.?.username);
}

const Row = struct {
    id: i32,
    username: []const u8,
    email: []const u8,
};

const ParserError = error{
    UnrecognizedStatement,
    UnexpectedToken,
};

pub fn parse(allocator: std.mem.Allocator, input: []const u8) !Statement {
    var l = lexer.Lexer.init(input, allocator);

    const tok = try l.next_token();
    defer l.free_token(tok);
    const stmt = switch (tok.kind) {
        lexer.TokenKind.create => Statement{ .kind = StmtKind.Create, .row = null },
        lexer.TokenKind.select => Statement{ .kind = StmtKind.Select, .row = null },
        lexer.TokenKind.insert => try parse_insert_stmt(&l),
        else => return ParserError.UnrecognizedStatement,
    };
    return stmt;
}

fn parse_insert_stmt(l: *lexer.Lexer) !Statement {
    const id = try expect_and_get(l, @tagName(lexer.TokenKind.numeric));
    const name = try expect_and_get(l, @tagName(lexer.TokenKind.string));
    const email = try expect_and_get(l, @tagName(lexer.TokenKind.string));

    const row = Row{
        .id = id.numVal(),
        .username = name.strVal(),
        .email = email.strVal(),
    };

    return Statement{
        .kind = StmtKind.Insert,
        .row = row,
    };
}

fn expect_and_get(l: *lexer.Lexer, kind: []const u8) !lexer.Token {
    const tok = try l.next_token();
    if (!std.mem.eql(u8, @tagName(tok.kind), kind)) {
        return ParserError.UnexpectedToken;
    }
    return tok;
}
