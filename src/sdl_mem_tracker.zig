const std = @import("std");
const c = @import("cdefs.zig").c;

var gTracker: *SDLMemoryTracker = undefined;

pub const Stats = struct {
    alloc: usize = 0,
    free: usize = 0,

    allocTTF_OpenFont: usize = 0,
    freeTTF_CloseFont: usize = 0,

    allocIMG_LoadTexture: usize = 0,
    freeSDL_DestroyTexture: usize = 0,

    allocMix_LoadMUS: usize = 0,
    freeMix_FreeMusic: usize = 0,

    allocMix_LoadWAV: usize = 0,
    freeMix_FreeChunk: usize = 0,

    freeSDL_Surface: usize = 0,
    allocSDL_CreateTextureFromSurface: usize = 0,
    alloc_SDL_CreateRGBSurfaceWithFormat: usize = 0,

    allocTTF_RenderUTF8_Blended: usize = 0,
    allocTTF_RenderUTF8_Blended_Wrapped: usize = 0,
};

pub const SDLMemoryTracker = struct {
    allocator: std.mem.Allocator,

    stats: Stats = Stats{},

    retAddress: ?usize = null,
    stackTraces: std.AutoHashMap(usize, std.builtin.StackTrace),
    maxStackSize: usize,

    const Self = @This();

    pub fn init(gpa: std.mem.Allocator, stackSize: usize) Self {
        return Self{
            .allocator = gpa,
            .maxStackSize = stackSize,
            .stackTraces = std.AutoHashMap(usize, std.builtin.StackTrace).init(gpa),
        };
    }

    pub fn install(self: *Self) void {
        gTracker = self;
    }

    pub fn deinit(self: *Self) void {
        defer {
            gTracker = undefined;
            self.stackTraces.deinit();
        }

        // 1. Report on unaccounted for leaks.
        const leakCount = self.stackTraces.count();
        if (leakCount > 0) {
            std.debug.print("Found: {d} SDL Resource leaks!\n", .{leakCount});
            std.debug.print("==============================\n", .{});

            var iter = self.stackTraces.iterator();
            var counter: usize = 0;
            while (iter.next()) |entry| {
                std.debug.print("Leak occurance: {d} of {d}\n", .{ counter + 1, leakCount });
                std.debug.print("=========================\n", .{});
                const key = entry.key_ptr.*;
                const stackTrace = self.stackTraces.get(key).?;
                std.debug.dumpStackTrace(stackTrace);

                // Free the stack trace sitting on the heap.
                self.allocator.free(stackTrace.instruction_addresses);
                counter += 1;
            }
        }
    }

    fn printCategory(self: Self, name: []const u8, allocs: usize, frees: usize) void {
        _ = self;
        const delta = @as(i32, @intCast(allocs)) - @as(i32, @intCast(frees));
        std.debug.print("{s} {s}:\n", .{ if (delta == 0) "✅" else "❌", name });
        std.debug.print("  Allocs: {d}\n", .{allocs});
        std.debug.print("  Frees:  {d}\n", .{frees});
        std.debug.print("  Delta:  {d}\n\n", .{delta});
    }

    pub fn DumpReport(self: Self) void {
        std.debug.print("\n", .{});

        // Fonts
        const fontAllocs = self.stats.allocTTF_OpenFont;
        const fontFrees = self.stats.freeTTF_CloseFont;
        self.printCategory("Fonts", fontAllocs, fontFrees);

        // Textures
        const textureAllocs = self.stats.allocIMG_LoadTexture + self.stats.allocSDL_CreateTextureFromSurface;
        const textureFrees = self.stats.freeSDL_DestroyTexture;
        self.printCategory("Textures", textureAllocs, textureFrees);

        // Music
        const musicAllocs = self.stats.allocMix_LoadMUS;
        const musicFrees = self.stats.freeMix_FreeMusic;
        self.printCategory("Music", musicAllocs, musicFrees);

        // Waves
        const waveAllocs = self.stats.allocMix_LoadWAV;
        const waveFrees = self.stats.freeMix_FreeChunk;
        self.printCategory("Waves", waveAllocs, waveFrees);

        // Surfaces
        const surfaceAllocs =
            self.stats.alloc_SDL_CreateRGBSurfaceWithFormat +
            self.stats.allocTTF_RenderUTF8_Blended +
            self.stats.allocTTF_RenderUTF8_Blended_Wrapped;
        const surfaceFrees = self.stats.freeSDL_Surface;
        self.printCategory("Surfaces", surfaceAllocs, surfaceFrees);

        // Final Totals
        const totalAllocs = self.stats.alloc;
        const totalFrees = self.stats.free;
        const totalDelta = @as(i32, @intCast(totalAllocs)) - @as(i32, @intCast(totalFrees));

        std.debug.print("====== SDL Resource Management Summary ======\n", .{});
        std.debug.print("Total Allocations: {d}\n", .{totalAllocs});

        std.debug.print("Total Frees:       {d}\n", .{totalFrees});
        std.debug.print("Total Delta:       {d}\n", .{totalDelta});
    }

    fn acquireStackTrace(self: *Self, ptr: *anyopaque) void {
        const addresses = self.allocator.alloc(usize, self.maxStackSize) catch return;
        @memset(addresses, 0);

        var stackTrace = std.builtin.StackTrace{
            .instruction_addresses = addresses,
            .index = 0,
        };

        std.debug.captureStackTrace(gTracker.retAddress, &stackTrace);

        const intPtr = @intFromPtr(ptr);
        self.stackTraces.put(intPtr, stackTrace) catch return;
    }

    // fn originalAcquireStackTrace(self: *Self, ptr: *anyopaque) void {
    //     // This needs to be reset after its used...just in case a wrapped
    //     // function that we're tracking fails to set it.
    //     defer self.retAddress = null;

    //     // TODO: dedup stacktraces, and just record a count everytime the
    //     // same stacktrace is seen.

    //     // 1. This line below just dumps to stderr output, with no control.
    //     // std.debug.dumpCurrentStackTrace(null);

    //     // 2. This, dumps to an ArrayList that we can inspect!
    //     // We can look for any needles in the haystack as necessary to identify stacktraces
    //     // that we want to look for.
    //     var list = std.ArrayList(u8).initCapacity(
    //         self.allocator,
    //         1024 * 4,
    //     ) catch return;
    //     defer list.deinit();

    //     const writer = list.writer();
    //     const debugInfo = std.debug.getSelfDebugInfo() catch return;
    //     std.debug.writeCurrentStackTrace(
    //         writer,
    //         debugInfo,
    //         .no_color,
    //         if (self.retAddress == null) @returnAddress() else self.retAddress.?,
    //     ) catch return;

    //     const intPtr = @intFromPtr(ptr);
    //     self.stackTraces.put(intPtr, list.toOwnedSlice() catch return) catch return;
    // }

    fn releaseStackTrace(self: *Self, ptr: *anyopaque) void {
        if (self.stackTraces.fetchRemove(@intFromPtr(ptr))) |entry| {
            self.allocator.free(entry.value.instruction_addresses);
        } else {
            @panic("Attempt to release a StackTrace for unknown ptr!");
        }
    }

    pub fn TTF_OpenFont(self: *Self, file: [:0]const u8, ptsize: usize) ?*c.TTF_Font {
        self.stats.alloc += 1;
        self.stats.allocTTF_OpenFont += 1;

        if (c.TTF_OpenFont(file, @intCast(ptsize))) |fnt| {
            self.acquireStackTrace(fnt);
            return fnt;
        }

        return null;
    }

    pub fn TTF_CloseFont(self: *Self, font: ?*c.TTF_Font) void {
        if (font) |fnt| {
            self.stats.free += 1;
            self.stats.freeTTF_CloseFont += 1;

            self.releaseStackTrace(fnt);
            c.TTF_CloseFont(fnt);
        }
    }

    pub fn IMG_LoadTexture(self: *Self, renderer: ?*c.SDL_Renderer, file: [:0]const u8) ?*c.SDL_Texture {
        self.stats.alloc += 1;
        self.stats.allocIMG_LoadTexture += 1;

        const txtr = c.IMG_LoadTexture(renderer, file);

        std.debug.assert(txtr != null);

        self.acquireStackTrace(txtr.?);
        return txtr;
    }

    pub fn SDL_DestroyTexture(self: *Self, texture: ?*c.SDL_Texture) void {
        std.debug.assert(texture != null);

        self.stats.free += 1;
        self.stats.freeSDL_DestroyTexture += 1;

        c.SDL_DestroyTexture(texture);
        self.releaseStackTrace(texture.?);
    }

    pub fn Mix_LoadMUS(self: *Self, file: [:0]const u8) ?*c.Mix_Music {
        self.stats.alloc += 1;
        self.stats.allocMix_LoadMUS += 1;

        const mus = c.Mix_LoadMUS(file);
        std.debug.assert(mus != null);
        self.acquireStackTrace(mus.?);
        return mus;
    }

    pub fn Mix_FreeMusic(self: *Self, sample: ?*c.Mix_Music) void {
        self.stats.free += 1;
        self.stats.freeMix_FreeMusic += 1;

        c.Mix_FreeMusic(sample);
        self.releaseStackTrace(sample.?);
    }

    pub fn Mix_LoadWAV(self: *Self, file: [:0]const u8) *c.Mix_Chunk {
        self.stats.alloc += 1;
        self.stats.allocMix_LoadWAV += 1;

        const wav = c.Mix_LoadWAV(file);
        self.acquireStackTrace(wav);
        return wav;
    }

    pub fn Mix_FreeChunk(self: *Self, sample: ?*c.Mix_Chunk) void {
        if (sample) |samp| {
            self.stats.free += 1;
            self.stats.freeMix_FreeChunk += 1;
            c.Mix_FreeChunk(samp);
            self.releaseStackTrace(samp);
        }
    }

    pub fn SDL_FreeSurface(self: *Self, surface: ?*c.SDL_Surface) void {
        if (surface) |surf| {
            self.stats.free += 1;
            self.stats.freeSDL_Surface += 1;

            c.SDL_FreeSurface(surf);
            self.releaseStackTrace(surf);
        }
    }

    pub fn SDL_CreateTextureFromSurface(self: *Self, renderer: ?*c.SDL_Renderer, surface: ?*c.SDL_Surface) ?*c.SDL_Texture {
        self.stats.alloc += 1;
        self.stats.allocSDL_CreateTextureFromSurface += 1;
        const txtr = c.SDL_CreateTextureFromSurface(renderer, surface);

        std.debug.assert(txtr != null);

        self.acquireStackTrace(txtr.?);
        return txtr;
    }

    pub fn SDL_CreateRGBSurfaceWithFormat(self: *Self, flags: u32, width: i32, height: i32, depth: i32, format: u32) *c.SDL_Surface {
        self.stats.alloc += 1;
        self.stats.alloc_SDL_CreateRGBSurfaceWithFormat += 1;

        const surface = c.SDL_CreateRGBSurfaceWithFormat(flags, width, height, depth, format);
        self.acquireStackTrace(surface);
        return surface;
    }

    pub fn TTF_RenderUTF8_Blended(self: *Self, renderer: ?*c.TTF_Font, text: [:0]const u8, fg: c.SDL_Color) *c.SDL_Surface {
        self.stats.alloc += 1;
        self.stats.allocTTF_RenderUTF8_Blended += 1;

        const surface = c.TTF_RenderUTF8_Blended(renderer, text, fg);
        self.acquireStackTrace(surface);
        return surface;
    }

    pub fn TTF_RenderUTF8_Blended_Wrapped(self: *Self, renderer: ?*c.TTF_Font, text: [:0]const u8, fg: c.SDL_Color, wrapLen: u32) *c.SDL_Surface {
        self.stats.alloc += 1;
        self.stats.allocTTF_RenderUTF8_Blended_Wrapped += 1;

        const surface = c.TTF_RenderUTF8_Blended_Wrapped(renderer, text, fg, wrapLen);
        self.acquireStackTrace(surface);
        return surface;
    }
};

