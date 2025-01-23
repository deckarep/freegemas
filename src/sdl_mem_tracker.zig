const std = @import("std");
const c = @import("cdefs.zig").c;

pub fn Stuff(comptime ChildFn: type) type {
    return struct {
        doIt: ChildFn = undefined,
        const Self = @This();

        pub fn init() Self {
            return Self{};
        }

        pub fn setHi(self: *Self, hiFn: ChildFn) void {
            self.doIt = hiFn;
        }

        pub fn call(self: Self, name: []const u8) void {
            self.doIt(name);
        }
    };
}

fn printCategory(name: []const u8, allocs: usize, frees: usize) void {
    const delta = @as(i32, @intCast(allocs)) - @as(i32, @intCast(frees));
    std.debug.print("{s}: {s}\n", .{ name, if (delta == 0) "✅" else "❌" });
    std.debug.print("  Allocs: {d}\n", .{allocs});
    std.debug.print("  Frees:  {d}\n", .{frees});
    std.debug.print("  Delta:  {d}\n\n", .{delta});
}

pub fn DumpReport() void {
    std.debug.print("\n", .{});

    // Fonts
    const fontAllocs = allocTTF_OpenFont;
    const fontFrees = freeTTF_CloseFont;
    printCategory("Fonts", fontAllocs, fontFrees);

    // Textures
    const textureAllocs = allocIMG_LoadTexture + allocSDL_CreateTextureFromSurface;
    const textureFrees = freeSDL_DestroyTexture;
    printCategory("Textures", textureAllocs, textureFrees);

    // Music
    const musicAllocs = allocMix_LoadMUS;
    const musicFrees = freeMix_FreeMusic;
    printCategory("Music", musicAllocs, musicFrees);

    // Waves
    const waveAllocs = allocMix_LoadWAV;
    const waveFrees = freeMix_FreeChunk;
    printCategory("Waves", waveAllocs, waveFrees);

    // Surfaces
    const surfaceAllocs =
        alloc_SDL_CreateRGBSurfaceWithFormat +
        allocTTF_RenderUTF8_Blended +
        allocTTF_RenderUTF8_Blended_Wrapped;
    const surfaceFrees = freeSDL_Surface;
    printCategory("Surfaces", surfaceAllocs, surfaceFrees);

    // Final Totals
    const totalAllocs = alloc;
    const totalFrees = free;
    const totalDelta = @as(i32, @intCast(totalAllocs)) - @as(i32, @intCast(totalFrees));

    std.debug.print("====== SDL Resource Management Summary ======\n", .{});
    std.debug.print("Total Allocations: {d}\n", .{totalAllocs});
    std.debug.print("Total Frees:       {d}\n", .{totalFrees});
    std.debug.print("Total Delta:       {d}\n", .{totalDelta});
}

var lock: std.Thread.Mutex = .{};
pub var txtrTracker: ?std.AutoHashMap(*c.SDL_Texture, usize) = undefined;

pub fn initMemTracker(gpa: std.mem.Allocator) void {
    if (txtrTracker == null) {
        txtrTracker = std.AutoHashMap(*c.SDL_Texture, usize).init(gpa);
    }
}

pub fn deinitMemTracker() void {
    // If all textures are accounted for and have been freed, this should always be zero.
    std.debug.assert(txtrTracker.?.count() == 0);
    txtrTracker.?.deinit();
}

var alloc: usize = 0;
var free: usize = 0;

var allocTTF_OpenFont: usize = 0;
var freeTTF_CloseFont: usize = 0;

pub inline fn TTF_OpenFont(file: [:0]const u8, ptsize: usize) ?*c.TTF_Font {
    alloc += 1;
    allocTTF_OpenFont += 1;
    return c.TTF_OpenFont(file, @intCast(ptsize));
}

pub inline fn TTF_CloseFont(font: ?*c.TTF_Font) void {
    free += 1;
    freeTTF_CloseFont += 1;
    c.TTF_CloseFont(font);
}

var allocIMG_LoadTexture: usize = 0;
var freeSDL_DestroyTexture: usize = 0;

