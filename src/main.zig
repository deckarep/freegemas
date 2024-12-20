const std = @import("std");
const goWin = @import("go_window.zig");
const dq = @import("go_drawingqueue.zig");
const c = @import("cdefs.zig").c;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const alloc = gpa.allocator();

pub fn main() !void {
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

    // In the original Game <inherits::from> GoWindow
    if (true) {
        var w = try goWin.GoWindow.init(
            800,
            600,
            "Free Gems - Zig Edition - @deckarep",
            30,
            alloc,
        );
        defer w.deinit();
        try w.setup();

        std.debug.print("MAIN: &w addr => {*}, mGame => {*}\n", .{ &w, goWin.howToPlay.?.mGame });
        std.debug.assert(goWin.howToPlay.?.mGame == &w);
        std.debug.assert(w.mDrawingQueue.queue.items.len == 0);
        std.debug.print("MAIN: win addr => {*}\n", .{&w});
        std.debug.print("MAIN:priority queue addr: {*}\n", .{&w.mDrawingQueue.queue});
        // Hack to fix the priority queue, force re-initialization.
        // NOTE: did not work!
        //w.mDrawingQueue.queue = std.PriorityQueue(dq.DrawingQueueOp, void, dq.lessThan).init(alloc, {});
        //std.debug.print("priority queue hack init done\n", .{});
        try w.show();
    }

    // Testing queue direct
    if (false) {
        const q = try dq.DrawingQueue.init(alloc);
        std.debug.print("q.queue.items.len => {d}\n", .{q.queue.items.len});

        try doAdds(q);
        std.debug.print("finished...\n", .{});
    }
}

pub fn doAdds(q: dq.DrawingQueue) !void {
    var myQ = q;
    for (0..5) |idx| {
        try myQ.draw(@floatFromInt(idx), dq.DrawingQueueOp{
            // .mColor = c.SDL_Color{
            //     .r = 255,
            //     .g = 255,
            //     .b = 255,
            //     .a = 255,
            // },
            // .mAlpha = 128,
            // .mDstRect = c.SDL_Rect{ .x = 0, .y = 0, .w = 12, .h = 23 },
            // .mTexture = undefined,
            // .mAngle = 0.0,
        });
    }
}
