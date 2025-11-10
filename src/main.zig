const MAX_FILE_SIZE = 10 * 1024 * 1024; // 10 MB

const CliArgs = struct {
    app_name: []const u8 = "Demo",
    base_path: []const u8 = "example",
    output_path: []const u8 = "dist",
    templates_folder: []const u8 = "__templates",
};

// TODO(seg4lt)
// - Using gpa, for now, but need to work with arena. Don't know life time well yet!!
// - Maybe we don't even care about memory as this is not long running process?
//      - But what if we add server later for search??
pub fn main() !void {
    const gpa, const deinit = getAllocator();
    _ = deinit;
    // defer if (deinit) {
    //     const leak_status = debug_allocator.deinit();
    //     if (builtin.mode == .Debug) std.log.debug("----- LEAK STATUS: {s} ----- ", .{@tagName(leak_status)});
    // };

    const args = claptain.parse(CliArgs, .{}) catch std.process.exit(1);

    std.fs.cwd().makePath(args.output_path) catch |err| if (err != error.PathAlreadyExists) return err;

    // Need to find better position
    const main_nav_html = try createMainNav(gpa, args.base_path, args.app_name);
    defer gpa.free(main_nav_html);

    var dir = try std.fs.cwd().openDir(args.base_path, .{ .iterate = true });
    defer dir.close();
    try walkDir(gpa, args.output_path, dir, "", main_nav_html);
}

pub fn createMainNav(gpa: Allocator, base_path: []const u8, app_name: []const u8) ![]const u8 {
    var dir = try std.fs.cwd().openDir(base_path, .{ .iterate = true });
    defer dir.close();
    var top_level_dirs: ArrayList([]const u8) = .empty;
    defer top_level_dirs.deinit(gpa);

    var it = dir.iterate();
    while (try it.next()) |dir_entry| {
        if (dir_entry.kind == .directory) {
            try top_level_dirs.append(gpa, dir_entry.name);
        }
    }
    var accumulator = std.io.Writer.Allocating.init(gpa);
    var writer = &accumulator.writer;
    try writer.print(
        \\<nav class="main-nav">
        \\    <div class="nav-container">
        \\        <a href="/" class="nav-logo">{s}</a>
        \\        <ul class="nav-links">
    , .{app_name});
    for (top_level_dirs.items) |dir_name| {
        try writer.print(
            \\<li><a href="/{s}/">{s}</a></li>
        , .{ dir_name, dir_name });
    }
    try writer.print(
        \\        </ul>
        \\    </div>
        \\</nav>
    , .{});
    return try accumulator.toOwnedSlice();
}

pub fn walkDir(gpa: Allocator, output_path: []const u8, dir: Dir, relative_path: []const u8, main_nav_html: []const u8) !void {
    var it = dir.iterate();

    while (try it.next()) |dir_entry| {
        switch (dir_entry.kind) {
            .file => {
                if (!mem.endsWith(u8, dir_entry.name, ".md")) continue;
                try generateHtml(gpa, output_path, dir, relative_path, dir_entry.name, main_nav_html);
            },
            .directory => {
                @panic("not implemented");
            },
            else => |tag| std.debug.panic("{s} not implemented", .{@tagName(tag)}),
        }
    }
}

fn generateHtml(gpa: Allocator, output_base: []const u8, dir: Dir, relative_path: []const u8, file_name: []const u8, main_nav_html: []const u8) !void {
    const html_name = try std.mem.replaceOwned(u8, gpa, file_name, ".md", ".html");
    defer gpa.free(html_name);

    const output_relative_path = if (relative_path.len > 0)
        try std.fs.path.join(gpa, &[_][]const u8{ relative_path, html_name })
    else
        html_name;

    defer if (relative_path.len > 0) gpa.free(output_relative_path);

    std.log.debug("Converting: {s} -> {s}", .{ file_name, output_relative_path });

    const md_content = try dir.readFileAlloc(gpa, file_name, MAX_FILE_SIZE);
    defer gpa.free(md_content);

    var parser = Parser.init(gpa, md_content);
    const doc = try parser.parse();

    var generator = HtmlGenerator.init(gpa, &doc, output_relative_path);
    const html = try generator.generate();

    // Apply base template with main_nav
    const full_html = try generator.replacePlaceholdersOwned(
        tmpl.DEFAULT_BASE_HTML,
        &[_][]const u8{ "{{title}}", "{{content}}", "{{main_nav}}" },
        &[_][]const u8{ doc.nodes.items[0].h1, html, main_nav_html },
    );
    defer gpa.free(full_html);

    // Write to output file
    const output_path = try std.fs.path.join(gpa, &[_][]const u8{ output_base, output_relative_path });
    defer gpa.free(output_path);

    const output_file = try std.fs.cwd().createFile(output_path, .{});
    defer output_file.close();
    try output_file.writeAll(full_html);
}

