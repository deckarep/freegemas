pub const SquareType = enum {
    sqEmpty,
    sqWhite,
    sqRed,
    sqPurple,
    sqOrange,
    sqGreen,
    sqYellow,
    sqBlue,

    pub fn String(self: SquareType) []const u8 {
        switch (self) {
            .sqEmpty => return "EMPT",
            .sqWhite => return "WHIT",
            .sqRed => return "RED_",
            .sqPurple => return "PURP",
            .sqOrange => return "ORAN",
            .sqGreen => return "GREE",
            .sqYellow => return "YELL",
            .sqBlue => return "BLUE",
        }
    }
};

pub const Square = struct {
    /// Kind of gem this square is holding.
    sqType: SquareType = .sqEmpty,

    /// Initial position of the square.
    /// r.c. - This one must stay as an i32.
    origY: i32 = 0,

    /// Vertical offset.
    /// This counts the number of positions this square has to fall.
    /// r.c. - better suited as usize vs i32.
    destY: usize = 0,

    /// Indicates whether the square has tot fall or not.
    mustFall: bool = false,

    pub fn eql(self: Square, other: Square) bool {
        return self.sqType == other.sqType;
    }

    pub fn tSquare(self: Square) SquareType {
        return self.sqType;
    }
};
