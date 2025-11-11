pub fn generateAll(gpa: Allocator, docs: *const ArrayList(Document), output_base: []const u8, tmpl_manager: *TemplateManager) !void {
    var map = std.StringHashMap(*ArrayList(*const ParsedFrontmatter)).init(gpa);
    for (docs.items) |doc| {
        const result = try map.getOrPut(doc.file_path);
        if (!result.found_existing) {
            const list = try gpa.create(ArrayList(*const ParsedFrontmatter));
            list.* = .empty;
            result.value_ptr.* = list;
        }
        try result.value_ptr.*.append(gpa, &doc.frontmatter);
    }

    for (docs.items) |*doc| {
        var generator = HtmlGenerator.init(gpa, doc, output_base, tmpl_manager, &map);
        const html = try generator.generate();

        // Apply base template with main_nav
        const full_html = try generator.replacePlaceholdersOwned(
            tmpl.DEFAULT_BASE_HTML,
            &[_][]const u8{ "{{title}}", "{{content}}", "{{main_nav}}" },
            &[_][]const u8{ doc.frontmatter.value.title, html, try tmpl_manager.getMainNav() },
        );
        defer gpa.free(full_html);

        // Write to output file
        const output_path = try std.fs.path.join(gpa, &[_][]const u8{ output_base, doc.file_path });
        defer gpa.free(output_path);

        std.fs.cwd().makePath(output_path) catch |err| if (err != error.PathAlreadyExists) return err;

        const output_file_path = try std.fs.path.join(gpa, &[_][]const u8{ output_path, doc.file_name });
        defer gpa.free(output_file_path);

        const html_name = try std.mem.replaceOwned(u8, gpa, output_file_path, ".md", ".html");
        defer gpa.free(html_name);

        const output_file = try std.fs.cwd().createFile(html_name, .{});
        defer output_file.close();
        try output_file.writeAll(full_html);
    }
}

const HtmlGenerator = struct {
    gpa: Allocator,
    document: *const Document,
    output_path: []const u8,
    template_manager: *TemplateManager,
    groups: *const std.StringHashMap(*ArrayList(*const ParsedFrontmatter)),
    accumulator: std.Io.Writer.Allocating,

    const Self = @This();

    const Error = error{ OutOfMemory, WriteFailed };

    fn init(gpa: Allocator, doc: *const Document, output_path: []const u8, template_manager: *TemplateManager, groups: *std.StringHashMap(*ArrayList(*const ParsedFrontmatter))) @This() {
        return .{
            .gpa = gpa,
            .output_path = output_path,
            .document = doc,
            .groups = groups,
            .template_manager = template_manager,
            .accumulator = std.io.Writer.Allocating.init(gpa),
        };
    }

    fn generate(self: *@This()) Error![]u8 {
        for (self.document.nodes.items) |node| {
            if (node == .code and node.code.language != null and mem.eql(u8, node.code.language.?, tmpl.MAGIC_FRONTMATTER)) {
                continue;
            }
            try self.generateNode(node);
        }
        var a = self.accumulator;
        return try a.toOwnedSlice();
    }

    fn generateNode(self: *@This(), node: Node) Error!void {
        const final_html = switch (node) {
            .h1, .h2, .h3, .h4 => try self.generateHeading(node),
            .p => |text| try self.generateParagraph(text),
            .code => |code_block| try self.generateCodeBlock(code_block),
            .magic_marker => |marker| try self.generateMagicMarker(marker),
        };
        defer self.gpa.free(final_html);
        try self.accumulator.writer.print("\n{s}\n", .{final_html});
        try self.accumulator.writer.flush();
    }

    fn generateMagicMarker(self: *@This(), marker: Node.MagicMarker) Error![]u8 {
        _ = self;
        _ = marker;
        @panic("... not implemented ...");
    }

    fn generateCodeBlock(self: *@This(), code_block: Node.CodeBlock) Error![]u8 {
        const class_attr = if (code_block.language) |lang|
            try std.fmt.allocPrint(self.gpa, " class=\"language-{s}\"", .{lang})
        else
            "";
        defer self.gpa.free(class_attr);

        const tmpl_str = tmpl.DEFAULT_CODE_BLOCK;
        const final_html = try self.replacePlaceholdersOwned(
            tmpl_str,
            &[_][]const u8{ "{{class}}", "{{content}}" },
            &[_][]const u8{ class_attr, code_block.content },
        );
        return final_html;
    }

    fn generateParagraph(self: *@This(), p_content: []const u8) Error![]u8 {
        return std.fmt.allocPrint(self.gpa,
            \\ <p>{s}</p>
        , .{p_content});
    }

    fn generateHeading(self: *@This(), node: Node) Error![]u8 {
        const text = switch (node) {
            .h1, .h2, .h3, .h4 => |text| text,
            else => std.debug.panic("** bug ** not reachable - only heading should reach here", .{}),
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

const std = @import("std");
const Document = @import("Document.zig");
const tmpl = @import("tmpl.zig");
const TemplateManager = @import("TemplateManager.zig");
const common = @import("common.zig");
const Parser = @import("Parser.zig");

const MAX_FILE_SIZE = common.MAX_FILE_SIZE;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Node = Document.Node;
const ParsedFrontmatter = Document.ParsedFrontmatter;
const Frontmatter = Document.Frontmatter;
const mem = std.mem;
