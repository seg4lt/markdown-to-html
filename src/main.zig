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

    var tmpl_manager = TemplateManager.init(gpa, args.base_path, args.tmpl_path, args.app_name);
    defer tmpl_manager.map.deinit();
    try tmpl_manager.copyDefaultFiles(args.output_path);

    // I am parsing all document and keeping them on memory, this might not be ideal
    // but if we need we can implement just frontmatter parsing on 1st phase and
    // on 2nd phase we can parse whole document and inject stuffs
    // Mainly needed for blog list and blog series support
    const docs = try Parser.parseFromDirPath(gpa, args.base_path, args.tmpl_path);

    try HtmlGenerator.generateAll(gpa, &docs, args.output_path, &tmpl_manager);
}

const Clap = struct {
    app_name: []const u8 = "Demo",
    base_path: []const u8 = "example",
    output_path: []const u8 = "dist",
    tmpl_path: []const u8 = "__templates",
};

fn getAllocator() struct { Allocator, bool } {
    return switch (builtin.mode) {
        .Debug, .ReleaseSafe => .{ debug_allocator.allocator(), true },
        .ReleaseSmall, .ReleaseFast => .{ std.heap.smp_allocator, false },
    };
}

const std = @import("std");
const claptain = @import("claptain");
const builtin = @import("builtin");
const TemplateManager = @import("TemplateManager.zig");
const Parser = @import("Parser.zig");
const HtmlGenerator = @import("HtmlGenerator.zig");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
var debug_allocator: std.heap.DebugAllocator(.{}) = .init;
