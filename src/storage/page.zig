const parser = @import("../parser/parser.zig");
const std = @import("std");

const PAGE_SIZE = 8000;
const MAX_FILE_SIZE = 1000000;
const NUM_OF_PAGES = @floor(MAX_FILE_SIZE / PAGE_SIZE);

pub const PageError = error{
    SlotOutOfRange,
    InvalidBufferSize,
    OutOfBounds,
};

const Page = packed struct {
    memory: *[PAGE_SIZE]u8,

    fn init(allocator: std.mem.Allocator) !Page {
        const slice = try allocator.alloc(u8, PAGE_SIZE);

        const header: *Header = @ptrCast(slice.ptr);
        header.* = Header{
            .slot_boundary = @sizeOf(Header),
            .slot_len = 0,
            .cell_offset = PAGE_SIZE,
        };

        const memory_ptr: *[PAGE_SIZE]u8 = @ptrCast(slice.ptr);
        return Page{ .memory = memory_ptr };
    }

    fn from_buffer(buffer: []u8) !Page {
        if (buffer.len != PAGE_SIZE) return PageError.InvalidBufferSize;
        const memory_ptr: *[PAGE_SIZE]u8 = @ptrCast(buffer.ptr);
        return Page{ .memory = memory_ptr };
    }

    fn get_row(self: *Page, row_id: u8) PageError![]const u8 {
        const slot_offset = (@sizeOf(Slot) * row_id) + @sizeOf(Header);
        const header = self.get_header();
        if (slot_offset > (header.*.slot_boundary - @sizeOf(Slot))) {
            return PageError.SlotOutOfRange;
        }

        const slot_ptr: *Slot = @ptrCast(&self.memory[slot_offset]);
        const slot = slot_ptr.*;

        const end = slot.offset + slot.size;
        if (end > PAGE_SIZE) {
            return PageError.OutOfBounds;
        }

        return self.memory[slot.offset .. slot.offset + slot.size];
    }

    fn insert_row(self: *Page, data: []u8) void {
        const header = self.get_header();
        header.slot_boundary += @sizeOf(Slot);
        header.slot_len += 1;
        header.cell_offset -= data.len;

        const slot = Slot{
            .offset = header.cell_offset,
            .size = data.len,
        };

        const slot_ptr: *Slot = @ptrCast(&self.memory[header.slot_boundary - @sizeOf(Slot)]);
        slot_ptr.* = slot;
        @memcpy(&self.memory[header.cell_offset .. header.cell_offset + data.len], data);
    }

    fn get_header(self: *Page) *Header {
        const header: *Header = @ptrCast(&self.memory.ptr);
        return header;
    }
};

const Header = packed struct {
    slot_boundary: u16,
    slot_len: u16, //number of slots
    cell_offset: u16,
};

const Slot = packed struct {
    offset: u16, //cell offset
    size: u16,
};
