```@@frontmatter
{
  "title": "Test Series 13 - Advanced Code Examples",
  "description": "Complex code examples across multiple programming languages.",
  "date": "2024-01-13",
  "index": 13
}
```

# Test Series 13 - Advanced Code Examples

{{ @@blog_series_toc }}

## Zig Memory Management

```zig
const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const numbers = try allocator.alloc(i32, 10);
    defer allocator.free(numbers);

    for (numbers, 0..) |*num, i| {
        num.* = @intCast(i32, i * i);
    }

    const stdout = std.io.getStdOut().writer();
    for (numbers) |num| {
        try stdout.print("{d} ", .{num});
    }
    try stdout.print("\n", .{});
}
```

## Rust Async Example

```rust
use tokio::time::{sleep, Duration};
use std::sync::Arc;

async fn fetch_data(id: u32) -> Result<String, Box<dyn std::error::Error>> {
    sleep(Duration::from_millis(100)).await;
    Ok(format!("Data for id: {}", id))
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let handles: Vec<_> = (0..5)
        .map(|i| tokio::spawn(fetch_data(i)))
        .collect();

    for handle in handles {
        let result = handle.await??;
        println!("{}", result);
    }
    Ok(())
}
```

## TypeScript Generic Functions

```typescript
interface Repository<T> {
  findById(id: string): Promise<T | null>;
  findAll(): Promise<T[]>;
  save(entity: T): Promise<T>;
  delete(id: string): Promise<void>;
}

class UserRepository implements Repository<User> {
  async findById(id: string): Promise<User | null> {
    // Implementation
    return null;
  }

  async findAll(): Promise<User[]> {
    return [];
  }

  async save(user: User): Promise<User> {
    return user;
  }

  async delete(id: string): Promise<void> {
    // Implementation
  }
}
```

## Python Context Managers

```python
from contextlib import contextmanager
from typing import Iterator

@contextmanager
def managed_resource(name: str) -> Iterator[str]:
    """Context manager for resource management."""
    print(f"Acquiring resource: {name}")
    try:
        yield name
    finally:
        print(f"Releasing resource: {name}")

# Usage
with managed_resource("database") as db:
    print(f"Using {db}")
    # Resource is automatically released
```

## Go Concurrency Patterns

```go
package main

import (
    "context"
    "fmt"
    "sync"
    "time"
)

func worker(ctx context.Context, id int, wg *sync.WaitGroup) {
    defer wg.Done()
    for {
        select {
        case <-ctx.Done():
            fmt.Printf("Worker %d stopping\n", id)
            return
        default:
            fmt.Printf("Worker %d working\n", id)
            time.Sleep(1 * time.Second)
        }
    }
}

func main() {
    ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
    defer cancel()

    var wg sync.WaitGroup
    for i := 0; i < 3; i++ {
        wg.Add(1)
        go worker(ctx, i, &wg)
    }
    wg.Wait()
}
```

