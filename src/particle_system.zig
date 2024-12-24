const std = @import("std");
const Particle = @import("particle.zig").Particle;
const goImg = @import("go_image.zig");
const utility = @import("utility.zig");
const c = @import("cdefs.zig").c;

pub const ParticleSystem = struct {
    mParticleQuantity: usize,

    /// Effect duration.
    mTotalSteps: f32,

    /// Position of animation.
    mCurrentStep: f32 = 0,

    /// Effect distance.
    mDistance: f32,

    /// Scale of explosion.
    mScale: f32,

    /// Particle colors
    mColor: c.SDL_Color,

    /// Container of particles.
    mParticleList: std.ArrayList(Particle),

    /// Position of particle.
    mPosX: i32,
    mPosY: i32,

    /// Flag that determines if the particle system is alive.
    mActive: bool = true,

    const Self = @This();

    pub fn init(
        imgParticle1: *goImg.GoImage,
        imgParticle2: *goImg.GoImage,
        particleQuantity: usize,
        totalSteps: i32,
        x: i32,
        y: i32,
        distance: usize,
        scale: f32,
        color: c.SDL_Color,
        allocator: std.mem.Allocator,
    ) !Self {
        var o = Self{
            .mParticleQuantity = particleQuantity,
            .mTotalSteps = totalSteps,
            .mPosX = x,
            .mPosY = y,
            .mScale = scale,
            .mDistance = distance,
            .mColor = color,
            .mParticleList = std.ArrayList(Particle).init(allocator),
        };

        // Reserve the space for the particles.
        try o.mParticleList.ensureTotalCapacity(o.mParticleQuantity);

        // Create the particles.
        for (0..o.mParticleQuantity) |_| {
            const ptr = o.mParticleList.addOneAssumeCapacity();
            ptr.* = Particle.init(
                try utility.getRandomFloat(0, 360),
                try utility.getRandomFloat(0, 1) * o.mDistance,
                try utility.getRandomFloat(0, o.mScale) + 1.0,
                try utility.getRandomFloat(0.1, 1) * o.mTotalSteps,
                if (try utility.getRandomFloat(0, 1) > 0.5) imgParticle1 else imgParticle2,
                o.mColor,
            );
        }

        return o;
    }

    pub fn deinit(self: Self) void {
        self.mParticleList.deinit();
    }

    pub fn ended(self: Self) bool {
        return !self.mActive;
    }

    pub fn draw(self: *Self) !void {
        self.mCurrentStep += 1;

        if (self.mCurrentStep < self.mTotalSteps) {
            for (0..self.mParticleQuantity) |i| {
                self.mParticleList.items[i].update();
                try self.mParticleList.items[i].draw(self.mPosX, self.mPosY);
            }
        } else {
            self.mActive = false;
        }
    }
};
