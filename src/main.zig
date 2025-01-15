const std = @import("std");
const glConsts = @import("global_consts.zig");
const goWin = @import("go_window.zig");
const c = @import("cdefs.zig").c;
const trkr = @import("sdl_mem_tracker.zig");
const sa = @import("sdl_scoped_allocator.zig");

// var gpa = std.heap.GeneralPurposeAllocator(.{
//     .safety = true,
//     .verbose_log = true,
// }){};
// const alloc = gpa.allocator();

// // Stores a mapping of pointers => requested size.
// var metadata = std.AutoHashMap(usize, usize).init(alloc);

// fn myMalloc(size: usize) callconv(.C) ?*anyopaque {
//     std.debug.print("myMalloc(size:{d}), metadata count: {d}\n", .{ size, metadata.count() });
//     const memBlock = alloc.alloc(u8, size) catch return null;
//     const intPtr = @intFromPtr(memBlock.ptr);
//     metadata.put(intPtr, size) catch return null;
//     return memBlock.ptr;
// }

// fn myCalloc(num: usize, size: usize) callconv(.C) ?*anyopaque {
//     std.debug.print("myCalloc(num:{d}, size:{d}, metadata count: {d})\n", .{ num, size, metadata.count() });

//     // Calloc has a slightly differing signature than malloc so we must multiply: num * size, to compute how many bytes
//     // are actually requested.
//     const computedBytes = num * size;
//     const memBlock = alloc.alloc(u8, computedBytes) catch return null;
//     // Zero out that shit.
//     for (memBlock) |*b| {
//         b.* = 0;
//     }
//     const intPtr = @intFromPtr(memBlock.ptr);
//     metadata.put(intPtr, computedBytes) catch return null;
//     return memBlock.ptr;
// }

// fn myRealloc(ptr: ?*anyopaque, size: usize) callconv(.C) ?*anyopaque {
//     if (ptr) |p| {
//         std.debug.print("myRealloc(ptr:{*}, size:{d}, metadata count: {d})\n", .{ p, size, metadata.count() });

//         const intPtr = @intFromPtr(p);
//         const originalSize = metadata.get(intPtr);
//         if (originalSize == null) {
//             @panic("ptr has unknown to metadata");
//         } else {
//             if (size == originalSize.?) {
//                 // Size is unchanged, return the same pointer.
//                 return p;
//             } else if (size > originalSize.?) {
//                 // Allocate a larger block
//                 const newBlock = myMalloc(size);
//                 if (newBlock == null) {
//                     return null;
//                 }
//                 const oldSlice = @as([*]u8, @ptrCast(p))[0..originalSize.?];
//                 const newSlice = @as([*]u8, @ptrCast(newBlock))[0..originalSize.?];
//                 @memcpy(newSlice, oldSlice);
//                 myFree(p); // Free the old block
//                 return newBlock;
//             } else {
//                 // NOTE: This is not as efficient as normal code because this code is always
//                 // allocating instead of just chopping off some tail portion of the original
//                 // memory block. Zig's GPA does not let us do this and always wants to only
//                 // ever free the head pointer. Maybe there is a way to make this work?
//                 const newBlock = myMalloc(size);
//                 if (newBlock == null) {
//                     return null;
//                 }
//                 const oldSlice = @as([*]u8, @ptrCast(p))[0..size];
//                 const newSlice = @as([*]u8, @ptrCast(newBlock))[0..size];
//                 @memcpy(newSlice, oldSlice);
//                 myFree(p); // Free the old block
//                 return newBlock;
//             }
//         }
//     }

//     // Accoridng to docs, if the ptr is null it's the same as just calling malloc(new_size)
//     // So for now, just dispatch to that call.
//     return myMalloc(size);
// }

// fn myFree(memBlock: ?*anyopaque) callconv(.C) void {
//     std.debug.assert(memBlock != null);

//     const intPtr = @intFromPtr(memBlock.?);
//     const size = metadata.get(intPtr).?;
//     std.debug.print("myFree(ptr:{*}, bytes: {d}, metadata count:{d})\n", .{ memBlock.?, size, metadata.count() });
//     defer {
//         const ok = metadata.remove(intPtr);
//         std.debug.assert(ok);
//     }
//     const slice: [*]u8 = @ptrCast(memBlock.?);
//     alloc.free(slice[0..size]);
// }

var scopedAllocator = sa.ScopedAllocator.init();

pub fn main() !void {
    try scopedAllocator.setup();
    defer scopedAllocator.wrappedReport();

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
