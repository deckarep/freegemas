const std = @import("std");
const c = @import("cdefs.zig").c;

pub const DrawingQueueOp = struct {
    /// mZDepth is used for the priority queue!
    mZdepth: f32,

    mTexture: *c.SDL_Texture,
    mDstRect: c.SDL_Rect,
    mAngle: f64,
    mAlpha: u8,
    mColor: c.SDL_Color,
};

/// lessThan will cause the priority queue to drawin from smallest z-depths to larger.
fn lessThan(context: void, a: DrawingQueueOp, b: DrawingQueueOp) std.math.Order {
    _ = context;
    return std.math.order(a.mZdepth, b.mZdepth);
}

const opQueue = std.PriorityQueue(DrawingQueueOp, void, lessThan);

pub const DrawingQueue = struct {
    allocator: std.mem.Allocator,
    // NOTE: original game uses a multi-map, we use  a priority queue instead.
    // Originally, I was going to do an AutoHashMap(f32, ArrayList(DrawingQueueOp))
    // But, floats need custom hash implementations and yawn.
    queue: opQueue,

    const Self = @This();

    // This will instantiate a ready-to-go DrawingQueue.
    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
            .queue = opQueue.init(allocator, {}),
        };
    }

    // Releases all memory.
    pub fn deinit(self: *Self) void {
        self.queue.deinit();
    }

    /// enqueues a drawing operation with a z-depth.
    pub fn draw(self: *Self, z: f32, op: DrawingQueueOp) !void {
        // NOTE: because this is a priority-queue instead of multi-map,
        // we simply package the z-depth into the op and uses that field
        // and only that field for the priority.
        var opWithDepth = op;
        opWithDepth.mZdepth = z;
        try self.queue.add(opWithDepth);
    }

    /// clear's the entire priority queue.
    pub fn clear(self: *Self) void {
        // This was the sanest way I could drain the queue.
        for (0..self.queue.count()) |_| {
            _ = self.queue.remove();
        }
    }

    /// returns an iterator against this priority queue.
    pub fn getIterator(self: *Self) opQueue.Iterator {
        return self.queue.iterator();
    }
};
