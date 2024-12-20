const goWin = @import("go_window.zig");
const goImg = @import("go_image.zig");
const goFont = @import("go_font.zig");
const st = @import("state.zig");
const std = @import("std");
const c = @import("cdefs.zig").c;

pub const StateHowToPlay = struct {
    mGame: *goWin.GoWindow = undefined,

    mImgBackground: goImg.GoImage,
    mImgTitle: goImg.GoImage,
    mImgSubtitle: goImg.GoImage,
    mImgBodyText: goImg.GoImage,

    const Self = @This();

    pub fn init(p: *goWin.GoWindow) !StateHowToPlay {
        var o = Self{
            .mGame = p,
            .mImgBackground = goImg.GoImage.init(),
            .mImgTitle = goImg.GoImage.init(),
            .mImgSubtitle = goImg.GoImage.init(),
            .mImgBodyText = goImg.GoImage.init(),
        };

        _ = try o.mImgBackground.setWindowAndPath(p, "media/howtoScreen.png");

        // Build the title text
        var fontTitle = goFont.GoFont.init();
        fontTitle.setWindow(p);
        try fontTitle.setPathAndSize("media/fuenteMenu.ttf", 48);

        o.mImgTitle = fontTitle.renderTextWithShadow(
            "How to play",
            c.SDL_Color{ .r = 255, .g = 255, .b = 255, .a = 255 },
            1,
            2,
            c.SDL_Color{ .r = 0, .g = 0, .b = 0, .a = 128 },
        );

        // Build the subtitle text
        var fontSubtitle = goFont.GoFont.init();
        fontSubtitle.setWindow(p);
        try fontSubtitle.setPathAndSize("media/fuenteMenu.ttf", 23);

        const subtitleText = "Press any button to go back";
        o.mImgSubtitle = fontSubtitle.renderTextWithShadow(
            subtitleText,
            c.SDL_Color{ .r = 255, .g = 255, .b = 255, .a = 255 },
            1,
            2,
            c.SDL_Color{ .r = 0, .g = 0, .b = 0, .a = 128 },
        );

        // Build the main text
        var fontText = goFont.GoFont.init();
        fontText.setWindow(p);
        try fontText.setPathAndSize("media/fuenteNormal.ttf", 28);

        const bodyText =
            \\The objective of the game is to swap one gem with an adjacent gem to form a horizontal or vertical chain of three or more gems.
            \\
            \\Click the first gem and then click the gem you want to swap it with. If the movement is correct, they will swap and the chained gems will disappear.
            \\
            \\Bonus points are given when more than three identical gems are formed. Sometimes chain reactions, called cascades, are triggered, where chains are formed by the falling gems. Cascades are awarded with bonus points.
        ;
        o.mImgBodyText = fontText.renderBlockWithShadow(
            bodyText,
            c.SDL_Color{ .r = 255, .g = 255, .b = 255, .a = 255 },
            450,
            1,
            2,
            c.SDL_Color{ .r = 0, .g = 0, .b = 0, .a = 128 },
        );

        return o;
    }

    pub fn update(ptr: *anyopaque) anyerror!void {
        _ = ptr;
        // No implementation for this struct.
    }

    pub fn draw(ptr: *anyopaque) anyerror!void {
        const self: *StateHowToPlay = @alignCast(@ptrCast(ptr));
        try self.mImgBackground.draw(0, 0, 0);
        try self.mImgTitle.draw(300 + 470 / 2 - @divTrunc(self.mImgTitle.getWidth(), @as(i32, 2)), 20, 1);
        try self.mImgSubtitle.draw(30, 550, 1);
        try self.mImgBodyText.draw(310, 110, 1);
    }

    fn buttonDown(ptr: *anyopaque, keyCode: c.SDL_Keycode) anyerror!void {
        const self: *StateHowToPlay = @alignCast(@ptrCast(ptr));
        _ = keyCode;
        try self.mGame.changeState("stateMainMenu");
    }

    fn buttonUp(ptr: *anyopaque, keyCode: c.SDL_Keycode) anyerror!void {
        const self: *StateHowToPlay = @alignCast(@ptrCast(ptr));
        _ = self;
        _ = keyCode;
        // No implementation for this struct.
    }

    fn mouseDown(ptr: *anyopaque, button: u8) anyerror!void {
        const self: *StateHowToPlay = @alignCast(@ptrCast(ptr));
        _ = button;
        try self.mGame.changeState("stateMainMenu");
    }

    fn mouseUp(ptr: *anyopaque, button: u8) anyerror!void {
        const self: *StateHowToPlay = @alignCast(@ptrCast(ptr));
        _ = self;
        _ = button;
        // No implementation for this struct.
    }

    pub fn stater(self: *StateHowToPlay, game: *goWin.GoWindow) st.State {
        self.mGame = game;
        return st.State{
            .ptr = self,
            //.mGame = game,
            .updateFn = update,
            .drawFn = draw,
            .buttonDownFn = buttonDown,
            .buttonUpFn = buttonUp,
            .mouseDownFn = mouseDown,
            .mouseUpFn = mouseUp,
        };
    }
};
