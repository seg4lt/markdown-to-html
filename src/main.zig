pub fn main() !void {
    var mem_ctx = try MemCtx.init();
    // Don't care about leak.. OS will reclaim all memory
    // defer mem_ctx.deinit();

    const args = claptain.parse(Clap, .{}) catch std.process.exit(1);

    if (args.export_default_tmpl) {
        try exportDefaultTmpl(mem_ctx.scratch, &args);
        std.process.exit(0);
    }

    var tm: TemplateManager = .init(&mem_ctx, &args);
    try tm.copyDefaultFiles();

    // I am parsing all document and keeping them on memory, this might not be ideal
    // but if we need we can implement just frontmatter parsing on 1st phase and
    // on 2nd phase we can parse whole document and inject stuffs
    // Mainly needed for blog list and blog series support
    const docs = try Parser.parseFromDirPath(&mem_ctx, args.md_base_path, args.tmpl_base_path);

    try HtmlGenerator.generateAll(&mem_ctx, &docs, &tm, &args);
}

fn exportDefaultTmpl(arena: Allocator, args: *const Clap) !void {
    const output_dir = try fs.path.join(arena, &[_][]const u8{ args.md_base_path, "__templates" });

    fs.cwd().makePath(output_dir) catch |err| {
        if (err != error.PathAlreadyExists) return err;
    };

    for (tmpl.TEMPLATES) |template| {
        const path = try fs.path.join(arena, &[_][]const u8{ output_dir, template.name });
        const file = try fs.cwd().createFile(path, .{});
        defer file.close();

        try file.writeAll(template.content);
        std.log.info("Created: {s}", .{path});
    }

    std.log.info("All default templates written to {s}/", .{output_dir});
}

const std = @import("std");
const claptain = @import("claptain");
const builtin = @import("builtin");
const tmpl = @import("tmpl.zig");
const TemplateManager = @import("TemplateManager.zig");
const Parser = @import("Parser.zig");
const HtmlGenerator = @import("HtmlGenerator.zig");
const MemCtx = @import("common.zig").MemCtx;
const Clap = @import("common.zig").AppArgs;

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const fs = std.fs;
