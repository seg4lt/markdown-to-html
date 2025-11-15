```@@frontmatter
{
  "title": "Example Markdown",
  "description": "An example markdown file with various elements.",
  "date": "2024-06-01"
}
```

# m2h

Markdown to HTML converter written in Zig. Very opinionated and supports only what I need.

[Example of generated site here](https://seg4lt.github.io/markdown-to-html/)

## Quick Start

```bash
zig build
./zig-out/bin/m2h
```

Generates HTML from markdown files in `example/` folder and drops the site into `markdown-to-html/`.
Pass `--web_root=/my-subdir` if you need links to be prefixed (handy for GitHub Pages projects).

## Command Line Flags

```bash
./zig-out/bin/m2h --md_base_path=example --output_base_path=markdown-to-html --tmpl_base_path=__templates --web_root=/markdown-to-html
```

All flags are optional with these defaults:
- `--md_base_path` = `example` (where your markdown files are)
- `--output_base_path` = `markdown-to-html` (where HTML goes)
- `--tmpl_base_path` = `__templates` (template folder name inside base_path)
- `--app_name` = `m2h` (used in HTML title)
- `--app_subtitle` = `Markdown to HTML generator written in Zig`
- `--web_root` = `` (leave blank unless you host under a sub-path)
- `--export_default_tmpl` = `false` (exports default templates to see what's available)

So basically it looks for markdown in `example/`, templates in `example/__templates/`, and outputs to `markdown-to-html/`.

## Folder Structre

```
example/
├── __templates/        # your custom templates go here
│   ├── base.html
│   ├── heading.html
│   ├── styles.css
│   └── ... other templates
├── blog/              # markdown files
│   └── post.md
└── index.md
```

The generator walks through all `.md` files and converts them to HTML.

## Override Templates & Styles

Just drop your custom template in `example/__templates/` folder. The build script will automatically bake them into the binary.

Example - to change how headings look:

```html
<!-- __templates/heading.html -->
<h{{level}} class="my-custom-class">{{content}}</h{{level}}>
```

Same for styles - edit `__templates/styles.css` and rebuild.

## Magic Markers

These are special markers you can use in markdown:

### Blog List
```markdown
{{ @@blog_list }}
```
Generates list of all blog posts with frontmatter like below

{{ @@blog_list 3 }}


### Blog Series TOC
```markdown
{{ @@blog_series_toc }}
```
Creates table of contents for blog series

### Grid Layout
```markdown
{{ @@grid_start 3 }}

your content here...

{{ @@grid_end }}
```
Creates responsive grid with 3 columns

## Highlight with Colors

Use `==text==` for highlights. You can add color variants:

```markdown
==normal highlight==
==important text===important=
==warning message===warning=
==note to self===note=
```

The variant gets added as CSS class so you can style them however you want.

## Blog Series

Put related posts in same folder and use the magic marker:

```
example/blog/test_series/
├── test_series_01.md
└── test_series_02.md
```

In any of those files add:
```markdown
{{ @@blog_series_toc }}
```

Generates something like:
```
Table of Contents
1. Test Series 01
2. Test Series 02
```

Each item links to that post. Same folder = series. Thats it.

## TODO
- [ ] blog series add previous and next links
- [ ] when limiting number of items in blog list, add "show more" link
- [ ] show more should take you to place where you can see all posts but with basic pagination
- [ ] maybe add blog search feature / local fuzzy search?
- [ ] this search can be maybe magic marker and can be added anywhere.
- [ ] when limiting numbr of items on blog series, show exact items, but if we have older items, show previous two and any other items should be current and new.
- [ ] Parse table
- [ ] add support for @@include_html and @@include_html_data for some dynamism - so I don't need to create parser for each type of thing I want to support