pub fn parseFromDirPath(
    mem_ctx: *MemCtx,
    base_path: []const u8,
    tmpl_path: []const u8,
) !ArrayList(Document) {
    var dir = try std.fs.cwd().openDir(base_path, .{ .iterate = true });
    defer dir.close();

    var docs: ArrayList(Document) = .empty;
    try walkDir(mem_ctx, dir, "", tmpl_path, &docs);
    return docs;
}

fn walkDir(
    mem_ctx: *MemCtx,
    open_dir: Dir,
    relative_path: []const u8,
    tmpl_path: []const u8,
    docs: *ArrayList(Document),
) !void {
    var it = open_dir.iterate();

    while (try it.next()) |dir_entry| {
        defer mem_ctx.resetScratch();
        switch (dir_entry.kind) {
            .file => {
                if (!mem.endsWith(u8, dir_entry.name, ".md")) continue;

                const doc_path = try mem_ctx.global.dupe(u8, relative_path);
                const file_name = try mem_ctx.global.dupe(u8, dir_entry.name);
                std.log.debug("Parsing: {s}/{s}", .{ doc_path, file_name });
                const md_content = try open_dir.readFileAlloc(mem_ctx.global, dir_entry.name, common.MAX_FILE_SIZE);

                var parser = Parser.init(mem_ctx, doc_path, file_name, md_content);
                const doc = try parser.parse();

                try docs.append(mem_ctx.global, doc);
            },
            .directory => {
                if (relative_path.len == 0 and mem.eql(u8, dir_entry.name, tmpl_path)) continue;
                if (mem.startsWith(u8, dir_entry.name, "__")) continue;

                const new_rel_path = if (relative_path.len > 0)
                    try path.join(
                        mem_ctx.scratch,
                        &[_][]const u8{ relative_path, dir_entry.name },
                    )
                else
                    dir_entry.name;

                var sub_dir = try open_dir.openDir(dir_entry.name, .{ .iterate = true });
                defer sub_dir.close();

                try walkDir(mem_ctx, sub_dir, new_rel_path, tmpl_path, docs);
            },
            else => {
                std.log.err("Unsupported file system entry at {s}/{s}", .{ relative_path, dir_entry.name });
                return error.UnsupportedFileType;
            },
        }
    }
}

