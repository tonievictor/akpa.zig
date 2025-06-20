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
};

const Token = struct {
    token_type: TokenType,
    line: i32,
    col: i32,

    pub fn init(ttype: TokenType, line: i32, col: i32) Token {
        return Token{
            .token_type = ttype,
            .line = line,
            .col = col,
        };
    }
};

const LexerError = error{
    IllegalCharacter,
};

pub fn free_tokens(allocator: std.mem.Allocator, tokens: []Token) void {
    for (tokens) |token| {
        switch (token.token_type) {
            .identifier, .string => |i| {
                allocator.free(i);
            },
            else => {
                continue;
            },
        }
    }
    allocator.free(tokens);
}

pub fn tokenize(allocator: std.mem.Allocator, code: []const u8) ![]Token {
    var index: u32 = 0;
    var line: i32 = 1;
    var col: i32 = 1;
    var tokens = std.ArrayList(Token).init(allocator);

    while (index < code.len) {
        var token: Token = undefined;
        const char = code[index];
        switch (char) {
            '\n' => {
                line += 1;
                col = 1;
                index += 1;
                continue;
            },
            ' ', '\t' => {
                col += 1;
                index += 1;
                continue;
            },
            ';' => {
                const ttype = TokenType{ .semicolon = ';' };
                token = Token.init(ttype, line, col);
                col += 1;
                index += 1;
            },
            ',' => {
                const ttype = TokenType{ .comma = ',' };
                token = Token.init(ttype, line, col);
                col += 1;
                index += 1;
            },
            '*' => {
                const ttype = TokenType{ .asterix = '*' };
                token = Token.init(ttype, line, col);
                col += 1;
                index += 1;
            },
            '(' => {
                const ttype = TokenType{ .oparen = '(' };
                token = Token.init(ttype, line, col);
                col += 1;
                index += 1;
            },
            ')' => {
                const ttype = TokenType{ .cparen = ')' };
                token = Token.init(ttype, line, col);
                col += 1;
                index += 1;
            },
            '\'' => {
                const amv = try extract_string_token(allocator, code, index + 1, col + 1, line);
                token = amv.t;
                index = amv.i;
                col = amv.c;
            },
            '0'...'9' => {
                const amv = try extract_numeric_token(code, index, col, line);
                token = amv.t;
                index = amv.i;
                col = amv.c;
            },
            'A'...'Z', 'a'...'z' => {
                const amv = try extract_character_sequence(allocator, code, index, col, line);
                token = amv.t;
                index = amv.i;
                col = amv.c;
            },
            else => {
                return LexerError.IllegalCharacter;
            },
        }
        try tokens.append(token);
    }
    return try tokens.toOwnedSlice();
}

fn extract_numeric_token(code: []const u8, s_index: u32, s_col: i32, line: i32) !struct { t: Token, i: u32, c: i32 } {
    var index = s_index;
    var col = s_col;
    while (index < code.len) {
        switch (code[index]) {
            '0'...'9' => {
                index += 1;
                col += 1;
            },
            else => break,
        }
    }
    const value = try std.fmt.parseInt(i32, code[s_index..index], 0);
    const ttype = TokenType{ .numeric = value };
    const token = Token.init(ttype, line, s_col);
    return .{ .t = token, .i = index, .c = col };
}

fn extract_string_token(allocator: std.mem.Allocator, code: []const u8, s_index: u32, s_col: i32, line: i32) !struct { t: Token, i: u32, c: i32 } {
    var index = s_index;
    var col = s_col;

    while (index < code.len) {
        const i = index;
        index += 1;
        col += 1;
        if (code[i] == '\'') break;
    }

    const copied = try allocator.dupe(u8, code[s_index..index]);
    const ttype = TokenType{ .string = copied };
    const token = Token.init(ttype, line, s_col - 1);
    return .{ .t = token, .i = index, .c = col };
}

fn extract_character_sequence(allocator: std.mem.Allocator, code: []const u8, s_index: u32, s_col: i32, line: i32) !struct { t: Token, i: u32, c: i32 } {
    var index = s_index;
    var col = s_col;
    while (index < code.len) {
        switch (code[index]) {
            'A'...'Z', 'a'...'z' => {
                index += 1;
                col += 1;
            },
            else => break,
        }
    }

    const ttype = try make_identifier_or_keyword(allocator, code[s_index..index]);
    const token = Token.init(ttype, line, s_col);
    return .{ .t = token, .i = index, .c = col };
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
