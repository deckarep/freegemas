const std = @import("std");
const c = @import("cdefs.zig").c;
const utility = @import("utility.zig");

pub const GoMusic = struct {
    mSample: ?*c.Mix_Music = null,

    const Self = @This();

    pub fn init() Self {
        return Self{};
    }

    pub fn deinit(self: *Self) void {
        if (self.mSample) |sample| {
            c.Mix_FreeMusic(sample);
            self.mSample = null;
        }
    }

    pub fn setSample(self: *Self, path: []const u8) !void {
        var buf: [128]u8 = undefined;
        const mPath = try std.fmt.bufPrintZ(
            &buf,
            "{s}{s}",
            .{ utility.getBasePath(), path },
        );

        self.mSample = c.Mix_LoadMUS(mPath.ptr);
        if (self.mSample == null) {
            std.log.err("failed to load music sample!", .{});
        }
    }

    pub fn play(self: Self, vol: f32) void {
        if (true) return;
        if (self.mSample) |sample| {
            _ = c.Mix_VolumeMusic(@intFromFloat(128.0 * vol));
            _ = c.Mix_FadeInMusic(sample, -1, 200);
        }
    }

    pub fn stop(self: Self) void {
        _ = self;
        _ = c.Mix_FadeOutMusic(200);
    }

    pub fn isPlaying(self: Self) bool {
        _ = self;
        return c.Mix_PlayingMusic();
    }
};
