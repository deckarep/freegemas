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

const BOARD_X_OFF = 241;
const BOARD_Y_OFF = 41;
const GEM_WH = 65;

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
        try tempFont.setAll(pw, "media/fuentelcd.ttf", 60);

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

        const p: f32 = 1.0 - @as(f32, @floatFromInt(self.mCurrentStep)) / @as(f32, @floatFromInt(self.mTotalSteps));
        const alpha: u8 = @intFromFloat(p * 255);

        const posX: f32 = BOARD_X_OFF + self.x_ * GEM_WH;
        const posY: f32 = BOARD_Y_OFF + self.y_ * GEM_WH - (1 - p) * 20;

        // Drop shadow.
        _ = try self.mScoreImageShadow.drawEx(
            @as(i32, @intFromFloat(posX)) + 2,
            @as(i32, @intFromFloat(posY)) + 2,
            @as(i32, @intFromFloat(self.z_ - 0.1)),
            1,
            1,
            0,
            alpha,
            scoreColor,
            c.SDL_BLENDMODE_BLEND,
        );

        // White additive score, applied thrice.
        for (0..3) |_| {
            _ = try self.mScoreImage.drawEx(
                @intFromFloat(posX),
                @intFromFloat(posY),
                @intFromFloat(self.z_),
                1,
                1,
                0,
                alpha,
                scoreColor,
                c.SDL_BLENDMODE_ADD,
            );
        }
    }
};
