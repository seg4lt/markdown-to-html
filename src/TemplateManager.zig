mem_ctx: *MemCtx,
template_cache: std.StringHashMap([]const u8),
args: *const Clap,
const Self = @This();

const COPY_FILES = [_][]const u8{
    "styles.css",
};

pub fn init(mem_ctx: *MemCtx, args: *const Clap) Self {
    return .{
        .mem_ctx = mem_ctx,
        .template_cache = std.StringHashMap([]const u8).init(mem_ctx.global),
        .args = args,
    };
}

pub fn get(self: *Self, tmpl_name: []const u8) ![]const u8 {
    if (self.template_cache.get(tmpl_name)) |tmpl_content| {
        return tmpl_content;
    }
    const file_content = try self.findOverride(tmpl_name) orelse blk: {
        for (tmpl.TEMPLATES) |template| {
            if (mem.eql(u8, template.name, tmpl_name)) {
                break :blk template.content;
            }
        }
        std.log.err("{s} template not found", .{tmpl_name});
        return error.TemplateNotFound;
    };

    try self.template_cache.put(tmpl_name, file_content);
    return file_content;
}

fn findOverride(self: *Self, tmpl_name: []const u8) !?[]const u8 {
    const file_path = try std.fs.path.join(self.mem_ctx.scratch, &[_][]const u8{
        self.args.md_base_path,
        self.args.tmpl_base_path,
        tmpl_name,
    });

    const file_content = std.fs.cwd().readFileAlloc(self.mem_ctx.global, file_path, common.MAX_FILE_SIZE) catch |err| {
        if (err == error.FileNotFound) {
            std.log.debug("No override found for {s} on `{s}`", .{ tmpl_name, file_path });
            return null;
        }
        return err;
    };
    std.log.info("Using override for {s}", .{tmpl_name});
    return file_content;
}

pub fn getMainNav(self: *Self) ![]const u8 {
    const NAV_MENU_KEY = "__main_nav__";

    if (self.template_cache.get(NAV_MENU_KEY)) |nav| {
        return nav;
    }

    var dir = try std.fs.cwd().openDir(self.args.md_base_path, .{ .iterate = true });
    defer dir.close();

    const NavItem = struct {
        name: []const u8,
        nav_index: u8,
    };
    var nav_items: ArrayList(NavItem) = .empty;

    try nav_items.append(self.mem_ctx.scratch, .{ .name = "__home__", .nav_index = 0 });

    var it = dir.iterate();
    while (try it.next()) |dir_entry| {
        if (dir_entry.kind != .directory) continue;
        if (mem.eql(u8, dir_entry.name, self.args.tmpl_base_path)) continue;
        if (mem.startsWith(u8, dir_entry.name, "__")) continue;

        var nav_index: u8 = 255; // default to last
        const index_path = try std.fs.path.join(self.mem_ctx.scratch, &[_][]const u8{
            self.args.md_base_path,
            dir_entry.name,
            "index.md",
        });

        if (Parser.parseFrontmatterFromPath(self.mem_ctx, index_path)) |fm| {
            if (fm.index) |idx| {
                nav_index = idx;
            }
        }

        const name_copy = try self.mem_ctx.scratch.dupe(u8, dir_entry.name);
        try nav_items.append(self.mem_ctx.scratch, .{ .name = name_copy, .nav_index = nav_index });
    }

    std.mem.sort(NavItem, nav_items.items, {}, struct {
        fn lessThan(_: void, a: NavItem, b: NavItem) bool {
            return a.nav_index < b.nav_index;
        }
    }.lessThan);

    var nav_items_acc: ArrayList(u8) = .empty;
    for (nav_items.items, 0..) |item, i| {
        const is_home = mem.eql(u8, item.name, "__home__");
        const link = try std.fmt.allocPrint(self.mem_ctx.scratch, "{s}/{s}", .{ self.args.web_root, if (is_home) "" else item.name });

        const nav_link = try replacePlaceholders(
            self.mem_ctx.scratch,
            try self.get(tmpl.TMPL_BUTTON_LINK_HTML.name),
            &[_][]const u8{ "{{link}}", "{{text}}" },
            &[_][]const u8{ link, if (is_home) "Home" else item.name },
        );

        const nav_item = try replacePlaceholders(
            self.mem_ctx.scratch,
            try self.get(tmpl.TMPL_MAIN_NAV_ITEM_HTML.name),
            &[_][]const u8{"{{item}}"},
            &[_][]const u8{nav_link},
        );

        try nav_items_acc.appendSlice(self.mem_ctx.scratch, nav_item);
        if (i < nav_items.items.len - 1) {
            try nav_items_acc.appendSlice(self.mem_ctx.scratch, "\n");
        }
    }

    const nav_menu = try replacePlaceholders(
        self.mem_ctx.scratch,
        try self.get(tmpl.TMPL_MAIN_NAV_HTML.name),
        &[_][]const u8{"{{nav_items}}"},
        &[_][]const u8{nav_items_acc.items},
    );
    const nav_menu_global_owned = try self.mem_ctx.global.dupe(u8, nav_menu);
    try self.template_cache.put(NAV_MENU_KEY, nav_menu_global_owned);
    return nav_menu;
}

