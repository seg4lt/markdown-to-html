pub const DEFAULT_BASE_HTML =
    \\<!DOCTYPE html>
    \\<html lang="en">
    \\<head>
    \\    <meta charset="UTF-8">
    \\    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    \\    <title>{{title}}</title>
    \\    <link rel="stylesheet" href="/__template/style.css">
    \\    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.11.1/styles/github-dark.min.css">
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
