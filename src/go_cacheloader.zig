const std = @import("std");
const c = @import("cdefs.zig").c;

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

pub const CacheLoader = struct {
    gpa: std.mem.Allocator,
    cache: std.StringHashMap(*anyopaque),

    const Self = @This();

    pub fn init(gpa: std.mem.Allocator) Self {
        return Self{
            .gpa = gpa,
            .cache = std.StringHashMap(*anyopaque).init(gpa),
        };
    }

    pub fn deinit(self: *Self) void {
        // TODO: still, iterate and release all resources of course.
        // ACTUALLY - upon shutdown, all Destory functions should have already been
        // called, and the cache should be empty to be correct.
        var iter = self.cache.iterator();
        while (iter.next()) |nxt| {
            std.debug.print("cache key still alive after exiting: \n  => {s}\n", .{nxt.key_ptr.*});
        }
        self.cache.deinit();
    }

    /// This function loads wavs.
    pub fn LoadWav(self: *Self, path: [:0]const u8) !*c.Mix_Chunk {
        if (self.cache.contains(path)) {
            std.debug.print("wav: {s} already loaded yay!\n", .{path});
            return @alignCast(@ptrCast(self.cache.get(path).?));
        }

        const sample = c.Mix_LoadWAV(path.ptr);
        std.debug.print("wav: {s} loaded for the first time.\n", .{path});

        // Take an owned copy of the key for safety, since the passed in path could
        // be stack allocated!!!
        const ownedKey = try self.gpa.dupe(u8, path);
        try self.cache.put(ownedKey, sample);

        return sample;
    }

    /// This function destroy wavs...hence the name...fuck face.
    pub fn DestroyWav(self: *Self, sample: *c.Mix_Chunk) void {
        // For now, just iterate to find the item.
        var iter = self.cache.iterator();
        var whichKey: ?[]const u8 = null;
        while (iter.next()) |entry| {
            if (@as(*anyopaque, @alignCast(@ptrCast(sample))) == entry.value_ptr.*) {
                whichKey = entry.key_ptr.*;
            }
        }

        // NOTE: This can occur if you attempt to load the same asset multiple times.
        // Any subsequent destroy calls will be a NOP as expected.
        if (whichKey == null) {
            // Nothing to do for now.
            return;
        }

        // 1. Destroy the wav sample.
        c.Mix_FreeChunk(sample);

        // 3. Delete the owned key.
        defer self.gpa.free(whichKey.?);

        // 2. Remove the entry
        _ = self.cache.remove(whichKey.?);
    }

    // TODO: font, but we need to consider that a unique font is (path + size)

    /// This function loads music.
    pub fn LoadMusic(self: *Self, path: [:0]const u8) !?*c.Mix_Music {
        if (self.cache.contains(path)) {
            std.debug.print("mus: {s} already loaded yay!\n", .{path});
            return @alignCast(@ptrCast(self.cache.get(path).?));
        }

        std.debug.print("mus: {s} loaded for the first time.\n", .{path});
        const sample = c.Mix_LoadMUS(path.ptr);
        if (sample == null) {
            // TODO: handle this better.
            return sample;
        }

        // Take an owned copy of the key for safety, since the passed in path could
        // be stack allocated!!!
        const ownedKey = try self.gpa.dupe(u8, path);
        try self.cache.put(ownedKey, sample.?);

        return sample;
    }

    /// This function destroy the music.
    pub fn DestroyMusic(self: *Self, sample: *c.Mix_Music) void {
        // Note: we only have a handle to the original pointer in the cache (possibly)
        // So we just scan for it and delete it if found.

        var iter = self.cache.iterator();
        var whichKey: ?[]const u8 = null;
        while (iter.next()) |entry| {
            if (@as(*anyopaque, @alignCast(@ptrCast(sample))) == entry.value_ptr.*) {
                whichKey = entry.key_ptr.*;
                break;
            }
        }

        if (whichKey == null) {
            // NOTE: This can occur if you attempt to load the same asset multiple times.
            // Any subsequent destroy calls will be a NOP as expected.

            // Nothing to do.
            return;
        }

        // 1. Destroy the sample.
        c.Mix_FreeMusic(sample);

        // 2. Clean the owned copy of the key.
        defer self.gpa.free(whichKey.?);

        // 3. But first remove the actual entry
        _ = self.cache.remove(whichKey.?);
    }

    /// This function loads an image (texture).
    pub fn LoadImage(self: *Self, renderer: ?*c.SDL_Renderer, path: [:0]const u8) !?*c.SDL_Texture {
        std.debug.print("cache size: {d}\n", .{self.cache.count()});
        if (self.cache.contains(path)) {
            std.debug.print("img: {s} already loaded yay!\n", .{path});
            return @alignCast(@ptrCast(self.cache.get(path).?));
        }

        std.debug.print("img: {s} loaded for the first time.\n", .{path});
        const img = c.IMG_LoadTexture(renderer, path.ptr);
        if (img == null) {
            // TODO: handle this better.
            return img;
        }

        // Take an owned copy of the key for safety, since the passed in path could
        // be stack allocated!!!
        const ownedKey = try self.gpa.dupe(u8, path);
        try self.cache.put(ownedKey, img.?);

        return img;
    }

    /// This function destroys an image (texture).
    pub fn DestroyImage(self: *Self, img: *c.SDL_Texture) void {
        // Note: we only have a handle to the original pointer in the cache (possibly)
        // So we just scan for it and delete it if found.

        var iter = self.cache.iterator();
        var whichKey: ?[]const u8 = null;
        while (iter.next()) |entry| {
            if (@as(*anyopaque, @alignCast(@ptrCast(img))) == entry.value_ptr.*) {
                whichKey = entry.key_ptr.*;
                break;
            }
        }

        if (whichKey == null) {
            // Nothing to do for now...
            // NOTE: This can occur if you attempt to load the same asset multiple times.
            // Any subsequent destroy calls will be a NOP as expected.
            return;
        }

        // 1. Destroy the image (texture).
        c.SDL_DestroyTexture(img);
        std.debug.print("Image destroyed: {s}\n", .{whichKey.?});

        // 2. Clean the owned copy of the key.
        defer self.gpa.free(whichKey.?);

        // 3. But first remove the actual entry
        _ = self.cache.remove(whichKey.?);
    }
};
