const std = @import("std");
const goWin = @import("go_window.zig");
const c = @import("cdefs.zig").c;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const alloc = gpa.allocator();

const WINDOW_WIDTH = 800;
const WINDOW_HEIGHT = 600;
const UPDATE_INTERVAL = 25; //30;

pub fn main() !void {
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) {
            std.debug.print("leaks detected; you lack discipline!", .{});
        }
    }

    var w = try goWin.GoWindow.init(
        WINDOW_WIDTH,
        WINDOW_HEIGHT,
        "Free Gems - Zig Edition - @deckarep",
        UPDATE_INTERVAL,
        alloc,
    );
    defer w.deinit();
    try w.setup();
    try w.show();
}
