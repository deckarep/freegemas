const std = @import("std");
const goSnd = @import("go_sound.zig");
const glConsts = @import("global_consts.zig");
const om = @import("options_manager.zig");

pub const GameSounds = struct {
    gpa: std.mem.Allocator,
    soundsLoaded: bool = false,
    options: om.OptionsManager = undefined,

    mSfxMatch1: goSnd.GoSound = goSnd.GoSound.init(),
    mSfxMatch2: goSnd.GoSound = goSnd.GoSound.init(),
    mSfxMatch3: goSnd.GoSound = goSnd.GoSound.init(),
    mSfxSelect: goSnd.GoSound = goSnd.GoSound.init(),
    mSfxFall: goSnd.GoSound = goSnd.GoSound.init(),

    mSfxAvatarSounds: ?[]goSnd.GoSound = null,

    const Self = @This();

    pub fn init(gpa: std.mem.Allocator) Self {
        return Self{
            .gpa = gpa,
        };
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

        self.unloadAvatarSounds();
    }

    pub fn loadResources(self: *Self) !void {
        std.debug.print("game_sounds.zig:loadResources() invoked...\n", .{});
        self.options.loadResources();

        if (self.options.getSoundEnabled() and !self.soundsLoaded) {
            try self.mSfxMatch1.setSample(glConsts.Sfx.Match1);
            try self.mSfxMatch2.setSample(glConsts.Sfx.Match1);
            try self.mSfxMatch3.setSample(glConsts.Sfx.Match1);
            try self.mSfxSelect.setSample("media/select.ogg");
            try self.mSfxFall.setSample("media/fall.ogg");

            std.debug.print("sound sfx loaded...\n", .{});

            self.soundsLoaded = true;
        } else if (!self.options.getSoundEnabled() and self.soundsLoaded) {
            self.destroyResources();
            self.soundsLoaded = false;
        }
    }

    /// These get loaded on a per board basis.
    pub fn loadAvatarSounds(self: *Self) !void {
        // 1. If we previously had sounds, unload them.
        self.unloadAvatarSounds();

        // 2. Next, load in sounds for the current avatar.
        const avatarSndCnt = try glConsts.getCurrentAvatarLineCount();
        if (avatarSndCnt > 0) {
            std.debug.print("avatar HAS {d} sounds to load!\n", .{avatarSndCnt});
            const lines = glConsts.Characters[glConsts.getCurrentChar()].AudioLines.?;
            self.mSfxAvatarSounds = try self.gpa.alloc(goSnd.GoSound, avatarSndCnt);
            if (self.mSfxAvatarSounds) |snds| {
                for (snds, 0..) |*snd, idx| {
                    snd.* = goSnd.GoSound.init();
                    try snd.setSample(lines[idx]);
                    snd.setChannel(3); // special channel dedicated to Avatar sounds.
                }
            }
        } else {
            std.debug.print("avatar has NO sounds\n", .{});
        }
    }

    pub fn unloadAvatarSounds(self: *Self) void {
        if (self.mSfxAvatarSounds) |prevSnds| {
            // Set ptr to null.
            defer self.mSfxAvatarSounds = null;

            // Release this guy last.
            defer self.gpa.free(self.mSfxAvatarSounds.?);

            // Every sound must be .deinit
            for (prevSnds) |*snd| {
                snd.deinit();
            }
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

    pub fn playAvatarSound(self: Self) void {
        const avatar = &glConsts.Characters[glConsts.getCurrentChar()];
        if (avatar.AudioLines) |_| {
            if (self.mSfxAvatarSounds) |snds| {
                snds[glConsts.getCurrentAvatarSoundIdx()].play(2.0);
                glConsts.selectNextAvatarSound();
            }
        }
    }

    pub fn isAvatarPlayingSound(self: Self) bool {
        const avatar = &glConsts.Characters[glConsts.getCurrentChar()];
        if (avatar.AudioLines) |_| {
            if (self.mSfxAvatarSounds) |snds| {
                return snds[glConsts.getCurrentAvatarSoundIdx()].isPlaying();
            }
        }

        // Hmm, when no sounds just return false I guess as it can never be busy.
        return false;
    }
};
