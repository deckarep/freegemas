const std = @import("std");
const goImg = @import("go_image.zig");
const easings = @import("easings.zig");
const c = @import("cdefs.zig").c;

const lim = 0.70;

pub const Particle = struct {
    mAngle: f32,
    mDistance: f32,
    mSize: f32,
    mTotalSteps: i32,
    mCurrentStep: i32 = 0,
    mImage: *goImg.GoImage,
    mColor: c.SDL_Color,
    mAlpha: u8 = 255,
    mPosX: f32 = 0,
    mPosY: f32 = 0,
    mSizeCoef: f32 = undefined,

    const Self = @This();

    pub fn init(angle: f32, distance: f32, size: f32, totalSteps: i32, img: *goImg.GoImage, color: c.SDL_Color) Self {
        return Self{
            .mAngle = angle,
            .mDistance = distance,
            .mSize = size,
            .mTotalSteps = totalSteps,
            .mImage = img,
            .mColor = color,
        };
    }

    pub fn update(self: *Self) void {
        if (self.mCurrentStep != self.mTotalSteps) {
            self.mCurrentStep += 1;
        }

        const tempPos: f32 = easings.easeOutQuart(@floatFromInt(self.mCurrentStep), 0, 1, @floatFromInt(self.mTotalSteps));

        if (tempPos >= lim) {
            self.mAlpha = @intFromFloat(255.0 * (1 - (tempPos - lim) / (1 - lim)));
        } else {
            self.mAlpha = 255;
        }

        self.mSizeCoef = self.mSize * (1 - tempPos);
        const imgWidth: f32 = @floatFromInt(self.mImage.getWidth());
        const imgHeight: f32 = @floatFromInt(self.mImage.getHeight());
        self.mPosX = tempPos * self.mDistance * @cos(self.mAngle * std.math.pi / 180.0) - imgWidth * self.mSizeCoef / 2.0;
        self.mPosY = tempPos * self.mDistance * @sin(self.mAngle * std.math.pi / 180.0) - imgHeight * self.mSizeCoef / 2.0;
    }

    pub fn draw(self: Self, oX: i32, oY: i32) !void {
        _ = try self.mImage.drawEx(
            oX + @as(i32, @intFromFloat(self.mPosX)),
            oY + @as(i32, @intFromFloat(self.mPosY)),
            7,
            self.mSizeCoef,
            self.mSizeCoef,
            0,
            self.mAlpha,
            self.mColor,
        );
    }

    pub fn state(self: Self) f32 {
        return @as(f32, @floatFromInt(self.mCurrentStep)) / @as(f32, @floatFromInt(self.mTotalSteps));
    }
};
