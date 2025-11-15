pub const MAX_FILE_SIZE = 10 * 1024 * 1024; // 10 MB

pub const AppArgs = struct {
    app_name: []const u8,
    app_subtitle: []const u8,
    md_base_path: []const u8,
    output_base_path: []const u8,
    tmpl_base_path: []const u8 = "__templates",
    web_root: []const u8 = "/",
    export_default_tmpl: bool = false,

    pub const __claptain_metadata: claptain.Metadata(@This()) = .{
        .app_name = .{ .short = "n" },
        .app_subtitle = .{ .short = "s" },
        .md_base_path = .{ .short = "m" },
        .output_base_path = .{ .short = "o" },
        .tmpl_base_path = .{ .short = "t" },
        .web_root = .{ .short = "w" },
        .export_default_tmpl = .{ .short = "e" },
    };
};

var debug_allocator: std.heap.DebugAllocator(.{}) = .init;

pub const MemCtx = struct {
    global: Allocator,
    scratch: Allocator,
    global_impl: *std.heap.ArenaAllocator,
    scratch_impl: *std.heap.ArenaAllocator,

    const MemCtxError = error{OutOfMemory};

    pub fn init() MemCtxError!MemCtx {
        const gpa, _ = getAllocator();

        var scratch_impl = try gpa.create(std.heap.ArenaAllocator);
        scratch_impl.* = std.heap.ArenaAllocator.init(gpa);

        var global_impl = try gpa.create(std.heap.ArenaAllocator);
        global_impl.* = std.heap.ArenaAllocator.init(gpa);

        return MemCtx{
            .global_impl = global_impl,
            .global = global_impl.allocator(),
            .scratch_impl = scratch_impl,
            .scratch = scratch_impl.allocator(),
        };
    }

    pub fn resetScratch(self: *MemCtx) void {
        _ = self.scratch_impl.reset(.retain_capacity);
    }

    pub fn deinit(self: *@This()) void {
        self.scratch_impl.reset(.free_all);
        self.global_impl.reset(.free_all);
        if (builtin.mode == .Debug) {
            const leak_status = debug_allocator.deinit();
            if (builtin.mode == .Debug) {
                std.log.debug("----- LEAK STATUS: {s} ----- ", .{@tagName(leak_status)});
            }
        }
    }

    fn getAllocator() struct { Allocator, bool } {
        return switch (builtin.mode) {
            .Debug, .ReleaseSafe => .{ debug_allocator.allocator(), true },
            .ReleaseSmall, .ReleaseFast => .{ std.heap.smp_allocator, false },
        };
    }
};

pub const GlobalError = error{
    // error to be used when we can't recover instead of process exit or panic
    // if we do exit / panic we can't cleanup
    UnrecoverablePanic,
};

const std = @import("std");
const claptain = @import("claptain");
const Allocator = std.mem.Allocator;
const builtin = @import("builtin");