pub inline fn IMG_LoadTexture(renderer: ?*c.SDL_Renderer, file: [:0]const u8) ?*c.SDL_Texture {
    alloc += 1;
    allocIMG_LoadTexture += 1;
    const txtr = c.IMG_LoadTexture(renderer, file);

    std.debug.assert(txtr != null);

    txtrTracker.?.put(txtr.?, @intFromPtr(txtr.?)) catch unreachable;
    return txtr;
}

pub inline fn SDL_DestroyTexture(texture: ?*c.SDL_Texture) void {
    std.debug.assert(texture != null);

    free += 1;
    freeSDL_DestroyTexture += 1;
    std.debug.assert(txtrTracker.?.remove(texture.?) == true);
    c.SDL_DestroyTexture(texture);
}

var allocMix_LoadMUS: usize = 0;
var freeMix_FreeMusic: usize = 0;

pub inline fn Mix_LoadMUS(file: [:0]const u8) ?*c.Mix_Music {
    alloc += 1;
    allocMix_LoadMUS += 1;
    return c.Mix_LoadMUS(file);
}

pub inline fn Mix_FreeMusic(sample: ?*c.Mix_Music) void {
    free += 1;
    freeMix_FreeMusic += 1;
    c.Mix_FreeMusic(sample);
}

var allocMix_LoadWAV: usize = 0;
var freeMix_FreeChunk: usize = 0;

pub inline fn Mix_LoadWAV(file: [:0]const u8) *c.Mix_Chunk {
    alloc += 1;
    allocMix_LoadWAV += 1;
    std.debug.print("c.Mix_LoadWAV({s})\n", .{file});
    return c.Mix_LoadWAV(file);
}

pub inline fn Mix_FreeChunk(sample: ?*c.Mix_Chunk) void {
    free += 1;
    freeMix_FreeChunk += 1;
    c.Mix_FreeChunk(sample);
}

var freeSDL_Surface: usize = 0;

pub inline fn SDL_FreeSurface(surface: ?*c.SDL_Surface) void {
    free += 1;
    freeSDL_Surface += 1;
    c.SDL_FreeSurface(surface);
}

var allocSDL_CreateTextureFromSurface: usize = 0;

pub inline fn SDL_CreateTextureFromSurface(renderer: ?*c.SDL_Renderer, surface: ?*c.SDL_Surface) ?*c.SDL_Texture {
    alloc += 1;
    allocSDL_CreateTextureFromSurface += 1;
    const txtr = c.SDL_CreateTextureFromSurface(renderer, surface);

    std.debug.assert(txtr != null);

    lock.lock();
    defer lock.unlock();
    txtrTracker.?.put(txtr.?, @intFromPtr(txtr.?)) catch unreachable;

    return txtr;
}

var alloc_SDL_CreateRGBSurfaceWithFormat: usize = 0;

pub inline fn SDL_CreateRGBSurfaceWithFormat(flags: u32, width: i32, height: i32, depth: i32, format: u32) *c.SDL_Surface {
    alloc += 1;
    alloc_SDL_CreateRGBSurfaceWithFormat += 1;
    return c.SDL_CreateRGBSurfaceWithFormat(flags, width, height, depth, format);
}

var allocTTF_RenderUTF8_Blended: usize = 0;

pub inline fn TTF_RenderUTF8_Blended(renderer: ?*c.TTF_Font, text: [:0]const u8, fg: c.SDL_Color) *c.SDL_Surface {
    alloc += 1;
    allocTTF_RenderUTF8_Blended += 1;
    return c.TTF_RenderUTF8_Blended(renderer, text, fg);
}

var allocTTF_RenderUTF8_Blended_Wrapped: usize = 0;

pub inline fn TTF_RenderUTF8_Blended_Wrapped(renderer: ?*c.TTF_Font, text: [:0]const u8, fg: c.SDL_Color, wrapLen: u32) *c.SDL_Surface {
    alloc += 1;
    allocTTF_RenderUTF8_Blended_Wrapped += 1;
    return c.TTF_RenderUTF8_Blended_Wrapped(renderer, text, fg, wrapLen);
}
