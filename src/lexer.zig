const std = @import("std");
const expect = std.testing.expect;

pub const TokenKind = union(enum) {
    identifier: []const u8,
    string: []const u8,
    numeric: u32,
    semicolon: u8,
    comma: u8,
    asterix: u8,
    oparen: u8,
    cparen: u8,
    create: void,
    table: void,
    int: void,
    text: void,
    insert: void,
    into: void,
    values: void,
    select: void,
    from: void,
    EOF: void,
};

pub const Token = struct {
    kind: TokenKind,
    col: u32,

    pub fn init(kind: TokenKind, col: u32) Token {
        return Token{
            .kind = kind,
            .col = col,
        };
    }

    pub fn strVal(self: Token) []const u8 {
        return switch (self.kind) {
            .identifier => self.kind.identifier,
            .string => self.kind.string,
            else => unreachable,
        };
    }

    pub fn numVal(self: Token) u32 {
        return switch (self.kind) {
            .numeric => self.kind.numeric,
            else => unreachable,
        };
    }
};

pub const LexerError = error{
    IllegalCharacter,
    TrailingCharacter,
    MalformedInput,
};

pub const Lexer = struct {
    input: []const u8,
    length: usize,
    index: u32,
    tok: Token,
    col: u32,
    allocator: std.mem.Allocator,

    pub fn init(input: []const u8, allocator: std.mem.Allocator) Lexer {
        return Lexer{
            .input = input,
            .length = input.len,
            .allocator = allocator,
            .index = 0,
            .col = 1,
            .tok = Token.init(TokenKind{ .EOF = {} }, 0),
        };
    }

    pub fn curr_token(self: *Lexer) Token {
        return self.tok;
    }

    pub fn next_token(self: *Lexer) !Token {
        while ((self.index < self.length) and self.input[self.index] == ' ') {
            self.index += 1;
        }

        if ((self.index < self.length) and self.input[self.index] == '\n') {
            self.col = 1;
        }

        if (self.index >= self.length) {
            self.tok = Token.init(TokenKind{ .EOF = {} }, self.index);
            return self.tok;
        }

        const char = self.input[self.index];
        switch (char) {
            ';' => {
                const ttype = TokenKind{ .semicolon = ';' };
                self.index += 1;
                self.tok = Token.init(ttype, self.col);
                self.col += 1;
                return self.tok;
            },
            ',' => {
                const ttype = TokenKind{ .comma = ',' };
                self.index += 1;
                self.tok = Token.init(ttype, self.col);
                self.col += 1;
                return self.tok;
            },
            '*' => {
                const ttype = TokenKind{ .asterix = '*' };
                self.index += 1;
                self.tok = Token.init(ttype, self.col);
                self.col += 1;
                return self.tok;
            },
            '(' => {
                const ttype = TokenKind{ .oparen = '(' };
                self.index += 1;
                self.tok = Token.init(ttype, self.col);
                self.col += 1;
                return self.tok;
            },
            ')' => {
                const ttype = TokenKind{ .cparen = ')' };
                self.index += 1;
                self.tok = Token.init(ttype, self.col);
                self.col += 1;
                return self.tok;
            },
            '0'...'9' => {
                const amtv = try extract_numeric_token(self.input, self.index, self.col);
                self.index = amtv.i;
                self.tok = amtv.t;
                self.col += 1;
                return amtv.t;
            },
            '\'' => {
                const amtv = try extract_string_token(self.allocator, self.input, self.index, self.col);
                self.index = amtv.i;
                self.tok = amtv.t;
                self.col += 1;
                return amtv.t;
            },
            'A'...'Z', 'a'...'z' => {
                const amtv = try extract_character_sequence(self.allocator, self.input, self.index, self.col);
                self.index = amtv.i;
                self.tok = amtv.t;
                self.col += 1;
                return amtv.t;
            },
            else => {
                std.debug.print("ERROR,{d}: unrecognized character found in input stream -> {c}\n", .{ self.index + 1, char });
                return LexerError.IllegalCharacter;
            },
        }
    }

    pub fn peek_token(self: *Lexer) ?Token {
        const i = self.index;
        defer self.index = i;

        return self.next_token() catch null;
    }
};

fn extract_numeric_token(code: []const u8, s_index: u32, col: u32) !struct { t: Token, i: u32 } {
    var index = s_index;
    while (index < code.len) {
        switch (code[index]) {
            '0'...'9' => {
                index += 1;
            },
            else => break,
        }
    }
    const value = try std.fmt.parseInt(u32, code[s_index..index], 0);
    const ttype = TokenKind{ .numeric = value };
    const token = Token.init(ttype, col);
    return .{ .t = token, .i = index };
}

fn extract_string_token(allocator: std.mem.Allocator, code: []const u8, s_index: u32, col: u32) !struct { t: Token, i: u32 } {
    var index = s_index + 1;

    while (index < code.len) {
        if (code[index] == '\'') {
            index += 1;
            break;
        }
        index += 1;
    }

    const copied = try allocator.dupe(u8, code[s_index + 1 .. index - 1]);
    const ttype = TokenKind{ .string = copied };
    const token = Token.init(ttype, col);
    return .{ .t = token, .i = index };
}

