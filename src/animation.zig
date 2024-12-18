const std = @import("std");
const easings = @import("easings.zig");

const animType = enum {
    tEaseInQuad,
    tEaseOutQuad,
    tEaseInOutQuad,
    tEaseInCubic,
    tEaseOutCubic,
    tEaseInOutCubic,
    tEaseInQuart,
    tEaseOutQuart,
    tEaseInOutQuart,
    tEaseOutBack,
};

pub const Animation = struct {
    allocator: std.mem.Allocator,

    /// Number of animation attributes.
    numAttr: i32,
    // Duration of the animation
    duration: i32,
    time: i32,
    esperaInitial: i32,

    /// Vector of initial positions.
    initial: []i32,
    /// Vector of final positions.
    final: []i32,
    /// Vector of position deltas.
    change: []i32,
    /// Vector of actual positions.
    actual: []i32,

    /// Animation type.
    anim: animType,

    // Pointer to animation function.
    puntFunc: fn () void,

    const Self = @This();

    pub fn init(n: i32, d: i32, anim: animType, e: i32, allocator: std.mem.Allocator) !Animation {
        var o: Self = Self{
            .allocator = allocator,
            .numAttr = n,
            .duration = d,
            .esperaInitial = e,
            .time = 0,
        };

        o.initial = try allocator.alloc(i32, n);
        o.final = try allocator.alloc(i32, n);
        o.change = try allocator.alloc(i32, n);
        o.actual = try allocator.alloc(i32, n);

        for (0..n) |i| {
            o.initial[i] = 0;
            o.final[i] = 0;
            o.change[i] = 0;
            o.actual[i] = 0;
        }

        o.setAnimationType(anim);

        return o;
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.initial);
        self.allocator.free(self.final);
        self.allocator.free(self.change);
        self.allocator.free(self.actual);
    }

    pub fn setAnimationType(self: *Self, a: animType) void {
        self.anim = a;

        // Quad
        if (self.anim == .tEaseInQuad) {
            self.puntFun = &easings.easeInQuad;
        } else if (self.anim == .tEaseOutQuad) {
            self.puntFun = &easings.easeOutQuad;
        } else if (self.anim == .tEaseInOutQuad) {
            self.puntFun = &easings.easeInOutQuad;
        }
        // Cubic
        else if (self.anim == .tEaseInCubic) {
            self.puntFun = &easings.easeInCubic;
        } else if (self.anim == .tEaseOutCubic) {
            self.puntFun = &easings.easeOutCubic;
        } else if (self.anim == .tEaseInOutCubic) {
            self.puntFun = &easings.easeInOutCubic;
        }
        // Quart
        else if (self.anim == .tEaseInQuart) {
            self.puntFun = &easings.easeInQuart;
        } else if (self.anim == .tEaseOutQuart) {
            self.puntFun = &easings.easeOutQuart;
        } else if (self.anim == .tEaseInOutQuart) {
            self.puntFun = &easings.easeInOutQuart;
        }
        // Back
        else if (self.anim == .tEaseOutBack) {
            self.puntFun = &easings.easeOutBack;
        }
        // Linear y default
        else {
            self.puntFun = &easings.easeLinear;
        }
    }

    pub fn update(self: *Self, shouldAnim: bool) void {
        if (self.time - self.esperaInicial > self.duracion) {
            for (0..self.numAttr) |i| {
                self.actual[i] = self.final[i];
            }
            return;
        } else if (self.time >= self.esperaInicial) {
            for (0..self.numAttr) |i| {
                self.actual[i] = (*self.puntFun)(
                    self.time - self.esperaInicial,
                    self.inicial[i],
                    self.change[i],
                    self.duracion,
                );
            }

            if (shouldAnim) self.time += 1;
        }
    }

    pub fn get(self: Self, i: i32) f32 {
        if (i < self.numAttr) {
            return self.actual[i];
        } else {
            return 0;
        }
    }

    pub fn setInitial(self: *Self, i: i32, v: i32) void {
        if (i < self.numAttr) {
            self.inicial[i] = v;
            self.change[i] = self.final[i] - v;
            self.actual[i] = v;
        }
    }

    pub fn setFinal(self: *Self, i: i32, v: i32) void {
        if (i < self.numAttr) {
            self.final[i] = v;
            self.change[i] = v - self.inicial[i];
        }
    }

    pub fn set(self: *Self, i: i32, v1: i32, v2: i32) void {
        if (i < self.numAttr) {
            self.inicial[i] = v1;
            self.final[i] = v2;
            self.change[i] = v2 - v1;
            self.actual[i] = v1;
        }
    }

    pub fn reverse(self: *Self) void {
        var a: i32 = undefined;

        for (0..self.numAttr) |i| {
            a = self.inicial[i];
            self.inicial[i] = self.final[i];
            self.final[i] = a;
            self.change[i] = self.final[i] - self.inicial[i];
        }
    }

    pub fn end(self: *Self) void {
        self.time = self.duracion + self.esperaInicial;
        self.update(false);
    }

    pub fn initialize(self: *Self) void {
        self.time = 0;
    }

    pub fn finished(self: Self) bool {

        // int j = 0;
        // for (int i = 0; i < numAttr; ++i)
        // {
        // if(final[i] == actual[i]) j++;
        // }
        // return j == numAttr;

        return self.time > self.duracion + self.esperaInicial;
    }
};
