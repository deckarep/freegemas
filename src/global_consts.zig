const utility = @import("utility.zig");
const c = @import("cdefs.zig").c;

// Application stuff
pub const App = struct {
    pub const WINDOW_WIDTH = 800;
    pub const WINDOW_HEIGHT = 600;
    pub const UPDATE_INTERVAL = 25; //30;

};

// Game general stuff
pub const Game = struct {
    pub const PointsPerGem = 5;
    pub const PointsPerGemWithHint = 0;
};
// Board and Gems
pub const Board = struct {
    pub const GridSize = 8; // 8x8
    pub const XOffset = 241;
    pub const YOffset = 41;
    pub const GemWH = 65;
    pub const GemHalfWH = Board.GemWH / 2;
};

// Audio
pub const Sfx = struct {
    pub const Match1 = "media/themes/kq6/audio/kings_quest_6_ding.mp3";
    pub const Match2 = "media/themes/kq6/audio/kings_quest_6_ding.mp3";
    pub const Match3 = "media/themes/kq6/audio/kings_quest_6_ding.mp3";
};

// Common Colors (TODO)

// Particles
pub const Particles = struct {
    pub const SpawnQuantity = 15;
};

// Theme / Avatars
pub const Avatar = struct {
    /// The character name of the avatar, not yet used in code.
    Name: []const u8,
    /// Which background image to use for this character. Should help reinforce
    /// the characters origin.
    BackgroundImgPath: []const u8,
    /// Obviously, if the character has a musical theme or related music.
    BackgroundMusic: []const u8,
    /// The actual character's portrait.
    PortraitImgPath: []const u8,
    /// Portraits top/left anchor position.
    PortraitXY: c.SDL_Point,

    /// The character's mouth/talking lip movements, for now played in sequence.
    FaceAnimImgPath: []const u8,
    /// How many cells does the character's mouth/talking lip movements have.
    MouthFrameCnt: usize,
    /// The top/left anchor position (relative to the portrait)
    MouthXY: c.SDL_Point,
    /// The width/height of a single mouth/lip cell.
    MouthWH: c.SDL_Point,

    /// The character's eye movements, for now random.
    EyeAnimImgPath: []const u8,
    /// The number of frames for the characters eye cells.
    EyeFrameCnt: usize,
    /// The top/left anchor position (relative to the portait)
    EyeXY: c.SDL_Point,
    /// The width/height for a single eye cell.
    EyeWH: c.SDL_Point,

    /// The character's audio lines, they are played in sequence but a random
    /// line is chosen, then in sequence there after and loops back around.
    AudioLines: ?[]const []const u8,
};

