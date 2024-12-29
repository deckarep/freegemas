const std = @import("std");
const utility = @import("utility.zig");
const c = @import("cdefs.zig").c;

pub const GoSound = struct {
    mSample: ?*c.Mix_Chunk = null,
    mChannel: ?c_int = null,

    const Self = @This();

    pub fn init() Self {
        return Self{};
    }

    pub fn setSample(self: *Self, path: []const u8) !void {
        var buf: [512]u8 = undefined;

        const mPath = try std.fmt.bufPrintZ(
            &buf,
            "{s}{s}",
            .{ utility.getBasePath(), path },
        );

        std.debug.print("wav => {s}\n", .{mPath});
        self.mSample = c.Mix_LoadWAV(mPath.ptr);
        if (self.mSample == null) {
            std.log.err("failed to load wav with err!", .{});
        }
    }

    pub fn setChannel(self: *Self, channelId: i32) void {
        self.mChannel = channelId;
    }

    pub fn unload(self: *Self) void {
        if (self.mSample) |sample| {
            c.Mix_FreeChunk(sample);
            self.mSample = null;
        }
    }

    pub fn play(self: Self, vol: f32) void {
        if (self.mSample) |sample| {
            _ = c.Mix_VolumeChunk(sample, @intFromFloat(128.0 * vol));
            _ = c.Mix_PlayChannel(if (self.mChannel != null) self.mChannel.? else -1, sample, 0);
        }
    }

    pub fn isPlaying(self: Self) bool {
        if (self.mSample) |_| {
            return c.Mix_Playing(if (self.mChannel != null) self.mChannel.? else -1) > 0;
        }
        return false;
    }
};
