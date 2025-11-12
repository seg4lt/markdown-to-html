pub const MAGIC_MARKER_PREFIX = "{{ @@";
pub const MAGIC_INCLUDE_HTML = "@@include_html";
pub const MAGIC_INCLUDE_HTML_DATA = "```@@include_html_data";
pub const MAGIC_BLOG_LIST = "@@blog_list";
pub const MAGIC_BLOG_SERIES_TOC = "@@blog_series_toc";
pub const MAGIC_FRONTMATTER = "@@frontmatter";

pub const Template = struct { name: []const u8, content: []const u8 };

pub const TMPL_BASE_HTML: Template = .{ .name = "base.html", .content = DEFAULT_BASE_HTML };
pub const TMPL_HEADING_HTML: Template = .{ .name = "heading.html", .content = DEFAULT_HEADING_HTML };
pub const TMPL_CODE_BLOCK_HTML: Template = .{ .name = "code_block.html", .content = DEFAULT_CODE_BLOCK };
pub const TMPL_BLOG_LIST_ITEM_HTML: Template = .{ .name = "blog_list_item.html", .content = DEFAULT_BLOG_LIST_ITEM_HTML };
pub const TMPL_BLOG_SERIES_SECTION_WRAPPER_HTML: Template = .{ .name = "blog_series_section_wrapper.html", .content = DEFAULT_BLOG_SERIES_SECTION_WRAPPER_HTML };
pub const TMPL_BLOG_SERIES_TOC_ITEM_HTML: Template = .{ .name = "blog_series_toc_item.html", .content = DEFAULT_BLOG_SERIES_TOC_ITEM_HTML };
pub const TMPL_MAIN_NAV_HTML: Template = .{ .name = "main_nav.html", .content = DEFAULT_MAIN_NAV_HTML };
pub const TMPL_MAIN_NAV_ITEM_HTML: Template = .{ .name = "main_nav_item.html", .content = DEFAULT_MAIN_NAV_ITEM_HTML };
pub const TMPL_TEXT_LINK: Template = .{ .name = "text_link.html", .content = DEFAULT_TEXT_LINK_HTML };
pub const TMPL_TEXT_LINK_ALT: Template = .{ .name = "text_link_alt.html", .content = DEFAULT_TEXT_LINK_ALT_HTML };
pub const TMPL_BUTTON_LINK: Template = .{ .name = "button_link.html", .content = DEFAULT_BUTTON_LINK_HTML };
pub const TMPL_CARD: Template = .{ .name = "card.html", .content = DEFAULT_CARD_HTML };
pub const TMPL_STYLES_CSS: Template = .{ .name = "styles.css", .content = DEFAULT_STYLES };

pub const TEMPLATES = [_]Template{
    TMPL_BASE_HTML,
    TMPL_HEADING_HTML,
    TMPL_CODE_BLOCK_HTML,
    TMPL_BLOG_LIST_ITEM_HTML,
    TMPL_BLOG_SERIES_SECTION_WRAPPER_HTML,
    TMPL_BLOG_SERIES_TOC_ITEM_HTML,
    TMPL_MAIN_NAV_HTML,
    TMPL_MAIN_NAV_ITEM_HTML,
    TMPL_TEXT_LINK,
    TMPL_TEXT_LINK_ALT,
    TMPL_BUTTON_LINK,
    TMPL_CARD,
    TMPL_STYLES_CSS,
};

