const std = @import("std");
const gi = @import("game_indicators.zig");
const gb = @import("game_board.zig");
const goImg = @import("go_image.zig");
const goFont = @import("go_font.zig");
const goWin = @import("go_window.zig");
const c = @import("cdefs.zig").c;
const st = @import("state.zig");

/// Instead of doing another level of inheritance, the ONLY thing
/// different between StateGameEndless vs StateGameTimetrial
/// (in referring to the original game) is that they each
/// have a different update method implementation.
/// So, I will just use an additional enum flag for the different
/// styles of game play, and one common update method that dispatches
/// to either sub update methods.
const tGameStyle = enum {
    eEndless,
    eTimetrial,
};

const tState = enum {
    eInitial,
    eStartLoading,
    eSteady,
};

pub const StateGame = struct {
    allocator: std.mem.Allocator = undefined,

    /// Game Style
    mStyle: tGameStyle,

    /// Current state
    mState: tState = undefined,

    mGame: *goWin.GoWindow = undefined,

    /// Left side of UI
    mGameIndicators: gi.GameIndicators = undefined,

    /// Right side of the UI
    mGameBoard: gb.GameBoard = undefined,

    /// Starting time
    mTimeStart: f64 = undefined,

    /// Loading screen image
    mImgLoadingBanner: goImg.GoImage = undefined,

    // Background image
    mImgBoard: goImg.GoImage = undefined,

    /// Flag that indicates whether the user is clicking
    mMousePressed: bool = false,

    const Self = @This();

    pub fn init(style: tGameStyle, g: *goWin.GoWindow, allocator: std.mem.Allocator) !Self {
        return Self{
            .allocator = allocator,
            .mGame = g,
            .mStyle = style,
        };
    }

    pub fn deinit(self: *Self) void {
        self.mGameBoard.deinit();
    }

    pub fn setup(ptr: *anyopaque) anyerror!void {
        const self: *Self = @alignCast(@ptrCast(ptr));

        self.setState(.eInitial);

        // Initialise game indicator
        self.mGameIndicators = gi.GameIndicators.init();
        self.mGameIndicators.setGame(self.mGame, self);

        // Initialise game board
        self.mGameBoard = gb.GameBoard.init(self.allocator);
        try self.mGameBoard.setGame(self.mGame, self);

        // Load the loading screen
        var tempLoadingFont = goFont.GoFont.init();
        try tempLoadingFont.setAll(self.mGame, "media/fuenteMenu.ttf", 64);

        self.mImgLoadingBanner = tempLoadingFont.renderText(
            "Loading...",
            c.SDL_Color{
                .r = 255,
                .g = 255,
                .b = 255,
                .a = 255,
            },
        );
    }

    pub fn update(ptr: *anyopaque) !void {
        const self: *Self = @alignCast(@ptrCast(ptr));

        switch (self.mStyle) {
            .eEndless => try self.updateEndless(),
            .eTimetrial => try self.updateTimetrial(),
        }
    }

    pub fn updateEndless(self: *Self) !void {
        // On the eInitial state, don't do anything about logic
        if (self.mState == .eInitial) {
            return;
        }

        // On this state, start loading the resources
        else if (self.mState == .eStartLoading) {
            try self.loadResources();
            self.setState(.eSteady);

            // Start the clock
            self.resetTime();

            self.mGameIndicators.disableTime();

            // Reset the scoreboard
            try self.mGameIndicators.setScore(0);
        }

        try self.mGameBoard.update();
    }

    pub fn updateTimetrial(self: *Self) !void {
        // On the eInitial state, don't do anything about logic
        if (self.mState == .eInitial) {
            return;
        }

        // On this state, start loading the resources
        else if (self.mState == .eStartLoading) {
            try self.loadResources();
            self.setState(.eSteady);

            // Start the clock
            self.resetTime();

            self.mGameIndicators.enableTime();

            // Reset the scoreboard
            try self.mGameIndicators.setScore(0);
        }

        // Compute remaining time
        const remainingTime: f64 = (self.mTimeStart - @as(f64, @floatFromInt(c.SDL_GetTicks()))) / 1000.0;

        try self.mGameIndicators.updateTime(remainingTime);

        if (remainingTime <= 0) {
            // Tell the board that the game ended with the given score
            try self.mGameBoard.endGame(self.mGameIndicators.getScore());
        }

        try self.mGameBoard.update();
    }

    pub fn draw(ptr: *anyopaque) anyerror!void {
        const self: *Self = @alignCast(@ptrCast(ptr));

        // On this state, show the loading screen and switch the state
        if (self.mState == .eInitial) {
            try self.mImgLoadingBanner.draw(280, 250, 2);
            self.setState(.eStartLoading);
            return;
        }

        // In all the other states, the full window is drawn
        try self.mImgBoard.draw(0, 0, 0);

        // Draw the indicators (buttons and labels)
        try self.mGameIndicators.draw();

        // Draw the main game board
        try self.mGameBoard.draw();
    }

    pub fn buttonDown(ptr: *anyopaque, button: c.SDL_Keycode) anyerror!void {
        const self: *Self = @alignCast(@ptrCast(ptr));

        if (button == c.SDLK_ESCAPE) {
            try self.mGame.changeState("stateMainMenu");
        } else if (button == c.SDLK_h) {
            try self.showHint();
        } else {
            try self.mGameBoard.buttonDown(button);
        }
    }

    pub fn buttonUp(ptr: *anyopaque, button: c.SDL_Keycode) anyerror!void {
        _ = ptr;
        _ = button;
        // No implementation at this time.
    }

    // void StateGame::controllerButtonDown(Uint8 button)
    // {
    //     if (button == SDL_CONTROLLER_BUTTON_START) {
    //         mGame -> changeState("stateMainMenu");
    //     } else if (button == SDL_CONTROLLER_BUTTON_BACK) {
    //         resetGame();
    //     } else {
    //         mGameBoard.controllerButtonDown(button);
    //     }
    // }

    pub fn mouseDown(ptr: *anyopaque, button: u8) anyerror!void {
        const self: *Self = @alignCast(@ptrCast(ptr));

        // Left mouse button was pressed
        if (button == c.SDL_BUTTON_LEFT) {
            self.mMousePressed = true;

            // Get click location
            const mouseX = self.mGame.getMouseX();
            const mouseY = self.mGame.getMouseY();

            // Inform the UI
            try self.mGameIndicators.click(mouseX, mouseY);

            // Inform the board
            try self.mGameBoard.mouseButtonDown(mouseX, mouseY);
        }
    }

    pub fn mouseUp(ptr: *anyopaque, button: u8) anyerror!void {
        const self: *Self = @alignCast(@ptrCast(ptr));

        // Left mouse button was released
        if (button == c.SDL_BUTTON_LEFT) {
            self.mMousePressed = false;

            // Get click location
            const mouseX = self.mGame.getMouseX();
            const mouseY = self.mGame.getMouseY();

            // Inform the board
            try self.mGameBoard.mouseButtonUp(mouseX, mouseY);
        }
    }

    pub fn setState(self: *Self, state: tState) void {
        self.mState = state;
    }

    // ----------------------------------------------------------------------------

    pub fn loadResources(self: *Self) !void {
        // Load the background image
        _ = try self.mImgBoard.setWindowAndPath(self.mGame, "media/board.png");

        try self.mGameIndicators.loadResources();
        try self.mGameBoard.loadResources();
    }

    pub fn resetGame(self: *Self) !void {
        try self.mGameIndicators.setScore(0);
        self.resetTime();
        try self.mGameBoard.resetGame();
    }

    pub fn resetTime(self: *Self) void {
        // Default time is 2 minutes
        self.mTimeStart = @as(f64, @floatFromInt(c.SDL_GetTicks())) + 2 * 60 * 1000;
    }

    pub fn showHint(self: *Self) !void {
        try self.mGameBoard.showHint();
    }

    pub fn increaseScore(self: *Self, amount: i32) !void {
        try self.mGameIndicators.increaseScore(amount);
    }

    pub fn getScore(self: Self) i32 {
        return self.mGameIndicators.getScore();
    }

    pub fn stater(self: *Self, game: *goWin.GoWindow) st.State {
        self.mGame = game;
        return st.State{
            .ptr = self,
            .setupFn = setup,
            .updateFn = update,
            .drawFn = draw,
            .buttonDownFn = buttonDown,
            .buttonUpFn = buttonUp,
            .mouseDownFn = mouseDown,
            .mouseUpFn = mouseUp,
        };
    }
};
