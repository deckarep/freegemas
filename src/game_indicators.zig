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
const glConsts = @import("global_consts.zig");
const Chars = glConsts.Characters;

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

    mAvatarPortrait: goImg.GoImage = goImg.GoImage.init(),
    mAvatarFaceAnim: goImg.GoImage = goImg.GoImage.init(),

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

    pub fn deinit(self: *Self) void {
        self.sfxSong.deinit();

        // deinit all images.
        self.mAvatarPortrait.deinit();
        self.mAvatarFaceAnim.deinit();
        self.mImgTimeBackground.deinit();
        self.mImgScoreBackground.deinit();
        self.mImgTime.deinit();
        self.mImgTimeHeader.deinit();
        self.mImgScore.deinit();
        self.mImgScoreHeader.deinit();

        // deinit all buttons
        self.mHintButton.deinit();
        self.mResetButton.deinit();
        self.mExitButton.deinit();
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

        self.mImgScoreHeader = tempHeaderFont.renderTextWithShadow("score", headerColor, 1, 1, headerShadow);
        self.mImgTimeHeader = tempHeaderFont.renderTextWithShadow("time left", headerColor, 1, 1, headerShadow);

        // Avatar hack.
        const portraitPng = Chars[glConsts.getCurrentChar()].PortraitImgPath;
        _ = try self.mAvatarPortrait.setWindowAndPath(self.mGame, portraitPng);
        const faceAnimPng = Chars[glConsts.getCurrentChar()].FaceAnimImgPath;
        _ = try self.mAvatarFaceAnim.setWindowAndPath(self.mGame, faceAnimPng);

        std.debug.print("loadResources => {s} {s}\n", .{ portraitPng, faceAnimPng });

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
            try self.sfxSong.setSample(glConsts.Characters[glConsts.getCurrentChar()].BackgroundMusic);
            self.sfxSong.play(1);

            const avatar = &glConsts.Characters[glConsts.getCurrentChar()];
            if (avatar.AudioLines) |lines| {
                std.debug.print("Avatar has {d} audio lines\n", .{lines.len});
            } else {
                std.debug.print("Avatar has NO audio lines setup!\n", .{});
            }
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
        if (true) {
            // Vertical initial position for the buttons
            const vertButStart = 407;

            // Draw the buttons
            if (self.mHintEnabled) {
                // Hint can be disabled for two reasons:
                // 1. Game ended, so don't render it.
                // 2. TODO: settings to not allow hints.
                try self.mHintButton.draw(17, vertButStart, 2);
            }
            try self.mResetButton.draw(17, vertButStart + 47, 2);
            try self.mExitButton.draw(17, 538, 2);
        }

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

        const avatar = &Chars[glConsts.getCurrentChar()];

        try self.drawAvatarHack(
            // Portrait
            &self.mAvatarPortrait,
            &avatar.PortraitXY,
            // Face anim below
            &self.mAvatarFaceAnim,
            &avatar.MouthXY,
            &avatar.EyeXY,
            &avatar.MouthWH,
            avatar.MouthFrameCnt,
            avatar.EyeFrameCnt,
            avatar.EyeVertOffset,
            &avatar.EyeWH,
        );
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
        totalMouthOffsets: usize,
        totalEyeOffsets: usize,
        eyesVertOffset: usize,
        eyeWH: *const c.SDL_Point,
    ) !void {
        defer self.mAvatarTicks += 1;

        // 1. PORTRAIT: Always draw static avatar portrait, bottom layer.
        _ = try portStatic.draw(
            portStaticPt.x,
            portStaticPt.y,
            36,
        );

        // 2. MOUTH: Next draw mouth cycle only when character is talking, next layer.
        if (self.mGame.getGameSounds().isAvatarPlayingSound()) {
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
                37,
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
            portStaticPt.y + eyePt.y + @as(i32, @intCast(eyesVertOffset)),
            38,
            1,
            1,
            0,
            255,
            c.SDL_Color{ .r = 255, .g = 255, .b = 255, .a = 255 },
            c.SDL_BLENDMODE_BLEND,
            c.SDL_Rect{
                .x = @as(i32, @intCast(self.mAvatarEyesOffset)) * (eyeWH.x + 2),
                .y = @intCast(eyesVertOffset),
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
            glConsts.selectNextChar();
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
