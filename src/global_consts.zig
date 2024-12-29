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
    pub const SpawnQuantity = 50;
};
