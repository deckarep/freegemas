const sq = @import("square.zig");
const Square = sq.Square;
const SquareType = sq.SquareType;
const utility = @import("utility.zig");

const GRID_SIZE = 8;

pub const Board = struct {
    /// Matrix of squares
    squares: [GRID_SIZE][GRID_SIZE]Square = undefined,

    const Self = @This();

    pub fn init() Self {
        return Self{};
    }

    /// Generates a random board.
    pub fn generate(self: *Self) !void {
        var repeat = false;

        // Converted to a while(true) with the test condition negated.
        // Since the original code was the fugly do/while loop.
        while (true) {
            repeat = false;

            for (0..GRID_SIZE) |i| {
                for (0..GRID_SIZE) |j| {
                    self.squares[i][j] = Square{};
                    self.squares[i][j].sqType = @enumFromInt((try utility.getRandomIntValue() % 7) + 1);
                    self.squares[i][j].mustFall = true;
                    self.squares[i][j].origY = (try utility.getRandomIntValue() % 8) - 9;
                    self.squares[i][j].destY = j - self.squares[i][j].origY;
                }
            }

            // TODO: regenerate one of the test below fails.
            // Such as when no solveable solutions exist.
            // if (!self.check().empty()) {
            //     repeat = true;
            // } else if (self.solutions().empty()) {
            //     repeat = true;
            // }

            if (!repeat) break;
        }
    }

    /// Swaps squares x1,y1 and x2,y2
    pub fn swap(self: *Self, x1: usize, y1: usize, x2: usize, y2: usize) void {
        const temp = self.squares[x1][y1];

        self.squares[x1][y1] = self.squares[x2][y2];
        self.squares[x2][y2] = temp;
    }

    /// Empties square (x,y)
    pub fn del(self: *Self, x: usize, y: usize) void {
        self.squares[x][y] = SquareType.sqEmpty;
    }

    /// Calculates squares' positions after deleting the matching gems, also filling the new spaces
    pub fn calcFallMovements(self: *Self) void {
        // TODO
    }

    /// Places all the gems out of the screen
    pub fn dropAllGems(self: *Self) void {
        for (0..GRID_SIZE) |x| {
            for (0..GRID_SIZE) |y| {
                self.squares[x][y].mustFall = true;
                self.squares[x][y].origY = y;
                self.squares[x][y].destY = 9 + try utility.getRandomIntValue() % 8;
            }
        }
    }

    /// Checks if there are matching horizontal and/or vertical groups
    //MultipleMatch check();

    /// Checks if current Board.has any possible valid movement
    //vector<Coord> solutions();

    /// Resets squares' animations
    pub fn endAnimations(self: *Self) void {
        for (0..GRID_SIZE) |x| {
            for (0..GRID_SIZE) |y| {
                self.squares[x][y].mustFall = false;
                self.squares[x][y].origY = y;
                self.squares[x][y].destY = 0;
            }
        }
    }
};
