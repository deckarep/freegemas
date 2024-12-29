const std = @import("std");
const goWin = @import("go_window.zig");
const goFont = @import("go_font.zig");
const goImg = @import("go_image.zig");
const goMus = @import("go_music.zig");
const om = @import("options_manager.zig");
const bb = @import("base_button.zig");
const c = @import("cdefs.zig").c;
const sg = @import("state_game.zig");
const utility = @import("utility.zig");

pub const GameIndicators = struct {
    mGame: *goWin.GoWindow = undefined,
    mStateGame: *sg.StateGame = undefined,

    mAvatarTicks: usize = 0,
    mAvatarMouthOffset: usize = 0,

    mAvatarEyesAllowedFrames: usize = 0,
    mAvatarEyesOffset: usize = 0,

    mScore: i32 = 0,
    mScorePrev: i32 = -1,
    mRemainingTime: f64 = 0,
    mRemainingTimePrev: f64 = 0,
    mTimeEnabled: bool = false,
    mHintEnabled: bool = false,

    mFontTime: goFont.GoFont = undefined,
    mFontScore: goFont.GoFont = undefined,

    mLampSellerPortrait: goImg.GoImage = goImg.GoImage.init(),
    mLampSellerFaceAnim: goImg.GoImage = goImg.GoImage.init(),

    mBookownerPortrait: goImg.GoImage = goImg.GoImage.init(),
    mBookownerFaceAnim: goImg.GoImage = goImg.GoImage.init(),

    mImgTimeBackground: goImg.GoImage = goImg.GoImage.init(),
    mImgScoreBackground: goImg.GoImage = goImg.GoImage.init(),

    mImgTime: goImg.GoImage = goImg.GoImage.init(),
    mImgTimeHeader: goImg.GoImage = goImg.GoImage.init(),

    mImgScore: goImg.GoImage = goImg.GoImage.init(),
    mImgScoreHeader: goImg.GoImage = goImg.GoImage.init(),

    mHintButton: bb.BaseButton = bb.BaseButton.init(),
    mResetButton: bb.BaseButton = bb.BaseButton.init(),
    mExitButton: bb.BaseButton = bb.BaseButton.init(),

    sfxSong: goMus.GoMusic = goMus.GoMusic.init(),

    options: om.OptionsManager = undefined,

    const Self = @This();

    pub fn init() Self {
        return Self{};
    }

    pub fn setGame(self: *Self, g: *goWin.GoWindow, stateGame: *sg.StateGame) void {
        self.mGame = g;
        self.mStateGame = stateGame;
    }

    pub fn loadResources(self: *Self) !void {
        // Load the font for the timer
        self.mFontTime = goFont.GoFont.init();
        try self.mFontTime.setAll(self.mGame, "media/fuentelcd.ttf", 62);

        // Load the font for the scoreboard
        self.mFontScore = goFont.GoFont.init();
        try self.mFontScore.setAll(self.mGame, "media/fuentelcd.ttf", 33);

        // Font to render some headers
        var tempHeaderFont = goFont.GoFont.init();
        try tempHeaderFont.setAll(self.mGame, "media/fuenteNormal.ttf", 37);

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

        // LampSeller face anim hack

        self.mImgScoreHeader = tempHeaderFont.renderTextWithShadow("score", headerColor, 1, 1, headerShadow);
        self.mImgTimeHeader = tempHeaderFont.renderTextWithShadow("time left", headerColor, 1, 1, headerShadow);

        // Lamp Seller
        _ = try self.mLampSellerPortrait.setWindowAndPath(self.mGame, "media/LampSellerPortrait.png");
        _ = try self.mLampSellerFaceAnim.setWindowAndPath(self.mGame, "media/LampSellerFaceAnimation.png");

        // Book owner
        _ = try self.mBookownerPortrait.setWindowAndPath(self.mGame, "media/BookownerPortrait.png");
        _ = try self.mBookownerFaceAnim.setWindowAndPath(self.mGame, "media/BookownerFaceAnimation.png");

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
            try self.sfxSong.setSample("media/Isle of the Chill (remix).mp3");
            self.sfxSong.play(1);
        }
    }

    /// Returns the current score
    pub fn getScore(self: Self) i32 {
        return self.mScore;
    }

    /// Sets the score to the given amount
    pub fn setScore(self: *Self, score: i32) !void {
        self.mScore = score;
        try self.regenerateScoreTexture();
    }

    /// Increases the score by the given amount
    pub fn increaseScore(self: *Self, amount: i32) !void {
        self.mScore += amount;
        try self.regenerateScoreTexture();
    }

    /// Updates the remaining time, the argument is given in seconds
    pub fn updateTime(self: *Self, time: f64) !void {
        const timeTxtColor = c.SDL_Color{
            .r = 78,
            .g = 193,
            .b = 190,
            .a = 255,
        };

        self.mRemainingTime = time;

        // Only recreate the time string if it's changed
        if (self.mRemainingTime >= 0 and self.mRemainingTime != self.mRemainingTimePrev) {
            const minutes: i32 = @intFromFloat(self.mRemainingTime / 60);
            const seconds: i32 = @as(i32, @intFromFloat(self.mRemainingTime)) - minutes * 60;

            // Compute prev min/sec to compare and not generate so much work.
            const prevMin: i32 = @intFromFloat(self.mRemainingTimePrev / 60);
            const prevSec: i32 = @as(i32, @intFromFloat(self.mRemainingTimePrev)) - minutes * 60;

            // r.c. - added second check, because the time only needs updating when either
            // minutes/seconds differ but since self.mRemainingTime and self.mRemainingTimePrev
            // are stored as f64 they are nearly always different due to precision not being
            // accounted for.
            if (minutes == prevMin and seconds == prevSec) {
                return;
            }

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

    pub fn enableTime(self: *Self) void {
        self.mTimeEnabled = true;
    }

    pub fn disableTime(self: *Self) void {
        self.mTimeEnabled = false;
    }

    pub fn enableHint(self: *Self) void {
        self.mHintEnabled = true;
    }

    pub fn disableHint(self: *Self) void {
        self.mHintEnabled = false;
    }

    pub fn draw(self: *Self) !void {
        // Vertical initial position for the buttons
        //        const vertButStart = 407;

        // Draw the buttons
        // if (self.mHintEnabled) {
        //     // Hint can be disabled for two reasons:
        //     // 1. Game ended, so don't render it.
        //     // 2. TODO: settings to not allow hints.
        //     try self.mHintButton.draw(17, vertButStart, 2);
        // }
        // try self.mResetButton.draw(17, vertButStart + 47, 2);
        // try self.mExitButton.draw(17, 538, 2);

        // Draw the score
        try self.mImgScoreBackground.draw(17, 124, 2);
        try self.mImgScoreHeader.draw(17 + @divTrunc(self.mImgScoreBackground.getWidth(), 2) - @divTrunc(self.mImgScoreHeader.getWidth(), 2), 84, 3);
        try self.mImgScore.draw(197 - self.mImgScore.getWidth(), 127, 3);

        // Draw the time
        if (self.mTimeEnabled) {
            try self.mImgTimeBackground.draw(17, 230, 2);
            try self.mImgTimeHeader.draw(17 + @divTrunc(self.mImgTimeBackground.getWidth(), 2) - @divTrunc(self.mImgTimeHeader.getWidth(), 2), 190, 3);
            try self.mImgTime.draw(190 - self.mImgTime.getWidth(), 232, 3);
        }

        if (true) {
            //if (true) @panic("The lampsellers mouthPt and eyePt must be converted to relative offset from base portrait!");
            // Lampseller!
            const portStaticPt = c.SDL_Point{ .x = 95, .y = 449 }; // top left corner of static character portrait.

            const mouthPt = c.SDL_Point{ .x = 62, .y = 87 }; // top left corner of mouth x/y
            const eyePt = c.SDL_Point{ .x = 62, .y = 18 }; // top left corner of eye x/y

            const totalMouthFrames = 10; // num mouth frames
            const totalEyeFrames = 3; // num eye frames
            // Mouth w/h for single frame.
            const mouthWH = c.SDL_Point{ .x = 32, .y = 44 };
            const eyeWH = c.SDL_Point{ .x = 36, .y = 14 };
            const eyesVertOffset = 46; // eye vertical offset
            // Eye w/h of single frame.
            try self.drawAvatarHack(
                // Portrait
                &self.mLampSellerPortrait,
                &portStaticPt,
                // Face anim below
                &self.mLampSellerFaceAnim,
                &mouthPt,
                &eyePt,
                &mouthWH,
                totalMouthFrames,
                totalEyeFrames,
                eyesVertOffset,
                &eyeWH,
            );
        }

        // TODO: use the KQ6 point score sound effect for gem matching! sound.
        if (false) {
            // Bookowner
            const portStaticPt = c.SDL_Point{ .x = 95, .y = 449 }; // top left corner of static character portrait.

            // These are both relative from portStaticPt.
            const mouthPt = c.SDL_Point{ .x = 62, .y = 84 }; // top left corner of mouth x/y
            const eyePt = c.SDL_Point{ .x = 56, .y = 38 }; // top left corner of eye x/y

            const totalMouthFrames = 10; // num mouth frames
            const totalEyeFrames = 3; // num eye frames
            // Mouth w/h for single frame.
            const mouthWH = c.SDL_Point{ .x = 26, .y = 22 };
            const eyeWH = c.SDL_Point{ .x = 32, .y = 4 };
            const eyesVertOffset = 24; // eye vertical offset
            // Eye w/h of single frame.
            try self.drawAvatarHack(
                // Portrait
                &self.mBookownerPortrait,
                &portStaticPt,
                // Face anim below
                &self.mBookownerFaceAnim,
                &mouthPt,
                &eyePt,
                &mouthWH,
                totalMouthFrames,
                totalEyeFrames,
                eyesVertOffset,
                &eyeWH,
            );
        }
    }

    // Total hack for lampseller below, beware!
    fn drawAvatarHack(
        self: *Self,
        portStatic: *goImg.GoImage,
        portStaticPt: *const c.SDL_Point,
        faceAnim: *goImg.GoImage,
        mouthPt: *const c.SDL_Point,
        eyePt: *const c.SDL_Point,
        mouthWH: *const c.SDL_Point,
        totalMouthOffsets: comptime_int,
        totalEyeOffsets: comptime_int,
        eyesVertOffset: comptime_int,
        eyeWH: *const c.SDL_Point,
    ) !void {
        defer self.mAvatarTicks += 1;

        // 1. PORTRAIT: Always draw static avatar portrait, bottom layer.
        _ = try portStatic.draw(
            portStaticPt.x,
            portStaticPt.y,
            4,
        );

        // 2. MOUTH: Next draw mouth cycle only when character is talking, next layer.
        if (self.mGame.getGameSounds().isPlayOldLampsBusy()) {
            const tickCount = 4;

            if ((self.mAvatarTicks % tickCount) == 0) {
                self.mAvatarMouthOffset += 1;
            }

            if (self.mAvatarMouthOffset > (totalMouthOffsets - 1)) {
                self.mAvatarMouthOffset = 0;
            }

            faceAnim.mWidth = mouthWH.x;
            faceAnim.mHeight = mouthWH.y;

            _ = try faceAnim.drawEx2(
                (portStaticPt.x + mouthPt.x),
                (portStaticPt.y + mouthPt.y),
                5,
                1,
                1,
                0,
                255,
                c.SDL_Color{ .r = 255, .g = 255, .b = 255, .a = 255 },
                c.SDL_BLENDMODE_BLEND,
                c.SDL_Rect{
                    .x = @as(i32, @intCast(self.mAvatarMouthOffset)) * (mouthWH.x + 2),
                    .y = 0,
                    .w = mouthWH.x,
                    .h = mouthWH.y,
                },
            );
        }

        // 3. EYES: Always draw blinking eyes, top layer no matter what.
        faceAnim.mWidth = eyeWH.x;
        faceAnim.mHeight = eyeWH.y;

        if (try utility.getRandomFloat(0, 1) > 0.98 and self.mAvatarEyesAllowedFrames == 0) {
            self.mAvatarEyesAllowedFrames = 4;
        }

        const eyesTickCount = 4;
        if ((self.mAvatarTicks % eyesTickCount) == 0 and self.mAvatarEyesAllowedFrames > 0) {
            self.mAvatarEyesOffset += 1;
        }

        if (self.mAvatarEyesOffset > (totalEyeOffsets - 1)) {
            self.mAvatarEyesOffset = 0;
        }

        if (self.mAvatarEyesAllowedFrames > 0) {
            self.mAvatarEyesAllowedFrames -= 1;
        }

        _ = try faceAnim.drawEx2(
            portStaticPt.x + eyePt.x,
            portStaticPt.y + eyePt.y + eyesVertOffset,
            6,
            1,
            1,
            0,
            255,
            c.SDL_Color{ .r = 255, .g = 255, .b = 255, .a = 255 },
            c.SDL_BLENDMODE_BLEND,
            c.SDL_Rect{
                .x = @as(i32, @intCast(self.mAvatarEyesOffset)) * (eyeWH.x + 2),
                .y = eyesVertOffset,
                .w = @intCast(eyeWH.x),
                .h = @intCast(eyeWH.y),
            },
        );
    }

    pub fn click(self: *Self, mouseX: i32, mouseY: i32) !void {
        // Why the hell do these apis want this as u32?
        // TODO: figure out what we should use and be consistent.
        const mX: u32 = @intCast(mouseX);
        const mY: u32 = @intCast(mouseY);

        // Exit button was clicked
        if (self.mExitButton.clicked(mX, mY)) {
            try self.mGame.changeState("stateMainMenu");
        }

        // Hint button was clicked
        else if (self.mHintEnabled and self.mHintButton.clicked(mX, mY)) {
            try self.mStateGame.showHint();
        }

        // Reset button was clicked
        else if (self.mResetButton.clicked(mX, mY)) {
            try self.mStateGame.resetGame();
        }
    }

    /// Regenerates the texture for the score, if necessary
    pub fn regenerateScoreTexture(self: *Self) !void {
        // Regenerate the texture if the score has changed

        const fc = c.SDL_Color{
            .r = 78,
            .g = 193,
            .b = 190,
            .a = 255,
        };

        if (self.mScore != self.mScorePrev) {
            var buf: [16]u8 = undefined;
            const txtScore = try std.fmt.bufPrintZ(&buf, "{d}", .{self.mScore});
            self.mImgScore = self.mFontScore.renderText(txtScore, fc);
            self.mScorePrev = self.mScore;
        }
    }
};