const HtmlGenerator = struct {
    gpa: Allocator,
    document: *const Document,
    output_path: []const u8,
    accumulator: std.Io.Writer.Allocating,

    pub const Error = error{ OutOfMemory, WriteFailed };

    pub fn init(gpa: Allocator, doc: *const Document, output_path: []const u8) HtmlGenerator {
        return .{
            .gpa = gpa,
            .output_path = output_path,
            .document = doc,
            .accumulator = std.io.Writer.Allocating.init(gpa),
        };
    }

    pub fn generate(self: *@This()) Error![]u8 {
        for (self.document.nodes.items) |node| {
            try self.generateNode(node);
        }
        var a = self.accumulator;
        return try a.toOwnedSlice();
    }

    fn generateNode(self: *@This(), node: Node) Error!void {
        const final_html = switch (node) {
            .h1, .h2, .h3, .h4 => try self.generateHeading(node),
        };
        defer self.gpa.free(final_html);
        try self.accumulator.writer.print("\n{s}\n", .{final_html});
        try self.accumulator.writer.flush();
    }

    fn generateHeading(self: *@This(), node: Node) Error![]u8 {
        const text = switch (node) {
            .h1, .h2, .h3, .h4 => |text| text,
            // else => std.debug.panic("** bug ** not reachable - only heading should reach here", .{}),
        };
        const tmpl_str = tmpl.DEFAULT_HEADING_HTML;
        const final_html = try self.replacePlaceholdersOwned(
            tmpl_str,
            &[_][]const u8{ "{{level}}", "{{content}}" },
            &[_][]const u8{ switch (node) {
                .h1 => "1",
                .h2 => "2",
                .h3 => "3",
                else => "4",
            }, text },
        );
        return final_html;
    }

    // TODO(seg4lt)
    // Maybe implement proper parser, so we don't use replaceOwned
    // replaceOwned is called multiple times, so it's not efficient
    // If we create our own parser, I think we can do this in one pass
    // Also we don't need to make copy and destroy
    fn replacePlaceholdersOwned(self: *@This(), haystack: []const u8, keys: []const []const u8, values: []const []const u8) Error![]u8 {
        var result = try self.gpa.dupe(u8, haystack);
        for (keys, values) |key, value| {
            const old = result;
            defer self.gpa.free(old);
            result = try mem.replaceOwned(u8, self.gpa, result, key, value);
        }
        return result;
    }
};

const Document = struct {
    nodes: ArrayList(Node),
    gpa: Allocator,

    pub fn init(gpa: Allocator) Document {
        return .{
            .nodes = .empty,
            .gpa = gpa,
        };
    }
};

const Node = union(enum) {
    h1: []const u8,
    h2: []const u8,
    h3: []const u8,
    h4: []const u8,
};

const Tokenizer = struct {
    source: []const u8,
    pos: usize,

    pub fn init(source: []const u8) Tokenizer {
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
};

const Parser = struct {
    document: Document,
    tokenizer: Tokenizer,
    gpa: Allocator,

    pub const ParseError = error{OutOfMemory};

    pub fn init(gpa: Allocator, source: []const u8) Parser {
        return .{
            .document = .init(gpa),
            .gpa = gpa,
            .tokenizer = Tokenizer.init(source),
        };
    }

    pub fn parse(self: *@This()) ParseError!Document {
        while (!self.tokenizer.isAtEnd()) try self.parseNextNode();
        return self.document;
    }

    fn parseNextNode(self: *@This()) ParseError!void {
        self.tokenizer.skipWhitespace();

        const ch = self.tokenizer.peek() orelse return;
        switch (ch) {
            '\n' => {
                _ = self.tokenizer.advance();
                return;
            },
            '#' => try self.parseHeading(),
            else => std.debug.panic("{s} I don't understand this\n", .{&[_]u8{ch}}),
        }
    }
    fn parseHeading(self: *@This()) ParseError!void {
        var level: usize = 0;
        while (self.tokenizer.peek() == '#') {
            _ = self.tokenizer.advance();
            level += 1;
        }
        const heading_text = std.mem.trim(u8, self.tokenizer.consumeLine(), " \t\r");
        const owned = try self.document.gpa.dupe(u8, heading_text);

        const node: Node = switch (level) {
            1 => .{ .h1 = owned },
            2 => .{ .h2 = owned },
            3 => .{ .h3 = owned },
            4 => .{ .h4 = owned },
            else => .{ .h4 = owned },
        };
        try self.document.nodes.append(self.document.gpa, node);
    }
};

fn getAllocator() struct { Allocator, bool } {
    return switch (builtin.mode) {
        .Debug, .ReleaseSafe => .{ debug_allocator.allocator(), true },
        .ReleaseSmall, .ReleaseFast => .{ std.heap.smp_allocator, false },
    };
}

const std = @import("std");
const claptain = @import("claptain");
const builtin = @import("builtin");
const tmpl = @import("tmpl.zig");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const mem = std.mem;
const Dir = std.fs.Dir;
var debug_allocator: std.heap.DebugAllocator(.{}) = .init;
