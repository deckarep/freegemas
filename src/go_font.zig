const std = @import("std");
const utility = @import("utility.zig");
const c = @import("cdefs.zig").c;
const goWin = @import("go_window.zig");
const cl = @import("go_cacheloader.zig");
const goImg = @import("go_image.zig");
const trkr = @import("sdl_mem_tracker.zig");

pub const GoFont = struct {
    // Parent window.
    mParentWindow: ?*goWin.GoWindow = null,

    // Path to the font file.
    // Choosing not to store path.
    // mPath: []const u8,

    // Size of the font.
    mSize: usize = 0,

    // Actual font
    mFont: ?*c.TTF_Font = null,

    const Self = @This();

    pub fn init() Self {
        checkInit();
        return Self{};
    }

    pub fn deinit(self: *Self) void {
        if (self.mFont) |fnt| {
            const cacher = cl.getCacheLoader();
            cacher.DestroyFont(fnt);
            self.mFont = null;
        }
    }

    fn checkInit() void {
        if (c.TTF_WasInit() == 0) {
            _ = c.TTF_Init(); // TODO: check for errors.
        }
    }

    pub fn setWindow(self: *Self, pw: *goWin.GoWindow) void {
        self.mParentWindow = pw;
    }

    pub fn setPathAndSize(self: *Self, path: [:0]const u8, size: usize) !void {
        self.mSize = size;

        var buf: [128]u8 = undefined;
        const finalPath = try std.fmt.bufPrintZ(&buf, "{s}{s}", .{ utility.getBasePath(), path });

        const cacher = cl.getCacheLoader();

        if (self.mFont) |fnt| {
            cacher.DestroyFont(fnt);
            self.mFont = null;
        }

        self.mFont = try cacher.LoadFont(finalPath, self.mSize);
        if (self.mFont == null) {
            std.log.err("failed to load font with err: {s}", .{std.mem.span(c.SDL_GetError())});
        }

        // TODO: check for errors
    }

    pub fn setAll(self: *Self, pw: *goWin.GoWindow, path: [:0]const u8, size: usize) !void {
        self.setWindow(pw);
        try self.setPathAndSize(path, size);
    }

    pub fn getTextWidth(self: *Self, text: [:0]const u8) usize {
        if (self.mFont == null) return 0;

        var w: c_int = 0;
        _ = c.TTF_SizeUTF8(self.mFont, text.ptr, &w, null);
        return w;
    }

    pub fn renderText(self: *Self, text: [:0]const u8, color: c.SDL_Color) goImg.GoImage {
        const tempSurface = trkr.TTF_RenderUTF8_Blended(self.mFont, text, color);
        return self.surfaceToImage(tempSurface);
    }

    pub fn renderTextWithShadow(self: *Self, text: [:0]const u8, color: c.SDL_Color, shadowX: i32, shadowY: i32, shadowColor: c.SDL_Color) goImg.GoImage {
        const textSurface = trkr.TTF_RenderUTF8_Blended(self.mFont, text, color);
        const shadowSurface = trkr.TTF_RenderUTF8_Blended(self.mFont, text, shadowColor);
        return self.surfaceToImageWithShadow(textSurface, shadowSurface, shadowX, shadowY);
    }

    pub fn renderBlock(self: *Self, text: [:0]const u8, color: c.SDL_Color, width: usize) goImg.GoImage {
        const tempSurface = trkr.TTF_RenderUTF8_Blended_Wrapped(self.mFont, text, color, width);
        return self.surfaceToImage(tempSurface);
    }

    pub fn renderBlockWithShadow(self: *Self, text: [:0]const u8, color: c.SDL_Color, width: usize, shadowX: i32, shadowY: i32, shadowColor: c.SDL_Color) goImg.GoImage {
        const textSurface = trkr.TTF_RenderUTF8_Blended_Wrapped(self.mFont, text, color, @intCast(width));
        const shadowSurface = trkr.TTF_RenderUTF8_Blended_Wrapped(self.mFont, text, shadowColor, @intCast(width));
        return self.surfaceToImageWithShadow(textSurface, shadowSurface, shadowX, shadowY);
    }

    pub fn surfaceToImage(self: *Self, tempSurface: *c.SDL_Surface) goImg.GoImage {
        const tempTexture = trkr.SDL_CreateTextureFromSurface(
            self.mParentWindow.?.getRenderer(),
            tempSurface,
        );

        trkr.SDL_FreeSurface(tempSurface);

        var img = goImg.GoImage.init();
        std.debug.assert(self.mParentWindow != null);
        img.setWindow(self.mParentWindow);
        img.setTexture(tempTexture);

        return img;
    }

    pub fn surfaceToImageWithShadow(
        self: *Self,
        textSurface: *c.SDL_Surface,
        shadowSurface: *c.SDL_Surface,
        shadowX: i32,
        shadowY: i32,
    ) goImg.GoImage {
        const tempSurface = trkr.SDL_CreateRGBSurfaceWithFormat(
            0,
            shadowX + shadowSurface.w,
            shadowY + shadowSurface.h,
            32,
            c.SDL_PIXELFORMAT_RGBA32,
        );

        var rect: c.SDL_Rect = .{
            .x = shadowX,
            .y = shadowY,
            .w = shadowSurface.w,
            .h = shadowSurface.h,
        };

        var res = c.SDL_SetSurfaceBlendMode(shadowSurface, c.SDL_BLENDMODE_NONE);
        std.debug.assert(res == 0);
        res = c.SDL_BlitSurface(shadowSurface, null, tempSurface, &rect);
        std.debug.assert(res == 0);
        trkr.SDL_FreeSurface(shadowSurface);

        rect.x = 0;
        rect.y = 0;
        rect.w = textSurface.w;
        rect.h = textSurface.h;

        res = c.SDL_SetSurfaceBlendMode(textSurface, c.SDL_BLENDMODE_BLEND);
        std.debug.assert(res == 0);
        res = c.SDL_BlitSurface(textSurface, null, tempSurface, &rect);
        std.debug.assert(res == 0);
        trkr.SDL_FreeSurface(textSurface);

        return self.surfaceToImage(tempSurface);
    }
};
