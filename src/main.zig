const std = @import("std");
const lexer = @import("lexer.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leak_check = gpa.deinit();
        if (leak_check == .leak) {
            std.debug.print("Memory leak detected!\n", .{});
        }
    }
    const allocator = gpa.allocator();

    while (true) {
        try print_dollar();
        const line = try getInput(allocator);
        defer allocator.free(line);
        if (std.mem.eql(u8, line, "quit") == true) {
            return;
        }

        const tokens = try lexer.tokenize(allocator, line);
        defer (lexer.free_tokens(allocator, tokens));
    }
}

fn getInput(allocator: std.mem.Allocator) ![]const u8 {
    const stdin = std.io.getStdIn().reader();
    const line = try stdin.readUntilDelimiterAlloc(allocator, '\n', 8192);

    return std.mem.trim(u8, line, "\r");
}

fn print_dollar() !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print("$> ", .{});
}
