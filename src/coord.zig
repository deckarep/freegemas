pub const Coord = struct {
    // r.c.: Better expressed as a usize vs i32 because Coord is used
    // to index into the Gem grid all over the fucken' place.
    x: ?usize = null,
    y: ?usize = null,

    // For a single Coord there are four possible states of values
    // 1. x is null
    // 2. x has a valid usize
    // 3. y is null
    // 4. y has a valid usize
    // The following functions should just work in terms of equality
    // even when they could be null.

    pub inline fn eqls(self: Coord, o: Coord) bool {
        return self.x == o.x and self.y == o.y;
    }

    pub inline fn notEqls(self: Coord, o: Coord) bool {
        return !self.eqls(o);
    }

    pub inline fn equals(self: Coord, x: usize, y: usize) bool {
        return self.x == x and self.y == y;
    }
};