pub fn copyDefaultFiles(self: *Self) !void {
    std.fs.cwd().makePath(self.args.output_base_path) catch |err| if (err != error.PathAlreadyExists) return err;

    for (COPY_FILES) |file_name| {
        const dest_path = try std.fs.path.join(self.mem_ctx.scratch, &[_][]const u8{ self.args.output_base_path, file_name });

        const style_text = try self.findOverride(file_name) orelse tmpl.DEFAULT_STYLES_CSS;
        std.log.debug("Using override for {s}", .{"styles.css"});
        const output_file = try std.fs.cwd().createFile(dest_path, .{});
        defer output_file.close();
        try output_file.writeAll(style_text);
    }

    const src_dir_path = try std.fs.path.join(
        self.mem_ctx.scratch,
        &[_][]const u8{ self.args.md_base_path, "__assets" },
    );
    var src_dir = std.fs.cwd().openDir(src_dir_path, .{ .iterate = true }) catch |err| {
        if (err == error.FileNotFound) {
            std.log.info("No __assets directory found at `{s}`", .{src_dir_path});
            return;
        }
        return err;
    };
    defer src_dir.close();

    const dest_dir_path = try std.fs.path.join(
        self.mem_ctx.scratch,
        &[_][]const u8{ self.args.output_base_path, "__assets" },
    );
    std.fs.cwd().makeDir(dest_dir_path) catch |err| if (err != error.PathAlreadyExists) return err;

    var dest_dir = try std.fs.cwd().openDir(dest_dir_path, .{ .iterate = true });
    defer dest_dir.close();

    try copyRecursive(&src_dir, &dest_dir);
}

fn copyRecursive(
    src_dir: *const std.fs.Dir,
    dest_dir: *const std.fs.Dir,
) !void {
    var src_it = src_dir.iterate();

    while (try src_it.next()) |entry| {
        switch (entry.kind) {
            .file => {
                try src_dir.copyFile(entry.name, dest_dir.*, entry.name, .{});
            },
            .directory => {
                var new_src_dir = try src_dir.openDir(entry.name, .{ .iterate = true });
                defer new_src_dir.close();

                try dest_dir.makeDir(entry.name);
                var new_dest_dir = try dest_dir.openDir(entry.name, .{ .iterate = true });
                defer new_dest_dir.close();

                try copyRecursive(&new_src_dir, &new_dest_dir);
            },
            else => continue,
        }
    }
}

// TODO(seg4lt)
// Maybe implement proper parser, so we don't use replaceOwned
// replaceOwned is called multiple times, so it's not efficient
// If we create our own parser, I think we can do this in one pass
// Also we don't need to make copies and destroy
pub fn replacePlaceholders(
    allocator: Allocator,
    haystack: []const u8,
    keys: []const []const u8,
    values: []const []const u8,
) ![]u8 {
    var result = try allocator.dupe(u8, haystack);
    for (keys, values) |key, value| {
        const old = result;
        defer allocator.free(old);
        result = try std.mem.replaceOwned(u8, allocator, result, key, value);
    }
    return result;
}

const std = @import("std");
const tmpl = @import("tmpl.zig");
const Parser = @import("Parser.zig");
const common = @import("common.zig");
const MemCtx = common.MemCtx;
const Clap = common.AppArgs;

const MAX_FILE_SIZE = common.MAX_FILE_SIZE;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const mem = std.mem;
