const std = @import("std");
const dq = @import("go_drawingqueue.zig");
const c = @import("cdefs.zig").c;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const alloc = gpa.allocator();

pub fn main() !void {
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

    var drawingQueue = dq.DrawingQueue.init(alloc);

    try drawingQueue.draw(3.2, dq.DrawingQueueOp{
        .mZdepth = undefined,
        .mAlpha = 100,
        .mAngle = 20,
        .mColor = c.SDL_Color{
            .a = 127,
            .r = 127,
            .g = 128,
            .b = 112,
        },
        .mDstRect = c.SDL_Rect{
            .x = 0,
            .y = 0,
            .w = 100,
            .h = 200,
        },
        .mTexture = undefined,
    });

    try drawingQueue.draw(5.3, dq.DrawingQueueOp{
        .mZdepth = undefined,
        .mAlpha = 100,
        .mAngle = 20,
        .mColor = c.SDL_Color{
            .a = 127,
            .r = 127,
            .g = 128,
            .b = 112,
        },
        .mDstRect = c.SDL_Rect{
            .x = 0,
            .y = 0,
            .w = 100,
            .h = 200,
        },
        .mTexture = undefined,
    });

    try drawingQueue.draw(2.3, dq.DrawingQueueOp{
        .mZdepth = undefined,
        .mAlpha = 100,
        .mAngle = 20,
        .mColor = c.SDL_Color{
            .a = 127,
            .r = 127,
            .g = 128,
            .b = 112,
        },
        .mDstRect = c.SDL_Rect{
            .x = 0,
            .y = 0,
            .w = 100,
            .h = 200,
        },
        .mTexture = undefined,
    });

    try drawingQueue.draw(3.3, dq.DrawingQueueOp{
        .mZdepth = undefined,
        .mAlpha = 100,
        .mAngle = 20,
        .mColor = c.SDL_Color{
            .a = 127,
            .r = 127,
            .g = 128,
            .b = 112,
        },
        .mDstRect = c.SDL_Rect{
            .x = 0,
            .y = 0,
            .w = 100,
            .h = 200,
        },
        .mTexture = undefined,
    });

    var iter = drawingQueue.getIterator();
    while (iter.next()) |entry| {
        std.debug.print("op => {d}\n", .{entry.mZdepth});
    }

    drawingQueue.clear();

    // try drawingQueue.draw(3.3, dq.DrawingQueueOp{
    //     .mZdepth = undefined,
    //     .mAlpha = 100,
    //     .mAngle = 20,
    //     .mColor = c.SDL_Color{
    //         .a = 127,
    //         .r = 127,
    //         .g = 128,
    //         .b = 112,
    //     },
    //     .mDstRect = c.SDL_Rect{
    //         .x = 0,
    //         .y = 0,
    //         .w = 100,
    //         .h = 200,
    //     },
    //     .mTexture = undefined,
    // });

    iter = drawingQueue.getIterator();
    while (iter.next()) |entry| {
        std.debug.print("op => {?}\n", .{entry});
    }

    // var w = Game{};
    // w.show();
}
