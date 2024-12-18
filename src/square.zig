pub const SquareType = enum {
    sqEmpty,
    sqWhite,
    sqRed,
    sqPurple,
    sqOrange,
    sqGreen,
    sqYellow,
    sqBlue,
};

pub const Square = struct {
    /// Kind of gem this square is holding.
    sqType: SquareType = .sqEmpty,

    /// Initial position of the square.
    origY: i32 = 0,

    /// Vertical offset.
    /// This counts the number of positions this square has to fall.
    destY: i32 = 0,

    /// Indicates whether the square has tot fall or not.
    mustFall: bool = false,

    pub fn eqls(self: Square, other: Square) bool {
        return self.sqType == other.sqType;
    }

    pub fn tSquare(self: Square) SquareType {
        return self.sqType;
    }
};
