const DocInfo = struct {
    file_path: []const u8,
    file_name: []const u8,
    frontmatter: *const Frontmatter,
};

pub fn generateAll(
    mem_ctx: *MemCtx,
    docs: *const ArrayList(Document),
    tmpl_manager: *TemplateManager,
    args: *const AppArgs,
) !void {
    var content_groups = std.StringHashMap(*ArrayList(DocInfo)).init(mem_ctx.global);

    for (docs.items) |*doc| {
        const result = try content_groups.getOrPut(doc.file_path);
        if (!result.found_existing) {
            const list = try mem_ctx.global.create(ArrayList(DocInfo));
            list.* = .empty;
            result.value_ptr.* = list;
        }
        try result.value_ptr.*.append(mem_ctx.global, .{
            .file_path = doc.file_path,
            .file_name = doc.file_name,
            .frontmatter = &doc.frontmatter.value,
        });

        // blog is special, so we collect sub items as well
        if (mem.startsWith(u8, doc.file_path, "blog/")) {
            const blog_result = try content_groups.getOrPut("blog");
            if (!blog_result.found_existing) {
                const list = try mem_ctx.global.create(ArrayList(DocInfo));
                list.* = .empty;
                blog_result.value_ptr.* = list;
            }
            try blog_result.value_ptr.*.append(mem_ctx.global, .{
                .file_path = doc.file_path,
                .file_name = doc.file_name,
                .frontmatter = &doc.frontmatter.value,
            });
        }
    }

    for (docs.items) |*doc| {
        defer mem_ctx.resetScratch();

        var generator = HtmlGenerator.init(mem_ctx.scratch, doc, tmpl_manager, &content_groups, args);
        const html = try generator.generate();

        const full_html = try TemplateManager.replacePlaceholders(
            mem_ctx.scratch,
            try tmpl_manager.get(tmpl.TMPL_BASE_HTML.name),
            &[_][]const u8{
                "{{app_name}}",
                "{{app_subtitle}}",
                "{{title}}",
                "{{content}}",
                "{{main_nav}}",
                "{{web_root}}",
            },
            &[_][]const u8{
                args.app_name,
                args.app_subtitle,
                doc.frontmatter.value.title,
                html,
                try tmpl_manager.getMainNav(),
                args.web_root,
            },
        );

        const output_path = try std.fs.path.join(
            mem_ctx.scratch,
            &[_][]const u8{ args.output_base_path, doc.file_path },
        );

        std.fs.cwd().makePath(output_path) catch |err| if (err != error.PathAlreadyExists) return err;

        const output_file_path = try std.fs.path.join(mem_ctx.scratch, &[_][]const u8{ output_path, doc.file_name });

        const html_name = try std.mem.replaceOwned(u8, mem_ctx.global, output_file_path, ".md", ".html");

        const output_file = try std.fs.cwd().createFile(html_name, .{});
        defer output_file.close();

        try output_file.writeAll(full_html);
    }
}

