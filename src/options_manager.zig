const std = @import("std");
const utility = @import("utility.zig");
const c = @import("cdefs.zig").c;

const optionsFile = "options.json";

/// NOTE: this is just a little options/settings wrapper around
/// something that can be serialized to disk and back in order
/// to save the users preferences but also to save high scores.
/// And that's it folks!
pub const OptionsManager = struct {
    // options: key/value thingy.
    optionsDir: []const u8,

    const Self = @This();

    pub fn init() Self {
        return Self{
            .optionsDir = undefined,
        };
    }

    pub fn loadResources(self: *Self) void {
        self.optionsDir = utility.getPrefPath();
        self.loadOptions();
    }

    pub fn writeOptions(self: Self) void {
        _ = self;
        // serializes into a json output.
        // TODO: serialize to disk in json format probably.
    }

    pub fn loadOptions(self: *Self) void {
        // deserializes into some kind of key/value thing like a map.
        _ = self;
    }

    pub fn setHighscoreTimetrial(self: *Self, score: i32) void {
        _ = self;
        _ = score;
    }

    pub fn setHighscoreEndless(self: *Self, score: i32) void {
        _ = self;
        _ = score;
    }

    pub fn setMusicEnabled(self: *Self, value: bool) void {
        _ = self;
        _ = value;
    }

    pub fn setSoundEnabled(self: *Self, value: bool) void {
        _ = self;
        _ = value;
    }

    pub fn setFullscreenEnabled(self: *Self, value: bool) void {
        _ = self;
        _ = value;
    }

    pub fn getHighscoreTimetrial() i32 {
        return 1e5;
    }

    pub fn getHighscoreEndless() i32 {
        return 1e5;
    }

    pub fn getMusicEnabled() bool {
        return true;
    }

    pub fn getSoundEnabled() bool {
        return true;
    }

    pub fn getFullscreenEnabled(self: Self) bool {
        _ = self;
        return false;
    }
};
