```@@frontmatter
{
  "title": "Test Series 04 - Code Blocks and Syntax Highlighting",
  "description": "Exploring various code blocks with different languages and syntax highlighting.",
  "date": "2024-01-04",
  "index": 4
}
```

# Test Series 04 - Code Blocks and Syntax Highlighting

{{ @@blog_series_toc }}

## Python Example

```python
def fibonacci(n):
    """Generate Fibonacci sequence up to n terms."""
    a, b = 0, 1
    sequence = []
    for _ in range(n):
        sequence.append(a)
        a, b = b, a + b
    return sequence

# Usage
result = fibonacci(10)
print(f"Fibonacci sequence: {result}")
```

## Rust Example

```rust
use std::collections::HashMap;

fn count_words(text: &str) -> HashMap<&str, usize> {
    let mut counts = HashMap::new();
    for word in text.split_whitespace() {
        *counts.entry(word).or_insert(0) += 1;
    }
    counts
}

fn main() {
    let text = "hello world hello rust world";
    let counts = count_words(text);
    println!("{:?}", counts);
}
```

## JavaScript/TypeScript Example

```typescript
interface User {
  id: number;
  name: string;
  email: string;
}

class UserService {
  private users: User[] = [];

  addUser(user: User): void {
    this.users.push(user);
  }

  findUserById(id: number): User | undefined {
    return this.users.find(u => u.id === id);
  }

  getAllUsers(): User[] {
    return [...this.users];
  }
}
```

## Shell Script Example

```bash
#!/bin/bash

# Process files in directory
for file in *.md; do
    if [ -f "$file" ]; then
        echo "Processing: $file"
        # Convert markdown to HTML
        pandoc "$file" -o "${file%.md}.html"
    fi
done
```

## SQL Example

```sql
-- Complex query with joins and aggregations
SELECT 
    u.username,
    COUNT(p.id) as post_count,
    MAX(p.created_at) as latest_post
FROM users u
LEFT JOIN posts p ON u.id = p.user_id
WHERE u.created_at > '2025-01-01'
GROUP BY u.id, u.username
HAVING COUNT(p.id) > 5
ORDER BY post_count DESC;
```