const HtmlGenerator = struct {
    arena: Allocator,
    document: *const Document,
    template_manager: *TemplateManager,
    groups: *const std.StringHashMap(*ArrayList(DocInfo)),
    accumulator: ArrayList(u8),
    args: *const AppArgs,

    const Self = @This();

    const Error = error{
        OutOfMemory,
        WriteFailed,
        UnknownMagicMarker,
    };

    fn init(
        arena: Allocator,
        doc: *const Document,
        template_manager: *TemplateManager,
        groups: *std.StringHashMap(*ArrayList(DocInfo)),
        args: *const AppArgs,
    ) @This() {
        return .{
            .arena = arena,
            .document = doc,
            .groups = groups,
            .template_manager = template_manager,
            .accumulator = .empty,
            .args = args,
        };
    }

    fn generate(self: *@This()) ![]u8 {
        for (self.document.nodes.items) |node| {
            if (node == .code and node.code.language != null and mem.eql(u8, node.code.language.?, tmpl.MAGIC_FRONTMATTER)) {
                continue;
            }
            try self.generateNode(node);
        }
        return self.accumulator.items;
    }

    fn generateNode(self: *@This(), node: Node) !void {
        const almost_final_html = switch (node) {
            .h1, .h2, .h3, .h4 => try self.generateHeading(node),
            .p => |text| try self.generateParagraph(text),
            .code => |code_block| try self.generateCodeBlock(code_block),
            .magic_marker => |marker| try self.generateMagicMarker(marker),
            .block_quote => |bq| try self.generateBlockquote(bq),
            .divider => |dtype| try self.generateDividerType(dtype),
            .list => |list| try self.generateList(list),
        };
        try self.accumulator.appendSlice(self.arena, "\n");
        try self.accumulator.appendSlice(self.arena, almost_final_html);
        try self.accumulator.appendSlice(self.arena, "\n");
    }

    fn generateList(self: *@This(), list: *Node.List) ![]u8 {
        var list_content: ArrayList(u8) = .empty;
        for (list.items.items, 0..) |item, i| {
            switch (item) {
                .todo_item => |todo_item| {
                    const text = try InlineStyler.apply(self.arena, todo_item.content, self.template_manager, self.args);

                    const item_html = try TemplateManager.replacePlaceholders(
                        self.arena,
                        try self.template_manager.get(tmpl.TMPL_TASK_LIST_ITEM_HTML.name),
                        &[_][]const u8{ "{{variant}}", "{{content}}" },
                        &[_][]const u8{
                            if (todo_item.checked) "checked" else "unchecked",
                            text,
                        },
                    );
                    try list_content.appendSlice(self.arena, item_html);
                },
                .p => |un_text| {
                    const text = try InlineStyler.apply(self.arena, un_text, self.template_manager, self.args);
                    const item_html = try TemplateManager.replacePlaceholders(
                        self.arena,
                        switch (list.kind) {
                            .ordered => try self.template_manager.get(tmpl.TMPL_ORDERED_LIST_ITEM_HTML.name),
                            .unordered => try self.template_manager.get(tmpl.TMPL_UNORDERED_LIST_ITEM_HTML.name),
                            .todo => try self.template_manager.get(tmpl.TMPL_TASK_LIST_ITEM_HTML.name),
                        },
                        &[_][]const u8{ "{{variant}}", "{{number}}", "{{content}}" },
                        &[_][]const u8{
                            switch (list.depth) {
                                0 => "primary",
                                1 => "secondary",
                                else => "accent",
                            },
                            try std.fmt.allocPrint(self.arena, "{d}", .{i + 1}),
                            text,
                        },
                    );
                    try list_content.appendSlice(self.arena, item_html);
                },
                .list => |sublist| {
                    const item_html = try self.generateList(sublist);
                    try list_content.appendSlice(self.arena, item_html);
                },
            }
        }
        const html = try TemplateManager.replacePlaceholders(
            self.arena,
            switch (list.kind) {
                .ordered => try self.template_manager.get(tmpl.TMPL_ORDERED_LIST_HTML.name),
                .unordered => try self.template_manager.get(tmpl.TMPL_UNORDERED_LIST_HTML.name),
                .todo => try self.template_manager.get(tmpl.TMPL_TASK_LIST_HTML.name),
            },
            &[_][]const u8{ "{{variant}}", "{{items}}", "{{depth}}" },
            &[_][]const u8{
                switch (list.depth) {
                    0 => "normal",
                    else => "nested",
                },
                list_content.items,
                switch (list.depth) {
                    0 => "1",
                    1 => "2",
                    else => "3",
                },
            },
        );
        return html;
    }

    fn generateDividerType(self: *@This(), dtype: Node.DividerType) ![]u8 {
        const final_html = try TemplateManager.replacePlaceholders(
            self.arena,
            "<hr class=\"divider {{variant}}\">",
            &[_][]const u8{"{{variant}}"},
            &[_][]const u8{switch (dtype) {
                .normal => "solid",
                .dashed => "dashed",
                .dotted => "dotted",
            }},
        );
        return final_html;
    }

    fn generateBlockquote(self: *@This(), bq: Node.Blockquote) ![]u8 {
        var iter = std.mem.splitAny(u8, bq.content, "\n");
        var bq_content: ArrayList(u8) = .empty;

        if (bq.kind != .normal) {
            try bq_content.appendSlice(self.arena, "<strong>");
            try bq_content.appendSlice(self.arena, @tagName(bq.kind));
            try bq_content.appendSlice(self.arena, "</strong>\n");
        }

        while (iter.next()) |line| {
            if (mem.trim(u8, line, " \t\r").len == 0) continue;
            const text = try InlineStyler.apply(self.arena, line, self.template_manager, self.args);
            try bq_content.appendSlice(self.arena, "<p>");
            try bq_content.appendSlice(self.arena, text);
            try bq_content.appendSlice(self.arena, "</p>");
        }

        const html = try TemplateManager.replacePlaceholders(
            self.arena,
            try self.template_manager.get(tmpl.TMPL_BLOCK_QUOTE_HTML.name),
            &[_][]const u8{ "{{variant}}", "{{content}}" },
            &[_][]const u8{ @tagName(bq.kind), try bq_content.toOwnedSlice(self.arena) },
        );
        return html;
    }

    fn generateMagicMarker(self: *@This(), marker: Node.MagicMarker) ![]const u8 {
        if (mem.eql(u8, marker.name, tmpl.MAGIC_BLOG_LIST)) {
            return try self.generateBlogList(marker);
        }
        if (mem.eql(u8, marker.name, tmpl.MAGIC_BLOG_SERIES_TOC)) {
            return try self.generateBlogSeriesTableOfContent(marker);
        }
        if (mem.eql(u8, marker.name, tmpl.MAGIC_GRID_START)) {
            const html = try TemplateManager.replacePlaceholders(
                self.arena,
                try self.template_manager.get(tmpl.TMPL_GRID_START_HTML.name),
                &[_][]const u8{"{{count}}"},
                &[_][]const u8{marker.args.?},
            );
            return html;
        }
        if (mem.eql(u8, marker.name, tmpl.MAGIC_GRID_END)) {
            return try self.template_manager.get(tmpl.TMPL_GRID_END_HTML.name);
        }
        std.log.err("unknown magic marker -- `{s}`", .{marker.name});
        return Error.UnknownMagicMarker;
    }

    fn generateBlogSeriesTableOfContent(self: *@This(), marker: Node.MagicMarker) ![]u8 {
        _ = marker;

        const blog_list = self.groups.get(self.document.file_path) orelse return "";

        var list_accum: ArrayList(u8) = .empty;

        // TODO(seg4lt) - need to sort by index, but let's do that later
        for (blog_list.items, 0..) |info, i| {
            const link = try std.fmt.allocPrint(
                self.arena,
                "{s}/{s}/{s}.html",
                .{
                    self.args.web_root,
                    info.file_path,
                    info.file_name[0 .. info.file_name.len - 3], // remove `.md`
                },
            );

            const item_link = try TemplateManager.replacePlaceholders(
                self.arena,
                try self.template_manager.get(tmpl.TMPL_BLOG_SERIES_TOC_ITEM_HTML.name),
                &[_][]const u8{ "{{variant}}", "{{number}}", "{{link}}", "{{title}}", "{{date}}" },

                &[_][]const u8{
                    "primary",
                    try std.fmt.allocPrint(self.arena, "{d}", .{i + 1}),
                    link,
                    info.frontmatter.title,
                    info.frontmatter.date,
                },
            );
            try list_accum.appendSlice(self.arena, item_link);
            try list_accum.appendSlice(self.arena, "\n");
        }
        const blog_series_html = try TemplateManager.replacePlaceholders(
            self.arena,
            try self.template_manager.get(tmpl.TMPL_ORDERED_LIST_HTML.name),
            &[_][]const u8{ "{{variant}}", "{{items}}", "{{depth}}" },
            &[_][]const u8{ "normal", list_accum.items, "1" },
        );

        const with_wrapper = try TemplateManager.replacePlaceholders(
            self.arena,
            try self.template_manager.get(tmpl.TMPL_CARD_HTML.name),
            &[_][]const u8{ "{{variant}}", "{{title}}", "{{content}}" },
            &[_][]const u8{ "secondary", "Table of Content", blog_series_html },
        );

        return with_wrapper;
    }

    fn generateBlogList(self: *@This(), marker: Node.MagicMarker) ![]u8 {
        _ = marker;
        const blog_list = self.groups.get("blog") orelse return "";

        var list_accum: ArrayList(u8) = .empty;
        // TODO(seg4lt) - need to sort by date desc, but let's do that later
        for (blog_list.items) |info| {
            const link = try std.fmt.allocPrint(
                self.arena,
                "{s}/{s}/{s}.html",
                .{
                    self.args.web_root,
                    info.file_path,
                    info.file_name[0 .. info.file_name.len - 3], // remove `.md`
                },
            );
            const item_html = try TemplateManager.replacePlaceholders(
                self.arena,
                try self.template_manager.get(tmpl.TMPL_BLOG_LIST_ITEM_HTML.name),
                &[_][]const u8{ "{{link}}", "{{title}}", "{{desc}}", "{{date}}" },
                &[_][]const u8{ link, info.frontmatter.title, info.frontmatter.description, info.frontmatter.date },
            );
            try list_accum.appendSlice(self.arena, item_html);
            try list_accum.appendSlice(self.arena, "\n");
        }
        const blog_list_html = try TemplateManager.replacePlaceholders(
            self.arena,
            try self.template_manager.get(tmpl.TMPL_CARD_HTML.name),
            &[_][]const u8{ "{{title}}", "{{variant}}", "{{content}}" },
            &[_][]const u8{ "Recent Blogs", "primary", list_accum.items },
        );
        return blog_list_html;
    }

    fn generateCodeBlock(self: *@This(), code_block: Node.CodeBlock) ![]u8 {
        const class_attr = if (code_block.language) |lang|
            try std.fmt.allocPrint(self.arena, " class=\"language-{s}\"", .{lang})
        else
            "";

        const tmpl_str = try self.template_manager.get(tmpl.TMPL_CODE_BLOCK_HTML.name);
        const code_html = try TemplateManager.replacePlaceholders(
            self.arena,
            tmpl_str,
            &[_][]const u8{ "{{class}}", "{{content}}" },
            &[_][]const u8{ class_attr, code_block.content },
        );
        return code_html;
    }

    fn generateParagraph(self: *@This(), p_content: []const u8) ![]u8 {
        if (p_content.len == 0) return "";
        const text = try InlineStyler.apply(self.arena, p_content, self.template_manager, self.args);
        return std.fmt.allocPrint(self.arena, "<p>{s}</p>\n", .{text});
    }

    fn generateHeading(self: *@This(), node: Node) ![]u8 {
        const unprocessed_text = switch (node) {
            .h1, .h2, .h3, .h4 => |text| text,
            else => return common.GlobalError.UnrecoverablePanic,
        };
        const text = try InlineStyler.apply(self.arena, unprocessed_text, self.template_manager, self.args);

        const tmpl_str = try self.template_manager.get(tmpl.TMPL_HEADING_HTML.name);
        const final_html = try TemplateManager.replacePlaceholders(
            self.arena,
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

const InlineStyler = struct {
    source: []const u8,
    pos: usize,
    processed_content: ArrayList(u8),
    tm: *TemplateManager,
    args: *const AppArgs,
    arena: Allocator,

    pub fn apply(arena: Allocator, source: []const u8, tm: *TemplateManager, args: *const AppArgs) ![]u8 {
        var self: @This() = .{
            .source = source,
            .pos = 0,
            .processed_content = .empty,
            .tm = tm,
            .arena = arena,
            .args = args,
        };
        return self.run();
    }

    fn run(self: *@This()) ![]u8 {
        while (!self.isAtEnd()) {
            // these have to be more or less on this order
            // not all of them, but image definitely has to come first, same for todo (i think)
            if (try self.processImage()) continue;
            if (try self.processLink()) continue;
            if (try self.processInlineCode()) continue;
            if (try self.processStrikethrough()) continue;
            if (try self.processBoldAndItalic()) continue;
            if (try self.processBold()) continue;
            if (try self.processItalic()) continue;
            if (try self.processHighlight()) continue;

            // Regular character
            try self.processed_content.append(self.arena, self.source[self.pos]);
            self.advance(1);
        }
        return self.processed_content.items;
    }

    fn processHighlight(self: *@This()) !bool {
        // ==text==
        if (self.peek() != '=' or self.peekAhead(1) != '=') return false;

        self.advance(2); // ==

        const text_pos_start = self.pos;
        while (!(self.peek() == '=' and self.peekAhead(1) == '=') and !self.isAtEnd()) {
            self.advance(1);
        }
        const highlight_text = self.source[text_pos_start..self.pos];

        self.advance(2); // ==
        // this is custom feature I added
        // ==highlighted text with different color===primary=.
        // note-mark // tip-mark  // important-mark  // warning-mark  // caution-mark
        var hl_type: []const u8 = "";
        if (self.peek() == '=' and !self.isAtEnd()) {
            self.advance(1);
            const type_pos_start = self.pos;
            while (self.peek() != '=' and !self.isAtEnd()) {
                self.advance(1);
            }
            hl_type = self.source[type_pos_start..self.pos];
        }
        self.advance(1); // =

        const highlight_html = try std.fmt.allocPrint(self.arena, "<mark class=\"highlight {s}-mark\">{s}</mark>", .{ hl_type, highlight_text });
        try self.processed_content.appendSlice(self.arena, highlight_html);
        return true;
    }

    fn processBoldAndItalic(self: *@This()) !bool {
        // ***text*** or ___text___
        const marker = self.peek();
        if (marker != '*' and marker != '_') return false;
        if (self.peekAhead(1) != marker) return false;
        if (self.peekAhead(2) != marker) return false;

        self.advance(3); // *** or ___

        const text_pos_start = self.pos;
        while (!(self.peek() == marker and self.peekAhead(1) == marker and self.peekAhead(2) == marker) and !self.isAtEnd()) {
            self.advance(1);
        }
        const bold_italic_text = self.source[text_pos_start..self.pos];
        self.advance(3); // *** or ___

        const bold_italic_html = try std.fmt.allocPrint(self.arena, "<strong class=\"bold-italic\"><em class=\"italic\">{s}</em></strong>", .{bold_italic_text});
        try self.processed_content.appendSlice(self.arena, bold_italic_html);
        return true;
    }

    fn processItalic(self: *@This()) !bool {
        // *text* or _text_
        const marker = self.peek();
        if (marker != '*' and marker != '_') return false;

        self.advance(1); // * or _

        const text_pos_start = self.pos;
        while (self.peek() != marker and !self.isAtEnd()) {
            self.advance(1);
        }
        const italic_text = self.source[text_pos_start..self.pos];
        self.advance(1); // * or _

        const italic_html = try std.fmt.allocPrint(self.arena, "<em class=\"italic\">{s}</em>", .{italic_text});
        try self.processed_content.appendSlice(self.arena, italic_html);
        return true;
    }

    fn processBold(self: *@This()) !bool {
        // **text** or __text__
        const marker = self.peek();
        if (marker != '*' and marker != '_') return false;
        if (self.peekAhead(1) != marker) return false;

        self.advance(2); // ** or __

        const text_pos_start = self.pos;
        while (!(self.peek() == marker and self.peekAhead(1) == marker) and !self.isAtEnd()) {
            self.advance(1);
        }
        const bold_text = self.source[text_pos_start..self.pos];
        self.advance(2); // ** or __

        const bold_html = try std.fmt.allocPrint(self.arena, "<strong class=\"bold\">{s}</strong>", .{bold_text});
        try self.processed_content.appendSlice(self.arena, bold_html);
        return true;
    }

    fn processStrikethrough(self: *@This()) !bool {
        // ~~text~~
        if (self.peek() != '~' or self.peekAhead(1) != '~') return false;

        self.advance(2); // ~~

        const text_pos_start = self.pos;
        while (!(self.peek() == '~' and self.peekAhead(1) == '~') and !self.isAtEnd()) {
            self.advance(1);
        }
        const strike_text = self.source[text_pos_start..self.pos];
        self.advance(2); // ~~

        const strike_html = try std.fmt.allocPrint(self.arena, "<del class=\"strikethrough\">{s}</del>", .{strike_text});
        try self.processed_content.appendSlice(self.arena, strike_html);
        return true;
    }

    fn processInlineCode(self: *@This()) !bool {
        // `code`
        if (self.peek() != '`') return false;

        self.advance(1); // `

        const code_pos_start = self.pos;
        while (self.peek() != '`' and !self.isAtEnd()) {
            self.advance(1);
        }
        const code_text = self.source[code_pos_start..self.pos];
        self.advance(1); // `

        const escaped_code_text = try escapeHtml(self.arena, code_text);

        const code_html = try std.fmt.allocPrint(self.arena, "<code class=\"inline-code\">{s}</code>", .{escaped_code_text});
        try self.processed_content.appendSlice(self.arena, code_html);
        return true;
    }

    fn escapeHtml(allocator: std.mem.Allocator, text: []const u8) ![]u8 {
        var result: ArrayList(u8) = .empty;
        for (text) |ch| {
            switch (ch) {
                '<' => try result.appendSlice(allocator, "&lt;"),
                '>' => try result.appendSlice(allocator, "&gt;"),
                '&' => try result.appendSlice(allocator, "&amp;"),
                '"' => try result.appendSlice(allocator, "&quot;"),
                '\'' => try result.appendSlice(allocator, "&#39;"),
                else => try result.append(allocator, ch),
            }
        }
        return result.toOwnedSlice(allocator);
    }

    fn processLink(self: *@This()) !bool {
        // [text](url)
        if (self.peek() != '[') return false;

        const original_start = self.pos;

        self.advance(1); // [
        const text_pos_start = self.pos;
        while (self.peek() != ']' and !self.isAtEnd()) {
            self.advance(1);
        }
        const link_text = self.source[text_pos_start..self.pos];
        self.advance(1); // ]

        if (self.peek() != '(') {
            std.log.err("invalid link syntax found", .{});
            try self.processed_content.appendSlice(self.arena, self.source[original_start..self.pos]);
            return true;
        }
        self.advance(1); // (

        const url_pos_start = self.pos;
        while (self.peek() != ')' and !self.isAtEnd()) {
            self.advance(1);
        }

        var url_type: enum { internal, external } = .internal;
        const url = blk: {
            const maybe_url = self.source[url_pos_start..self.pos];
            if (maybe_url[0] == '/' or maybe_url[0] == '.') {
                url_type = .internal;
                if (maybe_url[0] == '/') {
                    break :blk try std.fmt.allocPrint(self.arena, "{s}{s}", .{ self.args.web_root, maybe_url });
                }
            } else {
                url_type = .external;
            }
            break :blk maybe_url;
        };
        self.advance(1); // )

        const link_html = try TemplateManager.replacePlaceholders(
            self.arena,
            try self.tm.get(tmpl.TMPL_TEXT_LINK_HTML.name),
            &[_][]const u8{
                "{{link}}",
                "{{text}}",
                "{{target}}",
            },
            &[_][]const u8{
                url, link_text, switch (url_type) {
                    .internal => "target=\"_self\"",
                    .external => "target=\"_blank\"",
                },
            },
        );

        try self.processed_content.appendSlice(self.arena, link_html);
        return true;
    }

    fn processImage(self: *@This()) !bool {
        // ![alt text](image_url)
        if (!self.isImage()) return false;
        const original_start = self.pos;

        self.advance(2); // ![
        const alt_text_pos_start = self.pos;
        while (self.peek() != ']' and !self.isAtEnd()) {
            self.advance(1);
        }
        const alt_text = self.source[alt_text_pos_start..self.pos];
        self.advance(1); // ]

        if (self.peek() != '(') {
            std.log.err("invalid image syntax found", .{});
            try self.processed_content.appendSlice(self.arena, self.source[original_start..self.pos]);
            return true;
        }
        self.advance(1); // (

        const url_pos_start = self.pos;
        while (self.peek() != ')' and !self.isAtEnd()) {
            self.advance(1);
        }
        const url = blk: {
            const maybe_url = self.source[url_pos_start..self.pos];
            if (std.mem.startsWith(u8, maybe_url, "/")) {
                break :blk try std.fmt.allocPrint(self.arena, "{s}{s}", .{ self.args.web_root, maybe_url });
            }
            break :blk maybe_url;
        };
        self.advance(1); // )

        const img_html = try std.fmt.allocPrint(self.arena, "<img src=\"{s}\" alt=\"{s}\">", .{ url, alt_text });

        const image_card = try TemplateManager.replacePlaceholders(
            self.arena,
            try self.tm.get(tmpl.TMPL_CARD_HTML.name),
            &[_][]const u8{ "{{title}}", "{{variant}}", "{{content}}" },
            &[_][]const u8{ alt_text, "primary", img_html },
        );

        try self.processed_content.appendSlice(self.arena, image_card);
        return true;
    }

    fn isImage(self: *@This()) bool {
        if (self.peek() != '!') return false;
        if (self.peekAhead(1) != '[') return false;
        return true;
    }

    fn advance(self: *@This(), count: usize) void {
        self.pos += count;
    }

    fn isAtEnd(self: *@This()) bool {
        return self.pos >= self.source.len;
    }

    fn peek(self: *@This()) ?u8 {
        return self.peekAhead(0);
    }

    fn peekAhead(self: *@This(), offset: usize) ?u8 {
        const idx = self.pos + offset;
        if (idx >= self.source.len) return null;
        return self.source[idx];
    }
};

const std = @import("std");
const Document = @import("Document.zig");
const tmpl = @import("tmpl.zig");
const TemplateManager = @import("TemplateManager.zig");
const common = @import("common.zig");
const Parser = @import("Parser.zig");
const MemCtx = common.MemCtx;
const AppArgs = common.AppArgs;

const MAX_FILE_SIZE = common.MAX_FILE_SIZE;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Node = Document.Node;
const ParsedFrontmatter = Document.ParsedFrontmatter;
const Frontmatter = Document.Frontmatter;
const mem = std.mem;