pub const Characters = [_]Avatar{
    .{
        .Name = "Lampseller",
        .BackgroundImgPath = "media/board_kq6.png",
        //.BackgroundMusic = "media/Isle of the Chill (remix).mp3",
        .BackgroundMusic = "media/themes/kq6/audio/music_village_og.mp3",
        .PortraitImgPath = "media/LampSellerPortrait.png",
        .PortraitXY = c.SDL_Point{ .x = 95, .y = 449 },
        .FaceAnimImgPath = "media/LampSellerFaceAnimation.png",
        .EyeAnimImgPath = "media/LampSellerEyeAnimation.png",
        .MouthFrameCnt = 10,
        .MouthXY = c.SDL_Point{ .x = 62, .y = 87 },
        .MouthWH = c.SDL_Point{ .x = 32, .y = 44 },
        .EyeFrameCnt = 3,
        .EyeXY = c.SDL_Point{ .x = 62, .y = 62 },
        .EyeWH = c.SDL_Point{ .x = 36, .y = 14 },
        .AudioLines = &.{
            // Old lamps, is sprinkled throughout to pester the gamer just like in the original KQ6!
            "media/themes/kq6/avatars/lampseller/OldLamps.mp3",
            "media/themes/kq6/avatars/lampseller/Audio240-34-5-0-1.wav",
            "media/themes/kq6/avatars/lampseller/OldLamps.mp3",
            "media/themes/kq6/avatars/lampseller/Audio240-34-5-0-2.wav",
            "media/themes/kq6/avatars/lampseller/OldLamps.mp3",
            "media/themes/kq6/avatars/lampseller/Audio240-34-5-0-4.wav",
            "media/themes/kq6/avatars/lampseller/OldLamps.mp3",
            "media/themes/kq6/avatars/lampseller/Audio240-39-0-0-2.wav",
            "media/themes/kq6/avatars/lampseller/Audio240-39-0-0-3.wav",
            "media/themes/kq6/avatars/lampseller/Audio240-4-0-0-2.wav",
            "media/themes/kq6/avatars/lampseller/OldLamps.mp3",
            "media/themes/kq6/avatars/lampseller/Audio240-4-2-22-2.wav",
            "media/themes/kq6/avatars/lampseller/Audio240-4-2-22-4.wav",
            "media/themes/kq6/avatars/lampseller/OldLamps.mp3",
            "media/themes/kq6/avatars/lampseller/Audio240-4-2-23-2.wav",
            "media/themes/kq6/avatars/lampseller/OldLamps.mp3",
            "media/themes/kq6/avatars/lampseller/Audio240-4-43-22-2.wav",
            "media/themes/kq6/avatars/lampseller/Audio240-4-43-23-2.wav",
        },
    },
    .{
        //@07i0i0r.003
        .Name = "Bookowner",
        .BackgroundImgPath = "media/bookownerBoard.png",
        .BackgroundMusic = "media/themes/kq6/audio/music_village_og.mp3",
        .PortraitImgPath = "media/BookownerPortrait.png",
        .PortraitXY = c.SDL_Point{ .x = 95, .y = 449 },
        .FaceAnimImgPath = "media/BookownerFaceAnimation.png",
        .EyeAnimImgPath = "media/BookownerEyeAnimation.png",
        .MouthFrameCnt = 10,
        .MouthXY = c.SDL_Point{ .x = 62, .y = 84 },
        .MouthWH = c.SDL_Point{ .x = 26, .y = 22 },
        .EyeFrameCnt = 3,
        .EyeXY = c.SDL_Point{ .x = 56, .y = 60 },
        .EyeWH = c.SDL_Point{ .x = 32, .y = 4 },
        .AudioLines = &.{
            "media/themes/kq6/avatars/bookowner/Audio270-1-5-1-2.wav",
            "media/themes/kq6/avatars/bookowner/Audio270-1-5-1-3.wav",
            "media/themes/kq6/avatars/bookowner/Audio270-1-5-1-4.wav",
            "media/themes/kq6/avatars/bookowner/Audio270-18-2-22-10.wav",
            "media/themes/kq6/avatars/bookowner/Audio270-18-2-22-14.wav",
            "media/themes/kq6/avatars/bookowner/Audio270-18-2-22-15.wav",
            "media/themes/kq6/avatars/bookowner/Audio270-18-2-22-16.wav",
            "media/themes/kq6/avatars/bookowner/Audio270-18-2-22-17.wav",
            "media/themes/kq6/avatars/bookowner/Audio270-18-2-22-19.wav",
            "media/themes/kq6/avatars/bookowner/Audio270-18-2-22-8.wav",
            "media/themes/kq6/avatars/bookowner/Audio270-18-2-22-9.wav",
            "media/themes/kq6/avatars/bookowner/Audio270-18-2-24-3.wav",
            "media/themes/kq6/avatars/bookowner/Audio270-18-2-24-4.wav",
            "media/themes/kq6/avatars/bookowner/Audio270-18-2-25-1.wav",
            "media/themes/kq6/avatars/bookowner/Audio270-18-2-25-2.wav",
            "media/themes/kq6/avatars/bookowner/Audio270-18-2-26-4.wav",
            "media/themes/kq6/avatars/bookowner/Audio270-18-28-0-1.wav",
            "media/themes/kq6/avatars/bookowner/Audio270-18-32-0-1.wav",
            "media/themes/kq6/avatars/bookowner/Audio270-19-0-36-1.wav",
            "media/themes/kq6/avatars/bookowner/Audio270-2-5-4-2.wav",
            "media/themes/kq6/avatars/bookowner/Audio270-6-5-0-3.wav",
        },
    },
    .{
        // Pawnshop counter displays items of interest - 07s0z01.001
        // Sync36 - @07s0402.181 (around here)
        .Name = "Pawnowner",
        .BackgroundImgPath = "media/pawnownerBoard.png",
        .BackgroundMusic = "media/themes/kq6/audio/music_village_og.mp3",
        .PortraitImgPath = "media/PawnownerPortrait.png",
        .PortraitXY = c.SDL_Point{ .x = 95, .y = 449 },
        .FaceAnimImgPath = "media/PawnownerMouthAnimation.png",
        .EyeAnimImgPath = "media/PawnownerEyeAnimation.png",
        .MouthFrameCnt = 10,
        .MouthXY = c.SDL_Point{ .x = 58, .y = 72 },
        .MouthWH = c.SDL_Point{ .x = 34, .y = 36 },
        .EyeFrameCnt = 3,
        .EyeXY = c.SDL_Point{ .x = 50, .y = 50 },
        .EyeWH = c.SDL_Point{ .x = 40, .y = 4 },
        .AudioLines = &.{
            "media/themes/kq6/avatars/pawnowner/Audio280-11-5-39-1.wav",
            "media/themes/kq6/avatars/pawnowner/Audio280-11-5-40-1.wav",
            "media/themes/kq6/avatars/pawnowner/Audio280-37-5-16-2.wav",
            "media/themes/kq6/avatars/pawnowner/Audio280-37-5-39-2.wav",
            "media/themes/kq6/avatars/pawnowner/Audio280-4-12-30-2.wav",
            "media/themes/kq6/avatars/pawnowner/Audio280-4-12-31-2.wav",
            "media/themes/kq6/avatars/pawnowner/Audio280-4-13-0-2.wav",
            "media/themes/kq6/avatars/pawnowner/Audio280-4-2-61-2.wav",
            "media/themes/kq6/avatars/pawnowner/Audio280-4-2-61-4.wav",
            "media/themes/kq6/avatars/pawnowner/Audio280-4-2-61-5.wav",
            "media/themes/kq6/avatars/pawnowner/Audio280-4-2-61-7.wav",
            "media/themes/kq6/avatars/pawnowner/Audio280-4-40-69-2.wav",
            "media/themes/kq6/avatars/pawnowner/Audio280-4-42-0-2.wav",
            "media/themes/kq6/avatars/pawnowner/Audio280-4-63-0-2.wav",
            "media/themes/kq6/avatars/pawnowner/Audio280-4-66-26-2.wav",
            "media/themes/kq6/avatars/pawnowner/Audio280-4-66-28-2.wav",
            "media/themes/kq6/avatars/pawnowner/Audio280-4-7-0-2.wav",
            "media/themes/kq6/avatars/pawnowner/Audio280-4-70-18-2.wav",
            "media/themes/kq6/avatars/pawnowner/Audio280-4-70-18-3.wav",
            "media/themes/kq6/avatars/pawnowner/Audio280-4-70-21-2.wav",
            "media/themes/kq6/avatars/pawnowner/Audio280-6-5-0-2.wav",
        },
    },
    .{
        //@0780205.071, @0780502.0a2
        .Name = "Ferryman",
        .BackgroundImgPath = "media/ferrymanBoard.png",
        .BackgroundMusic = "media/themes/kq6/audio/music_ferrymen_og.mp3",
        .PortraitImgPath = "media/FerrymanPortrait.png",
        .PortraitXY = c.SDL_Point{ .x = 95, .y = 449 },
        .FaceAnimImgPath = "media/FerrymanFaceAnimation.png",
        .EyeAnimImgPath = "media/FerrymanEyeAnimation.png",
        .MouthFrameCnt = 10,
        .MouthXY = c.SDL_Point{ .x = 58, .y = 74 },
        .MouthWH = c.SDL_Point{ .x = 28, .y = 22 },
        .EyeFrameCnt = 3,
        .EyeXY = c.SDL_Point{ .x = 52, .y = 54 },
        .EyeWH = c.SDL_Point{ .x = 34, .y = 4 },
        .AudioLines = &.{
            "media/themes/kq6/avatars/ferryman/Audio260-1-0-6-1.wav",
            //"media/themes/kq6/avatars/ferryman/Audio260-10-1-0-1.wav", // Narrator audio when lvl loads maybe.
            "media/themes/kq6/avatars/ferryman/Audio260-2-5-18-1.wav",
            "media/themes/kq6/avatars/ferryman/Audio260-5-0-0-2.wav",
            "media/themes/kq6/avatars/ferryman/Audio260-5-2-10-2.wav",
            "media/themes/kq6/avatars/ferryman/Audio260-5-2-10-4.wav",
            "media/themes/kq6/avatars/ferryman/Audio260-5-2-17-2.wav",
            "media/themes/kq6/avatars/ferryman/Audio260-5-2-9-2.wav",
            "media/themes/kq6/avatars/ferryman/Audio260-5-40-0-2.wav",
            "media/themes/kq6/avatars/ferryman/Audio260-5-70-15-2.wav",
            "media/themes/kq6/avatars/ferryman/Audio260-5-70-16-2.wav",
        },
    },
};

