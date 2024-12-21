const std = @import("std");
const goWin = @import("go_window.zig");
const c = @import("cdefs.zig").c;

pub const State = struct {
    ptr: *anyopaque,

    setupFn: *const fn (ptr: *anyopaque) anyerror!void,

    updateFn: *const fn (ptr: *anyopaque) anyerror!void,
    drawFn: *const fn (ptr: *anyopaque) anyerror!void,

    buttonDownFn: *const fn (ptr: *anyopaque, keyCode: c.SDL_Keycode) anyerror!void,
    buttonUpFn: *const fn (ptr: *anyopaque, keyCode: c.SDL_Keycode) anyerror!void,

    mouseDownFn: *const fn (ptr: *anyopaque, button: u8) anyerror!void,
    mouseUpFn: *const fn (ptr: *anyopaque, button: u8) anyerror!void,

    pub fn setup(self: State) !void {
        return self.setupFn(self.ptr);
    }

    pub fn update(self: State) !void {
        return self.updateFn(self.ptr);
    }

    pub fn draw(self: State) !void {
        return self.drawFn(self.ptr);
    }

    pub fn buttonDown(self: State, keyCode: c.SDL_Keycode) !void {
        return self.buttonDownFn(self.ptr, keyCode);
    }

    pub fn buttonUp(self: State, keyCode: c.SDL_Keycode) !void {
        return self.buttonUpFn(self.ptr, keyCode);
    }

    pub fn mouseButtonDown(self: State, button: u8) !void {
        return self.mouseDownFn(self.ptr, button);
    }

    pub fn mouseButtonUp(self: State, button: u8) !void {
        return self.mouseUpFn(self.ptr, button);
    }

    // todo: controllerButtonDown belongs here too.
};
