```@@frontmatter
{
  "title": "Test Series 15 - Ultimate Complexity",
  "description": "The most complex markdown document combining all features.",
  "date": "2024-01-15",
  "index": 15
}
```

# Test Series 15 - Ultimate Complexity

{{ @@blog_series_toc }}

## Introduction

This document demonstrates the **ultimate complexity** in markdown formatting, combining *all* available features in intricate patterns.

## Complex Code Example

Here's a complex example with multiple languages:

### Zig Implementation

```zig
const std = @import("std");

pub const Parser = struct {
    allocator: std.mem.Allocator,
    tokens: std.ArrayList(Token),

    pub fn init(allocator: std.mem.Allocator) Parser {
        return .{
            .allocator = allocator,
            .tokens = std.ArrayList(Token).init(allocator),
        };
    }

    pub fn parse(self: *Parser, input: []const u8) !void {
        // Complex parsing logic here
        _ = input;
    }
};
```

### Equivalent Rust Code

```rust
use std::collections::VecDeque;

pub struct Parser {
    tokens: VecDeque<Token>,
}

impl Parser {
    pub fn new() -> Self {
        Self {
            tokens: VecDeque::new(),
        }
    }

    pub fn parse(&mut self, input: &str) -> Result<(), ParseError> {
        // Complex parsing logic
        Ok(())
    }
}
```

## Complex Data Structures

### Comparison Table

| Feature | Zig | Rust | Go | Python |
|:--------|:----|:----|:---|:--------|
| Memory Safety | Compile-time | Ownership | GC | GC |
| Performance | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ |
| Learning Curve | Steep | Steep | Moderate | Easy |
| Use Case | Systems | Systems | Services | General |

### Nested Lists with Code

1. **Language Features**
   - Memory management:
     ```zig
     const mem = try allocator.alloc(u8, size);
     defer allocator.free(mem);
     ```
   - Error handling:
     ```rust
     match result {
         Ok(value) => println!("{}", value),
         Err(e) => eprintln!("Error: {}", e),
     }
     ```
   - Concurrency:
     ```go
     go func() {
         // Concurrent operation
     }()
     ```

2. **Best Practices**
   - Always handle errors
   - Use appropriate data structures
   - Write tests

## Block Quotes with Complex Content

> ### Important Considerations
> 
> When choosing a language, consider:
> 
> 1. **Performance requirements**
>    - Real-time systems need low latency
>    - Batch processing can tolerate higher latency
> 
> 2. **Team expertise**
>    - Choose languages your team knows
>    - Consider learning curve
> 
> 3. **Ecosystem**
>    - Library availability
>    - Community support
>    - Documentation quality
> 
> > Nested quote: Remember that `the best tool` is the one that fits your **specific needs**.

## Mixed HTML and Markdown

<p>This paragraph uses <strong>HTML</strong> with <em>formatting</em>.</p>

But this paragraph uses **markdown** with *formatting*.

<div style="background: #f0f0f0; padding: 1em; border-left: 4px solid #007acc;">
  <h4>Styled HTML Block</h4>
  <p>This is a styled HTML block with:</p>
  <ul>
    <li>Custom styling</li>
    <li>Nested lists</li>
    <li><code>Inline code</code></li>
  </ul>
</div>

## Task Lists with Complex Items

- [x] **Phase 1: Planning**
  - [x] Requirements gathering
  - [x] Architecture design
  - [x] Technology selection
- [ ] **Phase 2: Implementation**
  - [x] Core functionality
  - [ ] Testing framework
  - [ ] Documentation
- [ ] **Phase 3: Deployment**
  - [ ] CI/CD setup
  - [ ] Monitoring
  - [ ] Performance optimization

## Links and References

Check out these resources:
- [Zig Documentation](https://ziglang.org/documentation/)
- [Rust Book](https://doc.rust-lang.org/book/)
- [Go Tour](https://go.dev/tour/)

See also [test series 01](./test_series_01.md) and [test series 14](./test_series_14.md).

## Conclusion

This document demonstrates the **full range** of markdown capabilities, from simple *formatting* to complex nested structures with `code`, [links](https://example.com), tables, and more.

> Final thought: *The complexity* of markdown allows for **rich documentation** while maintaining `readability` in source form.