/// Private, global current character.
var SelectedCharId: usize = 0;
var CurrentAvatarSound: usize = 0;

/// Public global function which returns the current character id.
pub fn getCurrentChar() usize {
    return SelectedCharId;
}

/// Public global function, which advances the selected char wrapping back to the
/// the 0th character.
pub fn selectNextChar() void {
    if (SelectedCharId < (Characters.len - 1)) {
        SelectedCharId += 1;
    } else {
        SelectedCharId = 0;
    }
}

pub fn getCurrentAvatarSoundIdx() usize {
    return CurrentAvatarSound;
}

pub fn getCurrentAvatarLineCount() !usize {
    const avatar = &Characters[getCurrentChar()];

    if (avatar.AudioLines) |lines| {
        // 1. Side effect to set a random initial sound.
        // NOTE: this should only happen once because we expect this to be queried once per lvl.
        CurrentAvatarSound = @intCast(try utility.getRandomInt(0, @as(i32, @intCast(lines.len)) - 1));

        // 2. Now get the count.
        return lines.len;
    }
    return 0;
}

pub fn selectNextAvatarSound() void {
    const avatar = &Characters[getCurrentChar()];
    if (avatar.AudioLines) |lines| {
        if (CurrentAvatarSound < (lines.len - 1)) {
            CurrentAvatarSound += 1;
        } else {
            CurrentAvatarSound = 0;
        }
    }
}
