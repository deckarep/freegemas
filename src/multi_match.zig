const std = @import("std");
const mch = @import("match.zig");
const MatchList = std.ArrayList(mch.Match);
const Coord = @import("coord.zig").Coord;

pub const MultiMatch = struct {
    // In the original code, MultiMatch inherits from Vector<Match>
    // In this code, I favor composition with an ArrayList
    // acting as my super.
    super: MatchList,

    const Self = @This();

    pub fn init(alloc: std.mem.Allocator) Self {
        return Self{
            .super = MatchList.init(alloc),
        };
    }

    pub fn deinit(self: *Self) void {
        defer self.super.deinit();

        for (self.super.items) |*m| {
            m.deinit();
        }
    }

    /// Checks if the given coordinate is matched in any of the matched groups.
    ///
    /// @param c The coordinates to look for.
    ///
    /// @return true if c was found in any of the matches
    ///
    pub fn matched(self: Self, c: Coord) bool {
        for (self.super.items) |*m| {
            if (m.match(c)) {
                return true;
            }
        }
        return false;
    }
};
