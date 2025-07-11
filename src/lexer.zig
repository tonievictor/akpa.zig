const std = @import("std");

const KeywordVariant = enum {
    Create,
    Table,
    Int,
    Text,
    Insert,
    Into,
    Values,
    Select,
    From,
};

const TokenType = union(enum) {
    keyword: KeywordVariant,
    identifier: []const u8,
    string: []const u8,
    numeric: i32,
    semicolon: u8,
    comma: u8,
    asterix: u8,
    oparen: u8,
    cparen: u8,
    EOF: u8,
};

pub const Token = struct {
    token_type: TokenType,
    col: u32,

    pub fn init(ttype: TokenType, col: u32) Token {
        return Token{
            .token_type = ttype,
            .col = col,
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
    allocator: std.mem.Allocator,

    pub fn init(input: []const u8, allocator: std.mem.Allocator) Lexer {
        return Lexer{
            .input = input,
            .length = input.len,
            .allocator = allocator,
            .index = 0,
        };
    }

    pub fn next_token(self: *Lexer) !Token {
        while ((self.index < self.length) and self.input[self.index] == ' ') {
            self.index += 1;
        }
        if (self.index >= self.length) {
            return Token.init(TokenType{ .EOF = ' ' }, self.index);
        }
        const char = self.input[self.index];
        switch (char) {
            ';' => {
                const ttype = TokenType{ .semicolon = ';' };
                self.index += 1;
                return Token.init(ttype, self.index);
            },
            ',' => {
                const ttype = TokenType{ .comma = ',' };
                self.index += 1;
                return Token.init(ttype, self.index);
            },
            '*' => {
                const ttype = TokenType{ .asterix = '*' };
                self.index += 1;
                return Token.init(ttype, self.index);
            },
            '(' => {
                const ttype = TokenType{ .oparen = '(' };
                self.index += 1;
                return Token.init(ttype, self.index);
            },
            ')' => {
                const ttype = TokenType{ .cparen = ')' };
                self.index += 1;
                return Token.init(ttype, self.index);
            },
            '0'...'9' => {
                const amtv = try extract_numeric_token(self.input, self.index);
                self.index = amtv.i;
                return amtv.t;
            },
            '\'' => {
                const amtv = try extract_string_token(self.allocator, self.input, self.index);
                self.index = amtv.i;
                return amtv.t;
            },
            'A'...'Z', 'a'...'z' => {
                const amtv = try extract_character_sequence(self.allocator, self.input, self.index);
                self.index = amtv.i;
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

    pub fn free_token(self: *Lexer, token: Token) void {
        switch (token.token_type) {
            .identifier, .string => |i| {
                self.allocator.free(i);
            },
            else => {},
        }
    }
};

fn extract_numeric_token(code: []const u8, s_index: u32) !struct { t: Token, i: u32 } {
    var index = s_index;
    while (index < code.len) {
        switch (code[index]) {
            '0'...'9' => {
                index += 1;
            },
            else => break,
        }
    }
    const value = try std.fmt.parseInt(i32, code[s_index..index], 0);
    const ttype = TokenType{ .numeric = value };
    const token = Token.init(ttype, s_index + 1);
    return .{ .t = token, .i = index };
}

fn extract_string_token(allocator: std.mem.Allocator, code: []const u8, s_index: u32) !struct { t: Token, i: u32 } {
    var index = s_index + 1;

    while (index < code.len) {
        if (code[index] == '\'') {
            index += 1;
            break;
        }
        index += 1;
    }

    const copied = try allocator.dupe(u8, code[s_index..index]);
    const ttype = TokenType{ .string = copied };
    const token = Token.init(ttype, s_index + 1);
    return .{ .t = token, .i = index };
}

fn extract_character_sequence(allocator: std.mem.Allocator, code: []const u8, s_index: u32) !struct { t: Token, i: u32 } {
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
    const token = Token.init(ttype, s_index + 1);
    return .{ .t = token, .i = index };
}

fn make_identifier_or_keyword(allocator: std.mem.Allocator, string: []const u8) !TokenType {
    if ((std.mem.eql(u8, string, "CREATE")) or (std.mem.eql(u8, string, "create"))) {
        return TokenType{ .keyword = KeywordVariant.Create };
    } else if ((std.mem.eql(u8, string, "TABLE")) or (std.mem.eql(u8, string, "table"))) {
        return TokenType{ .keyword = KeywordVariant.Table };
    } else if ((std.mem.eql(u8, string, "INT")) or (std.mem.eql(u8, string, "int"))) {
        return TokenType{ .keyword = KeywordVariant.Int };
    } else if ((std.mem.eql(u8, string, "TEXT")) or (std.mem.eql(u8, string, "text"))) {
        return TokenType{ .keyword = KeywordVariant.Text };
    } else if ((std.mem.eql(u8, string, "INSERT")) or (std.mem.eql(u8, string, "insert"))) {
        return TokenType{ .keyword = KeywordVariant.Insert };
    } else if ((std.mem.eql(u8, string, "INTO")) or (std.mem.eql(u8, string, "into"))) {
        return TokenType{ .keyword = KeywordVariant.Into };
    } else if ((std.mem.eql(u8, string, "VALUES")) or (std.mem.eql(u8, string, "values"))) {
        return TokenType{ .keyword = KeywordVariant.Values };
    } else if ((std.mem.eql(u8, string, "SELECT")) or (std.mem.eql(u8, string, "select"))) {
        return TokenType{ .keyword = KeywordVariant.Select };
    } else if ((std.mem.eql(u8, string, "FROM")) or (std.mem.eql(u8, string, "from"))) {
        return TokenType{ .keyword = KeywordVariant.From };
    } else {
        const copied = try allocator.dupe(u8, string);
        return TokenType{ .identifier = copied };
    }
}
