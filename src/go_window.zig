const std = @import("std");
const utility = @import("utility.zig");
const DrawingQueueOp = @import("go_drawingqueue.zig").DrawingQueueOp;
const DrawingQueue = @import("go_drawingqueue.zig").DrawingQueue;
const optsMan = @import("options_manager.zig");
const st = @import("state.zig");
const StateGame = @import("state_game.zig").StateGame;
const StateHowToPlay = @import("state_how_to_play.zig").StateHowToPlay;
const StateMainMenu = @import("state_main_menu.zig").StateMainMenu;
const goImg = @import("go_image.zig");
const gs = @import("game_sounds.zig");
const c = @import("cdefs.zig").c;

// Temporarily public for troubleshooting.
pub var howToPlay: ?StateHowToPlay = null;
pub var gamePlayEndless: ?StateGame = null;
pub var gamePlayTimetrial: ?StateGame = null;
pub var mainMenu: ?StateMainMenu = null;

pub const GoWindow = struct {
    allocator: std.mem.Allocator,

    /// Running flag
    mShouldRun: bool,

    /// Time interval between frames, in milliseconds
    mUpdateInterval: u32 = 17,

    /// Ticks recorded in last frame
    mLastTicks: u32,

    // Whether the mouse is in use
    mMouseActive: bool = false,

    /// Mouse coordinates
    mMouseX: i32,
    mMouseY: i32,

    /// Mouse coordinates
    mWidth: i32,
    mHeight: i32,

    /// Main rendering window
    mWindow: ?*c.SDL_Window = null,

    /// Main renderer
    mRenderer: ?*c.SDL_Renderer = null,

    // Game Sound controller
    mGameSounds: gs.GameSounds = gs.GameSounds.init(),

    /// Rendering queue
    mDrawingQueue: DrawingQueue,

    /// Options manager to get full screen setting
    mOptions: optsMan.OptionsManager,

    /// Whatever is the current state...TODO
    mCurrentState: ?st.State = null,
    mCurrentStateStr: []const u8 = "<none>",

    mMouseCursor: goImg.GoImage = goImg.GoImage.init(),

    mCaption: [:0]const u8 = undefined,

    /// Sounds controller
    //GameSounds mGameSounds;

    // List of connected game controllers
    //std::vector<SDL_GameController*> gameControllers;

    const Self = @This();

    pub fn init(
        width: comptime_int,
        height: comptime_int,
        caption: [:0]const u8,
        updateInterval: u32,
        allocator: std.mem.Allocator,
    ) !Self {
        std.debug.print("GoWindow::init()\n", .{});
        const o = Self{
            .allocator = allocator,
            .mCaption = caption,
            .mWidth = width,
            .mHeight = height,
            .mShouldRun = false,
            .mMouseX = -1,
            .mMouseY = -1,
            .mLastTicks = c.SDL_GetTicks(),
            .mUpdateInterval = updateInterval,
            .mOptions = optsMan.OptionsManager.init(),
            .mDrawingQueue = try DrawingQueue.init(allocator),
        };

        // WARNING: I spent hours tracking down an insidious bug
        // 1. Notice how I just set fields in the "o" object and return immediately?
        // 2. Previously, I was also calling other init functions and those functions
        //    were getting the address of stack "o" which is obviously undefined
        //    behavior. Just an oversight on my end but damn, was it freak-nasty.
        // 3. The fix was to introduce a separate setup function below which
        //    acts as more of an initialization of everything once the object
        //    is created.
        return o;
    }

    pub fn setup(self: *Self) !void {
        if (c.SDL_Init(c.SDL_INIT_VIDEO | c.SDL_INIT_AUDIO) < 0) { //| c.SDL_INIT_GAMECONTROLLER) < 0) {
            @panic("failed to init SDL with an error of sorts!");
        }

        // Set texture filtering to linear
        if (c.SDL_SetHint(c.SDL_HINT_RENDER_SCALE_QUALITY, "1") < 0) {
            std.log.warn("Warning: Linear texture filtering not enabled!", .{});
        }

        if (c.Mix_OpenAudio(
            c.MIX_DEFAULT_FREQUENCY,
            c.MIX_DEFAULT_FORMAT,
            c.MIX_DEFAULT_CHANNELS,
            4096,
        ) < 0) {
            @panic("failed to init SDL open audio!!");
        }

        // Load Sounds
        try self.mGameSounds.loadResources();

        // Create window
        self.mWindow = c.SDL_CreateWindow(
            self.mCaption.ptr,
            c.SDL_WINDOWPOS_UNDEFINED,
            c.SDL_WINDOWPOS_UNDEFINED,
            self.mWidth,
            self.mHeight,
            c.SDL_WINDOW_RESIZABLE,
        );
        // If window could not be created, throw an error
        if (self.mWindow == null) {
            @panic("failed to create window with err!");
        }

        // Create renderer for the window
        self.mRenderer = c.SDL_CreateRenderer(self.mWindow, -1, c.SDL_RENDERER_ACCELERATED);

        // If rendered could not be created, throw an error
        if (self.mRenderer == null) {
            @panic("failed to create SDL renderer with err!");
        }

        // For proper scaling in all resolutions
        _ = c.SDL_RenderSetLogicalSize(self.mRenderer, self.mWidth, self.mHeight);

        // Initialize renderer color
        _ = c.SDL_SetRenderDrawColor(self.mRenderer, 0, 0, 0, 255);

        // Initialize PNG loading
        const imgFlags = c.IMG_INIT_PNG;

        if ((c.IMG_Init(imgFlags) & imgFlags) < 0) {
            @panic("failed to init img png stuff with err!");
        }

        // Set full screen mode
        self.mOptions.loadResources();
        self.setFullscreen(self.mOptions.getFullscreenEnabled());

        // Hide cursor
        _ = c.SDL_ShowCursor(0);

        // Since we're not creating a Game class for Zig.
        // The "Game" constructor logic is here below.
        self.mMouseCursor.setWindow(self);
        try self.mMouseCursor.setPath("media/handCursor.png");

        // TODO: main menu for starters.
        try self.changeState("stateMainMenu");
    }

    pub fn deinit(self: *Self) void {
        // self.closeAllGameControllers();

        if (self.mRenderer) |rnd| {
            c.SDL_DestroyRenderer(rnd);
            self.mRenderer = null;
        }

        if (self.mWindow) |win| {
            c.SDL_DestroyWindow(win);
            self.mWindow = null;
        }

        // Quit SDL subsystems.
        c.Mix_Quit();
        c.IMG_Quit();
        c.SDL_Quit();
    }

    pub fn update(self: *Self) !void {
        if (self.mCurrentState) |cs| {
            try cs.update();
        }
    }

    pub fn draw(self: *Self) !void {
        if (self.getMouseActive()) {
            try self.mMouseCursor.draw(
                self.getMouseX(),
                self.getMouseY(),
                999,
            );
        }

        if (self.mCurrentState) |cs| {
            try cs.draw();
        }
    }

    fn buttonDown(self: *Self, button: c.SDL_Keycode) !void {
        if (self.mCurrentState) |cs| {
            try cs.buttonDown(button);
        }
    }

    fn buttonUp(self: *Self, button: c.SDL_Keycode) !void {
        if (self.mCurrentState) |cs| {
            try cs.buttonUp(button);
        }
    }

    fn mouseButtonDown(self: *Self, button: u8) !void {
        if (self.mCurrentState) |cs| {
            try cs.mouseButtonDown(button);
        }
    }

    fn mouseButtonUp(self: *Self, button: u8) !void {
        if (self.mCurrentState) |cs| {
            try cs.mouseButtonUp(button);
        }
    }

    pub fn show(self: *Self) !void {
        std.debug.print("show\n", .{});
        // To store the ticks passed between frames
        var newTicks: u32 = undefined;

        // To poll events
        var e: c.SDL_Event = undefined;

        // Show the window
        c.SDL_ShowWindow(self.mWindow);

        self.mShouldRun = true;

        // Main game loop
        exit: while (self.mShouldRun) {

            // Get ticks
            newTicks = c.SDL_GetTicks();

            // Get ticks from last frame and compare with framerate
            if (newTicks - self.mLastTicks < self.mUpdateInterval) {
                c.SDL_Delay(self.mUpdateInterval - (newTicks - self.mLastTicks));
                continue;
            }

            // Event loop
            while (c.SDL_PollEvent(&e) != 0) {
                switch (e.type) {
                    c.SDL_QUIT => {
                        // Yes, goto: http://stackoverflow.com/a/1257776/276451
                        // goto exit;

                        // r.c.: Nope, I don't think so -- no goto is needed for Zig.
                        break :exit;
                    },

                    c.SDL_KEYDOWN => {
                        self.mMouseActive = false;
                        try self.buttonDown(e.key.keysym.sym);
                    },

                    c.SDL_KEYUP => {
                        try self.buttonUp(e.key.keysym.sym);
                    },

                    c.SDL_MOUSEMOTION => {
                        self.mMouseActive = true;
                        self.mMouseX = e.motion.x;
                        self.mMouseY = e.motion.y;
                    },

                    c.SDL_MOUSEBUTTONDOWN => {
                        self.mMouseActive = true;
                        try self.mouseButtonDown(e.button.button);
                    },

                    c.SDL_MOUSEBUTTONUP => {
                        try self.mouseButtonUp(e.button.button);
                    },

                    c.SDL_CONTROLLERBUTTONDOWN => {
                        self.mMouseActive = false;
                        //self.controllerButtonDown(e.cbutton.button);
                    },

                    c.SDL_CONTROLLERDEVICEADDED => {
                        //self.openGameController(e.cdevice.which);
                    },

                    c.SDL_CONTROLLERDEVICEREMOVED => {
                        //self.closeDisconnectedGameControllers();
                    },
                    else => {},
                }
            }

            // Process logic
            try self.update();

            // Process drawing
            try self.draw();

            // Render the background clear
            _ = c.SDL_RenderClear(self.mRenderer);

            // Iterator for drawing operations
            var iter = self.mDrawingQueue.getIterator();
            while (iter.next()) |*op| {
                // Set transparency
                _ = c.SDL_SetTextureAlphaMod(op.mTexture, op.mAlpha);
                // Set coloring
                _ = c.SDL_SetTextureColorMod(
                    op.mTexture,
                    op.mColor.r,
                    op.mColor.g,
                    op.mColor.b,
                );
                // Set blend mode
                std.debug.assert(op.mBlendMode != c.SDL_BLENDMODE_NONE);
                _ = c.SDL_SetTextureBlendMode(op.mTexture, op.mBlendMode);

                // Draw the texture
                const res = c.SDL_RenderCopyEx(
                    self.mRenderer,
                    op.mTexture,
                    null,
                    &op.mDstRect,
                    op.mAngle,
                    null,
                    c.SDL_FLIP_NONE,
                );

                // Check for errors when drawing
                if (res != 0) {
                    std.log.err("error on drawing texture: {s}", .{std.mem.span(c.SDL_GetError())});
                }
            }

            // Empty the drawing queue
            self.mDrawingQueue.clear();

            // Update the screen
            c.SDL_RenderPresent(self.mRenderer);

            // Update the ticks
            self.mLastTicks = newTicks;
        }

        // Exit point for goto within switch
        std.debug.print("exiting...\n", .{});
    }

    pub fn close(self: *Self) void {
        self.mShouldRun = false;
    }

    pub inline fn getRenderer(self: Self) *c.SDL_Renderer {
        return self.mRenderer.?;
    }

    pub inline fn getGameSounds(self: *Self) *gs.GameSounds {
        return &self.mGameSounds;
    }

    pub fn enqueueDraw(
        self: *Self,
        texture: *c.SDL_Texture,
        destRect: c.SDL_Rect,
        angle: f64,
        z: f32,
        alpha: u8,
        color: c.SDL_Color,
        blendMode: c.SDL_BlendMode,
    ) !void {
        // Create the new drawing operation and fill it.
        const op = DrawingQueueOp{
            .mTexture = texture,
            .mDstRect = destRect,
            .mAngle = angle,
            .mAlpha = alpha,
            .mColor = color,
            .mBlendMode = blendMode,
        };

        // Store it in the container, sorted by depth.
        try self.mDrawingQueue.draw(z, op);
    }

    pub fn openGameController(self: *Self) void {
        _ = self;
    }
    pub fn closeDisconnectedGameControllers(self: *Self) void {
        _ = self;
    }
    pub fn closeAllGameControllers(self: *Self) void {
        _ = self;
    }

    pub fn setFullscreen(self: Self, value: bool) void {
        if (value) {
            _ = c.SDL_SetWindowFullscreen(self.mWindow.?, c.SDL_WINDOW_FULLSCREEN);
        } else {
            _ = c.SDL_SetWindowFullscreen(self.mWindow.?, 0);
        }
    }

    pub inline fn getMouseActive(self: Self) bool {
        return self.mMouseActive;
    }

    pub inline fn getMouseX(self: Self) i32 {
        return self.mMouseX;
    }

    pub inline fn getMouseY(self: Self) i32 {
        return self.mMouseY;
    }

    pub inline fn getCurrentState(self: Self) []const u8 {
        return self.mCurrentStateStr;
    }

    pub fn changeState(self: *Self, newState: []const u8) !void {
        if (std.mem.eql(u8, newState, self.mCurrentStateStr)) {
            return;
        } else if (std.mem.eql(u8, newState, "stateQuit")) {
            self.close();
        } else if (std.mem.eql(u8, newState, "stateGameEndless")) {
            if (gamePlayEndless == null) {
                gamePlayEndless = try StateGame.init(.eEndless, self, self.allocator);
            }

            const stater = gamePlayEndless.?.stater(self);
            try stater.setup();

            self.mCurrentState = stater;
            self.mCurrentStateStr = "stateGameEndless";
        } else if (std.mem.eql(u8, newState, "stateGameTimetrial")) {
            if (gamePlayTimetrial == null) {
                gamePlayTimetrial = try StateGame.init(.eTimetrial, self, self.allocator);
            }

            const stater = gamePlayTimetrial.?.stater(self);
            try stater.setup();

            self.mCurrentState = stater;
            self.mCurrentStateStr = "stateGameTimetrial";
        } else if (std.mem.eql(u8, newState, "stateOptions")) {
            std.debug.print("TODO: stateOptions...\n", .{});
        } else if (std.mem.eql(u8, newState, "stateHowtoplay")) {
            if (howToPlay == null) {
                howToPlay = try StateHowToPlay.init(self);
            }
            const stater = howToPlay.?.stater(self);
            // TODO: try stater.setup();
            self.mCurrentState = stater;
            self.mCurrentStateStr = "stateHowtoPlay";
        } else if (std.mem.eql(u8, newState, "stateMainMenu")) {
            if (mainMenu == null) {
                const mm = try StateMainMenu.init(self);
                mainMenu = mm;
            }
            const stater = mainMenu.?.stater(self);
            try stater.setup();
            self.mCurrentState = stater;
            self.mCurrentStateStr = "stateMainMenu";
        } else {
            @panic("unknown state, you must add it!!!");
        }
    }
};
