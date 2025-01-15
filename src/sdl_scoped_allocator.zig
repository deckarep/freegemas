const std = @import("std");
//const c = @import("cdefs.zig").c;

const gpaType = std.heap.GeneralPurposeAllocator(.{
    .safety = true,
    .verbose_log = true,
    .stack_trace_frames = 100,
});

//var gpa = std.heap.GeneralPurposeAllocator(.{}){
//.backing_allocator = //std.heap.c_allocator,
//};

// NOTE: C-based malloc, calloc, realloc and free basically use a general purpose
// stricter (larger) alignment that is intended to be suitable across all possible
// types. Zig on the other hand, will use more granular pointer alignment because
// the allocators know the type you are requested as a comptime argument.
// Therefore, we need to just mimic what C does because this ScopeAllocator is
// supposed is used by SDL when enabled.

// Effective result is that: all allocations will be 16 byte aligned which is suitable on
// a 64-bit platform.
//const PTR_ALIGNMENT: u29 = 16;

var activeAllocator: std.mem.Allocator = undefined;

// Stores a mapping of pointers => requested size.
const metadataType = std.AutoHashMap(usize, usize);
pub var metadata: metadataType = undefined;

const mappingType = std.AutoHashMap(usize, usize);
pub var mapping: mappingType = undefined;

const allocStackType = std.ArrayList(gpaType);

var scopedAllocator: *ScopedAllocator = undefined;

/// CMemInterface is simply a collection of C-abi pointers to functions
/// that can be used to give access to the ScopedAllocator's implemenation.
pub const CMemInterface = struct {
    malloc: fn (size: usize) callconv(.C) ?*anyopaque,
    calloc: fn (num: usize, size: usize) callconv(.C) ?*anyopaque,
    realloc: fn (ptr: ?*anyopaque, size: usize) callconv(.C) ?*anyopaque,
    free: fn (ptr: ?*anyopaque) callconv(.C) void,
};

fn detectAlignment() !u29 {
    const iterationCount = 100; // Number of allocations to test
    const maxAlignment = 256; // Upper limit of alignment to test

    // Bucket of tallies by alignment.
    var universalAlignmentTallies = [9]usize{
        0, // 1
        0, // 2
        0, // 4
        0, // 8
        0, // 16
        0, // 32
        0, // 64
        0, // 128
        0, // 256
    };

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const gpaAlloc = gpa.allocator();

    const tmpPointers = try gpaAlloc.alloc(usize, iterationCount);
    defer {
        // Clean each temp pointers.
        for (tmpPointers) |intPtr| {
            const ptr: ?*anyopaque = @ptrFromInt(intPtr);
            std.c.free(ptr);
        }

        // Clean the container itself.
        gpaAlloc.free(tmpPointers);
    }

    for (0..iterationCount) |i| {
        const ptr = std.c.malloc(1);
        // NOTE: malloc will keep returning the same pointer, so we need to prevent it
        // from recycling pointers by freeing everything at the end and avoiding the use
        // of defer.

        if (ptr == null) {
            std.debug.print("malloc failed on iteration {d}\n", .{i});
            return std.mem.Allocator.Error.OutOfMemory;
        }

        const intPtr = @intFromPtr(ptr.?);
        // Record the tmp ptr, to later free it.
        tmpPointers[i] = intPtr;

        var idx: usize = 0;
        var currentAlign: usize = 1;
        // Tally the alignments found for each given ptr.
        while (currentAlign <= maxAlignment) {
            if ((intPtr % currentAlign) == 0) {
                universalAlignmentTallies[idx] += 1;
                currentAlign <<= 1;
                idx += 1;
            } else {
                break;
            }
        }
    }

    // Find the strictest alignment used on this platform from the tallies.
    var strictestAlignment: u29 = 1;
    for (universalAlignmentTallies, 0..) |val, idx| {
        if (val < iterationCount) {
            strictestAlignment = @as(u29, 1) << @as(u5, @intCast(idx - 1));
            break;
        }
    }

    std.debug.print(
        "Minimum detected alignment of c.malloc: {any} alignment\n",
        .{strictestAlignment},
    );

    return strictestAlignment;
}

