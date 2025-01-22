const std = @import("std");
const c = @import("cdefs.zig").c;
const trkr = @import("sdl_mem_tracker.zig");

var cacheInitialized: bool = false;
var cacheLoaderInstance: CacheLoader = undefined;

pub fn initCacheLoader(gpa: std.mem.Allocator) void {
    cacheLoaderInstance = CacheLoader.init(gpa);
    cacheInitialized = true;
}

pub fn getCacheLoader() *CacheLoader {
    // This must always return true!
    std.debug.assert(cacheInitialized);
    return &cacheLoaderInstance;
}

const CacheObject = struct {
    // TODO: Makes more sense for everything to start with a 1 because the math works.
    // 1 - means one reference is out in the wild.
    // 0 - means, no more references, safe to destroy.
    count: usize = 0,
    data: *anyopaque,
};

/// The CacheLoader should eventually become the gateway to ALL SDL asset loading no matter what.
/// This will ensure that repeated loads of the same resource are just loaded once and destroyed
/// once. The CacheLoader additionally will help with catching memory leaks because if the
/// game shutsdown and items are still in the cache, this means not everything has been .deinited
/// as it should!
/// TODO: Fonts but a unique font should be both the (filepath, size) of the font requested.
pub const CacheLoader = struct {
    gpa: std.mem.Allocator,
    cache: std.StringHashMap(CacheObject),

    const Self = @This();

    pub fn init(gpa: std.mem.Allocator) Self {
        return Self{
            .gpa = gpa,
            .cache = std.StringHashMap(CacheObject).init(gpa),
        };
    }

    pub fn deinit(self: *Self) void {
        //std.debug.assert(self.cache.count() == 0);
        if (self.cache.count() != 0) {
            std.log.warn("Hey your CACHE IS NOT EMPTY: and has {d} items left in it!", .{self.cache.count()});
        }
        // TODO: still, iterate and release all resources of course.
        // ACTUALLY - upon shutdown, all Destory functions should have already been
        // called, and the cache should be empty to be correct.

        var iter = self.cache.iterator();
        while (iter.next()) |nxt| {
            std.debug.print("cache key still alive after exiting: \n  => {s}\n", .{nxt.key_ptr.*});
        }
        self.cache.deinit();
    }

    fn incRefCountForKey(self: *Self, key: []const u8) void {
        // Bump reference count with a mutable ptr to CacheObject.
        var cacheObjPtr = self.cache.getPtr(key).?;
        cacheObjPtr.count += 1;
    }

    fn decRefCountForKey(self: *Self, key: []const u8) bool {
        // If we're not at 0, just decrement the reference count.
        var cacheObjPtr = self.cache.getPtr(key).?;
        if (cacheObjPtr.count > 1) {
            cacheObjPtr.count -= 1;
            // NOTE: decrementing the reference count counts as a valid Destroy.
            return true;
        }
        // This means we're bottomed out at this point.
        return false;
    }

    /// This function loads fonts but ensures that a uniquely cached font
    /// is discriminated by: (path::size). So if I load fontA, 12 and fontA, 16
    /// The cache must have two entries by treating them as differing fonts.
    pub fn LoadFont(self: *Self, path: [:0]const u8, size: usize) !?*c.TTF_Font {
        // NOTE: a font key of (path::size) is considered a unique font, so this becomes
        // our font key.
        var buf: [128]u8 = undefined;
        const fontKey = try std.fmt.bufPrintZ(&buf, "{s}::{d}", .{ path, size });

        if (self.cache.contains(fontKey)) {
            self.incRefCountForKey(path);
            // Object already cached, so just return it.
            std.debug.print("font: {s} already loaded yay!\n", .{fontKey});
            return @alignCast(@ptrCast(self.cache.get(fontKey).?.data));
        }

        const font = trkr.TTF_OpenFont(path, size);
        if (font == null) return null;

        // Take an owned copy of the key for safety, since the passed in path could
        // be stack allocated!!!
        const ownedKey = try self.gpa.dupe(u8, fontKey);
        try self.cache.put(ownedKey, CacheObject{ .data = font.?, .count = 1 });

        return font;
    }

    pub fn DestroyFont(self: *Self, font: *c.TTF_Font) void {
        // For now, just iterate to find the item.
        var iter = self.cache.iterator();
        var whichKey: ?[]const u8 = null;
        while (iter.next()) |entry| {
            if (@as(*anyopaque, @alignCast(@ptrCast(font))) == entry.value_ptr.*.data) {
                whichKey = entry.key_ptr.*;
            }
        }

        // NOTE: This can occur if you attempt to load the same asset multiple times.
        // Any subsequent destroy calls will be a NOP as expected.
        if (whichKey == null) {
            // NOTE: if no key was found, the font in question is unknown to the cache.
            // But we still free it, otherwise it's a legit leak. This can occur when the
            // the font was not created from LoadFont but something else.

            // As it stands, we can end up with a free count that is higher than alloc count.

            trkr.TTF_CloseFont(font);
            return;
        }

        if (self.decRefCountForKey(whichKey.?)) {
            // We're done for now.
            return;
        }

        // Destroy the font.
        trkr.TTF_CloseFont(font);

        // Remove the entry
        std.debug.assert(self.cache.remove(whichKey.?));

        // Delete the owned key.
        self.gpa.free(whichKey.?);
    }

    /// This function loads wavs.
    pub fn LoadWav(self: *Self, path: [:0]const u8) !*c.Mix_Chunk {
        if (self.cache.contains(path)) {
            self.incRefCountForKey(path);
            // Return the obj, it's already known and cached.
            std.debug.print("wav: {s} already loaded yay!\n", .{path});
            return @alignCast(@ptrCast(self.cache.get(path).?.data));
        }

        const sample = trkr.Mix_LoadWAV(path);
        std.debug.print("wav: {s} loaded for the first time.\n", .{path});

        // Take an owned copy of the key for safety, since the passed in path could
        // be stack allocated!!!
        const ownedKey = try self.gpa.dupe(u8, path);
        try self.cache.put(ownedKey, CacheObject{ .data = sample, .count = 1 });

        return sample;
    }

    /// This function destroy wavs...hence the name...fuck face.
    pub fn DestroyWav(self: *Self, sample: *c.Mix_Chunk) void {
        // For now, just iterate to find the item.
        var iter = self.cache.iterator();
        var whichKey: ?[]const u8 = null;
        while (iter.next()) |entry| {
            if (@as(*anyopaque, @alignCast(@ptrCast(sample))) == entry.value_ptr.*.data) {
                whichKey = entry.key_ptr.*;
            }
        }

        // NOTE: This can occur if you attempt to load the same asset multiple times.
        // Any subsequent destroy calls will be a NOP as expected.
        if (whichKey == null) {

            // NOTE: if no key was found, the wave in question is unknown to the cache.
            // But we still free it, otherwise it's a legit leak. This can occur when the
            // the wave was not created from LoadWav but something else.

            trkr.Mix_FreeChunk(sample);
            return;
        }

        if (self.decRefCountForKey(whichKey.?)) {
            // If true, we're done for now.
            return;
        }

        // Destroy the wav sample.
        trkr.Mix_FreeChunk(sample);

        // Remove the entry
        std.debug.assert(self.cache.remove(whichKey.?));

        // Delete the owned key.
        self.gpa.free(whichKey.?);
    }

    /// This function loads music.
    pub fn LoadMusic(self: *Self, path: [:0]const u8) !?*c.Mix_Music {
        if (self.cache.contains(path)) {
            self.incRefCountForKey(path);
            std.debug.print("mus: {s} already loaded yay!\n", .{path});
            return @alignCast(@ptrCast(self.cache.get(path).?.data));
        }

        std.debug.print("mus: {s} loaded for the first time.\n", .{path});
        //const sample = c.Mix_LoadMUS(path.ptr);
        const sample = trkr.Mix_LoadMUS(path);
        if (sample == null) {
            // TODO: handle this better.
            return sample;
        }

        // Take an owned copy of the key for safety, since the passed in path could
        // be stack allocated!!!
        const ownedKey = try self.gpa.dupe(u8, path);
        try self.cache.put(ownedKey, CacheObject{ .data = sample.?, .count = 1 });

        return sample;
    }

    /// This function destroy the music.
    pub fn DestroyMusic(self: *Self, sample: *c.Mix_Music) void {
        // Note: we only have a handle to the original pointer in the cache (possibly)
        // So we just scan for it and delete it if found.

        var iter = self.cache.iterator();
        var whichKey: ?[]const u8 = null;
        while (iter.next()) |entry| {
            if (@as(*anyopaque, @alignCast(@ptrCast(sample))) == entry.value_ptr.*.data) {
                whichKey = entry.key_ptr.*;
                break;
            }
        }

        if (whichKey == null) {
            // NOTE: This can occur if you attempt to load the same asset multiple times.
            // Any subsequent destroy calls will be a NOP as expected.

            // NOTE: if no key was found, the music in question is unknown to the cache.
            // But we still free it, otherwise it's a legit leak. This can occur when the
            // the music was not created from LoadMusic but some other function.
            // As it stands, we can end up with a free count that is higher than alloc count.

            trkr.Mix_FreeMusic(sample);

            // Nothing to do.
            return;
        }

        if (self.decRefCountForKey(whichKey.?)) {
            // If true, we're done for now.
            return;
        }

        // Destroy the sample.
        trkr.Mix_FreeMusic(sample);

        // But first remove the actual entry
        std.debug.assert(self.cache.remove(whichKey.?));

        // Clean the owned copy of the key.
        self.gpa.free(whichKey.?);
    }

    /// This function loads an image (texture).
    /// If the same image is requested, the load returns a ptr to the same image without actually
    /// loading thanks to caching. All calls to Load must have matching calls to Destroy.
    /// This is because Load/Destroy does referencing counting.
    pub fn LoadImage(self: *Self, renderer: ?*c.SDL_Renderer, path: [:0]const u8) !?*c.SDL_Texture {
        std.debug.print("LoadImage: for path: {s}, cache size: {d}\n", .{ path, self.cache.count() });
        if (self.cache.contains(path)) {
            self.incRefCountForKey(path);
            // Return the obj.
            std.debug.print("img: {s} already loaded yay!\n", .{path});
            return @alignCast(@ptrCast(self.cache.get(path).?.data));
        }

        std.debug.print("img: {s} loaded for the first time.\n", .{path});
        const img = trkr.IMG_LoadTexture(renderer, path);
        if (img == null) {
            // TODO: handle this better.
            return img;
        }

        // Take an owned copy of the key for safety, since the passed in path could
        // be stack allocated!!!
        const ownedKey = try self.gpa.dupe(u8, path);
        // This is the first we've seen of the item, so it has a starting ref count of zero.
        try self.cache.put(ownedKey, CacheObject{ .data = img.?, .count = 1 });

        return img;
    }

    /// This function destroys an image (texture).
    pub fn DestroyImage(self: *Self, img: *c.SDL_Texture) void {
        // Note: we only have a handle to the original pointer in the cache (possibly)
        // So we just scan for it and delete it if found.

        // Yes, this is a linear scan...because we're only provided a pointer to the image.
        // In the future I'll optimize if this turns out to be slow but keep in mind.
        // Assets are loaded/destroyed on level load and unload, this is not the hot-path.
        // Fucken noob always trying to prematurely optimize shit.
        var iter = self.cache.iterator();
        var whichKey: ?[]const u8 = null;
        while (iter.next()) |entry| {
            if (@as(*anyopaque, @alignCast(@ptrCast(img))) == entry.value_ptr.*.data) {
                whichKey = entry.key_ptr.*;
                break;
            }
        }

        // Attemp to Destroy a texture that has no key entry in the cache!!!
        if (whichKey == null) {
            // NOTE: if no key was found, the texture in question is unknown to the cache.
            // But we still free it, otherwise it's a legit leak. This can occur when the
            // the texture was not created from LoadImage but something else such as:
            // c.SDL_CreateTextureFromSurface for example.
            // As it stands, we can end up with a free count that is higher than alloc count.

            trkr.SDL_DestroyTexture(img);

            return;
        }

        if (self.decRefCountForKey(whichKey.?)) {
            // We're done for now so return.
            return;
        }

        // Otherwise, release everything, for reals Nacho.

        // Destroy the image (texture).
        trkr.SDL_DestroyTexture(img);

        // Remove the cache entry.
        std.debug.assert(self.cache.remove(whichKey.?));

        // Clean the owned copy of the key.
        self.gpa.free(whichKey.?);

        return;
    }
};
