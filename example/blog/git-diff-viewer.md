```@@frontmatter
{
  "title": "Git Diff Viewer",
  "description": "Added git-diff code block support with syntax highlighting",
  "date": "2025-12-16"
}
```

# Git Diff Viewer

Added support for `git-diff` and `diff` code blocks with proper syntax highlighting.

## Usage

Use triple backticks with `git-diff` or `diff` as the language:

## Example - The Change That Added This Feature

Here's the actual diff that added this feature to HtmlGenerator.zig:

```diff
@@ -516,6 +516,13 @@
     }

-    fn generateCodeBlock(self: *@This(), code_block: Node.CodeBlock) ![]u8 {
-        const class_attr = if (code_block.language) |lang|
+    fn generateCodeBlock(self: *@This(), code_block: Node.CodeBlock) ![]u8 {
+        // Special handling for git-diff
+        if (code_block.language) |lang| {
+            if (mem.eql(u8, lang, "git-diff") or mem.eql(u8, lang, "diff")) {
+                return try self.generateDiffBlock(code_block.content);
+            }
+        }
+
+        const class_attr = if (code_block.language) |lang|
```

And the new function that renders diff blocks:

```diff
+    fn generateDiffBlock(self: *@This(), content: []const u8) ![]u8 {
+        var result: ArrayList(u8) = .empty;
+        try result.appendSlice(self.arena, "<pre class=\"code-block diff-block\"><code>");
+
+        var line_iter = mem.splitScalar(u8, content, '\n');
+        while (line_iter.next()) |line| {
+            if (line.len > 0 and line[0] == '+') {
+                // Green for additions
+            } else if (line.len > 0 and line[0] == '-') {
+                // Red for removals
+            }
+        }
+        return result.items;
+    }
```

## CSS Styles Added

```diff
+.diff-add {
+    display: block;
+    background-color: oklch(0.3 0.1 142);
+    color: oklch(0.85 0.15 142);
+}
+.diff-remove {
+    display: block;
+    background-color: oklch(0.3 0.1 25);
+    color: oklch(0.85 0.15 25);
+}
+.diff-hunk {
+    display: block;
+    color: var(--nav-primary-color);
+}
```
