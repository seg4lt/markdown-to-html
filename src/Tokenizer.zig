source: []const u8,
pos: usize,

pub fn init(source: []const u8) @This() {
    return .{
        .source = source,
        .pos = 0,
    };
}

pub fn peek(self: *@This()) ?u8 {
    if (self.isAtEnd()) return null;
    return self.source[self.pos];
}

pub fn peekLine(self: *@This()) []const u8 {
    const start = self.pos;
    var end = start;
    while (end < self.source.len and self.source[end] != '\n') {
        end += 1;
    }
    return self.source[start..end];
}

pub fn consumeLine(self: *@This()) []const u8 {
    const line = self.peekLine();
    self.pos += line.len;
    // peekLine doesn't pickup newline if exists, so we need to advance it exists
    if (self.pos < self.source.len and self.source[self.pos] == '\n') {
        self.pos += 1;
    }
    return line;
}

pub fn skipWhitespace(self: *@This()) void {
    while (std.ascii.isWhitespace(self.peek() orelse 0)) _ = self.advance();
}

pub fn advance(self: *@This()) ?u8 {
    if (self.isAtEnd()) return null;
    const ch = self.source[self.pos];
    self.pos += 1;
    return ch;
}

pub fn isAtEnd(self: *@This()) bool {
    return self.pos >= self.source.len;
}

const std = @import("std");
