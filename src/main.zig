const std = @import("std");
const glConsts = @import("global_consts.zig");
const goWin = @import("go_window.zig");
const c = @import("cdefs.zig").c;
const trkr = @import("sdl_mem_tracker.zig");
const sa = @import("sdl_scoped_allocator.zig");

var scopedAllocator = sa.ScopedAllocator.init();
pub fn main() !void {
    try scopedAllocator.setup();
    defer scopedAllocator.wrappedReport();
    try startGame();
}

fn startGame() !void {
    const cMemInter = scopedAllocator.getMemoryInterface();
    if (false) {
        // Setup SDL to use our custom scoped functions.
        const res = c.SDL_SetMemoryFunctions(
            cMemInter.malloc,
            cMemInter.calloc,
            cMemInter.realloc,
            cMemInter.free,
        );

        if (res != 0) {
            std.log.err("SDL_SetMemoryFunctions err: {s}\n", .{std.mem.span(c.SDL_GetError())});
            @panic("failed to shim SDL memory funcs!");
        }
    }

    //@panic("Question, can you nest GPA, such that you can take baseline snapshots of when to check for leaks?")
    trkr.initMemTracker(scopedAllocator.allocator());

    // NOTE: we still are leaking memory even though it looks like we're not.
    // When SDL is shutdown, all textures, surfaces are reclaimed even if the dev didn't do a good job.
    // But, for example when I do a time-trial I can clearly see textures/resources being leaks on countain
    // because the metadata goes up by 1 every single second of the clock!
    // https://wiki.libsdl.org/SDL2/SDL_SetMemoryFunctions
    // const res = c.SDL_SetMemoryFunctions(
    //     myMalloc,
    //     myCalloc,
    //     myRealloc,
    //     myFree,
    // );

    // if (res != 0) {
    //     std.debug.print("SDL_SetMemoryFunctions err: {s}\n", .{std.mem.span(c.SDL_GetError())});
    //     return;
    // }

    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});
    defer trkr.DumpReport();

    defer scopedAllocator.deinit();
    defer sa.mapping.deinit();
    // defer {
    //     const deinit_status = gpa.deinit();
    //     if (deinit_status == .leak) {
    //         std.debug.print("leaks detected; you lack discipline!", .{});
    //     }
    // }

    defer trkr.deinitMemTracker();
    defer sa.metadata.deinit();

    var w = try goWin.GoWindow.init(
        glConsts.App.WINDOW_WIDTH,
        glConsts.App.WINDOW_HEIGHT,
        "The Lampseller's Revenge: Old Lamps for New by @deckarep",
        glConsts.App.UPDATE_INTERVAL,
        &scopedAllocator,
    );
    try w.setup();
    try w.show();

    // Cross reference whatever is left
    var txtrIter = trkr.txtrTracker.?.iterator();
    while (txtrIter.next()) |entry| {
        const txtrIntPtr = @intFromPtr(entry.key_ptr.*);
        if (sa.metadata.contains(txtrIntPtr)) {
            var width: c_int = undefined;
            var height: c_int = undefined;
            _ = c.SDL_QueryTexture(entry.key_ptr.*, null, null, &width, &height);

            if (width == 65 and height == 65) continue;
            if (width == 38 and height == 38) continue;
            std.debug.print("Found texture unaccounted for: {*} => ({d}w, {d}h)\n", .{ entry.key_ptr.*, width, height });
        }
    }
    //std.process.exit(0);

    std.debug.print("Metadata count before goWindow.deinit => {d}\n", .{sa.metadata.count()});

    w.deinit();
}
