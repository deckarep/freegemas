const goImg = @import("go_image.zig");
const goWin = @import("go_window.zig");
const co = @import("coord.zig");
const c = @import("cdefs.zig").c;

pub const GameHint = struct {
    /// Total initial animation steps
    mAnimationCurrentStep: i32 = 0,

    /// Steps for the hanimation
    mAnimationTotalSteps: i32 = 40,

    /// Hint flag
    mShowingHint: bool = false,

    /// Coordinates for the hint
    mHintLocation: co.Coord = co.Coord{ .x = -1, .y = -1 },

    /// Image for the hint
    mImgSelector: goImg.GoImage = undefined,

    const Self = @This();

    pub fn init() Self {
        return Self{};
    }

    /// Sets the parent window and loads the resources
    pub fn setWindow(self: *Self, w: *goWin.GoWindow) !void {
        _ = try self.mImgSelector.setWindowAndPath(w, "media/selector.png");
    }

    /// Places the hint at the specified position and shows it
    pub fn showHint(self: *Self, location: co.Coord) void {
        // Set the location
        self.mHintLocation = location;

        // Reset the animation
        self.mAnimationCurrentStep = 0;

        // Set the flag
        self.mShowingHint = true;
    }

    /// Draws the hint (if necessary)
    pub fn draw(self: *Self) !void {
        // Don't draw if it's not necessary
        if (!self.mShowingHint) return;

        // Step the animation and check if it's finished
        defer self.mAnimationCurrentStep += 1;

        if (self.mAnimationCurrentStep == self.mAnimationTotalSteps) {
            self.mShowingHint = false;
        } else {
            // Get the opacity percentage
            const p1: f32 = 1 - @as(f32, @floatFromInt(@divExact(self.mAnimationCurrentStep, self.mAnimationTotalSteps)));

            // Get the location
            const pX1: f32 = 241 + @as(f32, @floatFromInt(self.mHintLocation.x.?)) * 65 - @as(f32, @floatFromInt(self.mImgSelector.getWidth())) * (2 - p1) / 2 + 65 / 2;
            const pY1: f32 = 41 + @as(f32, @floatFromInt(self.mHintLocation.y.?)) * 65 - @as(f32, @floatFromInt(self.mImgSelector.getHeight())) * (2 - p1) / 2 + 65 / 2;

            // Draw the hint
            _ = try self.mImgSelector.drawEx(
                @intFromFloat(pX1),
                @intFromFloat(pY1),
                10,
                2 - p1,
                2 - p1,
                0,
                @intFromFloat(p1 * 255),
                c.SDL_Color{ .r = 0, .g = 255, .b = 0, .a = 255 },
            );
        }
    }
};
