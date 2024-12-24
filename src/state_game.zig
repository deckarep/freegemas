const gi = @import("game_indicators.zig");
const gb = @import("game_board.zig");
const goImg = @import("go_image.zig");
const goFont = @import("go_font.zig");
const goWin = @import("go_window.zig");
const c = @import("cdefs.zig").c;

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
    /// Game Style
    mStyle: tGameStyle,

    /// Current state
    mState: tState,

    /// Left side of UI
    mGameIndicators: gi.GameIndicators,

    /// Right side of the UI
    mGameBoard: gb.GameBoard,

    /// Starting time
    mTimeStart: f64,

    /// Loading screen image
    mImgLoadingBanner: goImg.GoImage,

    // Background image
    mImgBoard: goImg.GoImage,

    /// Flag that indicates whether the user is clicking
    mMousePressed: bool,

    const Self = @This();

    pub fn init() Self {
        return Self{};
    }

    pub fn setup(self: *Self, p: *goWin.GoWindow) void {
        self.setState(.eInitial);

        // Initialise game indicator
        self.mGameIndicators.setGame(p, self);

        // Initialise game board
        self.mGameBoard.setGame(p, self);

        // Load the loading screen
        var tempLoadingFont = goFont.GoFont.init();
        tempLoadingFont.setAll(self.mGame, "media/fuenteMenu.ttf", 64);

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

    pub fn update(self: *Self) !void {
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
            self.mGameIndicators.setScore(0);
        }

        self.mGameBoard.update();
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
            self.mGameIndicators.setScore(0);
        }

        // Compute remaining time
        const remainingTime: f64 = (self.mTimeStart - @as(f64, @floatCast(c.SDL_GetTicks()))) / 1000.0;

        self.mGameIndicators.updateTime(remainingTime);

        if (remainingTime <= 0) {
            // Tell the board that the game ended with the given score
            self.mGameBoard.endGame(self.mGameIndicators.getScore());
        }

        self.mGameBoard.update();
    }

    pub fn draw(self: *Self) !void {
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

    pub fn buttonDown(self: *Self, button: c.SDL_Keycode) void {
        if (button == c.SDLK_ESCAPE) {
            self.mGame.changeState("stateMainMenu");
        } else if (button == c.SDLK_h) {
            self.showHint();
        } else {
            self.mGameBoard.buttonDown(button);
        }
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

    pub fn mouseButtonDown(self: *Self, button: u8) void {
        // Left mouse button was pressed
        if (button == c.SDL_BUTTON_LEFT) {
            self.mMousePressed = true;

            // Get click location
            const mouseX = self.mGame.getMouseX();
            const mouseY = self.mGame.getMouseY();

            // Inform the UI
            self.mGameIndicators.click(mouseX, mouseY);

            // Inform the board
            self.mGameBoard.mouseButtonDown(mouseX, mouseY);
        }
    }

    pub fn mouseButtonUp(self: *Self, button: u8) void {
        // Left mouse button was released
        if (button == c.SDL_BUTTON_LEFT) {
            self.mMousePressed = false;

            // Get click location
            const mouseX = self.mGame.getMouseX();
            const mouseY = self.mGame.getMouseY();

            // Inform the board
            self.mGameBoard.mouseButtonUp(mouseX, mouseY);
        }
    }

    pub fn setState(self: *Self, state: tState) void {
        self.mState = state;
    }

    // ----------------------------------------------------------------------------

    fn loadResources(self: *Self) !void {
        // Load the background image
        try self.mImgBoard.setWindowAndPath(self.mGame, "media/board.png");

        try self.mGameIndicators.loadResources();
        try self.mGameBoard.loadResources();
    }

    fn resetGame(self: *Self) void {
        self.mGameIndicators.setScore(0);
        self.resetTime();
        self.mGameBoard.resetGame();
    }

    fn resetTime(self: *Self) void {
        // Default time is 2 minutes
        self.mTimeStart = @as(f64, @floatFromInt(c.SDL_GetTicks())) + 2 * 60 * 1000;
    }

    fn showHint(self: *Self) void {
        self.mGameBoard.showHint();
    }

    fn increaseScore(self: *Self, amount: i32) void {
        self.mGameIndicators.increaseScore(amount);
    }

    fn getScore(self: Self) i32 {
        return self.mGameIndicators.getScore();
    }
};
