```@@frontmatter
{
  "title": "Test Series 14 - Documentation Patterns",
  "description": "Common documentation patterns and structures.",
  "date": "2024-01-14",
  "index": 14
}
```

# Test Series 14 - Documentation Patterns

{{ @@blog_series_toc }}

## API Documentation Example

### `calculateTotal(items, taxRate)`

Calculates the total price including tax.

**Parameters:**
- `items` (Array<Item>): List of items with price property
- `taxRate` (number): Tax rate as decimal (e.g., 0.08 for 8%)

**Returns:** (number) Total price including tax

**Example:**

```javascript
const items = [
  { name: "Apple", price: 1.00 },
  { name: "Banana", price: 0.50 }
];
const total = calculateTotal(items, 0.08);
console.log(total); // 1.62
```

## Function Reference

### `parseMarkdown(text: string): Document`

Parses markdown text into a document structure.

**Type Parameters:**
- None

**Parameters:**
- `text` (string): Markdown text to parse

**Returns:** `Document` - Parsed document object

**Throws:** `ParseError` if markdown is invalid

**Example:**

```typescript
const markdown = "# Hello\n\nThis is **bold**.";
const doc = parseMarkdown(markdown);
console.log(doc.title); // "Hello"
```

## Configuration Example

### Settings

| Setting | Type | Default | Description |
|:--------|:-----|:--------|:------------|
| `debug` | boolean | `false` | Enable debug logging |
| `port` | number | `8080` | Server port number |
| `host` | string | `"localhost"` | Server host address |
| `timeout` | number | `5000` | Request timeout in ms |

### Usage

```json
{
  "debug": true,
  "port": 3000,
  "host": "0.0.0.0",
  "timeout": 10000
}
```

## Step-by-Step Guide

1. **Installation**
   ```bash
   npm install package-name
   ```

2. **Configuration**
   - Create config file
   - Set environment variables
   - Configure database connection

3. **Usage**
   ```javascript
   import { initialize } from 'package-name';
   
   const app = initialize({
     config: './config.json'
   });
   ```

4. **Testing**
   ```bash
   npm test
   ```

## Troubleshooting

### Common Issues

> **Problem:** Module not found
> 
> **Solution:** Run `npm install` to install dependencies.

> **Problem:** Port already in use
> 
> **Solution:** Change the port in configuration or stop the process using the port.

