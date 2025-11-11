pub fn parseFromDirPath(gpa: Allocator, base_path: []const u8, tmpl_path: []const u8) !ArrayList(Document) {
    var dir = try std.fs.cwd().openDir(base_path, .{ .iterate = true });
    defer dir.close();

    var docs: ArrayList(Document) = .empty;
    try walkDir(gpa, dir, "", tmpl_path, &docs);
    return docs;
}

fn walkDir(gpa: Allocator, dir: Dir, relative_path: []const u8, tmpl_path: []const u8, docs: *ArrayList(Document)) !void {
    var it = dir.iterate();

    while (try it.next()) |dir_entry| {
        switch (dir_entry.kind) {
            .file => {
                if (!mem.endsWith(u8, dir_entry.name, ".md")) continue;

                const doc_path = try gpa.dupe(u8, relative_path);
                const file_name = try gpa.dupe(u8, dir_entry.name);

                std.log.debug("Parsing: {s}/{s}", .{ doc_path, file_name });

                const md_content = try dir.readFileAlloc(gpa, dir_entry.name, common.MAX_FILE_SIZE);
                defer gpa.free(md_content);

                var parser = Parser.init(gpa, doc_path, file_name, md_content);
                const doc = try parser.parse();
                try docs.append(gpa, doc);
            },
            .directory => {
                if (relative_path.len == 0 and mem.eql(u8, dir_entry.name, tmpl_path)) continue;

                const new_rel_path = if (relative_path.len > 0)
                    try path.join(gpa, &[_][]const u8{ relative_path, dir_entry.name })
                else
                    dir_entry.name;
                defer if (relative_path.len > 0) gpa.free(new_rel_path);

                var sub_dir = try dir.openDir(dir_entry.name, .{ .iterate = true });
                defer sub_dir.close();

                try walkDir(gpa, sub_dir, new_rel_path, tmpl_path, docs);
            },
            else => |tag| std.debug.panic("{s} not supported", .{@tagName(tag)}),
        }
    }
}

