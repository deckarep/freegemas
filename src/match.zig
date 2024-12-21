const std = @import("std");
const Coord = @import("coord.zig").Coord;

const CoordList = std.ArrayList(Coord);

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

    pub fn pushBack(self: *Self, c: Coord) !void {
        try self.super.append(c);
    }

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
    pub fn match(self: Self, c: Coord) bool {
        for (self.super.items) |*coord| {
            if (c.eqls(coord.*)) {
                return true;
            }
        }
        return false;
    }
};
