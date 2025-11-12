gpa: Allocator,
map: std.StringHashMap([]const u8),
base_path: []const u8,
tmpl_path: []const u8,
app_name: []const u8,

const Self = @This();

const COPY_FILES = [_][]const u8{
    "styles.css",
};

pub fn init(gpa: Allocator, base_path: []const u8, tmpl_path: []const u8, app_name: []const u8) Self {
    return .{
        .gpa = gpa,
        .base_path = base_path,
        .tmpl_path = tmpl_path,
        .app_name = app_name,
        .map = std.StringHashMap([]const u8).init(gpa),
    };
}
pub fn deinit(self: *Self) void {
    self.map.deinit();
}

pub fn get(self: *Self, tmpl_name: []const u8) ![]const u8 {
    if (self.map.get(tmpl_name)) |tmpl_content| {
        return tmpl_content;
    }
    const file_path = try std.fs.path.join(self.gpa, &[_][]const u8{
        self.base_path,
        self.tmpl_path,
        tmpl_name,
    });
    defer self.gpa.free(file_path);

    const file_content = try std.fs.cwd().readFileAlloc(self.gpa, file_path, common.MAX_FILE_SIZE);

    try self.map.put(tmpl_name, file_content);
    return file_content;
}

pub fn getMainNav(self: *Self) ![]const u8 {
    const NAV_MENU_KEY = "__main_nav__";

    if (self.map.get(NAV_MENU_KEY)) |nav| {
        return nav;
    }

    var dir = try std.fs.cwd().openDir(self.base_path, .{ .iterate = true });
    defer dir.close();
    var top_level_dirs: ArrayList([]const u8) = .empty;
    defer top_level_dirs.deinit(self.gpa);

    var it = dir.iterate();
    while (try it.next()) |dir_entry| {
        if (dir_entry.kind == .directory and !mem.eql(u8, dir_entry.name, self.tmpl_path) and !mem.startsWith(u8, dir_entry.name, "__")) {
            try top_level_dirs.append(self.gpa, dir_entry.name);
        }
    }

    // Build nav items
    var nav_items_acc = std.io.Writer.Allocating.init(self.gpa);
    defer nav_items_acc.deinit();
    for (top_level_dirs.items, 0..) |dir_name, i| {
        const link = try std.fmt.allocPrint(self.gpa, "/{s}/", .{dir_name});
        defer self.gpa.free(link);

        const nav_item = try replacePlaceholders(
            self.gpa,
            tmpl.DEFAULT_MAIN_NAV_ITEM_HTML,
            &[_][]const u8{ "{{link}}", "{{title}}" },
            &[_][]const u8{ link, dir_name },
        );
        defer self.gpa.free(nav_item);

        try nav_items_acc.writer.writeAll(nav_item);
        if (i < top_level_dirs.items.len - 1) {
            try nav_items_acc.writer.writeAll("\n");
        }
    }

    const nav_items = try nav_items_acc.toOwnedSlice();
    defer self.gpa.free(nav_items);

    const nav_menu = try replacePlaceholders(
        self.gpa,
        tmpl.DEFAULT_MAIN_NAV_HTML,
        &[_][]const u8{ "{{app_name}}", "{{nav_items}}" },
        &[_][]const u8{ self.app_name, nav_items },
    );
    try self.map.put(NAV_MENU_KEY, nav_menu);
    return nav_menu;
}

pub fn copyDefaultFiles(self: *Self, output_path: []const u8) !void {
    for (COPY_FILES) |file_name| {
        const src_path = try std.fs.path.join(self.gpa, &[_][]const u8{ self.base_path, self.tmpl_path, file_name });
        defer self.gpa.free(src_path);

        std.fs.cwd().makePath(output_path) catch |err| if (err != error.PathAlreadyExists) return err;

        const dest_path = try std.fs.path.join(self.gpa, &[_][]const u8{ output_path, file_name });
        defer self.gpa.free(dest_path);

        // Try to read from template folder first
        const content = std.fs.cwd().readFileAlloc(self.gpa, src_path, MAX_FILE_SIZE) catch |err| {
            if (err == error.FileNotFound) {
                // Fallback to default styles from tmpl.zig
                std.log.info("Template file {s} not found, using default from tmpl.zig", .{file_name});
                const default_content = if (mem.eql(u8, file_name, "styles.css"))
                    tmpl.DEFAULT_STYLES
                else
                    null;
                
                if (default_content) |content_str| {
                    const output_file = try std.fs.cwd().createFile(dest_path, .{});
                    defer output_file.close();
                    try output_file.writeAll(content_str);
                } else {
                    std.log.warn("No default content for {s}, skipping.", .{file_name});
                }
                continue;
            } else {
                return err;
            }
        };
        defer self.gpa.free(content);

        const output_file = try std.fs.cwd().createFile(dest_path, .{});
        defer output_file.close();
        try output_file.writeAll(content);
    }
}

pub fn getTemplate(self: *Self, name: []const u8) ?[]const u8 {
    if (self.map.get(name)) |template| {
        return template;
    }
    const path = try std.fs.path.join(self.gpa, &[_][]const u8{ self.base_path, self.tmpl_path, name });
    defer self.gpa.free(path);

    const content = try std.fs.cwd().readFileAlloc(self.gpa, path, MAX_FILE_SIZE);
    try self.map.put(name, content);
    return content;
}

// TODO(seg4lt)
// Maybe implement proper parser, so we don't use replaceOwned
// replaceOwned is called multiple times, so it's not efficient
// If we create our own parser, I think we can do this in one pass
// Also we don't need to make copy and destroy
pub fn replacePlaceholders(gpa: Allocator, haystack: []const u8, keys: []const []const u8, values: []const []const u8) ![]u8 {
    var result = try gpa.dupe(u8, haystack);
    for (keys, values) |key, value| {
        const old = result;
        defer gpa.free(old);
        result = try std.mem.replaceOwned(u8, gpa, result, key, value);
    }
    return result;
}

const std = @import("std");
const tmpl = @import("tmpl.zig");
const common = @import("common.zig");

const MAX_FILE_SIZE = common.MAX_FILE_SIZE;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const mem = std.mem;
