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

// Common Colors (TODO)

// Particles
pub const Particles = struct {
    pub const SpawnQuantity = 15;
};

// Theme / Avatars
pub const Avatar = struct {
    Name: []const u8,
    BackgroundImgPath: []const u8,
    PortraitImgPath: []const u8,
    FaceAnimImgPath: []const u8,
    PortraitXY: c.SDL_Point,

    MouthFrameCnt: usize,
    MouthXY: c.SDL_Point,
    MouthWH: c.SDL_Point,

    EyeFrameCnt: usize,
    EyeXY: c.SDL_Point,
    EyeWH: c.SDL_Point,
    EyeVertOffset: usize,
};

pub const LampsellerId = 0;
pub const BookownerId = 1;

// TODO: use the KQ6 point score sound effect for gem matching! sound.
pub const Characters = [_]Avatar{
    .{
        .Name = "Lampseller",
        .BackgroundImgPath = "media/board_kq6.png",
        .PortraitImgPath = "media/LampSellerPortrait.png",
        .PortraitXY = c.SDL_Point{ .x = 95, .y = 449 },
        .FaceAnimImgPath = "media/LampSellerFaceAnimation.png",
        .MouthFrameCnt = 10,
        .MouthXY = c.SDL_Point{ .x = 62, .y = 87 },
        .MouthWH = c.SDL_Point{ .x = 32, .y = 44 },
        .EyeFrameCnt = 3,
        .EyeXY = c.SDL_Point{ .x = 62, .y = 18 },
        .EyeWH = c.SDL_Point{ .x = 36, .y = 14 },
        .EyeVertOffset = 46,
    },
    .{
        .Name = "Bookowner",
        .BackgroundImgPath = "media/bookownerBoard.png",
        .PortraitImgPath = "media/BookownerPortrait.png",
        .PortraitXY = c.SDL_Point{ .x = 95, .y = 449 },
        .FaceAnimImgPath = "media/BookownerFaceAnimation.png",
        .MouthFrameCnt = 10,
        .MouthXY = c.SDL_Point{ .x = 62, .y = 84 },
        .MouthWH = c.SDL_Point{ .x = 26, .y = 22 },
        .EyeFrameCnt = 3,
        .EyeXY = c.SDL_Point{ .x = 56, .y = 38 },
        .EyeWH = c.SDL_Point{ .x = 32, .y = 4 },
        .EyeVertOffset = 24,
    },
    .{
        .Name = "Pawnowner",
        .BackgroundImgPath = "media/pawnownerBoard.png",
        .PortraitImgPath = "media/BookownerPortrait.png",
        .PortraitXY = c.SDL_Point{ .x = 95, .y = 449 },
        .FaceAnimImgPath = "media/BookownerFaceAnimation.png",
        .MouthFrameCnt = 10,
        .MouthXY = c.SDL_Point{ .x = 62, .y = 84 },
        .MouthWH = c.SDL_Point{ .x = 26, .y = 22 },
        .EyeFrameCnt = 3,
        .EyeXY = c.SDL_Point{ .x = 56, .y = 38 },
        .EyeWH = c.SDL_Point{ .x = 32, .y = 4 },
        .EyeVertOffset = 24,
    },
};

/// Private, global current character.
var SelectedCharId: usize = LampsellerId;

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
        SelectedCharId = LampsellerId;
    }
}