fn extract_character_sequence(allocator: std.mem.Allocator, code: []const u8, s_index: u32, col: u32) !struct { t: Token, i: u32 } {
    var index = s_index;
    while (index < code.len) {
        switch (code[index]) {
            'A'...'Z', 'a'...'z', '0'...'9' => {
                index += 1;
            },
            else => break,
        }
    }

    const ttype = try make_identifier_or_keyword(allocator, code[s_index..index]);
    const token = Token.init(ttype, col);
    return .{ .t = token, .i = index };
}

fn make_identifier_or_keyword(allocator: std.mem.Allocator, string: []const u8) !TokenKind {
    if ((std.mem.eql(u8, string, "CREATE")) or (std.mem.eql(u8, string, "create"))) {
        return TokenKind{ .create = {} };
    } else if ((std.mem.eql(u8, string, "TABLE")) or (std.mem.eql(u8, string, "table"))) {
        return TokenKind{ .table = {} };
    } else if ((std.mem.eql(u8, string, "INT")) or (std.mem.eql(u8, string, "int"))) {
        return TokenKind{ .int = {} };
    } else if ((std.mem.eql(u8, string, "TEXT")) or (std.mem.eql(u8, string, "text"))) {
        return TokenKind{ .text = {} };
    } else if ((std.mem.eql(u8, string, "INSERT")) or (std.mem.eql(u8, string, "insert"))) {
        return TokenKind{ .insert = {} };
    } else if ((std.mem.eql(u8, string, "INTO")) or (std.mem.eql(u8, string, "into"))) {
        return TokenKind{ .into = {} };
    } else if ((std.mem.eql(u8, string, "VALUES")) or (std.mem.eql(u8, string, "values"))) {
        return TokenKind{ .values = {} };
    } else if ((std.mem.eql(u8, string, "SELECT")) or (std.mem.eql(u8, string, "select"))) {
        return TokenKind{ .select = {} };
    } else if ((std.mem.eql(u8, string, "FROM")) or (std.mem.eql(u8, string, "from"))) {
        return TokenKind{ .from = {} };
    } else {
        const copied = try allocator.dupe(u8, string);
        return TokenKind{ .identifier = copied };
    }
}

test "test next token" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var lexer = Lexer.init("insert select create table text int into values from;*)( 123 'tonie' iden", allocator);

    const len = 16;
    const tokens: [len]Token = .{
        try lexer.next_token(),
        try lexer.next_token(),
        try lexer.next_token(),
        try lexer.next_token(),
        try lexer.next_token(),
        try lexer.next_token(),
        try lexer.next_token(),
        try lexer.next_token(),
        try lexer.next_token(),
        try lexer.next_token(),
        try lexer.next_token(),
        try lexer.next_token(),
        try lexer.next_token(),
        try lexer.next_token(),
        try lexer.next_token(),
        try lexer.next_token(),
    };

    const test_tokens: [len]Token = .{
        Token{ .kind = TokenKind.insert, .col = 1 },
        Token{ .kind = TokenKind.select, .col = 2 },
        Token{ .kind = TokenKind.create, .col = 3 },
        Token{ .kind = TokenKind.table, .col = 4 },
        Token{ .kind = TokenKind.text, .col = 5 },
        Token{ .kind = TokenKind.int, .col = 6 },
        Token{ .kind = TokenKind.into, .col = 7 },
        Token{ .kind = TokenKind.values, .col = 8 },
        Token{ .kind = TokenKind.from, .col = 9 },
        Token{ .kind = TokenKind{ .semicolon = ';' }, .col = 10 },
        Token{ .kind = TokenKind{ .asterix = '*' }, .col = 11 },
        Token{ .kind = TokenKind{ .cparen = ')' }, .col = 12 },
        Token{ .kind = TokenKind{ .oparen = '(' }, .col = 13 },
        Token{ .kind = TokenKind{ .numeric = 123 }, .col = 14 },
        Token{ .kind = TokenKind{ .string = "tonie" }, .col = 15 },
        Token{ .kind = TokenKind{ .identifier = "iden" }, .col = 16 },
    };

    const cmp = struct {
        pub fn eql(toks: []const Token) bool {
            for (toks, test_tokens) |tok, test_tok| {
                if (tok.col != test_tok.col) {
                    return false;
                }

                if (std.mem.eql(u8, @tagName(tok.kind), @tagName(test_tok.kind)) == false) {
                    return false;
                }

                switch (tok.kind) {
                    .string, .identifier => |val| {
                        if (std.mem.eql(u8, val, test_tok.strVal()) == false) {
                            return false;
                        }
                    },
                    .numeric => |val| {
                        if ((val == test_tok.numVal()) == false) {
                            return false;
                        }
                    },
                    else => continue,
                }
            }
            return true;
        }
    }.eql;

    try expect(cmp(&tokens) == true);
}
