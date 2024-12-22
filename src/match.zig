const std = @import("std");
const Coord = @import("coord.zig").Coord;

const CoordList = std.ArrayList(Coord);

/// A group of matched squares.
pub const Match = struct {
    // In the original code, Match inherits from Vector<Coord>
    // In this code, I favor composition with an ArrayList
    // acting as my super.
    super: CoordList,

    const Self = @This();

    pub fn init(alloc: std.mem.Allocator) Self {
        return Self{
            .super = CoordList.init(alloc),
        };
    }

    pub fn deinit(self: *Self) void {
        self.super.deinit();
    }

    /// pushBack method was added to keep the code looking similar to
    /// the original code as possible.
    pub fn pushBack(self: *Self, c: Coord) !void {
        try self.super.append(c);
    }

    /// size method was named to keep the code looking similar to
    /// the original code as possible.
    pub fn size(self: Self) usize {
        return self.super.items.len;
    }

    /// Returns the the most middle item.
    pub fn midSquare(self: Self) Coord {
        const half: usize = self.super.items.len >> 1;
        return self.super.items[half];
    }

    /// Checks if the given coordinate is matched within the group
    ///
    /// @param c The coordinates to look for.
    ///
    /// @return true if c was found among the coords in the group.
    ///
    pub fn matched(self: Self, c: Coord) bool {
        for (self.super.items) |*coord| {
            if (c.eqls(coord.*)) {
                return true;
            }
        }
        return false;
    }
};