const Parser = struct {
    frontmatter: ?ParsedFrontmatter,
    nodes: ArrayList(Node),
    file_path: []const u8,
    file_name: []const u8,

    tokenizer: Tokenizer,
    gpa: Allocator,

    pub const ParseError = error{ OutOfMemory, InvalidMagicMarker, FrontmatterNotFound } || std.json.ParseError(std.json.Scanner);

    fn init(gpa: Allocator, file_path: []const u8, file_name: []const u8, source: []const u8) @This() {
        return .{
            .nodes = .empty,
            .file_path = file_path,
            .file_name = file_name,
            .frontmatter = null,
            .tokenizer = Tokenizer.init(source),
            .gpa = gpa,
        };
    }

    fn parse(self: *@This()) ParseError!Document {
        while (!self.tokenizer.isAtEnd()) try self.parseNextNode();
        if (self.frontmatter == null) {
            std.log.err("frontmatter not found on {s}", .{self.file_path});
            return ParseError.FrontmatterNotFound;
        }
        return Document.init(self.gpa, self.nodes, self.frontmatter.?, self.file_path, self.file_name);
    }

    fn parseNextNode(self: *@This()) ParseError!void {
        self.tokenizer.skipWhitespace();

        const ch = self.tokenizer.peek() orelse return;
        if (ch == '\n') {
            _ = self.tokenizer.advance();
            return;
        }

        if (self.isHeading()) {
            try self.parseHeading();
            return;
        }

        if (self.isCodeBlock()) {
            try self.parseCodeBlock();
            return;
        }

        if (self.isMagicMarker()) {
            try self.parseMagicMarker();
            return;
        }

        try self.parseParagraph();
    }

    fn isMagicMarker(self: *@This()) bool {
        const line = self.tokenizer.peekLine();
        return mem.startsWith(u8, line, tmpl.MAGIC_MARKER_PREFIX);
    }

    fn parseMagicMarker(self: *@This()) ParseError!void {
        const line = self.tokenizer.consumeLine();
        var token_it = std.mem.tokenizeScalar(u8, line, ' ');
        _ = token_it.next(); // consume {{
        const marker_name = try self.gpa.dupe(u8, token_it.next() orelse return ParseError.InvalidMagicMarker);
        const marker_args = if (token_it.next()) |arg| try self.gpa.dupe(u8, arg) else null;
        var marker_data: ?std.json.Parsed(std.json.Value) = null;

        if (self.isCodeBlock()) {
            const code_block_line = self.tokenizer.peekLine();
            if (mem.startsWith(u8, code_block_line, tmpl.MAGIC_INCLUDE_HTML_DATA)) {
                const block = try self.parseCodeBlockGetNode();
                marker_data = std.json.parseFromSlice(std.json.Value, self.gpa, block.code.content, .{}) catch |err| {
                    std.log.err("Failed to parse JSON in magic marker '{s}' at {s}: {any}", .{ marker_name, self.file_path, err });
                    std.log.err("JSON content:\n{s}", .{block.code.content});
                    return err;
                };
            }
        }

        const node: Node = .{
            .magic_marker = .{
                .name = marker_name,
                .args = marker_args,
                .data = marker_data,
            },
        };
        try self.nodes.append(self.gpa, node);
    }

    fn isCodeBlock(self: *@This()) bool {
        const line = self.tokenizer.peekLine();
        return mem.startsWith(u8, line, "```");
    }

    fn parseCodeBlockGetNode(self: *@This()) ParseError!Node {
        var acc: ArrayList(u8) = .empty;
        defer acc.deinit(self.gpa);

        const opening_line = self.tokenizer.consumeLine(); // consume opening ```

        // Extract language (if any)
        const lang = if (opening_line.len > 3)
            try self.gpa.dupe(u8, opening_line[3..])
        else
            null;

        while (!self.tokenizer.isAtEnd()) {
            const line = self.tokenizer.peekLine();
            if (mem.startsWith(u8, line, "```")) {
                _ = self.tokenizer.consumeLine(); // consume closing ```
                break;
            }
            const code_line = self.tokenizer.consumeLine();
            try acc.appendSlice(self.gpa, code_line);
            try acc.append(self.gpa, '\n');
        }

        const node: Node = .{
            .code = .{
                .content = try acc.toOwnedSlice(self.gpa),
                .language = lang,
            },
        };
        return node;
    }

    fn parseCodeBlock(self: *@This()) ParseError!void {
        const node = try self.parseCodeBlockGetNode();
        if (node == .code and node.code.language != null and mem.eql(u8, node.code.language.?, tmpl.MAGIC_FRONTMATTER)) {
            const frontmatter_json = node.code.content;
            const parsed = try std.json.parseFromSlice(Frontmatter, self.gpa, frontmatter_json, .{});
            self.frontmatter = parsed;
            return;
        }
        try self.nodes.append(self.gpa, node);
    }

    fn parseParagraph(self: *@This()) ParseError!void {
        var acc: ArrayList(u8) = .empty;
        while (!self.tokenizer.isAtEnd()) {
            const line = self.tokenizer.consumeLine();
            try acc.appendSlice(self.gpa, line);

            if (self.isHeading()) break;
            if (self.isCodeBlock()) break;
        }
        const node: Node = .{ .p = try acc.toOwnedSlice(self.gpa) };
        try self.nodes.append(self.gpa, node);
    }

    fn isHeading(self: *@This()) bool {
        return self.tokenizer.peek() == '#';
    }

    fn parseHeading(self: *@This()) ParseError!void {
        var level: usize = 0;
        while (self.tokenizer.peek() == '#') {
            _ = self.tokenizer.advance();
            level += 1;
        }
        const heading_text = std.mem.trim(u8, self.tokenizer.consumeLine(), " \t\r");
        const owned = try self.gpa.dupe(u8, heading_text);

        const node: Node = switch (level) {
            1 => .{ .h1 = owned },
            2 => .{ .h2 = owned },
            3 => .{ .h3 = owned },
            4 => .{ .h4 = owned },
            else => .{ .h4 = owned },
        };
        try self.nodes.append(self.gpa, node);
    }
};

const std = @import("std");
const Document = @import("Document.zig");
const Tokenizer = @import("Tokenizer.zig");
const tmpl = @import("tmpl.zig");
const common = @import("common.zig");

const Allocator = std.mem.Allocator;
const Node = Document.Node;
const ParsedFrontmatter = Document.ParsedFrontmatter;
const Frontmatter = Document.Frontmatter;
const ArrayList = std.ArrayList;
const StringHashMap = std.StringHashMap;
const mem = std.mem;
const Dir = std.fs.Dir;
const path = std.fs.path;
