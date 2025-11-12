// TODO(seg4lt)
// - Using gpa, for now, but need to work with arena. Don't know life time well yet!!
// - Maybe we don't even care about memory as this is not long running process?
//      - But what if we add server later for search??
pub fn main() !void {
    const gpa, const deinit = getAllocator();
    _ = deinit;
    // defer if (deinit) {
    //     const leak_status = debug_allocator.deinit();
    //     if (builtin.mode == .Debug) std.log.debug("----- LEAK STATUS: {s} ----- ", .{@tagName(leak_status)});
    // };
    const args = claptain.parse(Clap, .{}) catch std.process.exit(1);

    if (args.output_default_tpl) {
        try outputDefaultTemplates(gpa);
        std.process.exit(0);
    }

    var tmpl_manager = TemplateManager.init(gpa, args.base_path, args.tmpl_path, args.app_name);
    defer tmpl_manager.map.deinit();
    try tmpl_manager.copyDefaultFiles(args.output_path);

    // I am parsing all document and keeping them on memory, this might not be ideal
    // but if we need we can implement just frontmatter parsing on 1st phase and
    // on 2nd phase we can parse whole document and inject stuffs
    // Mainly needed for blog list and blog series support
    const docs = try Parser.parseFromDirPath(gpa, args.base_path, args.tmpl_path);

    try HtmlGenerator.generateAll(gpa, &docs, args.app_name, args.app_subtitle, args.output_path, &tmpl_manager);
}

const Clap = struct {
    app_name: []const u8 = "m2h",
    app_subtitle: []const u8 = "Markdown to HTML generator written in Zig",
    base_path: []const u8 = "example",
    output_path: []const u8 = "dist",
    tmpl_path: []const u8 = "__templates",
    output_default_tpl: bool = false,
};

fn outputDefaultTemplates(gpa: Allocator) !void {
    const args = claptain.parse(Clap, .{}) catch std.process.exit(1);
    const output_dir = try std.fs.path.join(gpa, &[_][]const u8{ args.base_path, "__default_templates__" });
    defer gpa.free(output_dir);

    // Create the output directory
    std.fs.cwd().makePath(output_dir) catch |err| {
        if (err != error.PathAlreadyExists) return err;
    };

    for (tmpl.TEMPLATES) |template| {
        const path = try std.fs.path.join(gpa, &[_][]const u8{ output_dir, template.name });
        defer gpa.free(path);

        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();

        try file.writeAll(template.content);
        std.log.info("Created: {s}", .{path});
    }

    std.log.info("All default templates written to {s}/", .{output_dir});
}

fn getAllocator() struct { Allocator, bool } {
    return switch (builtin.mode) {
        .Debug, .ReleaseSafe => .{ debug_allocator.allocator(), true },
        .ReleaseSmall, .ReleaseFast => .{ std.heap.smp_allocator, false },
    };
}

const std = @import("std");
const claptain = @import("claptain");
const builtin = @import("builtin");
const tmpl = @import("tmpl.zig");
const TemplateManager = @import("TemplateManager.zig");
const Parser = @import("Parser.zig");
const HtmlGenerator = @import("HtmlGenerator.zig");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
var debug_allocator: std.heap.DebugAllocator(.{}) = .init;
