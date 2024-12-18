const std = @import("std");
const utility = @import("utility.zig");
const DrawingQueueOp = @import("go_drawingqueue.zig").DrawingQueueOp;
const c = @import("cdefs.zig").c;

pub const GoWindow = struct {
    /// Running flag
    mShouldRun: bool,

    /// Time interval between frames, in milliseconds
    mUpdateInterval: u32,

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

    // Rendering queue
    //DrawingQueue mDrawingQueue;

    // Options manager to get full screen setting
    //OptionsManager mOptions;

    // List of connected game controllers
    //std::vector<SDL_GameController*> gameControllers;

    const Self = @This();

    pub fn init(width: comptime_int, height: comptime_int, caption: [:0]const u8, updateInterval: u32) Self {
        var o = Self{
            .mLastTicks = c.SDL_GetTicks(),
            .mUpdateInterval = updateInterval,
        };

        if (c.SDL_Init(c.SDL_INIT_VIDEO | c.SDL_INIT_AUDIO | c.SDL_INIT_GAMECONTROLLER) < 0) {
            @panic("failed to init SDL with an error of sorts!");
        }

        // Set texture filtering to linear
        if (!c.SDL_SetHint(c.SDL_HINT_RENDER_SCALE_QUALITY, "1")) {
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
        c.SDL_RenderSetLogicalSize(o.mRenderer, width, height);

        // Initialize renderer color
        c.SDL_SetRenderDrawColor(o.mRenderer, 0, 0, 0, 255);

        // Initialize PNG loading
        const imgFlags = c.IMG_INIT_PNG;

        if (!(c.IMG_Init(imgFlags) & imgFlags)) {
            @panic("failed to init img png stuff with err!");
        }

        // Set full screen mode
        // TODO!
        //mOptions.loadResources();
        //o.setFullscreen(mOptions.getFullscreenEnabled());

        // Hide cursor
        c.SDL_ShowCursor(0);

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

    pub fn show(self: *Self) void {}

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
        // Create the new drawing operation.

        // Fill the operation.
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

    pub fn setFullScreen(self: Self, value: bool) void {
        if (value) {
            c.SDL_SetWindowFullscreen(self.mWindow.?, c.SDL_WINDOW_FULLSCREEN);
        } else {
            c.SDL_SetWindowFullscreen(self.mWindow.?, 0);
        }
    }
};
