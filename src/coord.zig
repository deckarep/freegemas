pub const Coord = struct {
    // Better expressed as a usize vs i32.
    x: ?usize = null,
    y: ?usize = null,

    pub inline fn equals(self: Coord, x: usize, y: usize) bool {
        return (self.x == x and self.y == y);
    }

    pub inline fn eqls(self: Coord, o: Coord) bool {
        return (self.x == o.x and self.y == o.y);
    }

    pub inline fn notEqls(self: Coord, o: Coord) bool {
        return !self.eqls(o);
    }
};
