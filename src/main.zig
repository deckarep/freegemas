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
        try w.show();
    }

    // Testing queue direct
    if (false) {
        const q = try dq.DrawingQueue.init(alloc);
        std.debug.print("q.queue.items.len => {d}\n", .{q.queue.items.len});

        try doAdds(q);
        std.debug.print("finished...\n", .{});
    }

    if (true) {
        try testMatches();
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

fn testMatches() !void {
    const mch = @import("match.zig");
    const co = @import("coord.zig");
    //const mm = @import("muli_match.zig");
    {
        var singleMatch = mch.Match.init(alloc);
        singleMatch.deinit();
        try singleMatch.pushBack(co.Coord{ .x = 1, .y = 2 });
        try singleMatch.pushBack(co.Coord{ .x = 11, .y = 22 });
        try singleMatch.pushBack(co.Coord{ .x = 111, .y = 222 });

        std.debug.print("midSquare => {?}\n", .{singleMatch.midSquare()});

        std.debug.print(
            "found? => {s}\n ",
            .{if (singleMatch.match(co.Coord{ .x = 121, .y = 22 })) "yes" else "no"},
        );
    }
}
