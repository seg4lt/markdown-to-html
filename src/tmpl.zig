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
pub const TMPL_BLOG_LIST_HTML: Template = .{ .name = "blog_list.html", .content = DEFAULT_BLOG_LIST_HTML };
pub const TMPL_BLOG_LIST_ITEM_HTML: Template = .{ .name = "blog_list_item.html", .content = DEFAULT_BLOG_LIST_ITEM_HTML };
pub const TMPL_BLOG_SERIES_SECTION_WRAPPER_HTML: Template = .{ .name = "blog_series_section_wrapper.html", .content = DEFAULT_BLOG_SERIES_SECTION_WRAPPER_HTML };
pub const TMPL_BLOG_SERIES_TOC_ITEM_HTML: Template = .{ .name = "blog_series_toc_item.html", .content = DEFAULT_BLOG_SERIES_TOC_ITEM_HTML };
pub const TMPL_MAIN_NAV_HTML: Template = .{ .name = "main_nav.html", .content = DEFAULT_MAIN_NAV_HTML };
pub const TMPL_MAIN_NAV_ITEM_HTML: Template = .{ .name = "main_nav_item.html", .content = DEFAULT_MAIN_NAV_ITEM_HTML };
pub const TMPL_STYLES_CSS: Template = .{ .name = "styles.css", .content = DEFAULT_STYLES };

pub const TEMPLATES = [_]Template{
    TMPL_BASE_HTML,
    TMPL_HEADING_HTML,
    TMPL_CODE_BLOCK_HTML,
    TMPL_BLOG_LIST_HTML,
    TMPL_BLOG_LIST_ITEM_HTML,
    TMPL_BLOG_SERIES_SECTION_WRAPPER_HTML,
    TMPL_BLOG_SERIES_TOC_ITEM_HTML,
    TMPL_MAIN_NAV_HTML,
    TMPL_MAIN_NAV_ITEM_HTML,
    TMPL_STYLES_CSS,
};

const DEFAULT_BASE_HTML =
    \\<!DOCTYPE html>
    \\<html lang="en">
    \\<head>
    \\    <meta charset="UTF-8">
    \\    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    \\    <title>{{title}}</title>
    \\    <link rel="stylesheet" href="/styles.css">
    \\    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.11.1/styles/github-dark.min.css">
    \\ <link rel="preconnect" href="https://fonts.googleapis.com">
    \\ <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    \\ <link href="https://fonts.googleapis.com/css2?family=Cascadia+Code:ital,wght@0,200..700;1,200..700&display=swap" rel="stylesheet">
    \\</head>
    \\<body>
    \\    {{main_nav}}
    \\    
    \\    <main class="container">
    \\     {{content}}
    \\    </main>
    \\    
    \\    <footer class="main-footer">
    \\        <div class="container">
    \\            <p>&copy; <span id="this-year"></span> seg4lt. Markdown to html generator written in Zig</p>
    \\        </div>
    \\    </footer>
    \\    <script defer src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.11.1/highlight.min.js"></script>
    \\    <script>
    \\    document.addEventListener('DOMContentLoaded', (event) => {
    \\        document.getElementById('this-year').textContent = new Date().getFullYear();
    \\ 
    \\        hljs.highlightAll();
    \\    });
    \\    </script>
    \\</body>
    \\</html>
;
const DEFAULT_HEADING_HTML =
    \\    <h{{level}}>{{content}}</h{{level}}>
;

const DEFAULT_CODE_BLOCK =
    \\    <pre><code{{class}}>{{content}}</code></pre>
;

const DEFAULT_BLOG_LIST_HTML =
    \\<section class="blog-list">
    \\    <h2>Recent Blogs</h2>
    \\    <ul class="blog-list-item">
    \\        {{content}}
    \\    </ul>
    \\</section>
;
const DEFAULT_BLOG_LIST_ITEM_HTML =
    \\ <li class="blog-list-item">
    \\     <a href="{{link}}" class="blog-list-item-link">
    \\         <div class="blog-list-item-title">{{title}}</div>
    \\         <div class="blog-list-item-desc">{{desc}}</div>
    \\         <div class="blog-list-item-date">{{date}}</div>
    \\    </a>
    \\ </li>
;

const DEFAULT_BLOG_SERIES_SECTION_WRAPPER_HTML =
    \\ <section class="blog-series table-of-content">
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
    \\    <div class="nav-container">
    \\        <a href="/" class="nav-logo">{{app_name}}</a>
    \\        <ul class="nav-links">
    \\{{nav_items}}
    \\        </ul>
    \\    </div>
    \\</nav>
;

pub const DEFAULT_MAIN_NAV_ITEM_HTML =
    \\            <li><a href="{{link}}">{{title}}</a></li>
;

pub const DEFAULT_STYLES =
    \\ /* Base theme variables */
    \\ :root {
    \\     --bg-primary: #ffffff;
    \\     --bg-secondary: #f6f8fa;
    \\     --bg-tertiary: #f0f2f5;
    \\     --text-primary: #24292f;
    \\     --text-secondary: #57606a;
    \\     --text-tertiary: #6e7781;
    \\     --border-color: #d0d7de;
    \\     --link-color: #0969da;
    \\     --link-hover: #0550ae;
    \\     --code-bg: #f6f8fa;
    \\     --code-border: #d0d7de;
    \\     --heading-color: #24292f;
    \\     --nav-bg: #24292f;
    \\     --nav-text: #ffffff;
    \\     --nav-hover: #0969da;
    \\ }
    \\ 
    \\ /* Dark theme */
    \\ [data-theme="dark"] {
    \\     --bg-primary: #0d1117;
    \\     --bg-secondary: #161b22;
    \\     --bg-tertiary: #21262d;
    \\     --text-primary: #c9d1d9;
    \\     --text-secondary: #8b949e;
    \\     --text-tertiary: #6e7681;
    \\     --border-color: #30363d;
    \\     --link-color: #58a6ff;
    \\     --link-hover: #79c0ff;
    \\     --code-bg: #161b22;
    \\     --code-border: #30363d;
    \\     --heading-color: #c9d1d9;
    \\     --nav-bg: #161b22;
    \\     --nav-text: #c9d1d9;
    \\     --nav-hover: #58a6ff;
    \\ }
    \\ 
    \\ /* Base styles */
    \\ * {
    \\     margin: 0;
    \\     padding: 0;
    \\     box-sizing: border-box;
    \\ }
    \\ 
    \\ body {
    \\     font-family: "Cascadia Code", sans-serif;
    \\     font-optical-sizing: auto;
    \\     font-size: 16px;
    \\     line-height: 1.6;
    \\     color: var(--text-primary);
    \\     background-color: var(--bg-primary);
    \\     max-width: 1200px;
    \\     margin: 0 auto;
    \\     padding: 20px;
    \\ }
;