pub fn TTF_OpenFont(file: [:0]const u8, ptsize: usize) ?*c.TTF_Font {
    gTracker.retAddress = @returnAddress();

    // var addresses: [5]usize = undefined;
    // @memset(&addresses, 0);
    // var stackTrace = std.builtin.StackTrace{
    //     .instruction_addresses = &addresses,
    //     .index = 0,
    // };
    //std.debug.captureStackTrace(gTracker.retAddress, &stackTrace);

    // for (addresses) |num| {
    //     std.debug.print("address => {0x}\n", .{num});
    // }

    // std.debug.dumpStackTrace(stackTrace);
    // std.process.exit(0);
    return gTracker.TTF_OpenFont(file, ptsize);
}

pub fn TTF_CloseFont(font: ?*c.TTF_Font) void {
    gTracker.retAddress = @returnAddress();
    return gTracker.TTF_CloseFont(font);
}

pub fn IMG_LoadTexture(renderer: ?*c.SDL_Renderer, file: [:0]const u8) ?*c.SDL_Texture {
    gTracker.retAddress = @returnAddress();
    return gTracker.IMG_LoadTexture(renderer, file);
}

pub fn SDL_DestroyTexture(texture: ?*c.SDL_Texture) void {
    gTracker.retAddress = @returnAddress();
    return gTracker.SDL_DestroyTexture(texture);
}

