const goSnd = @import("go_sound.zig");
const glConsts = @import("global_consts.zig");
const om = @import("options_manager.zig");

pub const GameSounds = struct {
    soundsLoaded: bool = false,
    options: om.OptionsManager = undefined,

    mSfxMatch1: goSnd.GoSound = undefined,
    mSfxMatch2: goSnd.GoSound = undefined,
    mSfxMatch3: goSnd.GoSound = undefined,
    mSfxSelect: goSnd.GoSound = undefined,
    mSfxFall: goSnd.GoSound = undefined,
    mSfxOldLamps: goSnd.GoSound = undefined,

    const Self = @This();

    pub fn init() Self {
        return Self{};
    }

    pub fn deinit(self: *Self) void {
        self.destroyResources();
    }

    pub fn destroyResources(self: *Self) void {
        self.mSfxMatch1.deinit();
        self.mSfxMatch2.deinit();
        self.mSfxMatch3.deinit();
        self.mSfxSelect.deinit();
        self.mSfxFall.deinit();
        self.mSfxOldLamps.deinit();
    }

    pub fn loadResources(self: *Self) !void {
        self.options.loadResources();

        if (self.options.getSoundEnabled() and !self.soundsLoaded) {
            try self.mSfxMatch1.setSample(glConsts.Sfx.Match1);
            try self.mSfxMatch2.setSample(glConsts.Sfx.Match1);
            try self.mSfxMatch3.setSample(glConsts.Sfx.Match1);
            try self.mSfxSelect.setSample("media/select.ogg");
            try self.mSfxFall.setSample("media/fall.ogg");

            try self.mSfxOldLamps.setSample("media/OldLamps.mp3");
            self.mSfxOldLamps.setChannel(3); // special channel.

            self.soundsLoaded = true;
        } else if (!self.options.getSoundEnabled() and self.soundsLoaded) {
            self.destroyResources();
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
        self.mSfxMatch1.play(0.55);
    }

    pub fn playSoundMatch2(self: Self) void {
        self.mSfxMatch2.play(0.55);
    }

    pub fn playSoundMatch3(self: Self) void {
        self.mSfxMatch3.play(0.55);
    }

    pub fn playOldLamps(self: Self) void {
        self.mSfxOldLamps.play(1.25);
    }

    pub fn isPlayOldLampsBusy(self: Self) bool {
        return self.mSfxOldLamps.isPlaying();
    }
};
