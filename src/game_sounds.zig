const goSnd = @import("go_sound.zig");
const om = @import("options_manager.zig");

pub const GameSounds = struct {
    soundsLoaded: bool = false,
    options: om.OptionsManager = undefined,

    mSfxMatch1: goSnd.GoSound = undefined,
    mSfxMatch2: goSnd.GoSound = undefined,
    mSfxMatch3: goSnd.GoSound = undefined,
    mSfxSelect: goSnd.GoSound = undefined,
    mSfxFall: goSnd.GoSound = undefined,

    const Self = @This();

    pub fn init() Self {
        return Self{};
    }

    pub fn loadResources(self: *Self) !void {
        self.options.loadResources();

        if (self.options.getSoundEnabled() and !self.soundsLoaded) {
            try self.mSfxMatch1.setSample("media/match1.ogg");
            try self.mSfxMatch2.setSample("media/match2.ogg");
            try self.mSfxMatch3.setSample("media/match3.ogg");
            try self.mSfxSelect.setSample("media/select.ogg");
            try self.mSfxFall.setSample("media/fall.ogg");

            self.soundsLoaded = true;
        } else if (!self.options.getSoundEnabled() and self.soundsLoaded) {
            self.mSfxMatch1.unload();
            self.mSfxMatch2.unload();
            self.mSfxMatch3.unload();
            self.mSfxSelect.unload();
            self.mSfxFall.unload();

            self.soundsLoaded = false;
        }
    }

    pub fn playSoundSelect(self: Self) void {
        self.mSfxSelect.play(0.3);
    }

    pub fn playSoundFall(self: Self) void {
        self.mSfxFall.play(0.3);
    }

    pub fn playSoundMatch1(self: Self) void {
        self.mSfxMatch1.play(0.25);
    }

    pub fn playSoundMatch2(self: Self) void {
        self.mSfxMatch2.play(0.25);
    }

    pub fn playSoundMatch3(self: Self) void {
        self.mSfxMatch3.play(0.25);
    }
};
