const goWin = @import("go_window.zig");
const goImg = @import("go_image.zig");
const goFont = @import("go_font.zig");
const st = @import("state.zig");
const std = @import("std");
const c = @import("cdefs.zig").c;
const jga = @import("jewel_group_anim.zig");

/// Possible states of the transition
const transitionState = enum { TransitionIn, Active, TransitionOut };

// Menu target states (TODO: move behind const identifiers)
const menuTargets = &[_][]const u8{
    "stateGameTimetrial",
    "stateGameEndless",
    "stateHowtoplay",
    "stateOptions",
    "stateQuit",
};

const menuTextColor = c.SDL_Color{
    .r = 255,
    .g = 255,
    .b = 255,
    .a = 255,
};

const menuShadowColor = c.SDL_Color{
    .r = 0,
    .g = 0,
    .b = 0,
    .a = 128,
};

pub const StateMainMenu = struct {
    mGame: *goWin.GoWindow = undefined,
    mCurrentTransitionState: transitionState = .TransitionIn,
    mAnimationCurrentStep: i32,
    mAnimationLogoSteps: i32,
    mAnimationTotalSteps: i32,
    mMenuSelectedOption: usize,

    mImgBackground: goImg.GoImage,
    mImgLogo: goImg.GoImage,
    mImgHighl: goImg.GoImage,
    mFont: goFont.GoFont,

    // Coordinates of the menu elements.
    mMenuYStart: i32,
    mMenuYEnd: i32,
    mMenuYGap: i32,

    mMenuRenderedTexts: [menuTargets.len]goImg.GoImage = undefined,
    mJewelAnimation: jga.JewewlGroupAnim = jga.JewewlGroupAnim.init(),

    const Self = @This();

    pub fn init(p: *goWin.GoWindow) !Self {
        const o = Self{
            .mGame = p,

            .mImgBackground = goImg.GoImage.init(),
            .mImgLogo = goImg.GoImage.init(),
            .mImgHighl = goImg.GoImage.init(),

            .mFont = goFont.GoFont.init(),

            .mAnimationTotalSteps = 30,
            .mAnimationLogoSteps = 30,
            .mAnimationCurrentStep = 0,

            .mMenuSelectedOption = 0,
            .mMenuYStart = 350,
            .mMenuYGap = 42,
            .mMenuYEnd = 0,
        };
        return o;
    }

    pub fn setup(ptr: *anyopaque) anyerror!void {
        const self: *Self = @alignCast(@ptrCast(ptr));

        // Init background image
        _ = try self.mImgBackground.setWindowAndPath(self.mGame, "media/stateMainMenu/mainMenuBackground.png");

        // Init logo image
        _ = try self.mImgLogo.setWindowAndPath(self.mGame, "media/stateMainMenu/mainMenuLogo.png");

        // Init menu highlight image
        _ = try self.mImgHighl.setWindowAndPath(self.mGame, "media/stateMainMenu/menuHighlight.png");

        // Load the font
        self.mFont.setWindow(self.mGame);
        try self.mFont.setPathAndSize("media/fuenteMenu.ttf", 30);

        // Menu text items
        self.mMenuRenderedTexts[0] = self.mFont.renderTextWithShadow("Timetrial mode", menuTextColor, 0, 2, menuShadowColor);
        self.mMenuRenderedTexts[1] = self.mFont.renderTextWithShadow("Endless mode", menuTextColor, 0, 2, menuShadowColor);
        self.mMenuRenderedTexts[2] = self.mFont.renderTextWithShadow("How to play?", menuTextColor, 0, 2, menuShadowColor);
        self.mMenuRenderedTexts[3] = self.mFont.renderTextWithShadow("Options", menuTextColor, 0, 2, menuShadowColor);
        self.mMenuRenderedTexts[4] = self.mFont.renderTextWithShadow("Exit", menuTextColor, 0, 2, menuShadowColor);

        // Jewel group animation
        try self.mJewelAnimation.loadResources(self.mGame);
        //self.mMenuYEnd = self.mMenuYStart + (int) self.mMenuTargets.size() * self.mMenuYGap;
    }

    pub fn update(ptr: *anyopaque) anyerror!void {
        const self: *Self = @alignCast(@ptrCast(ptr));

        if (self.mCurrentTransitionState == .TransitionIn) {
            self.mAnimationCurrentStep += 1;

            if (self.mAnimationCurrentStep == self.mAnimationTotalSteps) {
                self.mCurrentTransitionState = .Active;
            }
        } else if (self.mCurrentTransitionState == .Active) {
            // Nothing
        } else if (self.mCurrentTransitionState == .TransitionOut) {
            // Nothing
        }

        if (self.mGame.getMouseActive()) {
            // Update menu highlighting according to mouse position
            const mY: i32 = self.mGame.getMouseY();

            if (mY >= self.mMenuYStart and mY < self.mMenuYEnd) {
                self.mMenuSelectedOption = @intCast(@divTrunc((mY - self.mMenuYStart), self.mMenuYGap));
            }
        }
    }

    pub fn draw(ptr: *anyopaque) anyerror!void {
        const self: *Self = @alignCast(@ptrCast(ptr));
        try self.mImgBackground.draw(0, 0, 1);

        // Calculate the alpha value for the logo
        // TODO: do this fade in later, it's stupid I know.
        //const logoAlpha = std.math.clamp( i32,(int)(255 * (float)self.mAnimationCurrentStep / self.mAnimationLogoSteps),
        //                  0, 255);

        // Draw the logo
        try self.mImgLogo.draw(86, 2, 1); //86, 0, 2, 1, 1, 0, logoAlpha);

        // Loop to draw the menu items
        for (0..menuTargets.len) |i| {
            // Calculate the horizontal and vertical positions
            const posX = 800 / 2 - @divTrunc(self.mMenuRenderedTexts[i].getWidth(), 2);
            const posY = self.mMenuYStart + @as(i32, @intCast(i)) * self.mMenuYGap;

            // Draw the text and the shadow
            try self.mMenuRenderedTexts[i].draw(posX, posY, 3);
        }

        // Draw the menu highlighting
        try self.mImgHighl.draw(
            266,
            self.mMenuYStart + 5 + @as(i32, @intCast(self.mMenuSelectedOption)) * self.mMenuYGap,
            2,
        );

        // Draw the jewel animation
        try self.mJewelAnimation.draw();
    }

    fn buttonDown(ptr: *anyopaque, button: c.SDL_Keycode) anyerror!void {
        const self: *Self = @alignCast(@ptrCast(ptr));
        switch (button) {
            c.SDLK_ESCAPE => self.mGame.close(),
            c.SDLK_DOWN => self.moveDown(),
            c.SDLK_UP => self.moveUp(),
            c.SDLK_RETURN, c.SDLK_KP_ENTER, c.SDLK_SPACE => try self.optionChose(),
            else => {},
        }
    }

    fn optionChose(self: *Self) !void {
        try self.mGame.changeState(menuTargets[self.mMenuSelectedOption]);
    }

    fn moveUp(self: *Self) void {
        self.mGame.getGameSounds().playSoundSelect();

        if (self.mMenuSelectedOption == 0) {
            self.mMenuSelectedOption = menuTargets.len - 1;
        } else {
            self.mMenuSelectedOption -= 1;
        }
    }

    fn moveDown(self: *Self) void {
        self.mGame.getGameSounds().playSoundSelect();

        if (self.mMenuSelectedOption == menuTargets.len - 1) {
            self.mMenuSelectedOption = 0;
        } else {
            self.mMenuSelectedOption += 1;
        }
    }

    fn buttonUp(ptr: *anyopaque, keyCode: c.SDL_Keycode) anyerror!void {
        const self: *Self = @alignCast(@ptrCast(ptr));
        _ = self;
        _ = keyCode;
        // No implementation for this struct.
    }

    fn mouseUp(ptr: *anyopaque, button: u8) anyerror!void {
        const self: *Self = @alignCast(@ptrCast(ptr));
        _ = self;
        _ = button;
        // No implementation for this struct.
    }

    fn mouseDown(ptr: *anyopaque, button: u8) anyerror!void {
        const self: *Self = @alignCast(@ptrCast(ptr));
        _ = button;
        try self.mGame.changeState("stateMainMenu");
    }

    pub fn stater(self: *Self, game: *goWin.GoWindow) st.State {
        self.mGame = game;
        return st.State{
            .ptr = self,
            //.mGame = game,
            .setupFn = setup,
            .updateFn = update,
            .drawFn = draw,
            .buttonDownFn = buttonDown,
            .buttonUpFn = buttonUp,
            .mouseDownFn = mouseDown,
            .mouseUpFn = mouseUp,
        };
    }
};