const DEFAULT_BASE_HTML =
    \\<!doctype html>
    \\<html lang="en">
    \\    <head>
    \\        <meta charset="UTF-8" />
    \\        <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    \\        <title>{{title}} - Updated</title>
    \\        <link rel="stylesheet" href="/styles.css" />
    \\        <link
    \\            rel="stylesheet"
    \\            href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.11.1/styles/github-dark.min.css"
    \\        />
    \\        <link rel="preconnect" href="https://fonts.googleapis.com" />
    \\        <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
    \\        <link
    \\            href="https://fonts.googleapis.com/css2?family=Cascadia+Code:ital,wght@0,200..700;1,200..700&display=swap"
    \\            rel="stylesheet"
    \\        />
    \\        <link
    \\            href="https://fonts.googleapis.com/css2?family=Geist+Mono:wght@400;700;900&display=swap"
    \\            rel="stylesheet"
    \\        />
    \\        <script
    \\            defer
    \\            src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.11.1/highlight.min.js"
    \\        ></script>
    \\    </head>
    \\    <body>
    \\        <div class="global-container">
    \\            <header class="main-header">
    \\                <h1 class="main-title">{{app_name}}</h1>
    \\                <p class="main-subtitle">{{app_subtitle}}</p>
    \\                {{main_nav}}
    \\            </header>
    \\
    \\            <div class="main-content">{{content}}</div>
    \\
    \\            <footer class="main-footer">
    \\                <div class="container">
    \\                    <p>
    \\                        &copy; <span id="this-year"></span> seg4lt. Markdown to
    \\                        html generator written in Zig
    \\                    </p>
    \\                </div>
    \\            </footer>
    \\
    \\            <script>
    \\                document.addEventListener("DOMContentLoaded", (event) => {
    \\                    document.getElementById("this-year").textContent =
    \\                        new Date().getFullYear();
    \\                    hljs.highlightAll();
    \\                });
    \\            </script>
    \\        </div>
    \\    </body>
    \\</html>
;
const DEFAULT_HEADING_HTML =
    \\    <h{{level}}>{{content}}</h{{level}}>
;

const DEFAULT_CODE_BLOCK =
    \\    <pre class="code-block"><code{{class}}>{{content}}</code></pre>
;

const DEFAULT_BLOG_LIST_ITEM_HTML =
    \\<a href="{{link}}" class="blog-list-item-link button-link">
    \\    <div class="blog-list-item-title">{{title}}</div>
    \\    <div class="blog-list-item-desc">{{desc}}</div>
    \\    <div class="blog-list-item-date">{{date}}</div>
    \\</a>
;

const DEFAULT_BLOG_SERIES_SECTION_WRAPPER_HTML =
    \\ <section class="blog-series table-of-content">
    \\     <h3>Table of Contents</h3>
    \\     <ol>
    \\            {{content}}
    \\     </ol>
    \\ </section>
;

const DEFAULT_BLOG_SERIES_TOC_ITEM_HTML =
    \\         <li class="blog-series-item">
    \\             <a href="{{link}}" class="blog-series-toc-link">
    \\                 {{title}}
    \\             </a>
    \\         </li>
;

pub const DEFAULT_MAIN_NAV_HTML =
    \\<nav class="main-nav">
    \\    <ul class="nav-links">
    \\        {{nav_items}}
    \\    </ul>
    \\</nav>
;

pub const DEFAULT_MAIN_NAV_ITEM_HTML =
    \\<li>{{item}}</li>
;

pub const DEFAULT_TEXT_LINK_HTML =
    \\<a href="{{link}}" class="text-link">{{text}}</a>
;
pub const DEFAULT_TEXT_LINK_ALT_HTML =
    \\<a href="{{link}}" class="text-link">{{text}}</a>
;
pub const DEFAULT_BUTTON_LINK_HTML =
    \\<a href="{{link}}" class="button-link">{{text}}</a>
;

pub const CardType = enum { primary, accent, secondary };
pub const CardWidthType = enum {
    default,
    wide,
    full_width,

    pub fn format(self: @This(), writer: anytype) !void {
        const value = switch (self.type) {
            .default => "",
            .wide => "wide-card",
            .full_width => "full-width-card",
        };
        writer.print("{s}", .{value}) catch unreachable;
    }
};
pub const DEFAULT_CARD_HTML =
    \\<section class="card">
    \\    <!-- variant == primary, accent, secondary -->
    \\    <div class="card-header {{variant}}-header">
    \\        <h2 class="card-title">{{title}}</h2>
    \\    </div>
    \\    <div class="card-content">
    \\        {{content}}
    \\    </div>
    \\</section>
;

