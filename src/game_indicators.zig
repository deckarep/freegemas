const goWin = @import("go_window.zig");
const goFont = @import("go_font.zig");
const goImg = @import("go_image.zig");
const goMus = @import("go_music.zig");
const om = @import("options_manager.zig");
const bb = @import("base_button.zig");
const c = @import("cdefs.zig").c;

pub const GameIndicators = struct {
    mGame: *goWin.GoWindow = null,

    mScore: i32 = 0,
    mScorePrev: i32 = -1,
    mRemainingTime: f64 = 0,
    mRemainingTimePrev: f64 = 0,
    mTimeEnabled: bool,

    mFontTime: goFont.GoFont,
    mFontScore: goFont.GoFont,

    mImgTimeBackground: goImg.GoImage,
    mImgScoreBackground: goImg.GoImage,

    mImgTime: goImg.GoImage,
    mImgTimeHeader: goImg.GoImage,

    mImgScore: goImg.GoImage,
    mImgScoreHeader: goImg.GoImage,

    mHintButton: bb.BaseButton,
    mResetButton: bb.BaseButton,
    mExitButton: bb.BaseButton,

    sfxSong: goMus.GoMusic,

    options: om.OptionsManager,

    const Self = @This();

    pub fn init() Self {
        return Self{};
    }

    pub fn setGame(self: *Self, g: *goWin.GoWindow, sg: u8) void {
        self.mGame = g;
        self.mStateGame = sg;
    }

    pub fn loadResources(self: *Self) void {
        _ = self;
        // Load the font for the timer
        // mFontTime.setAll(mGame, "media/fuentelcd.ttf", 62);

        // // Load the font for the scoreboard
        // mFontScore.setAll(mGame, "media/fuentelcd.ttf", 33);

        // // Font to render some headers
        // GoSDL::Font tempHeaderFont;
        // tempHeaderFont.setAll(mGame, "media/fuenteNormal.ttf", 37);

        // mImgScoreHeader = tempHeaderFont.renderTextWithShadow(_("score"), {160, 169, 255, 255}, 1, 1, {0, 0, 0, 128});

        // mImgTimeHeader = tempHeaderFont.renderTextWithShadow(_("time left"), {160, 169, 255, 255}, 1, 1, {0, 0, 0, 128});

        // // Load the background image for the time
        // mImgTimeBackground.setWindowAndPath(mGame, "media/timeBackground.png");

        // // Load the background image for the scoreboard
        // mImgScoreBackground.setWindowAndPath(mGame, "media/scoreBackground.png");

        // // Buttons
        // std::string mHintButtonText = _("Show hint");
        // std::string mResetButtonText = _("Reset game");
        // std::string mExitButtonText = _("Exit");

        // #ifdef __vita__
        //     mHintButtonText += std::string(" (/\\)");
        //     mResetButtonText += std::string(" (SEL)");
        //     mExitButtonText += std::string(" (START)");
        // #endif

        // mHintButton.set(mGame,  mHintButtonText.c_str(), "iconHint.png");
        // mResetButton.set(mGame, mResetButtonText.c_str(), "iconRestart.png");
        // mExitButton.set(mGame, mExitButtonText.c_str(), "iconExit.png");

        // // Music
        // options.loadResources();

        // if (options.getMusicEnabled()) {
        //     sfxSong.setSample("media/music.ogg");
        //     sfxSong.play();
        // }
    }

    /// Returns the current score
    pub fn getScore(self: *Self) i32 {
        return self.mScore;
    }

    /// Sets the score to the given amount
    pub fn setScore(self: *Self, score: i32) void {
        self.mScore = score;
        self.regenerateScoreTexture();
    }

    /// Increases the score by the given amount
    pub fn increaseScore(self: *Self, amount: i32) void {
        self.mScore += amount;
        self.regenerateScoreTexture();
    }

    /// Updates the remaining time, the argument is given in seconds
    pub fn updateTime(self: *Self, time: f64) void {
        self.mRemainingTime = time;

        // TODO: below
        // Only recreate the tiem string if it's changed
        // if (mRemainingTime >= 0 && mRemainingTime != mRemainingTimePrevious)
        // {
        //     int minutes = int(mRemainingTime / 60);
        //     int seconds = int(mRemainingTime - minutes * 60);

        //     std::string txtTime = std::to_string(minutes) +
        //         (seconds < 10 ? ":0" : ":") +
        //         std::to_string(seconds);

        //     mImgTime = mFontTime.renderText(txtTime, {78, 193, 190, 255});

        //     mRemainingTimePrevious = mRemainingTime;
        // }
    }

    pub fn disableTime(self: *Self) void {
        self.mTimeEnabled = false;
    }

    pub fn enableTime(self: *Self) void {
        self.mTimeEnabled = true;
    }

    pub fn draw(self: *Self) !void {
        // Vertical initial position for the buttons
        const vertButStart = 407;

        // Draw the buttons
        try self.mHintButton.draw(17, vertButStart, 2);
        try self.mResetButton.draw(17, vertButStart + 47, 2);
        try self.mExitButton.draw(17, 538, 2);

        // Draw the score
        try self.mImgScoreBackground.draw(17, 124, 2);
        try self.mImgScoreHeader.draw(17 + self.mImgScoreBackground.getWidth() / 2 - self.mImgScoreHeader.getWidth() / 2, 84, 3);
        try self.mImgScore.draw(197 - self.mImgScore.getWidth(), 127, 2);

        // Draw the time
        if (self.mTimeEnabled) {
            try self.mImgTimeBackground.draw(17, 230, 2);
            try self.mImgTimeHeader.draw(17 + self.mImgTimeBackground.getWidth() / 2 - self.mImgTimeHeader.getWidth() / 2, 190, 3);
            try self.mImgTime.draw(190 - self.mImgTime.getWidth(), 232, 2);
        }
    }

    pub fn click(self: *Self, mouseX: i32, mouseY: i32) void {
        // Exit button was clicked
        if (self.mExitButton.clicked(mouseX, mouseY)) {
            self.mGame.changeState("stateMainMenu");
        }

        // Hint button was clicked
        else if (self.mHintButton.clicked(mouseX, mouseY)) {
            self.mStateGame.showHint();
        }

        // Reset button was clicked
        else if (self.mResetButton.clicked(mouseX, mouseY)) {
            self.mStateGame.resetGame();
        }
    }

    /// Regenerates the texture for the score, if necessary
    pub fn regenerateScoreTexture(self: *Self) void {
        // Regenerate the texture if the score has changed

        const fc = c.SDL_Color{
            .r = 78,
            .g = 193,
            .b = 190,
            .a = 255,
        };

        if (self.mScore != self.mScorePrev) {
            self.mImgScore = self.mFontScore.renderText(self.mScore, fc);
            self.mScorePrev = self.mScore;
        }
    }
};
