const sq = @import("square.zig");
const Square = sq.Square;
const SquareType = sq.SquareType;

const GRID_SIZE = 8;

pub const Board = struct {
    /// Matrix of squares
    squares: [8][8]Square = undefined,

    const Self = @This();

    pub fn init() Self {
        return Self{};
    }

    /// Swaps squares x1,y1 and x2,y2
    pub fn swap(self: *Self, x1: i32, y1: i32, x2: i32, y2: i32) void {
        // TODO
    }

    /// Empties square (x,y)
    pub fn del(self: *Self, x: i32, y: i32) void {
        // TODO
    }

    /// Generates a random board.
    pub fn generate(self: *Self) void {
        // TODO
    }

    /// Calculates squares' positions after deleting the matching gems, also filling the new spaces
    pub fn calcFallMovements(self: *Self) void {
        // TODO
    }

    /// Places all the gems out of the screen
    pub fn dropAllGems(self: *Self) void {
        // TODO
    }

    /// Checks if there are matching horizontal and/or vertical groups
    //MultipleMatch check();

    /// Checks if current Board.has any possible valid movement
    //vector<Coord> solutions();

    /// Resets squares' animations
    pub fn endAnimations(self: *Self) void {}
};
