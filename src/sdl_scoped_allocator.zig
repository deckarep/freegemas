const std = @import("std");
const c = @import("cdefs.zig").c;

const gpaType = std.heap.GeneralPurposeAllocator(.{
    .safety = true,
    .verbose_log = true,
    .stack_trace_frames = 100,
});

var gpa = std.heap.GeneralPurposeAllocator(.{}){
    //.backing_allocator = //std.heap.c_allocator,
};

// NOTE: C-based malloc, calloc, realloc and free basically use a general purpose
// stricter (larger) alignment that is intended to be suitable across all possible
// types. Zig on the other hand, will use more granular pointer alignment because
// the allocators know the type you are requested as a comptime argument.
// Therefore, we need to just mimic what C does because this ScopeAllocator is
// supposed is used by SDL when enabled.

// Effective result is that: all allocations will be 16 byte aligned which is suitable on
// a 64-bit platform.
const PTR_ALIGNMENT = 16;

var activeAllocator: std.mem.Allocator = undefined;
var scopedAllocator: *ScopedAllocator = undefined;

// Stores a mapping of pointers => requested size.
const metadataType = std.AutoHashMap(usize, usize);
pub var metadata: metadataType = undefined;

const mappingType = std.AutoHashMap(usize, usize);
pub var mapping: mappingType = undefined;

