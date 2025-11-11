nodes: ArrayList(Node),
file_path: []const u8,
file_name: []const u8,
frontmatter: ParsedFrontmatter,
gpa: Allocator,

pub fn init(gpa: Allocator, nodes: ArrayList(Node), frontmatter: ParsedFrontmatter, file_path: []const u8, file_name: []const u8) @This() {
    return .{
        .nodes = nodes,
        .frontmatter = frontmatter,
        .file_path = file_path,
        .file_name = file_name,
        .gpa = gpa,
    };
}

pub const ParsedFrontmatter = std.json.Parsed(Frontmatter);

pub const Frontmatter = struct {
    title: []const u8,
    description: []const u8,
    date: []const u8,
};

pub const Node = union(enum) {
    h1: []const u8,
    h2: []const u8,
    h3: []const u8,
    h4: []const u8,
    p: []const u8,
    code: CodeBlock,
    magic_marker: MagicMarker,

    pub const CodeBlock = struct {
        content: []const u8,
        language: ?[]const u8,
    };

    pub const MagicMarker = struct {
        name: []const u8,
        args: ?[]const u8,
    };
};

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
