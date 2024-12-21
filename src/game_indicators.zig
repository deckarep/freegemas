const std = @import("std");
const goWin = @import("go_window.zig");
const goFont = @import("go_font.zig");
const goImg = @import("go_image.zig");
const goMus = @import("go_music.zig");
const om = @import("options_manager.zig");
const bb = @import("base_button.zig");
const c = @import("cdefs.zig").c;

pub const GameIndicators = struct {
    mGame: ?*goWin.GoWindow = null,
    mStateGame: ?u8 = null,

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

    pub fn loadResources(self: *Self) !void {
        // Load the font for the timer
        self.mFontTime.setAll(self.mGame, "media/fuentelcd.ttf", 62);

        // Load the font for the scoreboard
        self.mFontScore.setAll(self.mGame, "media/fuentelcd.ttf", 33);

        // // Font to render some headers
        var tempHeaderFont = goFont.GoFont.init();
        tempHeaderFont.setAll(self.mGame, "media/fuenteNormal.ttf", 37);

        const headerColor = c.SDL_Color{
            .r = 160,
            .g = 169,
            .b = 255,
            .a = 255,
        };

        const headerShadow = c.SDL_Color{
            .r = 0,
            .g = 0,
            .b = 0,
            .a = 128,
        };

        self.mImgScoreHeader = tempHeaderFont.renderTextWithShadow("score", headerColor, 1, 1, headerShadow);
        self.mImgTimeHeader = tempHeaderFont.renderTextWithShadow("time left", headerColor, 1, 1, headerShadow);

        // Load the background image for the time
        _ = try self.mImgTimeBackground.setWindowAndPath(self.mGame, "media/timeBackground.png");

        // Load the background image for the scoreboard
        _ = try self.mImgScoreBackground.setWindowAndPath(self.mGame, "media/scoreBackground.png");

        // Buttons
        try self.mHintButton.set(self.mGame, "Show hint", "iconHint.png");
        try self.mResetButton.set(self.mGame, "Reset game", "iconRestart.png");
        try self.mExitButton.set(self.mGame, "Exit", "iconExit.png");

        // Music
        self.options.loadResources();

        if (self.options.getMusicEnabled()) {
            self.sfxSong.setSample("media/music.ogg");
            self.sfxSong.play();
        }
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
        const timeTxtColor = c.SDL_Color{
            .r = 78,
            .g = 193,
            .b = 190,
            .a = 255,
        };

        self.mRemainingTime = time;

        // Only recreate the time string if it's changed
        if (self.mRemainingTime >= 0 and self.mRemainingTime != self.mRemainingTimePrev) {
            const minutes: i32 = @floatFromInt(self.mRemainingTime / 60);
            const seconds: i32 = @floatFromInt(self.mRemainingTime - minutes * 60);

            var buf: [32]u8 = undefined;
            const txtTime = try std.fmt.bufPrintZ(
                &buf,
                "{d}{s}{d}",
                .{
                    minutes,
                    if (seconds < 10) ":0" else ":",
                    seconds,
                },
            );

            self.mImgTime = self.mFontTime.renderText(txtTime, timeTxtColor);
            self.mRemainingTimePrev = self.mRemainingTime;
        }
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