pub fn Mix_LoadMUS(file: [:0]const u8) ?*c.Mix_Music {
    gTracker.retAddress = @returnAddress();
    return gTracker.Mix_LoadMUS(file);
}

pub fn Mix_FreeMusic(sample: ?*c.Mix_Music) void {
    gTracker.retAddress = @returnAddress();
    return gTracker.Mix_FreeMusic(sample);
}

pub fn Mix_LoadWAV(file: [:0]const u8) *c.Mix_Chunk {
    gTracker.retAddress = @returnAddress();
    return gTracker.Mix_LoadWAV(file);
}

pub fn Mix_FreeChunk(sample: ?*c.Mix_Chunk) void {
    gTracker.retAddress = @returnAddress();
    return gTracker.Mix_FreeChunk(sample);
}

pub fn SDL_FreeSurface(surface: ?*c.SDL_Surface) void {
    gTracker.retAddress = @returnAddress();
    return gTracker.SDL_FreeSurface(surface);
}

pub fn SDL_CreateTextureFromSurface(renderer: ?*c.SDL_Renderer, surface: ?*c.SDL_Surface) ?*c.SDL_Texture {
    gTracker.retAddress = @returnAddress();

    return gTracker.SDL_CreateTextureFromSurface(renderer, surface);
}

pub fn SDL_CreateRGBSurfaceWithFormat(flags: u32, width: i32, height: i32, depth: i32, format: u32) *c.SDL_Surface {
    gTracker.retAddress = @returnAddress();
    return gTracker.SDL_CreateRGBSurfaceWithFormat(flags, width, height, depth, format);
}

pub fn TTF_RenderUTF8_Blended(renderer: ?*c.TTF_Font, text: [:0]const u8, fg: c.SDL_Color) *c.SDL_Surface {
    gTracker.retAddress = @returnAddress();
    return gTracker.TTF_RenderUTF8_Blended(renderer, text, fg);
}

pub fn TTF_RenderUTF8_Blended_Wrapped(renderer: ?*c.TTF_Font, text: [:0]const u8, fg: c.SDL_Color, wrapLen: u32) *c.SDL_Surface {
    gTracker.retAddress = @returnAddress();
    return gTracker.TTF_RenderUTF8_Blended_Wrapped(renderer, text, fg, wrapLen);
}

// pub fn Stuff(comptime ChildFn: type) type {
//     return struct {
//         doIt: ChildFn = undefined,
//         const Self = @This();

//         pub fn init() Self {
//             return Self{};
//         }

//         pub fn setHi(self: *Self, hiFn: ChildFn) void {
//             self.doIt = hiFn;
//         }

//         pub fn call(self: Self, name: []const u8) void {
//             self.doIt(name);
//         }
//     };
// }
