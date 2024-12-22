const std = @import("std");
const sq = @import("square.zig");
const Square = sq.Square;
const SquareType = sq.SquareType;
const utility = @import("utility.zig");
const co = @import("coord.zig");
const mch = @import("match.zig");
const mm = @import("multi_match.zig");

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
        // Before anything else, let's reset the animation coordinates for each square
        self.endAnimations();

        // First, let's calculate the new position for each gem
        // We start going column by column, from left to right
        for (0..GRID_SIZE) |x| {
            // Block introduced to minimize scope of y and not shadow y below this block!
            {
                // We go from the bottom up
                var y: i32 = 7;
                while (y >= 0) : (y -= 1) {
                    // origY stores the initial vertical position of the gem before falling
                    self.squares[x][y].origY = y;

                    // If the current square is empty, every square above it should fall one position
                    if (self.squares[x][y].tSquare() == .sqEmpty) {
                        var k = y - 1;
                        while (k >= 0) : (k -= 1) {
                            self.squares[x][k].mustFall = true;
                            self.squares[x][k].destY += 1;
                        }
                    }
                }

                // Now that each square has its new position in their destY property,
                // let's move them to that final position
                y = 7;
                while (y >= 0) : (y -= 1) {
                    // If the square is not empty and has to fall, move it to the new position
                    if (self.squares[x][y].mustFall and self.squares[x][y].tSquare() != .sqEmpty) {
                        const y0 = self.squares[x][y].destY;
                        self.squares[x][y + y0] = self.squares[x][y];
                        self.squares[x][y] = .sqEmpty;
                    }
                }
            }

            // Finally, let's count how many new empty spaces there are so we can fill
            // them with new random gems
            var emptySpaces: i32 = 0;

            // We start counting from top to bottom. Once we find a square, we stop counting
            for (0..GRID_SIZE) |y| {
                if (self.squares[x][y].tSquare() != .sqEmpty) {
                    break;
                }
                emptySpaces += 1;
            }

            // Again from top to bottom, fill the emtpy squares, assigning them a
            // proper position outta screen for the animation to work
            for (0..GRID_SIZE) |y| {
                if (self.squares[x][y].tSquare() == .sqEmpty) {
                    self.squares[x][y] = Square{};
                    self.squares[x][y].sqType = @enumFromInt((try utility.getRandomIntValue() % 7) + 1);

                    self.squares[x][y].mustFall = true;
                    self.squares[x][y].origY = y - emptySpaces;
                    self.squares[x][y].destY = emptySpaces;
                }
            }
        }
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

    /// Checks if there are matching horizontal and/or vertical groups.
    /// The inner for loop checks GRID_SIZE - 2 because to avoid out
    /// of bounds checks and because at least 3 consecutive squares
    /// are needed to be a match.
    /// A multi-match is simply all the horizontal and/or vertical
    /// matchings that were identified.
    ///
    /// NOTE: The caller owns the returned MultiMatch and must always deinit.
    pub fn check(self: *Self, allocator: std.mem.Allocator) !mm.MultiMatch {
        var k: i32 = undefined;

        // WARN: In terms of memory leaks think I accounted for all cases.
        // If this functions returns and matches is empty,
        // currentRow/currentColumn leaks memory because it's not added
        // to matches. So we need to deinit them.
        // Otherwise, if they are added to matches, matches is will be
        // returned and owned by the caller and upon matches.deinit being
        // called all memory will be cleaned up correctly.

        var matches = mm.MultiMatch.init(allocator);
        var cleanupHook = mm.MultiMatch.init(allocator);
        defer cleanupHook.deinit(); // Always fire deinit whether its populated or not.

        // First, we check each row (horizontal)
        for (0..GRID_SIZE) |y| {
            for (0..GRID_SIZE - 2) |x| {
                var currentRow = mch.Match.init(allocator);
                try currentRow.pushBack(co.Coord{ .x = x, .y = y });

                k = x + 1;
                while (k < GRID_SIZE) : (k += 1) {
                    if (self.squares[x][y] == self.squares[k][y] and
                        self.squares[x][y].tSquare() != .sqEmpty)
                    {
                        try currentRow.pushBack(co.Coord{ .x = k, .y = y });
                    } else {
                        break;
                    }
                }

                if (currentRow.size() > 2) {
                    try matches.pushBack(&currentRow);
                } else {
                    // We must still capture this allocation to ensure cleanup!
                    try cleanupHook.pushBack(&currentRow);
                }

                x = k - 1;
            }
        }

        // Next, check each column (vertical)
        for (0..GRID_SIZE) |x| {
            for (0..GRID_SIZE - 2) |y| {
                var currentColumn = mch.Match.init(allocator);
                try currentColumn.pushBack(co.Coord{ .x = x, .y = y });

                k = y + 1;
                while (k < GRID_SIZE) : (k += 1) {
                    if (self.squares[x][y] == self.squares[x][k] and
                        self.squares[x][y].tSquare() != .sqEmpty)
                    {
                        try currentColumn.pushBack(co.Coord{ .x = x, .y = k });
                    } else {
                        break;
                    }
                }

                if (currentColumn.size() > 2) {
                    try matches.pushBack(&currentColumn);
                } else {
                    // We must still capture this allocation to ensure cleanup!
                    try cleanupHook.pushBack(&currentColumn);
                }

                y = k - 1;
            }
        }

        return matches;
    }

    /// Checks if current Board has any possible valid movements.
    /// NOTE: Caller owns and must .deinit the returned results.
    pub fn solutions(self: *Self, allocator: std.mem.Allocator) !std.ArrayList(co.Coord) {
        var results = std.ArrayList(co.Coord).init(allocator);

        const matches = try self.check(allocator);
        defer matches.deinit();

        if (!matches.empty()) {
            try results.append(co.Coord{ .x = -1, .y = -1 });
            return results;
        }

        // Let's check all the possible boards
        // (49 * 4) + (32 * 2) even though there are many repetitions.

        // Original code, did the same and worked off a temp stack copy.
        var temp = self.*;

        for (0..GRID_SIZE) |x| {
            for (0..GRID_SIZE) |y| {
                // Swap with the cell above and check
                if (y > 0) {
                    temp.swap(x, y, x, y - 1);

                    const tempChecks = try temp.check(allocator);
                    defer tempChecks.deinit();

                    if (!tempChecks.empty()) {
                        try results.append(co.Coord{ .x = x, .y = y });
                    }

                    temp.swap(x, y, x, y - 1);
                }

                // Swap with the cell below and check
                if (y < 7) {
                    temp.swap(x, y, x, y + 1);

                    const tempChecks = try temp.check(allocator);
                    defer tempChecks.deinit();

                    if (!tempChecks.empty()) {
                        try results.append(co.Coord{ .x = x, .y = y });
                    }

                    temp.swap(x, y, x, y + 1);
                }

                // Swap with the cell to the left and check
                if (x > 0) {
                    temp.swap(x, y, x - 1, y);

                    const tempChecks = try temp.check(allocator);
                    defer tempChecks.deinit();

                    if (!tempChecks.empty()) {
                        try results.append(co.Coord{ .x = x, .y = y });
                    }

                    temp.swap(x, y, x - 1, y);
                }

                // Swap with the cell to the right and check
                if (x < 7) {
                    temp.swap(x, y, x + 1, y);

                    const tempChecks = try temp.check(allocator);
                    defer tempChecks.deinit();

                    if (!tempChecks.empty()) {
                        try results.append(co.Coord{ .x = x, .y = y });
                    }

                    temp.swap(x, y, x + 1, y);
                }
            }
        }

        return results;
    }

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
