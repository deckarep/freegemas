const std = @import("std");
const c = @import("cdefs.zig").c;

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
    const fontAllocs = allocTTF_OpenFont.load(.acquire);
    const fontFrees = freeTTF_CloseFont.load(.acquire);
    printCategory("Fonts", fontAllocs, fontFrees);

    // Textures
    const textureAllocs = allocIMG_LoadTexture.load(.acquire) + allocSDL_CreateTextureFromSurface.load(.acquire);
    const textureFrees = freeSDL_DestroyTexture.load(.acquire);
    printCategory("Textures", textureAllocs, textureFrees);

    // Music
    const musicAllocs = allocMix_LoadMUS.load(.acquire);
    const musicFrees = freeMix_FreeMusic.load(.acquire);
    printCategory("Music", musicAllocs, musicFrees);

    // Waves
    const waveAllocs = allocMix_LoadWAV.load(.acquire);
    const waveFrees = freeMix_FreeChunk.load(.acquire);
    printCategory("Waves", waveAllocs, waveFrees);

    // Surfaces
    const surfaceAllocs =
        alloc_SDL_CreateRGBSurfaceWithFormat.load(.acquire) +
        allocTTF_RenderUTF8_Blended.load(.acquire) +
        allocTTF_RenderUTF8_Blended_Wrapped.load(.acquire);
    const surfaceFrees = freeSDL_Surface.load(.acquire);
    printCategory("Surfaces", surfaceAllocs, surfaceFrees);

    // Final Totals
    const totalAllocs = alloc.load(.seq_cst);
    const totalFrees = free.load(.seq_cst);
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
    std.debug.assert(txtrTracker.?.count() == 0);
    txtrTracker.?.deinit();
}

var alloc = std.atomic.Value(usize).init(0);
var free = std.atomic.Value(usize).init(0);

var allocTTF_OpenFont = std.atomic.Value(usize).init(0);
var freeTTF_CloseFont = std.atomic.Value(usize).init(0);

pub inline fn TTF_OpenFont(file: [:0]const u8, ptsize: usize) ?*c.TTF_Font {
    _ = alloc.fetchAdd(1, .monotonic);
    _ = allocTTF_OpenFont.fetchAdd(1, .monotonic);
    return c.TTF_OpenFont(file, @intCast(ptsize));
}

pub inline fn TTF_CloseFont(font: ?*c.TTF_Font) void {
    _ = free.fetchAdd(1, .monotonic);
    _ = freeTTF_CloseFont.fetchAdd(1, .monotonic);
    c.TTF_CloseFont(font);
}

var allocIMG_LoadTexture = std.atomic.Value(usize).init(0);
var freeSDL_DestroyTexture = std.atomic.Value(usize).init(0);

pub inline fn IMG_LoadTexture(renderer: ?*c.SDL_Renderer, file: [:0]const u8) ?*c.SDL_Texture {
    _ = alloc.fetchAdd(1, .monotonic);
    _ = allocIMG_LoadTexture.fetchAdd(1, .monotonic);
    const txtr = c.IMG_LoadTexture(renderer, file);

    std.debug.assert(txtr != null);

    txtrTracker.?.put(txtr.?, @intFromPtr(txtr.?)) catch unreachable;
    return txtr;
}

pub inline fn SDL_DestroyTexture(texture: ?*c.SDL_Texture) void {
    std.debug.assert(texture != null);

    _ = free.fetchAdd(1, .monotonic);
    _ = freeSDL_DestroyTexture.fetchAdd(1, .monotonic);
    std.debug.assert(txtrTracker.?.remove(texture.?) == true);
    c.SDL_DestroyTexture(texture);
}

var allocMix_LoadMUS = std.atomic.Value(usize).init(0);
var freeMix_FreeMusic = std.atomic.Value(usize).init(0);

