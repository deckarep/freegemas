const std = @import("std");
const goWin = @import("go_window.zig");
const c = @import("cdefs.zig").c;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const alloc = gpa.allocator();

pub fn main() !void {
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) {
            std.debug.print("leaks detected; you lack discipline!", .{});
        }
    }

    var w = try goWin.GoWindow.init(
        800,
        600,
        "Free Gems - Zig Edition - @deckarep",
        30,
        alloc,
    );
    defer w.deinit();
    try w.setup();
    try w.show();
}
