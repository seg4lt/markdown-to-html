# Markdown Syntax Examples

This document demonstrates the basic markdown syntax that should be supported by the markdown-to-html converter.

## Headings

# Heading 1
## Heading 2
### Heading 3
#### Heading 4
##### Heading 5
###### Heading 6

## Text Formatting

This is **bold text** using double asterisks.

This is __bold text__ using double underscores.

This is *italic text* using single asterisks.

This is _italic text_ using single underscores.

This is ***bold and italic*** text.

This is ~~strikethrough~~ text.

## Paragraphs

This is a paragraph. Multiple lines of text
in the source will be combined into a single paragraph
unless separated by a blank line.

This is a second paragraph. It's separated from the first by a blank line.

## Line Breaks

This is a line with a hard break.  
This text appears on a new line (two spaces at the end of previous line).

## Lists

### Unordered Lists

* Item 1
* Item 2
* Item 3
  * Nested item 3.1
  * Nested item 3.2
* Item 4

Alternative syntax:

- Item A
- Item B
- Item C

Another alternative:

+ Plus item 1
+ Plus item 2

### Ordered Lists

1. First item
2. Second item
3. Third item
   1. Nested item 3.1
   2. Nested item 3.2
4. Fourth item

## Links

[This is a link to Google](https://www.google.com)

[This is a link with a title](https://www.example.com "Example Website")

<https://www.autolink.com>

## Images

![Alt text for image](https://via.placeholder.com/150)

![Image with title](https://via.placeholder.com/200 "Image Title")

## Blockquotes

> This is a blockquote.
> It can span multiple lines.

> This is another blockquote.
>
> It can contain multiple paragraphs.

> Blockquotes can be nested
>> Like this

## Code

### Inline Code

This is `inline code` within a sentence.

Use `var x = 10;` to declare a variable.

### Code Blocks

```
function hello() {
    console.log("Hello, World!");
}
```

With language specification:

```javascript
const greeting = "Hello";
console.log(greeting);
```

```python
def greet():
    print("Hello, World!")
```

Indented code blocks (4 spaces or 1 tab):

    function example() {
        return true;
    }

## Horizontal Rules

Three or more hyphens:

---

Three or more asterisks:

***

Three or more underscores:

___

## Tables

| Header 1 | Header 2 | Header 3 |
|----------|----------|----------|
| Row 1 Col 1 | Row 1 Col 2 | Row 1 Col 3 |
| Row 2 Col 1 | Row 2 Col 2 | Row 2 Col 3 |

With alignment:

| Left Aligned | Center Aligned | Right Aligned |
|:-------------|:--------------:|--------------:|
| Left         | Center         | Right         |
| Text         | Text           | Text          |

## Task Lists

- [x] Completed task
- [ ] Incomplete task
- [ ] Another incomplete task

## Escape Characters

Use backslash to escape special characters:

\* Not italic \*

\# Not a heading

\[Not a link\](url)

## Emphasis and Strong Emphasis

*This is emphasized text*

**This is strong text**

***This is both***

## Inline HTML

<div>This is inline HTML</div>

<span style="color: red;">Colored text</span>

## Footnotes

Here's a sentence with a footnote[^1].

[^1]: This is the footnote text.

## Definition Lists

Term 1
: Definition 1

Term 2
: Definition 2a
: Definition 2b

## Abbreviations

The HTML specification is maintained by the W3C.

*[HTML]: Hyper Text Markup Language
*[W3C]: World Wide Web Consortium

## Mixed Content Example

Here's a **complex example** with *multiple* types of formatting:

1. First, visit [the website](https://example.com)
2. Then, run this command: `npm install`
3. Finally, add this code:

```javascript
const result = calculate(42);
console.log(result);
```

> **Note:** Make sure to test everything!

---

This document covers most common markdown syntax elements.