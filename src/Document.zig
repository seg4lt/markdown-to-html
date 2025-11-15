nodes: ArrayList(Node),
file_path: []const u8,
file_name: []const u8,
frontmatter: ParsedFrontmatter,

pub fn init(nodes: ArrayList(Node), frontmatter: ParsedFrontmatter, file_path: []const u8, file_name: []const u8) @This() {
    return .{
        .nodes = nodes,
        .frontmatter = frontmatter,
        .file_path = file_path,
        .file_name = file_name,
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
    block_quote: Blockquote,
    divider: DividerType,
    list: *List,

    pub const ListKind = enum { ordered, unordered, todo };
    pub const List = struct {
        kind: ListKind,
        depth: usize,
        items: ArrayList(ListItemKind),

        pub const empty: @This() = .{ .kind = .unordered, .depth = 0, .items = .empty };
    };
    pub const ListItemKind = union(enum) {
        p: []const u8,
        todo_item: struct {
            checked: bool,
            content: []const u8,
        },
        list: *List,
    };

    pub const DividerType = enum { normal, dashed, dotted };

    pub const Blockquote = struct {
        kind: Kind,
        content: []const u8,

        pub const Kind = enum { normal, note, tip, important, warning, caution };
    };

    pub const CodeBlock = struct {
        content: []const u8,
        language: ?[]const u8,
    };

    pub const MagicMarker = struct {
        name: []const u8,
        args: ?[]const u8,
        data: ?std.json.Parsed(std.json.Value),
    };
};

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