const Parser = struct {
    frontmatter: ?ParsedFrontmatter,
    nodes: ArrayList(Node),
    file_path: []const u8,
    file_name: []const u8,

    tokenizer: Tokenizer,
    mem_ctx: *MemCtx,

    pub const ParseError = error{ OutOfMemory, InvalidMagicMarker, FrontmatterNotFound, InvalidSpecialBlockquote, InvalidList } || std.json.ParseError(std.json.Scanner);

    fn init(mem_ctx: *MemCtx, file_path: []const u8, file_name: []const u8, global_owned_source: []const u8) @This() {
        return .{
            .nodes = .empty,
            .file_path = file_path,
            .file_name = file_name,
            .frontmatter = null,
            .tokenizer = Tokenizer.init(global_owned_source),
            .mem_ctx = mem_ctx,
        };
    }

    fn parse(self: *@This()) !Document {
        while (!self.tokenizer.isAtEnd()) try self.parseNextNode();
        if (self.frontmatter == null) {
            std.log.err("frontmatter not found on {s}/{s}", .{ self.file_path, self.file_name });
            return ParseError.FrontmatterNotFound;
        }
        return .init(
            self.nodes,
            self.frontmatter.?,
            self.file_path,
            self.file_name,
        );
    }

    fn parseNextNode(self: *@This()) !void {
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
        if (self.isBlockquote()) {
            try self.parseBlockquote();
            return;
        }

        if (self.isDivider()) {
            try self.parseDivider();
            return;
        }
        if (isList(self.tokenizer.peekLine()) != null) {
            try self.parseList();
            return;
        }

        try self.parseParagraph();
    }

    fn isList(line: []const u8) ?Node.ListKind {
        if (isTodoList(line)) return .todo;
        if (isUnorderedList(line)) return .unordered;
        if (isOrderedList(line)) return .ordered;
        return null;
    }

    fn parseList(self: *@This()) !void {
        const node = try self.parseListAndGetNode(0, 0);
        try self.nodes.append(self.mem_ctx.global, .{ .list = node });
    }

    fn parseListAndGetNode(self: *@This(), depth: usize, indent: usize) !*Node.List {
        const list = try self.mem_ctx.global.create(Node.List);
        list.* = .empty;
        list.depth = depth;
        list.kind = if (isList(self.tokenizer.peekLine())) |kind| kind else return ParseError.InvalidList;

        while (!self.tokenizer.isAtEnd()) {
            const peeked_line = self.tokenizer.peekLine();
            if (isList(peeked_line) == null) {
                break;
            }
            const current_indent = getIndent(peeked_line);
            if (current_indent > indent) {
                const inner_list = try self.parseListAndGetNode(depth + 1, current_indent);
                try list.items.append(self.mem_ctx.global, .{ .list = inner_list });
                continue;
            }
            if (current_indent < indent and current_indent > 0) {
                break;
            }
            const line = self.tokenizer.consumeLine();
            const trimmed = std.mem.trim(u8, line, " \t\r");

            if (list.kind == .todo) {
                const checked = mem.startsWith(u8, trimmed, "- [x] ") or mem.startsWith(u8, trimmed, "- [X] ");
                const content_start = 6;
                const content = std.mem.trim(u8, trimmed[content_start..], " \t\r");
                try list.items.append(self.mem_ctx.global, .{
                    .todo_item = .{
                        .checked = checked,
                        .content = content,
                    },
                });
            } else {
                const content_start = blk: {
                    if (list.kind == .ordered) {
                        var i: usize = 0;
                        while (i < trimmed.len and std.ascii.isDigit(trimmed[i])) : (i += 1) {}
                        // after skipping number we skip ". "
                        break :blk i + 2;
                    }
                    // symbol and a space
                    break :blk 2;
                };
                try list.items.append(self.mem_ctx.global, .{ .p = trimmed[content_start..] });
            }
        }

        return list;
    }
    fn getIndent(line: []const u8) usize {
        var count: usize = 0;
        for (line) |c| {
            switch (c) {
                ' ' => count += 1,
                '\t' => count += 4,
                else => break,
            }
        }
        return count;
    }

    fn isTodoList(line: []const u8) bool {
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (mem.startsWith(u8, trimmed, "- [ ] ") or mem.startsWith(u8, trimmed, "- [x] ") or mem.startsWith(u8, trimmed, "- [X] ")) return true;
        return false;
    }

    fn isUnorderedList(line: []const u8) bool {
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (mem.startsWith(u8, trimmed, "- ") or mem.startsWith(u8, trimmed, "* ") or mem.startsWith(u8, trimmed, "+ ")) return true;
        return false;
    }

    fn isOrderedList(line: []const u8) bool {
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (trimmed.len >= 2 and std.ascii.isDigit(trimmed[0]) and trimmed[1] == '.' and trimmed[2] == ' ') return true;
        return false;
    }

    fn isDivider(self: *@This()) bool {
        const line = self.tokenizer.peekLine();
        const trimmed = std.mem.trim(u8, line, " \t\r");
        return mem.eql(u8, trimmed, "---") or mem.eql(u8, trimmed, "***") or mem.eql(u8, trimmed, "___");
    }

    fn parseDivider(self: *@This()) !void {
        const line = self.tokenizer.consumeLine();
        const trimmed = std.mem.trim(u8, line, " \t\r");
        var divider_type: Node.DividerType = .normal;
        if (mem.eql(u8, trimmed, "---")) {
            divider_type = .dashed;
        } else if (mem.eql(u8, trimmed, "***")) {
            divider_type = .dotted;
        } else if (mem.eql(u8, trimmed, "___")) {
            divider_type = .normal;
        }
        const node: Node = .{ .divider = divider_type };
        try self.nodes.append(self.mem_ctx.global, node);
    }

    fn isBlockquote(self: *@This()) bool {
        const line = self.tokenizer.peekLine();
        return mem.startsWith(u8, line, "> ");
    }

    fn parseBlockquote(self: *@This()) !void {
        var content: ArrayList(u8) = .empty;
        var first_line = true;
        var kind: Node.Blockquote.Kind = .normal;

        while (!self.tokenizer.isAtEnd()) {
            var line = self.tokenizer.peekLine();
            if (!mem.startsWith(u8, line, "> ")) break;

            line = std.mem.trim(u8, line, " \t\r");
            _ = self.tokenizer.consumeLine();

            if (first_line and mem.eql(u8, line, "> [!NOTE]")) {
                kind = .note;
                continue;
            }
            if (first_line and mem.eql(u8, line, "> [!TIP]")) {
                kind = .tip;
                continue;
            }
            if (first_line and mem.eql(u8, line, "> [!IMPORTANT]")) {
                kind = .important;
                continue;
            }
            if (first_line and mem.eql(u8, line, "> [!WARNING]")) {
                kind = .warning;
                continue;
            }
            if (first_line and mem.eql(u8, line, "> [!CAUTION]")) {
                kind = .caution;
                continue;
            }

            first_line = false;
            if (line.len >= 2) {
                const content_raw = std.mem.trim(u8, line[2..], " \t\r");
                try content.appendSlice(self.mem_ctx.global, content_raw);
                try content.append(self.mem_ctx.global, '\n');
            } else {
                // Empty blockquote line, just add newline
                try content.append(self.mem_ctx.global, '\n');
            }
        }
        if (kind != .normal and content.items.len == 0) {
            std.log.err("{s} found without any notes following it", .{@tagName(kind)});
            return error.InvalidSpecialBlockquote;
        }
        const node: Node = .{ .block_quote = .{
            .kind = kind,
            .content = content.items,
        } };
        try self.nodes.append(self.mem_ctx.global, node);
    }

    fn isMagicMarker(self: *@This()) bool {
        const line = self.tokenizer.peekLine();
        return mem.startsWith(u8, line, tmpl.MAGIC_MARKER_PREFIX);
    }

    fn parseMagicMarker(self: *@This()) !void {
        const line = self.tokenizer.consumeLine();
        var token_it = std.mem.tokenizeScalar(u8, line, ' ');
        _ = token_it.next(); // consume {{

        const marker_name = try self.mem_ctx.global.dupe(u8, token_it.next() orelse return ParseError.InvalidMagicMarker);
        const marker_args = if (token_it.next()) |arg| try self.mem_ctx.global.dupe(u8, arg) else null;
        var marker_data: ?std.json.Parsed(std.json.Value) = null;

        if (self.isCodeBlock()) {
            const code_block_line = self.tokenizer.peekLine();
            if (mem.startsWith(u8, code_block_line, tmpl.MAGIC_INCLUDE_HTML_DATA)) {
                const block = try self.parseCodeBlockGetNode();
                marker_data = std.json.parseFromSlice(std.json.Value, self.mem_ctx.global, block.code.content, .{}) catch |err| {
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
        try self.nodes.append(self.mem_ctx.global, node);
    }

    fn isCodeBlock(self: *@This()) bool {
        const line = self.tokenizer.peekLine();
        return mem.startsWith(u8, line, "```");
    }

    fn parseCodeBlockGetNode(self: *@This()) !Node {
        var code_content: ArrayList(u8) = .empty;

        const opening_line = self.tokenizer.consumeLine(); // consume opening ```

        // Extract language (if any)
        const lang = if (opening_line.len > 3) opening_line[3..] else null;

        while (!self.tokenizer.isAtEnd()) {
            const line = self.tokenizer.peekLine();
            if (mem.startsWith(u8, line, "```")) {
                _ = self.tokenizer.consumeLine(); // consume closing ```
                break;
            }
            const code_line = self.tokenizer.consumeLine();
            try code_content.appendSlice(self.mem_ctx.global, code_line);
            try code_content.append(self.mem_ctx.global, '\n');
        }

        const node: Node = .{
            .code = .{
                .content = code_content.items,
                .language = lang,
            },
        };
        return node;
    }

    fn parseCodeBlock(self: *@This()) !void {
        const node = try self.parseCodeBlockGetNode();
        if (node == .code and node.code.language != null and mem.eql(u8, node.code.language.?, tmpl.MAGIC_FRONTMATTER)) {
            const frontmatter_json = node.code.content;
            const parsed = try std.json.parseFromSlice(Frontmatter, self.mem_ctx.global, frontmatter_json, .{});
            self.frontmatter = parsed;
            return;
        }
        try self.nodes.append(self.mem_ctx.global, node);
    }

    fn parseParagraph(self: *@This()) !void {
        var pcontent: ArrayList(u8) = .empty;
        while (!self.tokenizer.isAtEnd()) {
            const line = self.tokenizer.consumeLine();
            try pcontent.appendSlice(self.mem_ctx.global, line);

            if (self.isHeading()) break;
            if (self.isCodeBlock()) break;
            if (self.isMagicMarker()) break;
            if (self.isBlockquote()) break;
            if (self.isDivider()) break;
            if (isList(self.tokenizer.peekLine()) != null) break;
            if (mem.trim(u8, self.tokenizer.peekLine(), " \t\r").len == 0) break;

            try pcontent.appendSlice(self.mem_ctx.global, " ");
        }
        const node: Node = .{ .p = pcontent.items };
        try self.nodes.append(self.mem_ctx.global, node);
    }

    fn isHeading(self: *@This()) bool {
        return self.tokenizer.peek() == '#';
    }

    fn parseHeading(self: *@This()) !void {
        var level: usize = 0;
        while (self.tokenizer.peek() == '#') {
            _ = self.tokenizer.advance();
            level += 1;
        }
        const heading_text = std.mem.trim(u8, self.tokenizer.consumeLine(), " \t\r");
        const node: Node = switch (level) {
            1 => .{ .h1 = heading_text },
            2 => .{ .h2 = heading_text },
            3 => .{ .h3 = heading_text },
            4 => .{ .h4 = heading_text },
            else => .{ .h4 = heading_text },
        };
        try self.nodes.append(self.mem_ctx.global, node);
    }
};

const std = @import("std");
const Document = @import("Document.zig");
const Tokenizer = @import("Tokenizer.zig");
const tmpl = @import("tmpl.zig");
const common = @import("common.zig");
const MemCtx = common.MemCtx;

const Allocator = std.mem.Allocator;
const Node = Document.Node;
const ParsedFrontmatter = Document.ParsedFrontmatter;
const Frontmatter = Document.Frontmatter;
const ArrayList = std.ArrayList;
const StringHashMap = std.StringHashMap;
const mem = std.mem;
const Dir = std.fs.Dir;
const path = std.fs.path;
