const std = @import("std");
const claptain = @import("claptain");

const CliArgs = struct {
    base_path: []const u8,
};

pub fn main() !void {
    const args = claptain.parse(CliArgs, .{}) catch {
        std.process.exit(1);
    };
    std.debug.print("Base path: {s}\n", .{args.base_path});
}
