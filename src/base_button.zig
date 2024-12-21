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
    mImgBackground: goImg.GoImage,
    mHasIcon: bool = false,
    // Icon is optional.
    mImgIcon: ?goImg.GoImage,
    mImgCaption: goImg.GoImage,
    mTextHorizontalPos: i32,
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
        try self.mImgBackground.setWindowAndPath(pw, "media/buttonBackground.png");

        self.mHasIcon = !std.mem.eql(u8, iconPath, "");

        if (self.mHasIcon) {
            var buf: [128]u8 = undefined;
            const finalPath = try std.fmt.bufPrintZ(&buf, "media/{s}", .{iconPath});
            try self.mImgIcon.setWindowAndPath(pw, finalPath);
        }

        self.setText(caption);
    }

    pub fn setText(self: *Self, caption: [:0]const u8) void {
        var textFont = goFont.GoFont.init();
        textFont.setAll(self.mParentWindow, "media/fuenteNormal.ttf", 27);

        self.mImgCaption = textFont.renderTextWithShadow(
            caption,
            fontColor,
            1,
            2,
            shadowColor,
        );

        if (self.mHasIcon) {
            self.mTextHorizontalPosition = 40 + (self.mImgBackground.getWidth() - 40) / 2 - self.mImgCaption.getWidth() / 2;
        } else {
            self.mTextHorizontalPosition = self.mImgBackground.getWidth() / 2 - self.mImgCaption.getWidth() / 2;
        }
    }

    pub fn draw(self: Self, x: i32, y: i32, z: f32) !void {
        self.mLastX = x;
        self.mLastY = y;

        if (self.mHasIcon) {
            try self.mImgIcon.draw(x + 7, y, z + 1);
        }

        try self.mImgCaption.draw(x + self.mTextHorizontalPosition, y + 5, z + 2);

        try self.mImgBackground.draw(x, y, z);
    }

    pub fn clicked(self: Self, mX: u32, mY: 32) bool {
        if (mX > self.mLastX and mX < self.mLastX + self.mImgBackground.getWidth() and
            mY > self.mLastY and mY < self.mLastY + self.mImgBackground.getHeight())
        {
            return true;
        }
        return false;
    }
};
