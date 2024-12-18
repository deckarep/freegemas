const std = @import("std");
const utility = @import("utility.zig");
const DrawingQueueOp = @import("go_drawingqueue.zig").DrawingQueueOp;
const DrawingQueue = @import("go_drawingqueue.zig").DrawingQueue;
const optsMan = @import("options_manager.zig");
const c = @import("cdefs.zig").c;

pub const GoWindow = struct {
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

    /// Main rendering window
    mWindow: ?*c.SDL_Window = null,

    /// Main renderer
    mRenderer: ?*c.SDL_Renderer = null,

    /// Rendering queue
    mDrawingQueue: DrawingQueue,

    /// Options manager to get full screen setting
    mOptions: optsMan.OptionsManager,

    /// Whatever is the current state...TODO
    mCurrentState: ?u8 = null,

    // List of connected game controllers
    //std::vector<SDL_GameController*> gameControllers;

    const Self = @This();

    pub fn init(
        width: comptime_int,
        height: comptime_int,
        caption: [:0]const u8,
        updateInterval: u32,
        allocator: std.mem.Allocator,
    ) Self {
        var o = Self{
            .mShouldRun = false,
            .mMouseX = -1,
            .mMouseY = -1,
            .mLastTicks = c.SDL_GetTicks(),
            .mUpdateInterval = updateInterval,
            .mOptions = optsMan.OptionsManager.init(),
            .mDrawingQueue = DrawingQueue.init(allocator),
        };

        if (c.SDL_Init(c.SDL_INIT_VIDEO | c.SDL_INIT_AUDIO | c.SDL_INIT_GAMECONTROLLER) < 0) {
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

        // Create window
        o.mWindow = c.SDL_CreateWindow(
            caption.ptr,
            c.SDL_WINDOWPOS_UNDEFINED,
            c.SDL_WINDOWPOS_UNDEFINED,
            width,
            height,
            c.SDL_WINDOW_RESIZABLE,
        );
        // If window could not be created, throw an error
        if (o.mWindow == null) {
            @panic("failed to create window with err!");
        }

        // Create renderer for the window
        o.mRenderer = c.SDL_CreateRenderer(o.mWindow, -1, c.SDL_RENDERER_ACCELERATED);

        // If rendered could not be created, throw an error
        if (o.mRenderer == null) {
            @panic("failed to create SDL renderer with err!");
        }

        // For proper scaling in all resolutions
        _ = c.SDL_RenderSetLogicalSize(o.mRenderer, width, height);

        // Initialize renderer color
        _ = c.SDL_SetRenderDrawColor(o.mRenderer, 0, 0, 0, 255);

        // Initialize PNG loading
        const imgFlags = c.IMG_INIT_PNG;

        if ((c.IMG_Init(imgFlags) & imgFlags) < 0) {
            @panic("failed to init img png stuff with err!");
        }

        // Set full screen mode
        o.mOptions.loadResources();
        o.setFullscreen(o.mOptions.getFullscreenEnabled());

        // Hide cursor
        _ = c.SDL_ShowCursor(0);

        return o;
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

    pub fn update(self: *Self) void {
        if (self.mCurrentState) |cs| {
            _ = cs;
            //cs.update();
        }
    }

    pub fn draw(self: *Self) void {
        if (self.mCurrentState) |cs| {
            _ = cs;
            //cs.draw();
        }
    }

    pub fn show(self: *Self) void {
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
                        //self.buttonDown(e.key.keysym.sym);
                    },

                    c.SDL_KEYUP => {
                        //self.buttonUp(e.key.keysym.sym);
                    },

                    c.SDL_MOUSEMOTION => {
                        self.mMouseActive = true;
                        self.mMouseX = e.motion.x;
                        self.mMouseY = e.motion.y;
                    },

                    c.SDL_MOUSEBUTTONDOWN => {
                        self.mMouseActive = true;
                        // self.mouseButtonDown(e.button.button);
                    },

                    c.SDL_MOUSEBUTTONUP => {
                        //self.mouseButtonUp(e.button.button);
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
            self.update();

            // Process drawing
            self.draw();

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
    }

    pub fn close(self: *Self) void {
        self.mShouldRun = false;
    }

    pub fn enqueueDraw(
        self: *Self,
        texture: *c.SDL_Texture,
        destRect: c.SDL_Rect,
        angle: f64,
        z: f32,
        alpha: u8,
        color: c.SDL_Color,
    ) void {
        // Create the new drawing operation and fill it.
        const op = DrawingQueueOp{
            .mTexture = texture,
            .mDstRect = destRect,
            .mAngle = angle,
            .mAlpha = alpha,
            .mColor = color,
        };

        // Store it in the container, sorted by depth.
        self.mDrawingQueue.draw(z, op);
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
};
