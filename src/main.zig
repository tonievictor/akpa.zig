const std = @import("std");
const parser = @import("parser.zig");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    try print("welcome to akpa, a minimal sql engine\n");
    try print("type '\\q' to quit\n");

    while (true) {
        try print("$> ");
        const line = try getInput(allocator);
        if (std.mem.eql(u8, line, "\\q") == true) {
            break;
        }

        const stmt = parser.parse(allocator, line) catch |err| {
            std.debug.print("{any}\n", .{err});
            continue;
        };
        std.debug.print("{any}\n", .{stmt});
    }
}

fn getInput(allocator: std.mem.Allocator) ![]const u8 {
    const stdin = std.io.getStdIn().reader();
    const line = try stdin.readUntilDelimiterAlloc(allocator, '\n', 8192);

    return std.mem.trim(u8, line, "\r");
}

fn print(prompt: []const u8) !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print("{s}", .{prompt});
}
