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
        if (dir_entry.kind == .directory and !mem.eql(u8, dir_entry.name, self.tmpl_path)) {
            try top_level_dirs.append(self.gpa, dir_entry.name);
        }
    }
    var accumulator = std.io.Writer.Allocating.init(self.gpa);
    var writer = &accumulator.writer;
    try writer.print(
        \\<nav class="main-nav">
        \\    <div class="nav-container">
        \\        <a href="/" class="nav-logo">{s}</a>
        \\        <ul class="nav-links">
    , .{self.app_name});
    for (top_level_dirs.items) |dir_name| {
        try writer.print(
            \\<li><a href="/{s}/">{s}</a></li>
        , .{ dir_name, dir_name });
    }
    try writer.print(
        \\        </ul>
        \\    </div>
        \\</nav>
    , .{});

    const nav_menu = try accumulator.toOwnedSlice();
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

        const content = std.fs.cwd().readFileAlloc(self.gpa, src_path, MAX_FILE_SIZE) catch |err| {
            if (err == error.FileNotFound) {
                std.log.warn("file {s} not found for copying, skipping copy.", .{src_path});
                break;
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

const std = @import("std");
const common = @import("common.zig");

const MAX_FILE_SIZE = common.MAX_FILE_SIZE;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const mem = std.mem;
