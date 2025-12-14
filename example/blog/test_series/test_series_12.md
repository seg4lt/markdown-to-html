```@@frontmatter
{
  "title": "Test Series 12 - Mixed Complex Content",
  "description": "Combining multiple markdown features in complex patterns.",
  "date": "2024-01-12",
  "index": 12
}
```

# Test Series 12 - Mixed Complex Content

{{ @@blog_series_toc }}

## Complex Section with Everything

This section combines multiple markdown features:

1. **Ordered list** with nested content:
   - Unordered sub-item with `inline code`
   - Another sub-item with [a link](https://example.com)
   - Sub-item with *italic* and **bold** text

2. **Code block** example:

```zig
const std = @import("std");

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print("Hello, World!\n", .{});
}
```

3. **Block quote** with content:

> This is a block quote containing:
> - A list item
> - Another list item
> - And `inline code`
> 
> It also has **bold text** and *italic text*.

## Table with Complex Content

| Feature | Example | Notes |
|:--------|:--------|:------|
| Code | `const x = 10;` | Inline code in table |
| Link | [Example](https://example.com) | Link in table cell |
| Formatting | **Bold** and *italic* | Mixed formatting |
| List | - Item 1<br>- Item 2 | HTML list in table |

## Nested Structures

### Code in Lists

- First item with code:
  ```python
  def hello():
      print("Hello!")
  ```
- Second item with different code:
  ```rust
  fn main() {
      println!("Hello!");
  }
  ```

### Lists in Block Quotes

> Important points to remember:
> 
> 1. First point
> 2. Second point
>    - Sub-point A
>    - Sub-point B
> 3. Third point

### Links and Formatting

Visit [this **bold link**](https://example.com) for more information.

Check out the [*italic link*](https://example.com) as well.

Here's a [link with `code`](https://example.com) in the text.
