const std = @import("std");
const utility = @import("utility.zig");
const c = @import("cdefs.zig").c;

pub const GoFont = struct {
    // Parent window.
    mParentWindow: u8 = null,

    // Path to the font file.
    mPath: []const u8,

    // Size of the font.
    mSize: usize,

    // Actual font
    mFont: ?*c.TTF_Font = null,

    const Self = @This();

    pub fn init() Self {
        checkInit();
        return Self{};
    }

    pub fn deinit(self: *Self) void {
        if (self.mFont) |fnt| {
            c.TTF_CloseFont(fnt);
            self.mFont = null;
        }
    }

    pub fn checkInit(self: Self) void {
        _ = self;

        if (!c.TTF_WasInit()) {
            c.TTF_Init(); // TODO: check for errors.
        }
    }

    pub fn setPathAndSize(self: *Self, size: usize) void {}

    pub fn setAll(self: *Self, parentWindow: u8, path: []const u8, size: usize) void {}

    pub fn getTextWidth(txt: []const u8) usize {}

    pub fn renderText() void {}

    pub fn renderTextWithShadow() void {}

    pub fn renderBlock() void {}

    pub fn renderBlockWithShadow() void {}
};
