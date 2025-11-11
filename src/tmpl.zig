pub const MAGIC_MARKER_PREFIX = "{{ @@";
pub const MAGIC_INCLUDE_HTML = "@@include_html";
pub const MAGIC_INCLUDE_HTML_DATA = "```@@include_html_data";
pub const MAGIC_BLOG_LIST = "@@blog_list";
pub const MAGIC_FRONTMATTER = "@@frontmatter";

pub const DEFAULT_BASE_HTML =
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
pub const DEFAULT_HEADING_HTML =
    \\    <h{{level}}>{{content}}</h{{level}}>
;

pub const DEFAULT_CODE_BLOCK =
    \\    <pre><code{{class}}>{{content}}</code></pre>
;

pub const DEFAULT_BLOG_LIST_HTML =
    \\<section class="blog-list">
    \\    <h2>Recent Blogs</h2>
    \\    <ul class="blog-list-item">
    \\        {{content}}
    \\    </ul>
    \\</section>
;
pub const DEFAULT_BLOG_LIST_ITEM_HTML =
    \\ <li class="blog-list-item">
    \\     <a href="{{link}}" class="blog-list-item-link">
    \\         <div class="blog-list-item-title">{{title}}</div>
    \\         <div class="blog-list-item-desc">{{desc}}</div>
    \\         <div class="blog-list-item-date">{{date}}</div>
    \\    </a>
    \\ </li>
;
