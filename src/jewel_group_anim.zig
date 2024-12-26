const goWin = @import("go_window.zig");
const goImg = @import("go_image.zig");
const easings = @import("easings.zig");
const std = @import("std");

const GEM_COUNT = 7;

/// This group animation is simply shown on the main menu.
/// It does not have any bearing on gameplay.
pub const JewewlGroupAnim = struct {
    animationCurrentStep: i32 = undefined,
    animationTotalSteps: i32 = undefined,

    imgGems: [GEM_COUNT]goImg.GoImage = undefined,
    posX: [GEM_COUNT]i32 = undefined,
    posFinalY: i32 = undefined,

    const Self = @This();

    pub fn init() Self {
        return Self{};
    }

    pub fn deinit(self: *Self) void {
        for (&self.imgGems) |*img| {
            img.deinit();
        }
    }

    pub fn loadResources(self: *Self, w: *goWin.GoWindow) !void {
        _ = try self.imgGems[0].setWindowAndPath(w, "media/gemWhite.png");
        _ = try self.imgGems[1].setWindowAndPath(w, "media/gemRed.png");
        _ = try self.imgGems[2].setWindowAndPath(w, "media/gemPurple.png");
        _ = try self.imgGems[3].setWindowAndPath(w, "media/gemOrange.png");
        _ = try self.imgGems[4].setWindowAndPath(w, "media/gemGreen.png");
        _ = try self.imgGems[5].setWindowAndPath(w, "media/gemYellow.png");
        _ = try self.imgGems[6].setWindowAndPath(w, "media/gemBlue.png");

        for (0..GEM_COUNT) |i| {
            self.posX[i] = 800 / 2 - (65 * 7) / 2 + @as(i32, @intCast(i)) * 65;
        }

        self.animationCurrentStep = 0;
        self.animationTotalSteps = 20;
        self.posFinalY = 265;
    }

    pub fn draw(self: *Self) !void {
        // Step the animation
        // r.c. - this should be in an update function...it's not drawing but stepping state.
        if (self.animationCurrentStep < 7 * 5 + self.animationTotalSteps) {
            self.animationCurrentStep += 1;
        }

        // Draw the jewels
        for (0..GEM_COUNT) |i| {
            const composedStep = self.animationCurrentStep - @as(i32, @intCast(i)) * 5;
            if (composedStep < 0) continue;

            if (composedStep < self.animationTotalSteps) {
                try self.imgGems[i].draw(
                    self.posX[i],
                    @intFromFloat(easings.easeOutCubic(
                        @floatFromInt(composedStep),
                        600.0,
                        @as(f32, @floatFromInt(self.posFinalY)) - 600.0,
                        @floatFromInt(self.animationTotalSteps),
                    )),
                    2.0,
                );
            } else {
                // TODO: when gem reaches final state, play a progressively pitched "chime" for each one.
                try self.imgGems[i].draw(self.posX[i], self.posFinalY, 2);
            }
        }
    }
};
