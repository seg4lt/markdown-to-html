```@@frontmatter
{
  "title": "Multi-File Diff Viewer",
  "description": "Interactive file tree viewer for git patches",
  "date": "2025-12-16"
}
```

# Multi-File Diff Viewer

When you paste a multi-file git patch into a diff code block, you'll see a file tree on the left. Click any file to view its diff.

## Example

```diff
diff --git a/src/main.zig b/src/main.zig
index 37414d1..ca32203 100644
--- a/src/main.zig
+++ b/src/main.zig
@@ -5,6 +5,20 @@ const CliArgs = struct {
     src_path: []const u8,
     happy: ?bool = null,
 
+    subcommand: union(enum) {
+        clone: struct {
+            url: []const u8,
+            depth: i32 = 1,
+
+            pub const __claptain_metadata: claptain.Metadata(@This()) = .{
+                .url = .{ .positional = true },
+            };
+        },
+        push: struct {
+            force: bool = false,
+        },
+    },
+
     pub const __claptain_metadata: claptain.Metadata(@This()) = .{
         .src_path = .{
             .short = "s",
@@ -17,8 +31,9 @@ const CliArgs = struct {
 };
 
 pub fn main() !void {
-    const args = try claptain.parse(CliArgs, .{});
-    structPrinter(args);
+    const cla = try claptain.parse(CliArgs, .{});
+    try cla.printHelp();
+    structPrinter(cla.args);
 }
 
 fn structPrinter(value: anytype) void {
diff --git a/src/root.zig b/src/root.zig
index ec09cef..71bcb36 100644
--- a/src/root.zig
+++ b/src/root.zig
@@ -44,19 +44,44 @@ pub const ArgInfo = struct {
     short: ?[]const u8 = null,
     long: ?[]const u8 = null,
     description: ?[]const u8 = null,
+    positional: bool = false,
 };
 
-pub fn parse(comptime T: type, option: ParseOptions) ParseError!T {
+pub fn Cla(comptime T: type) type {
+    return struct {
+        args: T,
+        option: ParseOptions,
+
+        pub fn printHelp(self: *const @This()) !void {
+            var buf: [1024]u8 = undefined;
+            var stderr_state = std.fs.File.stderr().writer(&buf);
+            const parser = ClaptainParser{
+                .writer = if (self.option.override_writer) |writer| writer else &stderr_state.interface,
+                .option = self.option,
+            };
+            try parser.printUsage(T);
+            try parser.flush();
+        }
+    };
+}
+
+pub fn parse(comptime T: type, option: ParseOptions) ParseError!Cla(T) {
     var iterator = std.process.args();
     return try parseWithIterator(T, option, &iterator);
 }
 
-pub fn parseWithIterator(comptime T: type, option: ParseOptions, args_iter: anytype) ParseError!T {
+pub fn parseWithIterator(comptime T: type, option: ParseOptions, args_iter: anytype) ParseError!Cla(T) {
+    return parseWithIteratorInternal(T, option, args_iter, true);
+}
+
+fn parseWithIteratorInternal(comptime T: type, option: ParseOptions, args_iter: anytype, skip_program_name: bool) ParseError!Cla(T) {
     if (!@hasDecl(@TypeOf(args_iter.*), "next")) @compileError("args_iter must have next() decl");
     if (@typeInfo(T) != .@"struct") @compileError("type passed to parse must be of type struct.");
 
-    const program_name = args_iter.next();
-    _ = program_name;
+    if (skip_program_name) {
+        const program_name = args_iter.next();
+        _ = program_name;
+    }
 
     var buf: [1024]u8 = undefined;
     var stderr_state = std.fs.File.stderr().writer(&buf);
@@ -95,7 +120,7 @@ pub fn parseWithIterator(comptime T: type, option: ParseOptions, args_iter: anyt
             return ParseError.UsageRequested;
         }
 
-        try self.parseFieldValue(T, &result, &fields_seen, arg);
+        try self.parseFieldValue(T, &result, &fields_seen, arg, args_iter);
     }
 
     // Verify all required arguments are provided
@@ -118,7 +143,10 @@ pub fn parseWithIterator(comptime T: type, option: ParseOptions, args_iter: anyt
         return ParseError.RequiredArgsNotProvided;
     }
 
-    return result;
+    return Cla(T){
+        .args = result,
+        .option = option,
+    };
 }
 
 const ClaptainParser = struct {
@@ -137,11 +165,29 @@ const ClaptainParser = struct {
         return ParseError.InvalidArgument;
     }
 
-    fn parseFieldValue(self: *const @This(), comptime S: type, result: *S, fields_seen: []bool, arg: []const u8) ParseError!void {
+    fn parseFieldValue(self: *const @This(), comptime S: type, result: *S, fields_seen: []bool, arg: []const u8, args_iter: anytype) ParseError!void {
         const index_of_equal = std.mem.indexOf(u8, arg, "=");
         const field_identifier = if (index_of_equal) |idx| arg[0..idx] else arg;
 
         const arg_length = isShortOrLongArg(field_identifier) catch |err| {
+            // Check for positional args
+            var positional_found = false;
+            inline for (std.meta.fields(S), 0..) |field, i| {
+                if (!positional_found and !fields_seen[i]) {
+                    const arg_info = getArgInfo(S, field.name);
+                    const is_positional = if (arg_info) |info| info.positional else false;
+
+                    if (is_positional) {
+                        // Found the first unseen positional field
+                        try self.matchAndSetPositionalValue(S, result, field, arg, args_iter);
+                        fields_seen[i] = true;
+                        positional_found = true;
+                    }
+                }
+            }
+
+            if (positional_found) return;
+
             if (!self.option.allow_invalid) {
                 try self.print("options should start with `--` or `-` found `{s}`", .{field_identifier});
                 return err;
@@ -170,11 +216,103 @@ const ClaptainParser = struct {
         }
     }
 
+    fn matchAndSetPositionalValue(
+        self: *const @This(),
+        comptime S: type,
+        result: *S,
+        comptime field: std.builtin.Type.StructField,
+        value_str: []const u8,
+        args_iter: anytype,
+    ) ParseError!void {
+        const actual_type = if (@typeInfo(field.type) == .optional) @typeInfo(field.type).optional.child else field.type;
+
+        switch (@typeInfo(actual_type)) {
+            .pointer => |ptr| {
+                const is_u8_slice = ptr.size == .slice and ptr.child == u8;
+                if (!is_u8_slice) @compileError("only []u8 pointer type is supported for string fields.");
+
+                if (std.mem.startsWith(u8, value_str, "\"") and std.mem.endsWith(u8, value_str, "\"")) {
+                    @field(result, field.name) = value_str[1 .. value_str.len - 1];
+                } else {
+                    @field(result, field.name) = value_str;
+                }
+            },
+            .@"union" => |union_info| {
+                if (union_info.tag_type) |tag_type| {
+                    const TagType = tag_type;
+                    var matched_tag: ?TagType = null;
+                    inline for (std.meta.fields(TagType)) |tag_field| {
+                        if (std.mem.eql(u8, tag_field.name, value_str)) {
+                            matched_tag = @enumFromInt(tag_field.value);
+                        }
+                    }
+
+                    if (matched_tag) |_| {
+                        inline for (union_info.fields) |union_field| {
+                            if (std.mem.eql(u8, union_field.name, value_str)) {
+                                const PayloadType = union_field.type;
+                                if (PayloadType == void) {
+                                    @field(result, field.name) = @unionInit(actual_type, union_field.name, {});
+                                } else {
+                                    const sub_cla = try parseWithIteratorInternal(PayloadType, self.option, args_iter, false);
+                                    @field(result, field.name) = @unionInit(actual_type, union_field.name, sub_cla.args);
+                                }
+                                return;
+                            }
+                        }
+                    }
+                }
+                try self.print("invalid subcommand '{s}'\n", .{value_str});
+                try self.printUsage(S);
+                return ParseError.InvalidArgument;
+            },
+            .@"enum" => |enum_info| {
+                var matched = false;
+                inline for (enum_info.fields) |enum_field| {
+                    if (std.mem.eql(u8, enum_field.name, value_str)) {
+                        @field(result, field.name) = @enumFromInt(enum_field.value);
+                        matched = true;
+                        break;
+                    }
+                }
+                if (!matched) {
+                    try self.print("invalid value '{s}' for argument '{s}'\n", .{ value_str, field.name });
+                    try self.printUsage(S);
+                    return ParseError.InvalidArgument;
+                }
+            },
+            .bool => {
+                if (std.mem.eql(u8, value_str, "true")) {
+                    @field(result, field.name) = true;
+                } else if (std.mem.eql(u8, value_str, "false")) {
+                    @field(result, field.name) = false;
+                } else {
+                    try self.print("invalid boolean value '{s}' for argument '{s}'\n", .{ value_str, field.name });
+                    try self.printUsage(S);
+                    return ParseError.InvalidArgument;
+                }
+            },
+            .int, .float => {
+                const value = switch (@typeInfo(actual_type)) {
+                    .int => std.fmt.parseInt(actual_type, value_str, 10),
+                    .float => std.fmt.parseFloat(actual_type, value_str),
+                    else => |tag| @compileError(@tagName(tag) ++ " ** bug ** this should not happen at all"),
+                } catch {
+                    try self.print("invalid number value '{s}' for argument '{s}'\n", .{ value_str, field.name });
+                    try self.printUsage(S);
+                    return ParseError.InvalidArgument;
+                };
+                @field(result, field.name) = value;
+            },
+            else => @compileError("type not supported: " ++ @typeName(actual_type)),
+        }
+    }
+
     fn matchAndSetFieldValue(
         self: *const @This(),
         comptime S: type,
         result: *S,
-        field: std.builtin.Type.StructField,
+        comptime field: std.builtin.Type.StructField,
         interested_field_name: []const u8, // actual field name to match against
         arg: []const u8, // full arg string e.g -s=value
         arg_field_name: []const u8, // user provided arg name - which can be different as it can be overridden
@@ -238,6 +376,10 @@ const ClaptainParser = struct {
                     return ParseError.InvalidArgument;
                 }
             },
+            .@"union" => |union_info| {
+                _ = union_info;
+                return false;
+            },
             .int, .float => {
                 if (index_of_equal == null) {
                     try self.print("missing value for argument '{s}'\n", .{arg_field_name});
@@ -248,7 +390,7 @@ const ClaptainParser = struct {
                 const value = switch (@typeInfo(actual_type)) {
                     .int => std.fmt.parseInt(actual_type, value_str, 10),
                     .float => std.fmt.parseFloat(actual_type, value_str),
-                    else => |tag| @compileError(tag ++ " ** bug ** this should not happen at all"),
+                    else => |tag| @compileError(@tagName(tag) ++ " ** bug ** this should not happen at all"),
                 } catch {
                     try self.print("invalid number value '{s}' for argument '{s}'\n", .{ value_str, arg_field_name });
                     try self.printUsage(S);
@@ -256,7 +398,7 @@ const ClaptainParser = struct {
                 };
                 @field(result, field.name) = value;
             },
-            else => |tag| @compileError(tag ++ " not supported"),
+            else => @compileError("type not supported: " ++ @typeName(actual_type)),
         }
         return true;
     }
@@ -359,6 +501,21 @@ const ClaptainParser = struct {
                     }
                     try self.printAdditionalUsageInfo(print_additional_info_buf, has_default, is_required, field);
                 },
+                .@"union" => |union_info| {
+                    if (union_info.tag_type) |tag_type| {
+                        const print_count = try self.printArgInfo(T, field.name, print_args_info_buf);
+                        var pos = print_count;
+                        inline for (std.meta.fields(tag_type), 0..) |tag_field, i| {
+                            _ = try self.bufPrint(print_args_info_buf[pos..], "{s}", .{tag_field.name});
+                            pos += tag_field.name.len;
+                            if (i < std.meta.fields(tag_type).len - 1) {
+                                _ = try self.bufPrint(print_args_info_buf[pos..], "|", .{});
+                                pos += 1;
+                            }
+                        }
+                        try self.printAdditionalUsageInfo(print_additional_info_buf, has_default, is_required, field);
+                    }
+                },
                 .int => {
                     const print_count = try self.printArgInfo(T, field.name, print_args_info_buf);
                     _ = try self.bufPrint(print_args_info_buf[print_count..], "int", .{});
@@ -369,7 +526,7 @@ const ClaptainParser = struct {
                     _ = try self.bufPrint(print_args_info_buf[print_count..], "float", .{});
                     try self.printAdditionalUsageInfo(print_additional_info_buf, has_default, is_required, field);
                 },
-                else => |tag| @compileError(tag ++ " not supported yet"),
+                else => @compileError("type not supported yet"),
             }
             try self.print("{s}\n", .{print_line_buf});
             try self.flush();
@@ -451,4 +608,6 @@ test {
     _ = testing.refAllDeclsRecursive(@import("./tests/float_test.zig"));
     _ = testing.refAllDeclsRecursive(@import("./tests/metadata_test.zig"));
     _ = testing.refAllDeclsRecursive(@import("./tests/multi_arg_test.zig"));
+    _ = testing.refAllDeclsRecursive(@import("./tests/positional_test.zig"));
+    _ = testing.refAllDeclsRecursive(@import("./tests/subcommand_test.zig"));
 }
diff --git a/src/tests/metadata_test.zig b/src/tests/metadata_test.zig
index bad295c..896a275 100644
--- a/src/tests/metadata_test.zig
+++ b/src/tests/metadata_test.zig
@@ -129,9 +129,9 @@ pub const MultipleFieldsWithShortNames = struct {
             .override_writer = writer,
         }, &iter);
 
-        try std.testing.expectEqualSlices(u8, "input.txt", result.input_file);
-        try std.testing.expect(result.verbose == true);
-        try std.testing.expect(result.output_file == null);
+        try std.testing.expectEqualSlices(u8, "input.txt", result.args.input_file);
+        try std.testing.expect(result.args.verbose == true);
+        try std.testing.expect(result.args.output_file == null);
     }
 
     test "metadata - different short name should work after another" {
@@ -144,8 +144,8 @@ pub const MultipleFieldsWithShortNames = struct {
             .override_writer = writer,
         }, &iter);
 
-        try std.testing.expectEqualSlices(u8, "in.txt", result.input_file);
-        try std.testing.expectEqualSlices(u8, "out.txt", result.output_file.?);
-        try std.testing.expect(result.verbose == true);
+        try std.testing.expectEqualSlices(u8, "in.txt", result.args.input_file);
+        try std.testing.expectEqualSlices(u8, "out.txt", result.args.output_file.?);
+        try std.testing.expect(result.args.verbose == true);
     }
-};
\ No newline at end of file
+};
diff --git a/src/tests/test_util.zig b/src/tests/test_util.zig
index bef76b4..7ac9451 100644
--- a/src/tests/test_util.zig
+++ b/src/tests/test_util.zig
@@ -39,7 +39,7 @@ pub fn runTest(comptime A: type, comptime V: type, comptime tc: TestCase(V)) !vo
         return err;
     };
 
-    const field = @field(value, tc.field_name);
+    const field = @field(value.args, tc.field_name);
     const is_optional = @typeInfo(@TypeOf(field)) == .optional;
     const actual_type = if (is_optional) @typeInfo(@TypeOf(field)).optional.child else @TypeOf(field);
     const expected = tc.expected_value;

```

The viewer automatically:
- Parses the patch to find all files
- Shows a clickable file list on the left
- Displays the selected file's diff on the right with syntax highlighting