pub const ScopedAllocator = struct {

    // TODO: make these atomic probably.
    // NOTE: This metric tracking is adapted from the Zig gimme project by @Nektro.
    count_activeBytes: u64 = 0,
    count_totalBytes: u64 = 0,
    count_allocs: u64 = 0,
    count_alloc_failures: u64 = 0,
    count_allocs_success: u64 = 0,
    count_resizes: u64 = 0,
    count_frees: u64 = 0,

    allocatorStack: allocStackType = undefined,

    const Self = @This();
    // Hardcoded for now on 64-bit MacOS.
    const PTR_ALIGNMENT = 16;

    pub fn init() Self {
        return Self{};
    }

    /// .deinit will ensure the allocator stack has already been dealt with.
    /// This means if you have invoked .push() for any additionaly scoped GPAs,
    /// you must have invoked .pop() to ensure those additional scopes were cleaned up.
    /// It therefore only legal to call .deinit when the ScopeAllocator is back at root scope.
    /// The final root allocator will be checked for leaks.
    pub fn deinit(self: *Self) void {
        // 1. Ensure the stack must be back to the root GPA!
        std.debug.assert(self.allocatorStack.items.len == 1);

        // 2. The root can be deinitialized then.
        const deinit_status = self.allocatorStack.items[0].deinit();
        if (deinit_status == .leak) {
            std.debug.print("ROOT: leaks detected; you lack discipline!", .{});
        }
    }

    pub fn setup(self: *Self) !void {
        // Capture a global reference to this ScopeAllocator instance.
        scopedAllocator = self;

        // Initialize the root allocator, which is at index 0.
        var rootGPA = gpaType{};
        self.allocatorStack = allocStackType.init(rootGPA.allocator());
        _ = try self.allocatorStack.append(rootGPA);
        rootGPA = undefined;
        // gpaType{
        //     // NOTE: the macOS app leaks can detect leaks with the classic C-based malloc/free
        //     // So we use this on purpose.
        //     //.backing_allocator = std.heap.c_allocator,
        // };
        activeAllocator = self.allocator();
        metadata = metadataType.init(activeAllocator);
        mapping = mappingType.init(activeAllocator);

        // Figure out this platforms native memory alignment for C-abi calls.
        //try self.detectAlignment();
    }

    /// Detects the generic and strictests alignment that the C abi uses. This alignment will be used
    /// when the C abi functions are used as a shim along with the GPA. I know this code
    /// can likely be streamlined or refactored or perhaps some compilers provide
    /// this information but keep in mind this is highly, highly dependent on both
    /// the platform and compiler suite/tooling used for a given environment.
    // pub fn detectAlignment(self: *Self) !void {
    //     const iterationCount = 100; // Number of allocations to test
    //     const maxAlignment = 256; // Upper limit of alignment to test

    //     // Bucket of tallies by alignment.
    //     var universalAlignmentTallies = [9]usize{
    //         0, // 1
    //         0, // 2
    //         0, // 4
    //         0, // 8
    //         0, // 16
    //         0, // 32
    //         0, // 64
    //         0, // 128
    //         0, // 256
    //     };

    //     var tmpAlloc = self.allocator();
    //     const tmpPointers = try tmpAlloc.alloc(usize, iterationCount);
    //     defer {
    //         // Clean each temp pointers.
    //         for (tmpPointers) |intPtr| {
    //             const ptr: ?*anyopaque = @ptrFromInt(intPtr);
    //             std.c.free(ptr);
    //         }

    //         // Clean the container itself.
    //         tmpAlloc.free(tmpPointers);
    //     }

    //     for (0..iterationCount) |i| {
    //         const ptr = std.c.malloc(1);
    //         // NOTE: malloc will keep returning the same pointer, so we need to prevent it
    //         // from recycling pointers by freeing everything at the end and avoiding the use
    //         // of defer.

    //         if (ptr == null) {
    //             std.debug.print("malloc failed on iteration {d}\n", .{i});
    //             return;
    //         }

    //         const intPtr = @intFromPtr(ptr.?);
    //         // Record the tmp ptr, to later free it.
    //         tmpPointers[i] = intPtr;

    //         var idx: usize = 0;
    //         var currentAlign: usize = 1;
    //         // Tally the alignments found for each given ptr.
    //         while (currentAlign <= maxAlignment) {
    //             if ((intPtr % currentAlign) == 0) {
    //                 universalAlignmentTallies[idx] += 1;
    //                 currentAlign <<= 1;
    //                 idx += 1;
    //             } else {
    //                 break;
    //             }
    //         }
    //     }

    //     // Find the strictest alignment used on this platform from the tallies.
    //     var strictestAlignment: u29 = 1;
    //     for (universalAlignmentTallies, 0..) |val, idx| {
    //         if (val < iterationCount) {
    //             strictestAlignment = @as(u29, 1) << @as(u5, @intCast(idx - 1));
    //             break;
    //         }
    //     }

    //     std.debug.print(
    //         "Minimum detected alignment of c.malloc: {any} alignment\n",
    //         .{strictestAlignment},
    //     );
    // }

    /// Returns the complete C-abi memory interface if an app would like to use these for
    /// all their C-based memory allocations needs.
    pub inline fn getMemoryInterface(self: Self) CMemInterface {
        _ = self;

        return .{
            .malloc = myMalloc,
            .calloc = myCalloc,
            .realloc = myRealloc,
            .free = myFree,
        };
    }

    /// allocator simply returns an allocator interface that internally wraps
    /// the ScopedAllocator to allow for metrics.
    pub inline fn allocator(self: *Self) std.mem.Allocator {
        return .{
            .ptr = self,
            .vtable = &.{
                .alloc = wrappedAlloc,
                .resize = wrappedResize,
                .free = wrappedFree,
            },
        };
    }

    pub fn wrappedReport(self: Self) void {
        std.debug.print("***wrappedReport***\n", .{});
        std.debug.print("activeBytes: {d}\n", .{self.count_activeBytes});
        std.debug.print("totalBytes: {d}\n", .{self.count_totalBytes});
        std.debug.print("allocs: {d}\n", .{self.count_allocs});
        std.debug.print("allocs_success: {d}\n", .{self.count_allocs_success});
        std.debug.print("allocs_failures: {d}\n", .{self.count_alloc_failures});
        std.debug.print("resizes: {d}\n", .{self.count_resizes});
        std.debug.print("frees: {d}\n", .{self.count_frees});
        std.debug.print("missing frees (delta): {d}\n", .{self.count_allocs - self.count_frees});
    }

    fn wrappedAlloc(ctx: *anyopaque, len: usize, ptr_align: u8, ret_addr: usize) ?[*]u8 {
        var self: *Self = @alignCast(@ptrCast(ctx));
        var childAllocator = self.allocatorStack.items[self.currIdx()].allocator();
        self.count_allocs += 1;
        const ptr = childAllocator.rawAlloc(len, ptr_align, ret_addr);
        if (ptr == null) {
            self.count_alloc_failures += 1;
            return null;
        }
        self.count_allocs_success += 1;
        self.count_activeBytes += len;
        self.count_totalBytes += len;
        return ptr.?;
    }

    fn wrappedResize(ctx: *anyopaque, buf: []u8, buf_align: u8, new_len: usize, ret_addr: usize) bool {
        var self: *Self = @alignCast(@ptrCast(ctx));
        var childAllocator = self.allocatorStack.items[self.currIdx()].allocator();
        self.count_resizes += 1;
        const old_len = buf.len;
        const stable = childAllocator.rawResize(buf, buf_align, new_len, ret_addr);
        if (stable) {
            if (new_len > old_len) {
                self.count_activeBytes += new_len;
                self.count_activeBytes -= old_len;
                self.count_totalBytes += new_len;
                self.count_totalBytes -= old_len;
            } else {
                self.count_activeBytes -= old_len;
                self.count_activeBytes += new_len;
                self.count_totalBytes -= old_len;
                self.count_totalBytes += new_len;
            }
        }
        return stable;
    }

    fn wrappedFree(ctx: *anyopaque, buf: []u8, buf_align: u8, ret_addr: usize) void {
        var self: *Self = @alignCast(@ptrCast(ctx));
        var childAllocator = self.allocatorStack.items[self.currIdx()].allocator();
        self.count_frees += 1;
        self.count_activeBytes -= buf.len;
        return childAllocator.rawFree(buf, buf_align, ret_addr);
    }

    /// currIdx returns the index of the currently activeAllocator.
    inline fn currIdx(self: Self) usize {
        return self.allocatorStack.items.len - 1;
    }

    /// This will push and activate a freshly initialized GPA allocator onto the scope stack.
    /// Going forward, all allocations will use this GPA instance.
    pub inline fn push(self: *Self) !void {
        _ = try self.allocatorStack.append(gpaType{});
        activeAllocator = self.allocator();
    }

    /// This will remove the top-most active GPA and automatically .deinit it.
    /// If during .deinit this allocator has memory leaks, they will be reported.
    /// The immediately bottom allocator will become the active one going forward.
    /// An assertion ensures that you don't attempt to pop the root allocator.
    pub fn pop(self: *Self) void {
        // 1. Ensure we're at least above the root allocator and won't underflow.
        std.debug.assert(self.allocatorStack.items.len > 0);

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

        _ = self.allocatorStack.pop();
        activeAllocator = self.allocator();
    }

    /// This allocates a default 16 byte aligned address for fresh memory.
    /// The memory returned is uninitialized.
    fn myMalloc(size: usize) callconv(.C) ?*anyopaque {
        std.debug.print("myMalloc(size:{d}), mapping count: {d}, scope: {d}\n", .{ size, metadata.count(), scopedAllocator.currIdx() });
        const memBlock = activeAllocator.alignedAlloc(u8, PTR_ALIGNMENT, size) catch return null;

        // 2. If this assertion failed, this is a bug in the Zig stdlib.
        const intPtr = @intFromPtr(memBlock.ptr);
        std.debug.assert(std.mem.isAligned(intPtr, PTR_ALIGNMENT));

        // 3. Record the metadata of size and scope index.
        metadata.put(intPtr, size) catch return null;
        mapping.put(intPtr, scopedAllocator.currIdx()) catch return null;

        // 4. Finally, return the newly allocated child pointer.
        return memBlock.ptr;
    }

    fn myCalloc(num: usize, size: usize) callconv(.C) ?*anyopaque {
        std.debug.print("myCalloc(num:{d}, size:{d}, mapping count: {d}, scope: {d})\n", .{ num, size, metadata.count(), scopedAllocator.currIdx() });

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
        mapping.put(intPtr, scopedAllocator.currIdx()) catch return null;

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
                    mapping.put(possibleNewIntPtr, scopedAllocator.currIdx()) catch return null;

                    // And remove the original one, because realloc decided to use a new ptr.
                    _ = metadata.remove(intPtr);
                    _ = mapping.remove(intPtr);
                } else {
                    // Otherwise, the same ptr was used, just overwrite metadata records with the new size and scope index.
                    metadata.put(possibleNewIntPtr, size) catch return null;
                    mapping.put(possibleNewIntPtr, scopedAllocator.currIdx()) catch return null;
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
            const scopeIdx = mapping.get(intPtr).?;

            std.debug.print("myFree(ptr:{*}, bytes: {d}, alloc_bucket: {d}, mapping count:{d}, scope: {d})\n", .{
                block,
                size,
                scopeIdx,
                mapping.count(),
                scopedAllocator.currIdx(),
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
            const whichAllocator = scopedAllocator.allocatorStack.items[scopeIdx].allocator();
            whichAllocator.free(slice);
        }

        // 5. Zig and the C standard allow invoking free against null ptrs.
        // So this effectively is a NOP.
    }
};

// pub const ScopedAllocator = struct {
//     // TODO: make these atomic probably.
//     // NOTE: This metric tracking is adapted from the Zig gimme project by @Nektro.
//     count_activeBytes: u64 = 0,
//     count_totalBytes: u64 = 0,
//     count_allocs: u64 = 0,
//     count_alloc_failures: u64 = 0,
//     count_allocs_success: u64 = 0,
//     count_resizes: u64 = 0,
//     count_frees: u64 = 0,

//     allocatorStack: allocStackType = undefined,

//     const Self = @This();

//     pub fn init() Self {
//         return Self{};
//     }

//     /// .deinit will ensure the allocator stack has already been dealt with.
//     /// This means if you have invoked .push() for any additionaly scoped GPAs,
//     /// you must have invoked .pop() to ensure those additional scopes were cleaned up.
//     /// It therefore only legal to call .deinit when the ScopeAllocator is back at root scope.
//     /// The final root allocator will be checked for leaks.
//     pub fn deinit(self: *Self) void {
//         // 1. Ensure the stack must be back to the root GPA!
//         std.debug.assert(self.allocatorStack.items.len == 1);

//         // 2. The root can be deinitialized then.
//         const deinit_status = self.allocatorStack.items[0].deinit();
//         if (deinit_status == .leak) {
//             std.debug.print("ROOT: leaks detected; you lack discipline!", .{});
//         }
//     }

//     pub fn setup(self: *Self) !void {
//         // Capture a global reference to this ScopeAllocator instance.
//         scopedAllocator = self;

//         // Initialize the root allocator, which is at index 0.
//         var rootGPA = gpaType{};
//         self.allocatorStack = allocStackType.init(rootGPA.allocator());
//         _ = try self.allocatorStack.append(rootGPA);
//         rootGPA = undefined;
//         // gpaType{
//         //     // NOTE: the macOS app leaks can detect leaks with the classic C-based malloc/free
//         //     // So we use this on purpose.
//         //     //.backing_allocator = std.heap.c_allocator,
//         // };
//         activeAllocator = self.allocator();
//         metadata = metadataType.init(activeAllocator);
//         mapping = mappingType.init(activeAllocator);

//         // Figure out this platforms native memory alignment for C-abi calls.
//         try self.detectAlignment();
//     }

//     /// Detects the generic and strictests alignment that the C abi uses. This alignment will be used
//     /// when the C abi functions are used as a shim along with the GPA. I know this code
//     /// can likely be streamlined or refactored or perhaps some compilers provide
//     /// this information but keep in mind this is highly, highly dependent on both
//     /// the platform and compiler suite/tooling used for a given environment.
//     pub fn detectAlignment(self: *Self) !void {
//         const iterationCount = 100; // Number of allocations to test
//         const maxAlignment = 256; // Upper limit of alignment to test

//         // Bucket of tallies by alignment.
//         var universalAlignmentTallies = [9]usize{
//             0, // 1
//             0, // 2
//             0, // 4
//             0, // 8
//             0, // 16
//             0, // 32
//             0, // 64
//             0, // 128
//             0, // 256
//         };

//         var tmpAlloc = self.allocator();
//         const tmpPointers = try tmpAlloc.alloc(usize, iterationCount);
//         defer {
//             // Clean each temp pointers.
//             for (tmpPointers) |intPtr| {
//                 const ptr: ?*anyopaque = @ptrFromInt(intPtr);
//                 std.c.free(ptr);
//             }

//             // Clean the container itself.
//             tmpAlloc.free(tmpPointers);
//         }

//         for (0..iterationCount) |i| {
//             const ptr = std.c.malloc(1);
//             // NOTE: malloc will keep returning the same pointer, so we need to prevent it
//             // from recycling pointers by freeing everything at the end and avoiding the use
//             // of defer.

//             if (ptr == null) {
//                 std.debug.print("malloc failed on iteration {d}\n", .{i});
//                 return;
//             }

//             const intPtr = @intFromPtr(ptr.?);
//             // Record the tmp ptr, to later free it.
//             tmpPointers[i] = intPtr;

//             var idx: usize = 0;
//             var currentAlign: usize = 1;
//             // Tally the alignments found for each given ptr.
//             while (currentAlign <= maxAlignment) {
//                 if ((intPtr % currentAlign) == 0) {
//                     universalAlignmentTallies[idx] += 1;
//                     currentAlign <<= 1;
//                     idx += 1;
//                 } else {
//                     break;
//                 }
//             }
//         }

//         // Find the strictest alignment used on this platform from the tallies.
//         var strictestAlignment: u29 = 1;
//         for (universalAlignmentTallies, 0..) |val, idx| {
//             if (val < iterationCount) {
//                 strictestAlignment = @as(u29, 1) << @as(u5, @intCast(idx - 1));
//                 break;
//             }
//         }

//         std.debug.print(
//             "Minimum detected alignment of c.malloc: {any} alignment\n",
//             .{strictestAlignment},
//         );
//     }

//     /// Returns the complete C-abi memory interface if an app would like to use these for
//     /// all their C-based memory allocations needs.
//     pub inline fn getMemoryInterface(self: Self) CMemInterface {
//         _ = self;

//         return .{
//             .malloc = myMalloc,
//             .calloc = myCalloc,
//             .realloc = myRealloc,
//             .free = myFree,
//         };
//     }

//     /// allocator simply returns an allocator interface that internally wraps
//     /// the ScopedAllocator to allow for metrics.
//     pub inline fn allocator(self: *Self) std.mem.Allocator {
//         return .{
//             .ptr = self,
//             .vtable = &.{
//                 .alloc = wrappedAlloc,
//                 .resize = wrappedResize,
//                 .free = wrappedFree,
//             },
//         };
//     }

//     pub fn wrappedReport(self: Self) void {
//         std.debug.print("***wrappedReport***\n", .{});
//         std.debug.print("activeBytes: {d}\n", .{self.count_activeBytes});
//         std.debug.print("totalBytes: {d}\n", .{self.count_totalBytes});
//         std.debug.print("allocs: {d}\n", .{self.count_allocs});
//         std.debug.print("allocs_success: {d}\n", .{self.count_allocs_success});
//         std.debug.print("allocs_failures: {d}\n", .{self.count_alloc_failures});
//         std.debug.print("resizes: {d}\n", .{self.count_resizes});
//         std.debug.print("frees: {d}\n", .{self.count_frees});
//         std.debug.print("missing frees (delta): {d}\n", .{self.count_allocs - self.count_frees});
//     }

//     fn wrappedAlloc(ctx: *anyopaque, len: usize, ptr_align: u8, ret_addr: usize) ?[*]u8 {
//         var self: *ScopedAllocator = @alignCast(@ptrCast(ctx));
//         var childAllocator = self.allocatorStack.items[self.currIdx()].allocator();
//         self.count_allocs += 1;
//         const ptr = childAllocator.rawAlloc(len, ptr_align, ret_addr);
//         if (ptr == null) {
//             self.count_alloc_failures += 1;
//             return null;
//         }
//         self.count_allocs_success += 1;
//         self.count_activeBytes += len;
//         self.count_totalBytes += len;
//         return ptr.?;
//     }

//     fn wrappedResize(ctx: *anyopaque, buf: []u8, buf_align: u8, new_len: usize, ret_addr: usize) bool {
//         var self: *ScopedAllocator = @alignCast(@ptrCast(ctx));
//         var childAllocator = self.allocatorStack.items[self.currIdx()].allocator();
//         self.count_resizes += 1;
//         const old_len = buf.len;
//         const stable = childAllocator.rawResize(buf, buf_align, new_len, ret_addr);
//         if (stable) {
//             if (new_len > old_len) {
//                 self.count_activeBytes += new_len;
//                 self.count_activeBytes -= old_len;
//                 self.count_totalBytes += new_len;
//                 self.count_totalBytes -= old_len;
//             } else {
//                 self.count_activeBytes -= old_len;
//                 self.count_activeBytes += new_len;
//                 self.count_totalBytes -= old_len;
//                 self.count_totalBytes += new_len;
//             }
//         }
//         return stable;
//     }

//     fn wrappedFree(ctx: *anyopaque, buf: []u8, buf_align: u8, ret_addr: usize) void {
//         var self: *ScopedAllocator = @alignCast(@ptrCast(ctx));
//         var childAllocator = self.allocatorStack.items[self.currIdx()].allocator();
//         self.count_frees += 1;
//         self.count_activeBytes -= buf.len;
//         return childAllocator.rawFree(buf, buf_align, ret_addr);
//     }

//     /// currIdx returns the index of the currently activeAllocator.
//     inline fn currIdx(self: Self) usize {
//         return self.allocatorStack.items.len - 1;
//     }

//     /// This will push and activate a freshly initialized GPA allocator onto the scope stack.
//     /// Going forward, all allocations will use this GPA instance.
//     pub inline fn push(self: *Self) !void {
//         _ = try self.allocatorStack.append(gpaType{});
//         activeAllocator = self.allocator();
//     }

//     /// This will remove the top-most active GPA and automatically .deinit it.
//     /// If during .deinit this allocator has memory leaks, they will be reported.
//     /// The immediately bottom allocator will become the active one going forward.
//     /// An assertion ensures that you don't attempt to pop the root allocator.
//     pub fn pop(self: *Self) void {
//         // 1. Ensure we're at least above the root allocator and won't underflow.
//         std.debug.assert(self.allocatorStack.items.len > 0);

//         // 2. Assert we left nothing over in mapping at this bucket.
//         var mappingIter = mapping.iterator();
//         var mappingCount: usize = 0;
//         while (mappingIter.next()) |e| {
//             if (e.value_ptr.* == self.idx) {
//                 mappingCount += 1;
//             }
//         }

//         if (mappingCount > 0) {
//             std.debug.print("Found {d} mappings at this bucket level - you claimed you were done deallocating!\n", .{mappingCount});
//             //std.debug.assert(mappingCount == 0);
//         }

//         const deinit_status = self.allocators[self.idx].deinit();
//         if (deinit_status == .leak) {
//             std.debug.print("{d}: leaks detected; you lack discipline!\n", .{self.idx});
//         }

//         _ = self.allocatorStack.pop();
//         activeAllocator = self.allocator();
//     }

//     /// This allocates a default 16 byte aligned address for fresh memory.
//     /// The memory returned is uninitialized.
//     fn myMalloc(size: usize) callconv(.C) ?*anyopaque {
//         std.debug.print("myMalloc(size:{d}), mapping count: {d}, scope: {d}\n", .{ size, metadata.count(), scopedAllocator.currIdx() });
//         const memBlock = activeAllocator.alignedAlloc(u8, PTR_ALIGNMENT, size) catch return null;

//         // 2. If this assertion failed, this is a bug in the Zig stdlib.
//         const intPtr = @intFromPtr(memBlock.ptr);
//         std.debug.assert(std.mem.isAligned(intPtr, PTR_ALIGNMENT));

//         // 3. Record the metadata of size and scope index.
//         metadata.put(intPtr, size) catch return null;
//         mapping.put(intPtr, scopedAllocator.currIdx()) catch return null;

//         // 4. Finally, return the newly allocated child pointer.
//         return memBlock.ptr;
//     }

//     fn myCalloc(num: usize, size: usize) callconv(.C) ?*anyopaque {
//         std.debug.print("myCalloc(num:{d}, size:{d}, mapping count: {d}, scope: {d})\n", .{ num, size, metadata.count(), scopedAllocator.currIdx() });

//         // 1. Calloc has a slightly differing signature than malloc so we must multiply: num * size, to compute how many bytes
//         // are actually requested.
//         const computedBytes = num * size;
//         const memBlock = activeAllocator.alignedAlloc(u8, PTR_ALIGNMENT, computedBytes) catch return null;

//         // 2. Calloc requires zeroed memory, so zero out that shit.
//         @memset(memBlock, 0);

//         const intPtr = @intFromPtr(memBlock.ptr);
//         std.debug.assert(std.mem.isAligned(intPtr, PTR_ALIGNMENT));

//         // 3. Record the new ptr's metadata and scope index.
//         metadata.put(intPtr, computedBytes) catch return null;
//         mapping.put(intPtr, scopedAllocator.currIdx()) catch return null;

//         // 4. Finally return the child ptr.
//         return memBlock.ptr;
//     }

//     fn myRealloc(ptr: ?*anyopaque, size: usize) callconv(.C) ?*anyopaque {
//         if (ptr) |p| {
//             const intPtr = @intFromPtr(p);
//             std.debug.assert(std.mem.isAligned(intPtr, PTR_ALIGNMENT));

//             // NOTE: Since this is an existing pointer and a realloc call, assert that we
//             // must already be aware of this ptr within the metadata.
//             const originalSize = metadata.get(intPtr);
//             if (originalSize == null) {
//                 // This should never happen when all code is correct, so we'll return null.
//                 // C memory funcs basically treats error results by returning null.
//                 std.log.err("ptr was unknown to metadata!", .{});
//                 return null;
//             } else {
//                 // Zig's allocator apis work on slices, so we package up the data in a properly aligned slice.
//                 const memBlock: []align(PTR_ALIGNMENT) u8 = @alignCast(@as([*]u8, @ptrCast(p))[0..originalSize.?]);
//                 const reallocResult = activeAllocator.realloc(memBlock, size) catch return null;

//                 // Realloc may have provided a new/fresh pointer so we must use that going forward for the metadata.
//                 // We also assert this new ptr was aligned correctly. If not, this would technically be a Zig bug.
//                 const possibleNewIntPtr = @intFromPtr(reallocResult.ptr);
//                 std.debug.assert(std.mem.isAligned(possibleNewIntPtr, PTR_ALIGNMENT));

//                 if (possibleNewIntPtr != intPtr) {
//                     // Not the same, so record the new pointers within the metadata.
//                     metadata.put(possibleNewIntPtr, size) catch return null;
//                     mapping.put(possibleNewIntPtr, scopedAllocator.currIdx()) catch return null;

//                     // And remove the original one, because realloc decided to use a new ptr.
//                     _ = metadata.remove(intPtr);
//                     _ = mapping.remove(intPtr);
//                 } else {
//                     // Otherwise, the same ptr was used, just overwrite metadata records with the new size and scope index.
//                     metadata.put(possibleNewIntPtr, size) catch return null;
//                     mapping.put(possibleNewIntPtr, scopedAllocator.currIdx()) catch return null;
//                 }

//                 // Finally, return the child ptr.
//                 return reallocResult.ptr;
//             }
//         }

//         // If the incoming ptr is null, realloc is expected to simply malloc.
//         return myMalloc(size);
//     }

//     fn myFree(memBlock: ?*anyopaque) callconv(.C) void {
//         if (memBlock) |block| {
//             // 1. Ensure we're properly aligned.
//             const intPtr = @intFromPtr(block);
//             std.debug.assert(std.mem.isAligned(intPtr, PTR_ALIGNMENT));

//             // 2.  Grab the metadata out.
//             const size = metadata.get(intPtr).?;
//             const scopeIdx = mapping.get(intPtr).?;

//             std.debug.print("myFree(ptr:{*}, bytes: {d}, alloc_bucket: {d}, mapping count:{d}, scope: {d})\n", .{
//                 block,
//                 size,
//                 scopeIdx,
//                 mapping.count(),
//                 scopedAllocator.currIdx(),
//             });

//             // 6. Lastly, clean out the metadata.
//             defer {
//                 // 1. Remove the metadata we're tracking.
//                 var ok = metadata.remove(intPtr);
//                 std.debug.assert(ok);

//                 // 2. Remove the mapping of which bucket as well.
//                 ok = mapping.remove(intPtr);
//                 std.debug.assert(ok);
//             }

//             // 3. Zig's apis require a slice so we need to package in the raw pointer into a multi-pointer
//             // and finally into a properly aligned slice.
//             const multiPtr: [*]u8 = @ptrCast(block);
//             const slice: []align(PTR_ALIGNMENT) u8 = @alignCast(multiPtr[0..size]);

//             // 4. Grab a reference to the allocator for this scope and free it.
//             const whichAllocator = scopedAllocator.allocatorStack.items[scopeIdx].allocator();
//             whichAllocator.free(slice);
//         }

//         // 5. Zig and the C standard allow invoking free against null ptrs.
//         // So this effectively is a NOP.
//     }
// };
