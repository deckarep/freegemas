const std = @import("std");
const utility = @import("utility.zig");
const goWin = @import("go_window.zig");
const c = @import("cdefs.zig").c;

pub const GoImage = struct {
    // Parent window.
    mParentWindow: ?*goWin.GoWindow = null,

    // Path to the font file.
    // NOTE: not using, don't need to store, just created on demand.
    //mPath: []const u8,

    // Texture of this image.
    mTexture: ?*c.SDL_Texture = null,

    // Dimensions.
    mWidth: i32,
    mHeight: i32,

    const Self = @This();

    pub fn init() Self {
        return Self{
            .mWidth = 0,
            .mHeight = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        self.mParentWindow = null;
    }

    pub fn setWindow(self: *Self, pw: ?*goWin.GoWindow) void {
        std.debug.assert(pw != null);
        self.mParentWindow = pw;
    }

    pub fn setPath(self: *Self, path: []const u8) !void {
        var buf: [128]u8 = undefined;
        const finalPath = try std.fmt.bufPrintZ(&buf, "{s}{s}", .{ utility.getBasePath(), path });
        _ = self.loadTexture(finalPath);
    }

    pub fn setWindowAndPath(self: *Self, pw: *goWin.GoWindow, path: []const u8) !bool {
        self.mParentWindow = pw;

        var buf: [128]u8 = undefined;
        const finalPath = try std.fmt.bufPrintZ(&buf, "{s}{s}", .{ utility.getBasePath(), path });
        std.debug.print("finalPath => {s}\n", .{finalPath});
        return self.loadTexture(finalPath);
    }

    pub fn loadTexture(self: *Self, path: [:0]const u8) bool {
        // Load texture from file
        const texture = c.IMG_LoadTexture(self.mParentWindow.?.getRenderer(), path.ptr);
        if (texture == null) {
            return false;
        }

        // Fill the managed pointer
        // TODO: how to handle this deleter nonsense.
        //self.mTexture.reset(texture, GoSDL::Image::SDL_Texture_Deleter());
        // destroy the old texture if one is set.
        if (self.mTexture) |txt| {
            c.SDL_DestroyTexture(txt);
        }
        self.mTexture = texture;

        // Get texture's width and height
        _ = c.SDL_QueryTexture(self.mTexture, null, null, &self.mWidth, &self.mHeight);

        return true;
    }

    pub fn setTexture(self: *Self, texture: ?*c.SDL_Texture) void {
        // Assign the texture

        // TODO: how to handle this deleter nonsense.
        //self.mTexture.reset(texture, GoSDL::Image::SDL_Texture_Deleter());
        // destroy the old texture if one is set.
        if (self.mTexture) |txt| {
            c.SDL_DestroyTexture(txt);
        }

        self.mTexture = texture;

        // Get texture's width and height
        _ = c.SDL_QueryTexture(
            self.mTexture,
            null,
            null,
            &self.mWidth,
            &self.mHeight,
        );
    }

    pub fn getWidth(self: Self) i32 {
        return self.mWidth;
    }

    pub fn getHeight(self: Self) i32 {
        return self.mHeight;
    }

    pub fn draw(self: *Self, x: i32, y: i32, z: i32) !void {
        const color = c.SDL_Color{
            .r = 255,
            .g = 255,
            .b = 255,
            .a = 255,
        };
        _ = try self.drawEx(
            x,
            y,
            z,
            1,
            1,
            0,
            255,
            color,
            c.SDL_BLENDMODE_BLEND,
        );
    }

    pub fn drawEx(
        self: *Self,
        x: i32,
        y: i32,
        z: i32,
        factorX: f64,
        factorY: f64,
        angle: f32,
        alpha: u8,
        color: c.SDL_Color,
        blendMode: c.SDL_BlendMode,
    ) !bool {
        //std.debug.assert(self.mParentWindow != null);
        if (self.mParentWindow == null) {
            std.log.warn("self: {*} => parent window is null, cannot draw!", .{self});
            return false;
        }

        if (self.mTexture == null) {
            std.log.warn("texture is null, nothing to draw!", .{});
            return false;
        }

        const destRect = c.SDL_Rect{
            .w = @intFromFloat(@as(f64, @floatFromInt(self.mWidth)) * factorX),
            .h = @intFromFloat(@as(f64, @floatFromInt(self.mHeight)) * factorY),
            .x = x,
            .y = y,
        };

        try self.mParentWindow.?.enqueueDraw(
            self.mTexture.?,
            destRect,
            angle,
            @floatFromInt(z),
            alpha,
            color,
            blendMode,
        );

        return true;
    }
};
