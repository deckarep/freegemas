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

    // Testing board.
    if (false) {
        try testBoard();
    }

    // Testing queue direct
    if (false) {
        const q = try dq.DrawingQueue.init(alloc);
        std.debug.print("q.queue.items.len => {d}\n", .{q.queue.items.len});

        try doAdds(q);
        std.debug.print("finished...\n", .{});
    }

    if (false) {
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
    const mm = @import("multi_match.zig");
    {
        var sm1 = mch.Match.init(alloc);
        sm1.deinit();
        try sm1.pushBack(co.Coord{ .x = 1, .y = 2 });
        try sm1.pushBack(co.Coord{ .x = 11, .y = 22 });
        try sm1.pushBack(co.Coord{ .x = 111, .y = 222 });

        var sm2 = mch.Match.init(alloc);
        sm2.deinit();
        try sm2.pushBack(co.Coord{ .x = 1, .y = 2 });
        try sm2.pushBack(co.Coord{ .x = 11, .y = 22 });
        try sm2.pushBack(co.Coord{ .x = 111, .y = 222 });

        var multiM = mm.MultiMatch.init(alloc);
        try multiM.pushBack(&sm1);
        try multiM.pushBack(&sm2);

        const res = multiM.matched(co.Coord{ .x = 11, .y = 22 });
        std.debug.print("found? => {s}\n", .{if (res) "yes" else "no"});
    }
}

fn testBoard() !void {
    const bd = @import("board.zig");

    var brd = bd.Board.init(alloc);
    defer brd.deinit();

    try brd.generate();
    std.debug.print("final board:\n", .{});
    brd.dump();

    while (true) {
        std.time.sleep(std.time.ns_per_s * 1);
    }
}
