const DocInfo = struct {
    file_path: []const u8,
    file_name: []const u8,
    frontmatter: *const Frontmatter,
};

pub fn generateAll(gpa: Allocator, docs: *const ArrayList(Document), app_name: []const u8, app_subtitle: []const u8, output_base: []const u8, tmpl_manager: *TemplateManager) !void {
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
            try tmpl_manager.get(tmpl.TMPL_BASE_HTML.name),
            &[_][]const u8{ "{{app_name}}", "{{app_subtitle}}", "{{title}}", "{{content}}", "{{main_nav}}" },
            &[_][]const u8{ app_name, app_subtitle, doc.frontmatter.value.title, html, try tmpl_manager.getMainNav() },
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

    fn generate(self: *@This()) ![]u8 {
        for (self.document.nodes.items) |node| {
            if (node == .code and node.code.language != null and mem.eql(u8, node.code.language.?, tmpl.MAGIC_FRONTMATTER)) {
                continue;
            }
            try self.generateNode(node);
        }
        var a = self.accumulator;
        return try a.toOwnedSlice();
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
        defer self.gpa.free(almost_final_html);

        const final_html = try MarkdownInlineStyler.apply(self.gpa, almost_final_html, self.template_manager);
        defer self.gpa.free(final_html);

        try self.accumulator.writer.print("\n{s}\n", .{final_html});
        try self.accumulator.writer.flush();
    }
    fn generateList(self: *@This(), list: *Node.List) ![]u8 {
        const task_list_tmpl =
            \\ <ul class="{{variant}}-task-list {{variant}}-unordered-list-depth-{{depth}}">
            \\     {{items}}
            \\ </ul>
        ;
        const ul_tmpl =
            \\ <ul class="{{variant}}-unordered-list {{variant}}-unordered-list-depth-{{depth}}">
            \\   {{items}}
            \\ </ul>
        ;
        const ol_tmpl =
            \\ <ol class="{{variant}}-ordered-list {{variant}}-ordered-list-depth-{{depth}}">
            \\   {{items}}
            \\ </ol>
        ;
        const todo_li_tmpl =
            \\ <li>
            \\     <span class="checkbox {{variant}}"></span>
            \\     <span>{{content}}</span>
            \\ </li>
        ;
        const ul_li_tmpl =
            \\      <li>
            \\          <span class="bullet {{variant}}-bullet"></span>
            \\          <span>{{content}}</span>
            \\      </li>
        ;
        const ol_li_tmpl =
            \\     <li>
            \\         <span class="number {{variant}}-number">{{number}}</span>
            \\         <span>{{content}}</span>
            \\     </li>
        ;
        var acc: ArrayList(u8) = .empty;
        for (list.items.items, 0..) |item, i| {
            switch (item) {
                .todo_item => |todo_item| {
                    const item_html = try TemplateManager.replacePlaceholders(
                        self.gpa,
                        todo_li_tmpl,
                        &[_][]const u8{ "{{variant}}", "{{content}}" },
                        &[_][]const u8{
                            if (todo_item.checked) "checked" else "unchecked",
                            todo_item.content,
                        },
                    );
                    try acc.appendSlice(self.gpa, item_html);
                },
                .p => |text| {
                    const item_html = try TemplateManager.replacePlaceholders(
                        self.gpa,
                        switch (list.kind) {
                            .ordered => ol_li_tmpl,
                            .unordered => ul_li_tmpl,
                            .todo => todo_li_tmpl,
                        },
                        &[_][]const u8{ "{{variant}}", "{{number}}", "{{content}}" },
                        &[_][]const u8{
                            switch (list.depth) {
                                0 => "primary",
                                1 => "secondary",
                                else => "accent",
                            },
                            try std.fmt.allocPrint(self.gpa, "{d}", .{i + 1}),
                            text,
                        },
                    );
                    try acc.appendSlice(self.gpa, item_html);
                },
                .list => |sublist| {
                    const item_html = try self.generateList(sublist);
                    try acc.appendSlice(self.gpa, item_html);
                },
            }
        }
        const html = try TemplateManager.replacePlaceholders(
            self.gpa,
            switch (list.kind) {
                .ordered => ol_tmpl,
                .unordered => ul_tmpl,
                .todo => task_list_tmpl,
            },
            &[_][]const u8{ "{{variant}}", "{{items}}", "{{depth}}" },
            &[_][]const u8{
                switch (list.depth) {
                    0 => "normal",
                    else => "nested",
                },
                try acc.toOwnedSlice(self.gpa),
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
            self.gpa,
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
        var acc: ArrayList(u8) = .empty;

        if (bq.kind != .normal) {
            try acc.appendSlice(self.gpa, try std.fmt.allocPrint(self.gpa, "<strong>{s}</strong>\n", .{@tagName(bq.kind)}));
        }
        while (iter.next()) |line| {
            if (mem.trim(u8, line, " \t\r").len == 0) continue;
            try acc.appendSlice(self.gpa, try std.fmt.allocPrint(self.gpa, "<p>{s}<p>", .{line}));
        }

        const html = try TemplateManager.replacePlaceholders(
            self.gpa,
            try self.template_manager.get(tmpl.TMPL_BLOCK_QUOTE_HTML.name),
            &[_][]const u8{ "{{variant}}", "{{content}}" },
            &[_][]const u8{ @tagName(bq.kind), try acc.toOwnedSlice(self.gpa) },
        );
        return html;
    }

    fn generateMagicMarker(self: *@This(), marker: Node.MagicMarker) ![]u8 {
        if (mem.eql(u8, marker.name, tmpl.MAGIC_BLOG_LIST)) {
            return try self.generateBlogList(marker);
        }
        if (mem.eql(u8, marker.name, tmpl.MAGIC_BLOG_SERIES_TOC)) {
            return try self.generateBlogSeriesTableOfContent(marker);
        }
        if (mem.eql(u8, marker.name, tmpl.MAGIC_GRID_START)) {
            const html = try TemplateManager.replacePlaceholders(
                self.gpa,
                try self.template_manager.get(tmpl.TMPL_GRID_START_HTML.name),
                &[_][]const u8{"{{count}}"},
                &[_][]const u8{marker.args.?},
            );
            return html;
        }
        if (mem.eql(u8, marker.name, tmpl.MAGIC_GRID_END)) {
            return self.gpa.dupe(u8, try self.template_manager.get(tmpl.TMPL_GRID_END_HTML.name));
        }
        std.log.err("unknown magic marker -- `{s}`", .{marker.name});
        return Error.UnknownMagicMarker;
    }
    fn generateBlogSeriesTableOfContent(self: *@This(), marker: Node.MagicMarker) ![]u8 {
        _ = marker;

        const blog_list = self.groups.get(self.document.file_path) orelse return "";

        var list_accum = std.io.Writer.Allocating.init(self.gpa);
        // TODO(seg4lt) - need to sort by index, but let's do that later
        for (blog_list.items) |info| {
            const link = try std.fmt.allocPrint(self.gpa, "/{s}/{s}.html", .{ info.file_path, info.file_name[0 .. info.file_name.len - 3] }); // remove .md
            defer self.gpa.free(link);
            const item_html = try TemplateManager.replacePlaceholders(
                self.gpa,
                try self.template_manager.get(tmpl.TMPL_BLOG_SERIES_TOC_ITEM_HTML.name),
                &[_][]const u8{ "{{link}}", "{{title}}" },
                &[_][]const u8{ link, info.frontmatter.title },
            );
            defer self.gpa.free(item_html);
            try list_accum.writer.print("{s}\n", .{item_html});
        }
        const blog_list_html = try TemplateManager.replacePlaceholders(
            self.gpa,
            try self.template_manager.get(tmpl.TMPL_BLOG_SERIES_SECTION_WRAPPER_HTML.name),
            &[_][]const u8{"{{content}}"},
            &[_][]const u8{try list_accum.toOwnedSlice()},
        );
        return blog_list_html;
    }

    fn generateBlogList(self: *@This(), marker: Node.MagicMarker) ![]u8 {
        _ = marker;
        const blog_list = self.groups.get("blog") orelse return "";

        var list_accum = std.io.Writer.Allocating.init(self.gpa);
        // TODO(seg4lt) - need to sort by date desc, but let's do that later
        for (blog_list.items) |info| {
            const link = try std.fmt.allocPrint(self.gpa, "/{s}/{s}.html", .{ info.file_path, info.file_name[0 .. info.file_name.len - 3] }); // remove .md
            defer self.gpa.free(link);
            const item_html = try TemplateManager.replacePlaceholders(
                self.gpa,
                try self.template_manager.get(tmpl.TMPL_BLOG_LIST_ITEM_HTML.name),
                &[_][]const u8{ "{{link}}", "{{title}}", "{{desc}}", "{{date}}" },
                &[_][]const u8{ link, info.frontmatter.title, info.frontmatter.description, info.frontmatter.date },
            );
            defer self.gpa.free(item_html);
            try list_accum.writer.print("{s}\n", .{item_html});
        }
        const blog_list_html = try TemplateManager.replacePlaceholders(
            self.gpa,
            try self.template_manager.get(tmpl.TMPL_CARD_HTML.name),
            &[_][]const u8{ "{{title}}", "{{variant}}", "{{content}}" },
            &[_][]const u8{ "Recent Blogs", "primary", try list_accum.toOwnedSlice() },
        );
        return blog_list_html;
    }

    fn generateCodeBlock(self: *@This(), code_block: Node.CodeBlock) ![]u8 {
        const class_attr = if (code_block.language) |lang|
            try std.fmt.allocPrint(self.gpa, " class=\"language-{s}\"", .{lang})
        else
            "";
        defer self.gpa.free(class_attr);

        const tmpl_str = try self.template_manager.get(tmpl.TMPL_CODE_BLOCK_HTML.name);
        const code_html = try TemplateManager.replacePlaceholders(
            self.gpa,
            tmpl_str,
            &[_][]const u8{ "{{class}}", "{{content}}" },
            &[_][]const u8{ class_attr, code_block.content },
        );
        return code_html;
    }

    fn generateParagraph(self: *@This(), p_content: []const u8) ![]u8 {
        if (p_content.len == 0) return "";

        // image already handled in inline styler
        if (p_content[0] == '!') return self.gpa.dupe(u8, p_content);

        return std.fmt.allocPrint(self.gpa,
            \\ <p>{s}</p>
        , .{p_content});
    }

    fn generateHeading(self: *@This(), node: Node) ![]u8 {
        const text = switch (node) {
            .h1, .h2, .h3, .h4 => |text| text,
            else => std.debug.panic("** bug ** not reachable - only heading should reach here", .{}),
        };
        const tmpl_str = try self.template_manager.get(tmpl.TMPL_HEADING_HTML.name);
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

const MarkdownInlineStyler = struct {
    source: []const u8,
    pos: usize,
    acc: ArrayList(u8),
    tm: *TemplateManager,
    allocator: Allocator,

    pub fn apply(allocator: Allocator, source: []const u8, tm: *TemplateManager) ![]u8 {
        var self: @This() = .{
            .source = source,
            .pos = 0,
            .acc = .empty,
            .tm = tm,
            .allocator = allocator,
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
            try self.acc.append(self.allocator, self.source[self.pos]);
            self.advance(1);
        }
        return try self.acc.toOwnedSlice(self.allocator);
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

        const highlight_html = try std.fmt.allocPrint(self.allocator, "<mark class=\"highlight {s}-mark\">{s}</mark>", .{ hl_type, highlight_text });
        try self.acc.appendSlice(self.allocator, highlight_html);
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

        const bold_italic_html = try std.fmt.allocPrint(self.allocator, "<strong class=\"bold-italic\"><em class=\"italic\">{s}</em></strong>", .{bold_italic_text});
        try self.acc.appendSlice(self.allocator, bold_italic_html);
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

        const italic_html = try std.fmt.allocPrint(self.allocator, "<em class=\"italic\">{s}</em>", .{italic_text});
        try self.acc.appendSlice(self.allocator, italic_html);
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

        const bold_html = try std.fmt.allocPrint(self.allocator, "<strong class=\"bold\">{s}</strong>", .{bold_text});
        try self.acc.appendSlice(self.allocator, bold_html);
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

        const strike_html = try std.fmt.allocPrint(self.allocator, "<del class=\"strikethrough\">{s}</del>", .{strike_text});
        try self.acc.appendSlice(self.allocator, strike_html);
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
        const code_text = try self.allocator.dupe(u8, self.source[code_pos_start..self.pos]);
        self.advance(1); // `

        const escaped_code_text = try escapeHtml(self.allocator, code_text);

        const code_html = try std.fmt.allocPrint(self.allocator, "<code class=\"inline-code\">{s}</code>", .{escaped_code_text});
        try self.acc.appendSlice(self.allocator, code_html);
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
            try self.acc.appendSlice(self.allocator, self.source[original_start..self.pos]);
            return true;
        }
        self.advance(1); // (

        const url_pos_start = self.pos;
        while (self.peek() != ')' and !self.isAtEnd()) {
            self.advance(1);
        }
        const url = self.source[url_pos_start..self.pos];
        self.advance(1); // )

        const link_html = try std.fmt.allocPrint(self.allocator, "<a href=\"{s}\" class=\"text-link\">{s}</a>", .{ url, link_text });
        try self.acc.appendSlice(self.allocator, link_html);
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
            try self.acc.appendSlice(self.allocator, self.source[original_start..self.pos]);
            return true;
        }
        self.advance(1); // (

        const url_pos_start = self.pos;
        while (self.peek() != ')' and !self.isAtEnd()) {
            self.advance(1);
        }
        const url = self.source[url_pos_start..self.pos];
        self.advance(1); // )

        const img_html = try std.fmt.allocPrint(self.allocator, "<img src=\"{s}\" alt=\"{s}\">", .{ url, alt_text });

        const image_card = try TemplateManager.replacePlaceholders(
            self.allocator,
            try self.tm.get(tmpl.TMPL_CARD_HTML.name),
            &[_][]const u8{ "{{title}}", "{{variant}}", "{{content}}" },
            &[_][]const u8{ alt_text, "primary", img_html },
        );

        try self.acc.appendSlice(self.allocator, image_card);
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

const MAX_FILE_SIZE = common.MAX_FILE_SIZE;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Node = Document.Node;
const ParsedFrontmatter = Document.ParsedFrontmatter;
const Frontmatter = Document.Frontmatter;
const mem = std.mem;
