const std = @import("std");
const goWin = @import("go_window.zig");
const goFont = @import("go_font.zig");
const goImg = @import("go_image.zig");
const c = @import("cdefs.zig").c;

const scoreColor = c.SDL_Color{
    .r = 255,
    .g = 255,
    .b = 255,
    .a = 255,
};

const scoreShadowColor = c.SDL_Color{
    .r = 0,
    .g = 0,
    .b = 0,
    .a = 255,
};

pub const FloatingScore = struct {
    mScoreImage: goImg.GoImage = undefined,
    mScoreImageShadow: goImg.GoImage = undefined,

    x_: f32 = 0,
    y_: f32 = 0,
    z_: f32 = 0,

    mCurrentStep: i32 = 0,
    mTotalSteps: i32 = 50,

    const Self = @This();

    pub fn init(pw: *goWin.GoWindow, score: i32, x: f32, y: f32, z: f32) !Self {
        var tempFont = goFont.GoFont.init();
        tempFont.setAll(pw, "media/fuentelcd.ttf", 60);

        var buf: [32]u8 = undefined;
        const scoreTxt = try std.fmt.bufPrintZ(&buf, "{d}", .{score});

        return Self{
            .x_ = x,
            .y_ = y,
            .z_ = z,

            // Build the image
            .mScoreImage = tempFont.renderText(scoreTxt, scoreColor),
            .mScoreImageShadow = tempFont.renderText(scoreTxt, scoreShadowColor),
        };
    }

    pub fn ended(self: Self) bool {
        return self.mCurrentStep >= self.mTotalSteps;
    }

    pub fn draw(self: *Self) !void {
        if (self.ended()) return;

        self.mCurrentStep += 1;

        const p: f32 = 1.0 - @divExact(self.mCurrentStep, self.mTotalSteps);

        const posX: f32 = 241 + self.x_ * 65;
        const posY: f32 = 41 + self.y_ * 65 - (1 - p) * 20;

        try self.mScoreImage.drawEx(
            posX,
            posY,
            self.z_,
            1,
            1,
            0,
            @intFromFloat(p * 255),
            scoreColor,
        );

        try self.mScoreImageShadow.drawEx(
            posX + 2,
            posY + 2,
            self.z_ - 0.1,
            1,
            1,
            0,
            @intFromFloat(p * 255),
            scoreColor,
        );

        try self.mScoreImageShadow.drawEx(
            posX - 2,
            posY - 2,
            self.z_ - 0.1,
            1,
            1,
            0,
            @intFromFloat(p * 255),
            scoreColor,
        );
    }
};
