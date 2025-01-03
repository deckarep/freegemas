const std = @import("std");
const goWin = @import("go_window.zig");
const goImg = @import("go_image.zig");
const goFont = @import("go_font.zig");
const c = @import("cdefs.zig").c;

const fontColor = c.SDL_Color{
    .r = 255,
    .g = 255,
    .b = 255,
    .a = 255,
};

const shadowColor = c.SDL_Color{
    .r = 0,
    .g = 0,
    .b = 0,
    .a = 128,
};

pub const BaseButton = struct {
    mParentWindow: *goWin.GoWindow = undefined,
    mImgBackground: goImg.GoImage = goImg.GoImage.init(),
    mHasIcon: bool = false,
    // Icon is optional.
    mImgIcon: ?goImg.GoImage = null,
    mImgCaption: goImg.GoImage = goImg.GoImage.init(),
    mTextHorizontalPos: i32 = 0,
    mLastX: u32 = 0,
    mLastY: u32 = 0,

    const Self = @This();

    pub fn init() Self {
        return Self{};
    }

    pub fn set(
        self: *Self,
        pw: *goWin.GoWindow,
        caption: [:0]const u8,
        iconPath: []const u8,
    ) !void {
        self.mParentWindow = pw;
        _ = try self.mImgBackground.setWindowAndPath(pw, "media/buttonBackground.png");

        // WARN: This check may not be robust enough.
        self.mHasIcon = iconPath.len > 0;

        if (self.mHasIcon) {
            var buf: [128]u8 = undefined;
            const finalPath = try std.fmt.bufPrintZ(&buf, "media/{s}", .{iconPath});
            self.mImgIcon = goImg.GoImage.init();
            _ = try self.mImgIcon.?.setWindowAndPath(pw, finalPath);
        }

        try self.setText(caption);
    }

    pub fn setText(self: *Self, caption: [:0]const u8) !void {
        var textFont = goFont.GoFont.init();
        try textFont.setAll(self.mParentWindow, "media/fuenteNormal.ttf", 27);

        self.mImgCaption = textFont.renderTextWithShadow(
            caption,
            fontColor,
            1,
            2,
            shadowColor,
        );

        if (self.mHasIcon) {
            self.mTextHorizontalPos = 40 + @divExact((self.mImgBackground.getWidth() - 40), 2) - @divExact(self.mImgCaption.getWidth(), 2);
        } else {
            self.mTextHorizontalPos = @divExact(self.mImgBackground.getWidth(), 2) - @divExact(self.mImgCaption.getWidth(), 2);
        }
    }

    pub fn draw(self: *Self, x: i32, y: i32, z: f32) !void {
        self.mLastX = @intCast(x);
        self.mLastY = @intCast(y);

        const zi32: i32 = @intFromFloat(z);

        if (self.mHasIcon) {
            try self.mImgIcon.?.draw(x + 7, y, zi32 + 1);
        }

        try self.mImgCaption.draw(x + self.mTextHorizontalPos, y + 5, zi32 + 2);

        try self.mImgBackground.draw(x, y, zi32);
    }

    pub fn clicked(self: Self, mX: u32, mY: u32) bool {
        const imgWidth: u32 = @intCast(self.mImgBackground.getWidth());
        const imgHeight: u32 = @intCast(self.mImgBackground.getHeight());
        if (mX > self.mLastX and mX < self.mLastX + imgWidth and
            mY > self.mLastY and mY < self.mLastY + imgHeight)
        {
            return true;
        }
        return false;
    }
};
