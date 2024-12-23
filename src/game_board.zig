const std = @import("std");
const co = @import("coord.zig");
const mm = @import("multi_match.zig");
const brd = @import("board.zig");
const goImg = @import("go_image.zig");
const goWin = @import("go_window.zig");
const c = @import("cdefs.zig").c;
const fs = @import("floating_score.zig");

pub const tState = enum {
    eNoBoard,
    eBoardAppearing,
    eBoardFilling,
    eBoardDisappearing,
    eSteady,
    eGemSelected,
    eGemSwitching,
    eGemDisappearing,
    eTimeFinished,
    eShowingScoreTable,
};

/// Visual representation of a Board, basically the UI.
pub const GameBoard = struct {
    allocator: std.mem.Allocator,

    mState: tState = .eNoBoard,

    // mStateGame: *StateGame,

    // Parent game.
    mGame: *goWin.GoWindow,

    /// Coordinates for the selected square (if any)
    mSelectedSquareFirst: co.Coord,

    /// Coordinates for the second selected square
    mSelectedSquareSecond: co.Coord,

    /// Container for the grouped squares
    mGroupedSquares: ?mm.MultiMatch = null,

    /// The game board - raw in-memory datastructure representation.
    mBoard: brd.Board = undefined,

    /// Hint
    //GameHint mHint;

    /// Imágenes de las partículas
    mImgParticle1: goImg.GoImage,
    mImgParticle2: goImg.GoImage,

    /// Image for the gem selector
    mImgSelector: goImg.GoImage,

    mImgWhite: goImg.GoImage,
    mImgRed: goImg.GoImage,
    mImgPurple: goImg.GoImage,
    mImgOrange: goImg.GoImage,
    mImgGreen: goImg.GoImage,
    mImgYellow: goImg.GoImage,
    mImgBlue: goImg.GoImage,

    /// Animation current step
    mAnimationCurrentStep: i32 = 0,

    /// Long animation total steps
    mAnimationLongTotalSteps: i32 = 50,

    /// Short animation total steps
    mAnimationShortTotalSteps: i32 = 17,

    /// Current score multiplier
    mMultiplier: i32 = 1,

    /// Group of floating scores. There may be some at the same time.
    //vector<FloatingScore> mFloatingScores;
    mFloatingScores: std.ArrayList(fs.FloatingScore) = undefined,

    /// Group of particle systems
    //vector<ParticleSystem> mParticleSet;

    /// Reference to the score table
    //std::shared_ptr<ScoreTable> scoreTable;

    // The position of the selector square on the board
    mSelectorX: i32 = 3,
    mSelectorY: i32 = 3,

    // Track if a hint is used, to prevent score increases when so
    mHintUsed: bool = false,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
            .mFloatingScores = std.ArrayList(fs.FloatingScore).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        if (self.mGroupedSquares) |gs| {
            gs.deinit();
            self.mGroupedSquares = null;
        }

        self.mFloatingScores.deinit();
        // TODO: self.mParticleSet.deinit();
    }

    // Public below
    pub fn setGame(self: *Self, game: *goWin.GoWindow, stateGame: u8) !void {
        self.mGame = game;
        //self.mStateGame = stateGame;

        self.mBoard = brd.Board.init(self.allocator);
        try self.mBoard.generate();

        self.mState = .eBoardAppearing;
        self.mAnimationCurrentStep = 0;
    }

    pub fn resetGame(self: *Self) void {
        // Game can only be reset on the steady state, or when the Game.has ended
        if (self.mState != .eSteady and self.mState != .eShowingScoreTable)
            return;

        // Reset the variables
        self.mMultiplier = 0;
        self.mAnimationCurrentStep = 0;

        // If there's a board on screen, make it disappear first
        if (self.mState != .eShowingScoreTable) {
            // Drop all gems
            self.mBoard.dropAllGems();

            // Switch state
            self.mState = .eBoardDisappearing;
        }
        // Otherwise, directly generate and show the new board
        else {
            // Generate a brand new board
            try self.mBoard.generate();

            // Switch state
            self.mState = .eBoardAppearing;
        }
    }

    pub fn endGame(self: *Self, score: i32) void {
        if (self.mState == .eTimeFinished or self.mState == .eShowingScoreTable) {
            return;
        }

        self.mBoard.dropAllGems();
        self.mState = .eTimeFinished;

        // TODO: Generate the score table
        _ = score;
        //scoreTable = std::make_shared<ScoreTable>(mGame, score, mGame->getCurrentState());
    }

    pub fn loadResources(self: *Self) void {
        self.mImgWhite.setWindowAndPath(self.mGame, "media/gemWhite.png");
        self.mImgRed.setWindowAndPath(self.mGame, "media/gemRed.png");
        self.mImgPurple.setWindowAndPath(self.mGame, "media/gemPurple.png");
        self.mImgOrange.setWindowAndPath(self.mGame, "media/gemOrange.png");
        self.mImgGreen.setWindowAndPath(self.mGame, "media/gemGreen.png");
        self.mImgYellow.setWindowAndPath(self.mGame, "media/gemYellow.png");
        self.mImgBlue.setWindowAndPath(self.mGame, "media/gemBlue.png");

        // Load the image for the square selector
        self.mImgSelector.setWindowAndPath(self.mGame, "media/selector.png");

        // Load the images for the particles
        self.mImgParticle1.setWindowAndPath(self.mGame, "media/partc1.png");
        self.mImgParticle2.setWindowAndPath(self.mGame, "media/partc2.png");

        // Initialise the hint
        //self.mHint.setWindow(self.mGame);

        // Initialise the sounds
        self.mGame.getGameSounds().loadResources();
    }

    pub fn update(self: *Self) void {
        // Default state, do nothing
        if (self.mState == .eSteady) {
            self.mMultiplier = 0;
            self.mAnimationCurrentStep = 0;
        }

        // Board appearing, gems are falling
        else if (self.mState == .eBoardAppearing) {
            // Update the animation frame
            self.mAnimationCurrentStep += 1;

            // If the Animation.has finished, switch to steady state
            if (self.mAnimationCurrentStep == self.mAnimationLongTotalSteps) {
                self.mState = .eSteady;
            }
        }

        // Two winning gems are switching places
        else if (self.mState == .eGemSwitching) {
            // Update the animation frame
            self.mAnimationCurrentStep += 1;

            // If the Animation.has finished, matching gems should disappear
            if (self.mAnimationCurrentStep == self.mAnimationShortTotalSteps) {
                // Winning games should disappear
                self.mState = .eGemDisappearing;

                // Reset the animation
                self.mAnimationCurrentStep = 0;

                // Swap the gems in the board
                self.mBoard.swap(
                    self.mSelectedSquareFirst.x,
                    self.mSelectedSquareFirst.y,
                    self.mSelectedSquareSecond.x,
                    self.mSelectedSquareSecond.y,
                );

                // Increase the mMultiplier
                self.mMultiplier += 1;

                // Play matching sound
                self.playMatchSound();

                // Create floating scores for the matching group
                self.createFloatingScores();
            }
        }

        // Matched gems are disappearing
        else if (self.mState == .eGemDisappearing) {
            // Update the animation frame
            self.mAnimationCurrentStep += 1;

            // If the Animation.has finished
            if (self.mAnimationCurrentStep == self.mAnimationShortTotalSteps) {
                // Empty spaces should be filled with new gems
                self.mState = .eBoardFilling;

                // Delete the squares that were matched in the board
                if (self.mGroupedSquares) |gs| {
                    for (gs.super.items, 0..) |*m, i| {
                        for (m.super.items, 0..) |_, j| {
                            const crd = gs.at(i, j);
                            self.mBoard.del(crd.x, crd.y);
                        }
                    }

                    // r.c. - not in the original code, but once we've called mBoard.del
                    // we should be able to also .deinit self.mGroupedSquares
                    // because they're no longer needed or referenced.
                    self.mGroupedSquares.?.deinit();
                    self.mGroupedSquares = null;
                }

                // Calculate fall movements
                self.mBoard.calcFallMovements();

                // Reset the animation
                self.mAnimationCurrentStep = 0;
            }
        }

        // New gems are falling to their proper places
        else if (self.mState == .eBoardFilling) {
            // Update the animation frame
            self.mAnimationCurrentStep += 1;

            // If the Animation.has finished
            if (self.mAnimationCurrentStep == self.mAnimationShortTotalSteps) {
                // Play the fall sound
                self.mGame.getGameSounds().playSoundFall();

                // Switch to the normal state
                self.mState = .eSteady;

                // Allow getting points again if a hint was used
                self.mHintUsed = false;

                // Reset the animation
                self.mAnimationCurrentStep = 0;

                // Reset animations in the board
                self.mBoard.endAnimations();

                // Check if there are matching groups
                if (self.mGroupedSquares) |_| {
                    // Ensure deallocation of previously allocated.
                    self.mGroupedSquares.?.deinit();
                }
                self.mGroupedSquares = try self.mBoard.check();

                // If there are...
                if (!self.mGroupedSquares.empty()) {
                    // Increase the score mMultiplier
                    self.mMultiplier += 1;

                    // Create the floating scores
                    // TODO: self.createFloatingScores();

                    // Play matching sound
                    self.playMatchSound();

                    // Go back to the gems-fading mState
                    self.mState = .eGemDisappearing;
                }

                // If there are neither current solutions nor possible future solutions
                // Note: converted else if => else with nested if check because
                // I must ensure sols is reclaimed.
                else {
                    const sols = try self.mBoard.solutions();
                    defer sols.deinit();
                    if (sols.empty()) {
                        if (std.mem.eql(u8, self.mGame.getCurrentState(), "stateGameEndless")) {
                            self.endGame(self.mStateGame.getScore());
                        } else {
                            // Make the board disappear
                            self.mState = .eBoardDisappearing;

                            // Make all the gems want to go outside the board
                            self.mBoard.dropAllGems();
                        }
                    }
                }
            }
        }

        // The entire board is disappearing to show a new one
        else if (self.mState == .eBoardDisappearing) {
            // Update the animation frame
            self.mAnimationCurrentStep += 1;

            // If the Animation.has finished
            if (self.mAnimationCurrentStep == self.mAnimationLongTotalSteps) {
                // Reset animation counter
                self.mAnimationCurrentStep = 0;

                // Generate a brand new board
                self.mBoard.generate();

                // Switch state
                self.mState = .eBoardAppearing;
            }
        }

        // The board is disappearing because the time has run out
        else if (self.mState == .eTimeFinished) {
            // Update the animation frame
            self.mAnimationCurrentStep += 1;

            // If the Animation.has finished
            if (self.mAnimationCurrentStep == self.mAnimationLongTotalSteps) {
                // Reset animation counter
                self.mAnimationCurrentStep = 0;

                // Switch state
                self.mState = .eShowingScoreTable;
            }
        }

        // Remove the hidden floating score
        // NOTE: First iteration, is to capture what needed to be removed.
        // Second iteration is to actually do the removal.
        // I use this technique because iteration + mutation will invalidate pointers.
        var floaterIndicesBuf: [10]usize = undefined;
        var floatIdx: usize = 0;
        for (self.mFloatingScores.items, 0..) |*floater, idx| {
            if (floater.ended()) {
                floaterIndicesBuf[floatIdx] = idx;
                floatIdx += 1;
            }
        }
        for (0..floatIdx) |idx| {
            // swapRemove is known as a "swap and pop" which means
            // if order doesn't matter a swap occurs with the last item.
            // Then the last item is popped. This technique avoids having
            // to shift and copy shit around.
            _ = self.mFloatingScores.swapRemove(idx);
        }

        // TODO: Remove the hiden particle systems
        // mParticleSet.erase(
        //     remove_if (mParticleSet.begin(),
        //             mParticleSet.end(),
        //             std::bind<bool>(&ParticleSystem::ended, _1)),
        //     mParticleSet.end());
    }

    pub fn draw(self: *Self) void {
        // TODO
    }

    pub fn mouseButtonDown(self: *Self, mouseX: i32, mouseY: i32) void {
        // A gem was clicked
        if (self.overGem(mouseX, mouseY)) {
            const mouseCoords = self.getCoord(mouseX, mouseY);
            self.mSelectorX = mouseCoords.x;
            self.mSelectorY = mouseCoords.y;
            self.selectGem();
        }
    }

    pub fn mouseButtonUp(self: *Self, mX: i32, mY: i32) void {
        if (self.mState == .eGemSelected) {
            // Get the coordinates where the mouse was released
            const res = self.getCoord(mX, mY);

            // If the square is different from the previously selected one
            if (res != self.mSelectedSquareFirst and self.checkSelectedSquare()) {
                // Switch the state and reset the animation
                self.mState = .eGemSwitching;
                self.mAnimationCurrentStep = 0;
            }
        }
    }

    pub fn buttonDown(self: *Self, button: c.SDL_Keycode) void {
        switch (button) {
            c.SDLK_LEFT => {
                self.mGame.getGameSounds().playSoundSelect();
                self.moveSelector(-1, 0);
            },

            c.SDLK_RIGHT => {
                self.mGame.getGameSounds().playSoundSelect();
                self.moveSelector(1, 0);
            },

            c.SDLK_UP => {
                self.mGame.getGameSounds().playSoundSelect();
                self.moveSelector(0, -1);
            },

            c.SDLK_DOWN => {
                self.mGame.getGameSounds().playSoundSelect();
                self.moveSelector(0, 1);
            },

            c.SDLK_SPACE => {
                self.selectGem();
            },
            else => {},
        }
    }

    // pub fn controllerButtonDown(Uint8 button) void {
    //     // TODO
    // }

    pub fn showHint(self: *Self) !void {
        if (self.mState == .eSteady) {
            // Make sure no points can be earned next turn
            self.mHintUsed = true;

            // Get possible hint locations
            const hintLocations = try self.mBoard.solutions();
            defer hintLocations.deinit();

            // Start hint animation
            self.mHint.showHint(hintLocations.items[0]);
        }
    }

    // Private below

    // Tests if the mouse is over a gem
    fn overGem(self: Self, mX: i32, mY: i32) bool {
        _ = self;
        // WARN: hardcoded nonsense here.
        return (mX > 241 and mX < 241 + 65 * 8 and
            mY > 41 and mY < 41 + 65 * 8);
    }

    // /// Returns the coords of the gem the mouse is over
    fn getCoord(self: Self, mX: i32, mY: i32) co.Coord {
        _ = self;
        return co.Coord{
            .x = (mX - 241) / 65,
            .y = (mY - 41) / 65,
        };
    }

    // // Checks if the newly selected square has formed a matching groups
    fn checkSelectedSquare(self: *Self) bool {
        // Get the selected square
        // WARN: hardcoded nonsense here, too.
        self.mSelectedSquareSecond = self.getCoord(
            241 + self.mSelectorX * 65,
            41 + self.mSelectorY * 65,
        );

        // If it's a contiguous square
        if (@abs(self.mSelectedSquareFirst.x - self.mSelectedSquareSecond.x) +
            @abs(self.mSelectedSquareFirst.y - self.mSelectedSquareSecond.y) == 1)
        {
            // Create a temporal board with the movement already performed
            var temporal = self.mBoard;
            temporal.swap(self.mSelectedSquareFirst.x, self.mSelectedSquareFirst.y, self.mSelectedSquareSecond.x, self.mSelectedSquareSecond.y);

            // Check if there are grouped gems in that new board
            if (self.mGroupedSquares != null) {
                // Any previous ones, must be reclaimed ya'll.
                self.mGroupedSquares.?.deinit();
            }
            self.mGroupedSquares = try temporal.check();

            // If there are winning movements
            if (!self.mGroupedSquares.?.empty()) {
                return true;
            }
        }

        return false;
    }

    // // Moves the selector square a specific amount from the current position
    fn moveSelector(self: *Self, x: i32, y: i32) void {
        self.mSelectorX += x;
        self.mSelectorY += y;

        if (self.mSelectorX < 0) {
            self.mSelectorX = 7;
        } else if (self.mSelectorY < 0) {
            self.mSelectorY = 7;
        } else if (self.mSelectorX > 7) {
            self.mSelectorX = 0;
        } else if (self.mSelectorY > 7) {
            self.mSelectorY = 0;
        }
    }

    // // Activates the currently selected square for matching
    fn selectGem(self: *Self) void {
        self.mGame.getGameSounds().playSoundSelect();

        if (self.mState == .eSteady) {
            self.mState = .eGemSelected;

            self.mSelectedSquareFirst.x = self.mSelectorX;
            self.mSelectedSquareFirst.y = self.mSelectorY;
        }
        // If there was previous a gem selected
        else if (self.mState == .eGemSelected) {
            // If the newly clicked gem is a winning one
            if (self.checkSelectedSquare()) {
                // Switch the state and reset the animation
                self.mState = .eGemSwitching;
                self.mAnimationCurrentStep = 0;
            } else {
                self.mState = .eSteady;
                self.mSelectedSquareFirst.x = -1;
                self.mSelectedSquareFirst.y = -1;
            }
        }
    }

    /// Creates a small label that indicates the points generated by a match
    fn createFloatingScores(self: *Self) !void {
        // Do not grant points if a hint was used
        var pointsPerGem: i32 = 5;
        if (self.mHintUsed) {
            pointsPerGem = 0;
        }

        // For each match in the group of matched squares
        if (self.mGroupedSquares) |gs| {
            for (gs.super.items) |*m| {
                const score = m.size() * pointsPerGem * self.mMultiplier;

                // Create a new floating score image
                try self.mFloatingScores.append(try fs.FloatingScore.init(
                    self.mGame,
                    score,
                    m.midSquare().x.?,
                    m.midSquare().y.?,
                    80,
                ));

                // TODO particles soon.
                // Create a new particle system for it to appear over the square
                // for(size_t i = 0, s = m.size(); i < s; ++i)
                // {
                //     mParticleSet.emplace_back(ParticleSystem(&mImgParticle1, &mImgParticle2,
                //         50, 50,
                //         241 + m[i].x * 65 + 32,
                //         41 + m[i].y * 65 + 32, 60, 0.5));

                // }

                self.mStateGame.increaseScore(score);
            }
        }
    }

    // /// Plays the proper match sound depending on the current multiplier
    fn playMatchSound(self: Self) void {
        if (self.mMultiplier == 1) {
            self.mGame.getGameSounds().playSoundMatch1();
        } else if (self.mMultiplier == 2) {
            self.mGame.getGameSounds().playSoundMatch2();
        } else {
            self.mGame.getGameSounds().playSoundMatch3();
        }
    }
};
