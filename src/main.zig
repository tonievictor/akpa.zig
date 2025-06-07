const std = @import("std");

pub fn main() !void {
    while (true) {
        try print_dollar();
        const line = try getInput();
        defer std.heap.page_allocator.free(line);

        if (std.mem.eql(u8, line, "quit") == true) {
            return;
        }
    }
}

fn getInput() ![]const u8 {
    const stdin = std.io.getStdIn().reader();
    const line = try stdin.readUntilDelimiterAlloc(std.heap.page_allocator, '\n', 8192);

    return std.mem.trim(u8, line, "\r");
}

fn print_dollar() !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print("$> ", .{});
}

