const std = @import("std");
const c = @import("cdefs.zig").c;

var prng: std.Random.Xoshiro256 = undefined;
var rand: ?std.Random = null;

var basePathStrBuf: [128]u8 = undefined;
var basePathStr: ?[]const u8 = null;

var prefPathStrBuf: [128]u8 = undefined;
var prefPathStr: ?[]const u8 = null;

/// getRandom lazily on first invocation will instantiate a random object
/// for use going forward. On subsequent invocations, it just
/// returns whatever was instantiated.
pub fn getRandom() !std.Random {
    if (rand) |r| {
        return r;
    }

    prng = std.rand.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try std.posix.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });

    rand = prng.random();
    return rand.?;
}

/// getBasePath effectively queries SDL, and caches the result.
/// Once cached, the same string result is always returned.
pub fn getBasePath() []const u8 {
    if (basePathStr) |str| {
        // We already have it set, so just return it.
        return str;
    }

    const basePath = c.SDL_GetBasePath();
    if (basePath) |bp| {
        defer c.SDL_free(basePath);
        const res = std.mem.span(bp);

        // WARN: Hack for now: removes the "zig-out/bin/" when run with
        // zig build run
        var lessCount: usize = 0;
        const artifactPath = "zig-out/bin/";
        if (std.mem.endsWith(u8, res, artifactPath)) {
            lessCount = artifactPath.len;
        }

        const finalSlice = res[0 .. res.len - lessCount];
        @memcpy(basePathStrBuf[0..finalSlice.len], finalSlice);
        basePathStr = basePathStrBuf[0..finalSlice.len];
        return basePathStr.?;
    }

    // #if !defined(_WIN32) && !defined(__vita__)
    //     // Check if game is installed system wide
    //     DIR* dir = opendir(std::string(basePathStr + "../share/freegemas/").c_str());
    //     if (dir) {
    //         basePathStr += "../share/freegemas/";
    //         closedir(dir);
    //     }
    // #endif

    return basePathStr.?;
}

/// getPrefPath effectively queries SDL, and caches the result.
/// Once cached, the same string result is always returned.
pub fn getPrefPath() []const u8 {
    if (prefPathStr) |str| {
        // We already have it set, so just return it.
        return str;
    }

    const prefPath = c.SDL_GetPrefPath(null, "freegemas");
    if (prefPath) |pp| {
        defer c.SDL_free(prefPath);
        const res = std.mem.span(pp);
        @memcpy(prefPathStrBuf[0..res.len], res);
        prefPathStr = prefPathStrBuf[0..res.len];
        return prefPathStr.?;
    }

    return prefPathStr.?;
}

/// Returns a random float between a lower and upper bound.
pub fn getRandomFloat(a: f32, b: f32) !f32 {
    const r = try getRandom();
    return r.float(f32) * (b - a) + a;
}

/// Returns a random int between a lower and upper bound.
pub fn getRandomInt(min: i32, max: i32) !i32 {
    const r = try getRandom();
    const res = r.int(i32);
    return @mod(res, (max - min + 1)) + min;
}

/// Returns a random i32 int from the full range.
pub fn getRandomIntValue() !i32 {
    const r = try getRandom();
    return r.int(i32);
}
