pub const Coord = struct {
    x: i32 = -1,
    y: i32 = -1,

    pub inline fn equals(self: Coord, x: i32, y: i32) bool {
        return (self.x == x and self.y == y);
    }

    pub inline fn eqls(self: Coord, o: Coord) bool {
        return (self.x == o.x and self.y == o.y);
    }

    pub inline fn notEqls(self: Coord, o: Coord) bool {
        return !self.eqls(o);
    }
};