pub const DEFAULT_STYLES =
    \\:root {
    \\    --bg-background: oklch(0.12 0 0);
    \\    --bg-background-slightly-light: oklch(0.18 0 0);
    \\    --code-background-color: oklch(0.25 0 0);
    \\    --text-foreground: oklch(0.98 0 0);
    \\    --text-subtitle: oklch(0.65 0 0);
    \\
    \\    --primary-color: oklch(0.75 0.19 142);
    \\    --secondary-color: oklch(0.78 0.2 50);
    \\    --primary-color-accent: oklch(0.82 0.15 85);
    \\    --ternary-color: oklch(0.63 0.12 255.91);
    \\    --nav-primary-color: oklch(0.62 0.18 315.9);
    \\}
    \\
    \\* {
    \\    margin: 0;
    \\    padding: 0;
    \\    box-sizing: border-box;
    \\}
    \\
    \\body {
    \\    background-color: var(--bg-background);
    \\    color: var(--text-foreground);
    \\    font-family: "Geist Mono", monospace;
    \\    min-height: 100vh;
    \\    padding: 24px;
    \\}
    \\
    \\code {
    \\    font-family: "Cascadia Code";
    \\}
    \\
    \\.global-container {
    \\    max-width: 1200px;
    \\    margin: 0 auto;
    \\    display: flex;
    \\    flex-direction: column;
    \\    gap: 1.5em;
    \\}
    \\
    \\/* ============================================
    \\   MAIN HEADER
    \\   ============================================ */
    \\.main-header {
    \\    margin-bottom: 48px;
    \\    border: 4px solid var(--text-foreground);
    \\    background-color: var(--bg-background-slightly-light);
    \\    padding: 16px;
    \\    box-shadow: 8px 8px 0px 0px rgba(250, 250, 250, 1);
    \\    position: sticky;
    \\    top: 0;
    \\}
    \\
    \\.main-title {
    \\    margin-bottom: 16px;
    \\    font-size: 2rem;
    \\    font-weight: 900;
    \\    text-transform: uppercase;
    \\    letter-spacing: -0.025em;
    \\    line-height: 1;
    \\    color: var(--text-foreground);
    \\}
    \\
    \\.main-subtitle {
    \\    font-size: 1rem;
    \\    font-weight: 500;
    \\    color: var(--text-subtitle);
    \\    line-height: 1.5;
    \\}
    \\
    \\/* ============================================
    \\   MAIN CONTENT
    \\   ============================================ */
    \\.main-content {
    \\    display: flex;
    \\    flex-direction: column;
    \\    gap: 1.5em;
    \\}
    \\
    \\/* ============================================
    \\   MAIN NAV
    \\   ============================================ */
    \\.nav-links {
    \\    font-size: 1rem;
    \\    list-style: none;
    \\    display: flex;
    \\    flex-direction: row;
    \\    flex-grow: 0;
    \\    gap: 1em;
    \\    flex-wrap: wrap;
    \\}
    \\.nav-links > li > a {
    \\    background-color: var(--nav-primary-color);
    \\}
    \\
    \\/* ============================================
    \\   GRID LAYOUT
    \\   ============================================ */
    \\.grid {
    \\    display: grid;
    \\    gap: 24px;
    \\    grid-template-columns: 1fr;
    \\}
    \\
    \\@media (min-width: 768px) {
    \\    .grid {
    \\        grid-template-columns: repeat(2, 1fr);
    \\    }
    \\}
    \\
    \\@media (min-width: 1024px) {
    \\    .grid {
    \\        grid-template-columns: repeat(3, 1fr);
    \\    }
    \\}
    \\
    \\/* ============================================
    \\   HEADINGS
    \\   ============================================ */
    \\h1 {
    \\    font-size: 2.25rem;
    \\    font-weight: 900;
    \\    color: var(--text-foreground);
    \\}
    \\
    \\h2 {
    \\    font-size: 1.875rem;
    \\    font-weight: 900;
    \\    color: var(--text-foreground);
    \\}
    \\
    \\h3 {
    \\    font-size: 1.5rem;
    \\    font-weight: 700;
    \\    color: var(--text-foreground);
    \\}
    \\
    \\h4 {
    \\    font-size: 1.25rem;
    \\    font-weight: 700;
    \\    color: var(--text-foreground);
    \\}
    \\
    \\h5 {
    \\    font-size: 1.125rem;
    \\    font-weight: 700;
    \\    color: var(--text-foreground);
    \\}
    \\
    \\h6 {
    \\    font-size: 1rem;
    \\    font-weight: 700;
    \\    color: var(--text-foreground);
    \\}
    \\
    \\/* ============================================
    \\   LINKS
    \\   ============================================ */
    \\.text-link {
    \\    border-bottom: 4px solid var(--primary-color);
    \\    font-weight: 700;
    \\    color: var(--primary-color);
    \\    text-decoration: none;
    \\    transition: all 0.2s;
    \\}
    \\
    \\.text-link:hover {
    \\    border-color: var(--primary-color-accent);
    \\    color: var(--primary-color-accent);
    \\}
    \\
    \\.text-link.alt {
    \\    border-color: var(--secondary-color);
    \\    color: var(--secondary-color);
    \\}
    \\
    \\.text-link.alt:hover {
    \\    border-color: var(--primary-color);
    \\    color: var(--primary-color);
    \\}
    \\
    \\.button-link {
    \\    display: inline-block;
    \\    border: 4px solid oklch(0.98 0 0);
    \\    background-color: var(--primary-color);
    \\    padding: 8px 16px;
    \\    font-weight: 900;
    \\    text-transform: uppercase;
    \\    color: oklch(0.12 0 0);
    \\    box-shadow: 4px 4px 0px 0px rgba(250, 250, 250, 1);
    \\    transition: all 0.2s;
    \\    text-decoration: none;
    \\}
    \\
    \\.button-link:hover {
    \\    transform: translate(1px, 1px);
    \\    box-shadow: none;
    \\}
    \\
    \\/* ============================================
    \\   CARD COMPONENTS
    \\   ============================================ */
    \\.card {
    \\    border: 4px solid var(--text-foreground);
    \\    background-color: var(--bg-background-slightly-light);
    \\    padding: 24px;
    \\    box-shadow: 6px 6px 0px 0px rgba(250, 250, 250, 1);
    \\}
    \\
    \\.wide-card {
    \\    grid-column: span 1;
    \\}
    \\
    \\.full-width-card {
    \\    grid-column: span 1;
    \\}
    \\
    \\@media (min-width: 768px) {
    \\    .wide-card {
    \\        grid-column: span 2;
    \\    }
    \\}
    \\
    \\@media (min-width: 1024px) {
    \\    .full-width-card {
    \\        grid-column: span 3;
    \\    }
    \\}
    \\
    \\.card-header {
    \\    margin-bottom: 16px;
    \\    border-bottom: 4px solid;
    \\    padding-bottom: 8px;
    \\}
    \\
    \\.primary-header {
    \\    border-color: var(--primary-color);
    \\}
    \\
    \\.secondary-header {
    \\    border-color: var(--secondary-color);
    \\}
    \\.accent-header {
    \\    border-color: var(--primary-color-accent);
    \\}
    \\
    \\.card-title {
    \\    font-size: 1.5rem;
    \\    font-weight: 900;
    \\    text-transform: uppercase;
    \\}
    \\
    \\.primary-header .card-title {
    \\    color: --var(--primary-color);
    \\}
    \\
    \\.secondary-header .card-title {
    \\    color: --var(--secondary-color);
    \\}
    \\
    \\.accent-header .card-title {
    \\    color: --var(--primary-color-accent);
    \\}
    \\
    \\.card-content {
    \\    display: flex;
    \\    flex-direction: column;
    \\    gap: 12px;
    \\}
    \\
    \\.blog-list-item-link {
    \\    background-color: var(--ternary-color);
    \\}
    \\
    \\/* ============================================
    \\   CODE BLOCk
    \\   ============================================ */
    \\.code-block {
    \\    overflow-x: auto;
    \\    border: 4px solid var(--text-foreground);
    \\    background-color: var(--code-background-color);
    \\    padding: 16px;
    \\    box-shadow: 4px 4px 0px 0px rgba(250, 250, 250, 1);
    \\}
    \\.code-block code {
    \\    border: none;
    \\    background: none;
    \\    padding: 0;
    \\    font-size: 0.875rem;
    \\    color: var(--text-foreground);
    \\}
;
