const DocInfo = struct {
    file_path: []const u8,
    file_name: []const u8,
    frontmatter: *const Frontmatter,
};

pub fn generateAll(gpa: Allocator, docs: *const ArrayList(Document), output_base: []const u8, tmpl_manager: *TemplateManager) !void {
    var groups = std.StringHashMap(*ArrayList(DocInfo)).init(gpa);
    for (docs.items) |*doc| {
        std.log.debug("title({s}) file_path({s}), file_name({s})", .{ doc.frontmatter.value.title, doc.file_path, doc.file_name });

        const result = try groups.getOrPut(doc.file_path);
        if (!result.found_existing) {
            const list = try gpa.create(ArrayList(DocInfo));
            list.* = .empty;
            result.value_ptr.* = list;
        }
        try result.value_ptr.*.append(gpa, .{
            .file_path = doc.file_path,
            .file_name = doc.file_name,
            .frontmatter = &doc.frontmatter.value,
        });

        // blog is special, so we collect sub items as well
        if (mem.startsWith(u8, doc.file_path, "blog/")) {
            const blog_result = try groups.getOrPut("blog");
            if (!blog_result.found_existing) {
                const list = try gpa.create(ArrayList(DocInfo));
                list.* = .empty;
                blog_result.value_ptr.* = list;
            }
            try blog_result.value_ptr.*.append(gpa, .{
                .file_path = doc.file_path,
                .file_name = doc.file_name,
                .frontmatter = &doc.frontmatter.value,
            });
        }
    }

    for (docs.items) |*doc| {
        var generator = HtmlGenerator.init(gpa, doc, output_base, tmpl_manager, &groups);
        const html = try generator.generate();

        // Apply base template with main_nav
        const full_html = try TemplateManager.replacePlaceholders(
            gpa,
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
    groups: *const std.StringHashMap(*ArrayList(DocInfo)),
    accumulator: std.Io.Writer.Allocating,

    const Self = @This();

    const Error = error{
        OutOfMemory,
        WriteFailed,
        UnknownMagicMarker,
    };

    fn init(gpa: Allocator, doc: *const Document, output_path: []const u8, template_manager: *TemplateManager, groups: *std.StringHashMap(*ArrayList(DocInfo))) @This() {
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
        if (mem.eql(u8, marker.name, tmpl.MAGIC_BLOG_LIST)) {
            return try self.generateBlogList(marker);
        }
        if (mem.eql(u8, marker.name, tmpl.MAGIC_BLOG_SERIES_TOC)) {
            return try self.generateBlogSeriesTableOfContent(marker);
        }
        std.log.err("unknown magic marker -- `{s}`", .{marker.name});
        return Error.UnknownMagicMarker;

        // if (marker.data) |data| {
        //     std.log.debug(">>>> {any}", .{data.value});
        // } else {
        //     std.log.debug(">>>> null", .{});
        // }
        // @panic("... not implemented ...");
    }
    fn generateBlogSeriesTableOfContent(self: *@This(), marker: Node.MagicMarker) Error![]u8 {
        _ = marker;

        const blog_list = self.groups.get(self.document.file_path) orelse return "";

        var list_accum = std.io.Writer.Allocating.init(self.gpa);
        // TODO(seg4lt) - need to sort by index, but let's do that later
        for (blog_list.items) |info| {
            const link = try std.fmt.allocPrint(self.gpa, "/{s}/{s}.html", .{ info.file_path, info.file_name[0 .. info.file_name.len - 3] }); // remove .md
            defer self.gpa.free(link);
            const item_html = try TemplateManager.replacePlaceholders(
                self.gpa,
                tmpl.DEFAULT_BLOG_SERIES_TOC_ITEM_HTML,
                &[_][]const u8{ "{{link}}", "{{title}}" },
                &[_][]const u8{ link, info.frontmatter.title },
            );
            defer self.gpa.free(item_html);
            try list_accum.writer.print("{s}\n", .{item_html});
        }
        const blog_list_html = try TemplateManager.replacePlaceholders(
            self.gpa,
            tmpl.DEFAULT_BLOG_SERIES_SECTION_WRAPPER_HTML,
            &[_][]const u8{"{{content}}"},
            &[_][]const u8{try list_accum.toOwnedSlice()},
        );
        return blog_list_html;
    }

    fn generateBlogList(self: *@This(), marker: Node.MagicMarker) Error![]u8 {
        _ = marker;
        const blog_list = self.groups.get("blog") orelse return "";

        var list_accum = std.io.Writer.Allocating.init(self.gpa);
        // TODO(seg4lt) - need to sort by date desc, but let's do that later
        for (blog_list.items) |info| {
            const link = try std.fmt.allocPrint(self.gpa, "/{s}/{s}.html", .{ info.file_path, info.file_name[0 .. info.file_name.len - 3] }); // remove .md
            defer self.gpa.free(link);
            const item_html = try TemplateManager.replacePlaceholders(
                self.gpa,
                tmpl.DEFAULT_BLOG_LIST_ITEM_HTML,
                &[_][]const u8{ "{{link}}", "{{title}}", "{{desc}}", "{{date}}" },
                &[_][]const u8{ link, info.frontmatter.title, info.frontmatter.description, info.frontmatter.date },
            );
            defer self.gpa.free(item_html);
            try list_accum.writer.print("{s}\n", .{item_html});
        }
        const blog_list_html = try TemplateManager.replacePlaceholders(
            self.gpa,
            tmpl.DEFAULT_BLOG_LIST_HTML,
            &[_][]const u8{"{{content}}"},
            &[_][]const u8{try list_accum.toOwnedSlice()},
        );
        return blog_list_html;
    }

    fn generateCodeBlock(self: *@This(), code_block: Node.CodeBlock) Error![]u8 {
        const class_attr = if (code_block.language) |lang|
            try std.fmt.allocPrint(self.gpa, " class=\"language-{s}\"", .{lang})
        else
            "";
        defer self.gpa.free(class_attr);

        const tmpl_str = tmpl.DEFAULT_CODE_BLOCK;
        const final_html = try TemplateManager.replacePlaceholders(
            self.gpa,
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
        const final_html = try TemplateManager.replacePlaceholders(
            self.gpa,
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
