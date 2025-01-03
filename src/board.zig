const std = @import("std");
const sq = @import("square.zig");
const Square = sq.Square;
const SquareType = sq.SquareType;
const utility = @import("utility.zig");
const co = @import("coord.zig");
const mch = @import("match.zig");
const mm = @import("multi_match.zig");

const MAX_GEN_ATTEMPS = 50;
const GRID_SIZE = 8;

pub const Board = struct {
    allocator: std.mem.Allocator,

    /// Matrix of squares
    squares: [GRID_SIZE][GRID_SIZE]Square = undefined,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        std.debug.print("size of SquareType => {d}\n", .{@sizeOf(sq.SquareType)});
        return Self{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: Self) void {
        _ = self;
        // For now, nothing to deinit because the board doesn't do
        // allocations up front. (at this point in time)
    }

    /// Debug function to dump the state of the board.
    pub fn dump(self: Self) void {
        std.debug.print(">>>>>>>>>>>>>>>>>\n", .{});
        for (0..GRID_SIZE) |i| {
            for (0..GRID_SIZE) |j| {
                std.debug.print("{s} ", .{self.squares[i][j].tSquare().String()});
            }
            std.debug.print("\n", .{});
        }
        std.debug.print("<<<<<<<<<<<<<<<<<\n", .{});
    }

    /// Generates a random board.
    pub fn generate(self: *Self) !void {
        var repeat = false;

        // Regenerate if there is a direct solution or if it is impossible
        var iterCount: usize = 0;

        // Converted to a while(true) with the test condition negated.
        // Since the original code was the fugly do/while loop.
        while (true) {
            repeat = false;

            for (0..GRID_SIZE) |i| {
                for (0..GRID_SIZE) |j| {
                    self.squares[i][j] = Square{};
                    self.squares[i][j].sqType = @enumFromInt(@as(usize, @intCast(@mod(try utility.getRandomIntValue(), 7))) + 1);
                    self.squares[i][j].mustFall = true;
                    self.squares[i][j].origY = @mod(try utility.getRandomIntValue(), 8) - 9;
                    self.squares[i][j].destY = @intCast(@as(i32, @intCast(j)) - self.squares[i][j].origY);
                }
            }

            std.debug.print("intermedia board:\n", .{});
            self.dump();

            const matchesCheck = try self.check();
            defer matchesCheck.deinit();
            if (!matchesCheck.empty()) {
                // Generated Board has matches. Repeating...

                // r.c. - In other words, we don't want to start with a board that already
                // needs to cascade. It must start stable.
                repeat = true;
            } else {
                const sol = try self.solutions();
                defer sol.deinit();
                if (sol.items.len == 0) {
                    // Generated Board has no solutions. Repeating...

                    // r.c. - In other words, we must start with a board that is solvable.
                    // Otherwise the player already lost before they've even begun. So sad.
                    repeat = true;
                }
            }

            // DEBUG CODE HERE.
            iterCount += 1;
            if (iterCount >= MAX_GEN_ATTEMPS) {
                std.debug.print("bailing after {d} iters...\n", .{MAX_GEN_ATTEMPS});
            }

            if (!repeat) break;
        }

        // When our loop exits its because:
        // The generated Board has no direct matches but some possible solutions.
        // So the board is now ready.
        std.debug.print("final board generated after {d} iters...\n", .{iterCount});
    }

    /// Swaps squares x1,y1 and x2,y2
    pub fn swap(self: *Self, x1: usize, y1: usize, x2: usize, y2: usize) void {
        const temp = self.squares[x1][y1];

        self.squares[x1][y1] = self.squares[x2][y2];
        self.squares[x2][y2] = temp;
    }

    /// Empties square (x,y)
    pub fn del(self: *Self, x: usize, y: usize) void {
        self.squares[x][y] = Square{ .sqType = .sqEmpty };
    }

    /// Calculates squares' positions after deleting the matching gems, also filling the new spaces
    pub fn calcFallMovements(self: *Self) !void {
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
                    self.squares[x][@intCast(y)].origY = y;

                    // If the current square is empty, every square above it should fall one position
                    if (self.squares[x][@intCast(y)].tSquare() == .sqEmpty) {
                        var k = y - 1;
                        while (k >= 0) : (k -= 1) {
                            self.squares[x][@intCast(k)].mustFall = true;
                            self.squares[x][@intCast(k)].destY += 1;
                        }
                    }
                }

                // Now that each square has its new position in their destY property,
                // let's move them to that final position
                y = 7;
                while (y >= 0) : (y -= 1) {
                    // If the square is not empty and has to fall, move it to the new position
                    if (self.squares[x][@intCast(y)].mustFall and self.squares[x][@intCast(y)].tSquare() != .sqEmpty) {
                        const y0 = self.squares[x][@intCast(y)].destY;
                        self.squares[x][@as(usize, @intCast(y)) + y0] = self.squares[x][@intCast(y)];
                        // r.c. - not sure if this is equivilent, original code set the entire object to .sqEmpty.
                        // This could have introduced a bug...check on it.
                        self.squares[x][@intCast(y)].sqType = .sqEmpty;
                    }
                }
            }

            // Finally, let's count how many new empty spaces there are so we can fill
            // them with new random gems
            var emptySpaces: usize = 0;

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
                    self.squares[x][y].sqType = @enumFromInt(@mod(try utility.getRandomIntValue(), 7) + 1);

                    self.squares[x][y].mustFall = true;
                    self.squares[x][y].origY = @as(i32, @intCast(y)) - @as(i32, @intCast(emptySpaces));
                    self.squares[x][y].destY = emptySpaces;
                }
            }
        }
    }

    /// Places all the gems out of the screen
    pub fn dropAllGems(self: *Self) !void {
        for (0..GRID_SIZE) |x| {
            for (0..GRID_SIZE) |y| {
                self.squares[x][y].mustFall = true;
                self.squares[x][y].origY = @intCast(y);
                self.squares[x][y].destY = @intCast(9 + @mod(try utility.getRandomIntValue(), 8));
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
    pub fn check(self: *Self) !mm.MultiMatch {
        const start = try std.time.Instant.now();
        std.debug.print("board::check started...\n", .{});

        // r.c. better expressed as a usize vs i32.
        var k: usize = undefined;

        // WARN: In terms of memory leaks I *think* I accounted for all cases.
        // For Zig, I added a cleanupHook to capture anything NOT added to
        // the returned multi match. This way, those allocations while never
        // returned to the caller can still be cleaned up.

        var matches = mm.MultiMatch.init(self.allocator);
        var cleanupHook = mm.MultiMatch.init(self.allocator);
        defer cleanupHook.deinit(); // Always fire deinit whether its populated or not.

        // First, we check each row (horizontal)
        for (0..GRID_SIZE) |y| {
            var x: usize = 0;
            while (x < GRID_SIZE - 2) : (x += 1) {
                var currentRow = mch.Match.init(self.allocator);
                try currentRow.pushBack(co.Coord{ .x = x, .y = y });

                k = x + 1;
                while (k < GRID_SIZE) : (k += 1) {
                    if (self.squares[x][y].eql(self.squares[k][y]) and
                        self.squares[x][y].tSquare() != .sqEmpty)
                    {
                        try currentRow.pushBack(co.Coord{ .x = k, .y = y });
                    } else {
                        break;
                    }
                }

                if (currentRow.size() > 2) {
                    try matches.pushBack(currentRow);
                } else {
                    // We must still capture this allocation to ensure cleanup!
                    try cleanupHook.pushBack(currentRow);
                }

                x = k - 1;
            }
        }

        // Next, check each column (vertical)
        for (0..GRID_SIZE) |x| {
            var y: usize = 0;
            while (y < GRID_SIZE - 2) : (y += 1) {
                var currentColumn = mch.Match.init(self.allocator);
                try currentColumn.pushBack(co.Coord{ .x = x, .y = y });

                k = y + 1;
                while (k < GRID_SIZE) : (k += 1) {
                    if (self.squares[x][y].eql(self.squares[x][k]) and
                        self.squares[x][y].tSquare() != .sqEmpty)
                    {
                        try currentColumn.pushBack(co.Coord{ .x = x, .y = k });
                    } else {
                        break;
                    }
                }

                if (currentColumn.size() > 2) {
                    try matches.pushBack(currentColumn);
                } else {
                    // We must still capture this allocation to ensure cleanup!
                    try cleanupHook.pushBack(currentColumn);
                }

                y = k - 1;
            }
        }

        // Measure elapsed.
        const end = try std.time.Instant.now();
        const elapsed: f64 = @floatFromInt(end.since(start));
        std.debug.print("board::check finished in {d:.3}ms...\n", .{elapsed / std.time.ns_per_ms});

        return matches;
    }

    // Low-hanging fruit for optimization
    // 0. ✅ Square methods should be inlined.
    // 1. ✅ As long as at least one move exists, solutions should early return (at least in some cases).
    // 2. Better cache coherency: Both solutions and check could operate on [8][8]SquareType which has a @sizeOf() 64 bytes.
    //    This would be significantly better than what it's doing now: [8][8]Square => @sizeOf() 1024 bytes.

    /// Checks if current Board has any possible valid movements.
    /// NOTE: Caller owns and must .deinit the returned results.
    /// This function is expensive and costs about 120ms+ in debug mode.
    /// And then costs about 13-19ms in ReleaseFast mode.
    /// It does contribute to a little bit of frame stutter in debug mode.
    /// BIG CHANGE: See the optimizations above, 1 and 2 are done.
    /// This means, solutions will early-exit if just ONE match is found.
    /// Currently solutions will never return all solutions found.
    /// If, that is needed, we need to introduce an argument for ALL or just ONE.
    pub fn solutions(self: *Self) !std.ArrayList(co.Coord) {
        var results = std.ArrayList(co.Coord).init(self.allocator);

        // First check, if we have any matches in the current state.
        const matches = try self.check();
        defer matches.deinit();

        if (!matches.empty()) {
            try results.append(co.Coord{ .x = null, .y = null });
            return results;
        }

        const start = try std.time.Instant.now();
        std.debug.print("board::solutions started...\n", .{});

        // Let's check all possible swaps on the board.
        // For an 8x8 grid:
        // - 4 corner cells, each with 2 valid swaps: 4 * 2 = 8 checks
        // - 24 edge cells (excluding corners), each with 3 valid swaps: 24 * 3 = 72 checks
        // - 36 interior cells, each with 4 valid swaps: 36 * 4 = 144 checks
        // Total checks = 8 (corners) + 72 (edges) + 144 (interior) = 224 checks

        // And, if you're counting the first check that occurs above with the early exit:
        // Final total checks = 225.

        // Original code, did the same and worked off a temp stack copy.
        var temp = self.*;

        earlyExit: for (0..GRID_SIZE) |x| {
            for (0..GRID_SIZE) |y| {
                // Swap with the cell above and check
                if (y > 0) {
                    temp.swap(x, y, x, y - 1);

                    const tempChecks = try temp.check();
                    defer tempChecks.deinit();

                    if (!tempChecks.empty()) {
                        try results.append(co.Coord{ .x = x, .y = y });
                        break :earlyExit;
                    }

                    temp.swap(x, y, x, y - 1);
                }

                // Swap with the cell below and check
                if (y < 7) {
                    temp.swap(x, y, x, y + 1);

                    const tempChecks = try temp.check();
                    defer tempChecks.deinit();

                    if (!tempChecks.empty()) {
                        try results.append(co.Coord{ .x = x, .y = y });
                        break :earlyExit;
                    }

                    temp.swap(x, y, x, y + 1);
                }

                // Swap with the cell to the left and check
                if (x > 0) {
                    temp.swap(x, y, x - 1, y);

                    const tempChecks = try temp.check();
                    defer tempChecks.deinit();

                    if (!tempChecks.empty()) {
                        try results.append(co.Coord{ .x = x, .y = y });
                        break :earlyExit;
                    }

                    temp.swap(x, y, x - 1, y);
                }

                // Swap with the cell to the right and check
                if (x < 7) {
                    temp.swap(x, y, x + 1, y);

                    const tempChecks = try temp.check();
                    defer tempChecks.deinit();

                    if (!tempChecks.empty()) {
                        try results.append(co.Coord{ .x = x, .y = y });
                        break :earlyExit;
                    }

                    temp.swap(x, y, x + 1, y);
                }
            }
        }

        // Measure elapsed.
        const end = try std.time.Instant.now();
        const elapsed: f64 = @floatFromInt(end.since(start));
        std.debug.print("board::solutions finished in {d:.3}ms...\n", .{elapsed / std.time.ns_per_ms});
        return results;
    }

    /// Resets squares' animations
    pub fn endAnimations(self: *Self) void {
        for (0..GRID_SIZE) |x| {
            for (0..GRID_SIZE) |y| {
                self.squares[x][y].mustFall = false;
                self.squares[x][y].origY = @intCast(y);
                self.squares[x][y].destY = 0;
            }
        }
    }
};