pub const ScopedAllocator = struct {
    idx: usize = 0,
    // TODO: this is likely better served as a dynamic ArrayList.
    // This way you could push/pop to an arbitrary depth of GPA's
    // Not that, you'd want to go nuts with it...sheesh.
    allocators: [10]gpaType = undefined,

    const Self = @This();

    pub fn init() Self {
        return Self{};
    }

    /// .deinit will ensure the allocator stack has already been dealt with.
    /// This means if you have invoked .push() for any additionaly scoped GPAs,
    /// you must have invoked .pop() to ensure those additional scopes were cleaned up.
    /// It therefore only legal to call .deinit when the ScopeAllocator is back at root scope.
    /// The final root allocator will be checked for leaks.
    pub fn deinit(self: *Self) void {
        // 1. The stack must be back to zero!
        std.debug.assert(self.idx == 0);

        // 2. The root can be deinitialized then.
        const deinit_status = self.allocators[0].deinit();
        if (deinit_status == .leak) {
            std.debug.print("ROOT: leaks detected; you lack discipline!", .{});
        }
    }

    pub fn setup(self: *Self) void {
        // Capture a global reference to this ScopeAllocator instance.
        scopedAllocator = self;

        // Initialize the root allocator.
        self.allocators[0] = gpaType{
            // NOTE: the macOS app leaks can detect leaks with the classic C-based malloc/free
            // So we use this on purpose.
            //.backing_allocator = std.heap.c_allocator,
        };

        activeAllocator = self.allocator();
        metadata = metadataType.init(activeAllocator);
        mapping = mappingType.init(activeAllocator);

        if (false) {
            // Setup SDL to use our custom scoped functions.
            const res = c.SDL_SetMemoryFunctions(
                myMalloc,
                myCalloc,
                myRealloc,
                myFree,
            );

            if (res != 0) {
                std.log.err("SDL_SetMemoryFunctions err: {s}\n", .{std.mem.span(c.SDL_GetError())});
                @panic("failed to shim SDL memory funcs!");
            }
        }
    }

    /// allocator simply returns the current allocator interface.
    pub inline fn allocator(self: *Self) std.mem.Allocator {
        return self.allocators[self.idx].allocator();
    }

    /// This will push and activate a freshly initialized GPA allocator onto the scope stack.
    /// Going forward, all allocations will use this GPA instance.
    pub fn push(self: *Self) !void {
        // Ensure we don't push too many beyond max.
        std.debug.assert(self.idx < (self.allocators.len - 1));

        self.idx += 1;
        self.allocators[self.idx] = gpaType{};
        activeAllocator = self.allocator();
    }

    /// This will remove the top-most active GPA and automatically .deinit it.
    /// If during .deinit this allocator has memory leaks, they will be reported.
    /// The immediately bottom allocator will become the active one going forward.
    /// An assertion ensures that you don't attempt to pop the root allocator.
    pub fn pop(self: *Self) void {
        // 1. Ensure we're at least above the root allocator and won't underflow.
        std.debug.assert(self.idx > 0);

        // 2. Assert we left nothing over in mapping at this bucket.
        var mappingIter = mapping.iterator();
        var mappingCount: usize = 0;
        while (mappingIter.next()) |e| {
            if (e.value_ptr.* == self.idx) {
                mappingCount += 1;
            }
        }

        if (mappingCount > 0) {
            std.debug.print("Found {d} mappings at this bucket level - you claimed you were done deallocating!\n", .{mappingCount});
            //std.debug.assert(mappingCount == 0);
        }

        const deinit_status = self.allocators[self.idx].deinit();
        if (deinit_status == .leak) {
            std.debug.print("{d}: leaks detected; you lack discipline!\n", .{self.idx});
        }

        self.allocators[self.idx] = undefined;
        self.idx -= 1;
        activeAllocator = self.allocator();
    }

    /// This allocates a default 16 byte aligned address for fresh memory.
    /// The memory returned is uninitialized.
    fn myMalloc(size: usize) callconv(.C) ?*anyopaque {
        std.debug.print("myMalloc(size:{d}), mapping count: {d}, scope: {d}\n", .{ size, metadata.count(), scopedAllocator.idx });
        const memBlock = activeAllocator.alignedAlloc(u8, PTR_ALIGNMENT, size) catch return null;

        // 2. If this assertion failed, this is a bug in the Zig stdlib.
        const intPtr = @intFromPtr(memBlock.ptr);
        std.debug.assert(std.mem.isAligned(intPtr, PTR_ALIGNMENT));

        // 3. Record the metadata of size and scope index.
        metadata.put(intPtr, size) catch return null;
        mapping.put(intPtr, scopedAllocator.idx) catch return null;

        // 4. Finally, return the newly allocated child pointer.
        return memBlock.ptr;
    }

    fn myCalloc(num: usize, size: usize) callconv(.C) ?*anyopaque {
        std.debug.print("myCalloc(num:{d}, size:{d}, mapping count: {d}, scope: {d})\n", .{ num, size, metadata.count(), scopedAllocator.idx });

        // 1. Calloc has a slightly differing signature than malloc so we must multiply: num * size, to compute how many bytes
        // are actually requested.
        const computedBytes = num * size;
        const memBlock = activeAllocator.alignedAlloc(u8, PTR_ALIGNMENT, computedBytes) catch return null;

        // 2. Calloc requires zeroed memory, so zero out that shit.
        @memset(memBlock, 0);

        const intPtr = @intFromPtr(memBlock.ptr);
        std.debug.assert(std.mem.isAligned(intPtr, PTR_ALIGNMENT));

        // 3. Record the new ptr's metadata and scope index.
        metadata.put(intPtr, computedBytes) catch return null;
        mapping.put(intPtr, scopedAllocator.idx) catch return null;

        // 4. Finally return the child ptr.
        return memBlock.ptr;
    }

    fn myRealloc(ptr: ?*anyopaque, size: usize) callconv(.C) ?*anyopaque {
        if (ptr) |p| {
            const intPtr = @intFromPtr(p);
            std.debug.assert(std.mem.isAligned(intPtr, PTR_ALIGNMENT));

            // NOTE: Since this is an existing pointer and a realloc call, assert that we
            // must already be aware of this ptr within the metadata.
            const originalSize = metadata.get(intPtr);
            if (originalSize == null) {
                // This should never happen when all code is correct, so we'll return null.
                // C memory funcs basically treats error results by returning null.
                std.log.err("ptr was unknown to metadata!", .{});
                return null;
            } else {
                // Zig's allocator apis work on slices, so we package up the data in a properly aligned slice.
                const memBlock: []align(PTR_ALIGNMENT) u8 = @alignCast(@as([*]u8, @ptrCast(p))[0..originalSize.?]);
                const reallocResult = activeAllocator.realloc(memBlock, size) catch return null;

                // Realloc may have provided a new/fresh pointer so we must use that going forward for the metadata.
                // We also assert this new ptr was aligned correctly. If not, this would technically be a Zig bug.
                const possibleNewIntPtr = @intFromPtr(reallocResult.ptr);
                std.debug.assert(std.mem.isAligned(possibleNewIntPtr, PTR_ALIGNMENT));

                if (possibleNewIntPtr != intPtr) {
                    // Not the same, so record the new pointers within the metadata.
                    metadata.put(possibleNewIntPtr, size) catch return null;
                    mapping.put(possibleNewIntPtr, scopedAllocator.idx) catch return null;

                    // And remove the original one, because realloc decided to use a new ptr.
                    _ = metadata.remove(intPtr);
                    _ = mapping.remove(intPtr);
                } else {
                    // Otherwise, the same ptr was used, just overwrite metadata records with the new size and scope index.
                    metadata.put(possibleNewIntPtr, size) catch return null;
                    mapping.put(possibleNewIntPtr, scopedAllocator.idx) catch return null;
                }

                // Finally, return the child ptr.
                return reallocResult.ptr;
            }
        }

        // If the incoming ptr is null, realloc is expected to simply malloc.
        return myMalloc(size);
    }

    fn myFree(memBlock: ?*anyopaque) callconv(.C) void {
        if (memBlock) |block| {
            // 1. Ensure we're properly aligned.
            const intPtr = @intFromPtr(block);
            std.debug.assert(std.mem.isAligned(intPtr, PTR_ALIGNMENT));

            // 2.  Grab the metadata out.
            const size = metadata.get(intPtr).?;
            const allocatorBucket = mapping.get(intPtr).?;

            std.debug.print("myFree(ptr:{*}, bytes: {d}, alloc_bucket: {d}, mapping count:{d}, scope: {d})\n", .{
                block,
                size,
                allocatorBucket,
                mapping.count(),
                scopedAllocator.idx,
            });

            // 6. Lastly, clean out the metadata.
            defer {
                // 1. Remove the metadata we're tracking.
                var ok = metadata.remove(intPtr);
                std.debug.assert(ok);

                // 2. Remove the mapping of which bucket as well.
                ok = mapping.remove(intPtr);
                std.debug.assert(ok);
            }

            // 3. Zig's apis require a slice so we need to package in the raw pointer into a multi-pointer
            // and finally into a properly aligned slice.
            const multiPtr: [*]u8 = @ptrCast(block);
            const slice: []align(PTR_ALIGNMENT) u8 = @alignCast(multiPtr[0..size]);

            // 4. Grab a reference to the allocator for this scope and free it.
            const whichAllocator = scopedAllocator.allocators[allocatorBucket].allocator();
            whichAllocator.free(slice);
        }

        // 5. Zig and the C standard allow invoking free against null ptrs.
        // So this effectively is a nop.
    }
};
