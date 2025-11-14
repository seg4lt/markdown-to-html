```@@frontmatter
{
  "title": "Example Markdown",
  "description": "An example markdown file with various elements.",
  "date": "2024-06-01"
}
```

# m2h

Markdown to HTML converter written in Zig. Very opinionated and supports only what I need.

## Quick Start

```bash
zig build
./zig-out/bin/m2h
```

Generates HTML from markdown files in `example/` folder and outputs to `dist/`

## Command Line Flags

```bash
./zig-out/bin/m2h --base_path=example --output_path=dist --tmpl_path=__templates
```

All flags are optional with these defaults:
- `--base_path` = `example` (where your markdown files are)
- `--output_path` = `dist` (where HTML goes)
- `--tmpl_path` = `__templates` (template folder name inside base_path)
- `--app_name` = `m2h` (used in HTML title)
- `--app_subtitle` = `Markdown to HTML generator written in Zig`
- `--export_default_tmpl` = `false` (exports default templates to see what's available)

So basically it looks for markdown in `example/`, templates in `example/__templates/`, and outputs to `dist/`.

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

{{ @@blog_list }}


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
- [ ] Sort blog content
- [ ] @@blog_list to support number of blog
- [ ] gen html should have date based folder structure
- [ ] Parse table
- [ ] fix table of content for table series
- [ ] fix sorting on table of content using index
- [ ] add support for @@include_html and @@include_html_data for some dynamism - so I don't need to create parser for each type of thing I want to support
- [ ] ol/ul list template on `__templates` folder so it can be picked up by build script
- [ ] For quick prototyping I was using gpa everywhere, and not cleaning up memory properly. Fix that !!