pub inline fn Mix_LoadMUS(file: [:0]const u8) ?*c.Mix_Music {
    _ = alloc.fetchAdd(1, .monotonic);
    _ = allocMix_LoadMUS.fetchAdd(1, .monotonic);
    return c.Mix_LoadMUS(file);
}

pub inline fn Mix_FreeMusic(sample: ?*c.Mix_Music) void {
    _ = free.fetchAdd(1, .monotonic);
    _ = freeMix_FreeMusic.fetchAdd(1, .monotonic);
    c.Mix_FreeMusic(sample);
}

var allocMix_LoadWAV = std.atomic.Value(usize).init(0);
var freeMix_FreeChunk = std.atomic.Value(usize).init(0);

pub inline fn Mix_LoadWAV(file: [:0]const u8) *c.Mix_Chunk {
    _ = alloc.fetchAdd(1, .monotonic);
    _ = allocMix_LoadWAV.fetchAdd(1, .monotonic);
    std.debug.print("c.Mix_LoadWAV({s})\n", .{file});
    return c.Mix_LoadWAV(file);
}

pub inline fn Mix_FreeChunk(sample: ?*c.Mix_Chunk) void {
    _ = free.fetchAdd(1, .monotonic);
    _ = freeMix_FreeChunk.fetchAdd(1, .monotonic);
    c.Mix_FreeChunk(sample);
}

var freeSDL_Surface = std.atomic.Value(usize).init(0);

pub inline fn SDL_FreeSurface(surface: ?*c.SDL_Surface) void {
    _ = free.fetchAdd(1, .monotonic);
    _ = freeSDL_Surface.fetchAdd(1, .monotonic);
    c.SDL_FreeSurface(surface);
}

var allocSDL_CreateTextureFromSurface = std.atomic.Value(usize).init(0);

pub inline fn SDL_CreateTextureFromSurface(renderer: ?*c.SDL_Renderer, surface: ?*c.SDL_Surface) ?*c.SDL_Texture {
    _ = alloc.fetchAdd(1, .monotonic);
    _ = allocSDL_CreateTextureFromSurface.fetchAdd(1, .monotonic);
    const txtr = c.SDL_CreateTextureFromSurface(renderer, surface);

    std.debug.assert(txtr != null);

    lock.lock();
    defer lock.unlock();
    txtrTracker.?.put(txtr.?, @intFromPtr(txtr.?)) catch unreachable;

    return txtr;
}

var alloc_SDL_CreateRGBSurfaceWithFormat = std.atomic.Value(usize).init(0);

pub inline fn SDL_CreateRGBSurfaceWithFormat(flags: u32, width: i32, height: i32, depth: i32, format: u32) *c.SDL_Surface {
    _ = alloc.fetchAdd(1, .monotonic);
    _ = alloc_SDL_CreateRGBSurfaceWithFormat.fetchAdd(1, .monotonic);
    return c.SDL_CreateRGBSurfaceWithFormat(flags, width, height, depth, format);
}

var allocTTF_RenderUTF8_Blended = std.atomic.Value(usize).init(0);

pub inline fn TTF_RenderUTF8_Blended(renderer: ?*c.TTF_Font, text: [:0]const u8, fg: c.SDL_Color) *c.SDL_Surface {
    _ = alloc.fetchAdd(1, .monotonic);
    _ = allocTTF_RenderUTF8_Blended.fetchAdd(1, .monotonic);
    return c.TTF_RenderUTF8_Blended(renderer, text, fg);
}

var allocTTF_RenderUTF8_Blended_Wrapped = std.atomic.Value(usize).init(0);

pub inline fn TTF_RenderUTF8_Blended_Wrapped(renderer: ?*c.TTF_Font, text: [:0]const u8, fg: c.SDL_Color, wrapLen: u32) *c.SDL_Surface {
    _ = alloc.fetchAdd(1, .monotonic);
    _ = allocTTF_RenderUTF8_Blended_Wrapped.fetchAdd(1, .monotonic);
    return c.TTF_RenderUTF8_Blended_Wrapped(renderer, text, fg, wrapLen);
}
