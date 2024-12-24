pub fn easeLinear(t: f32, b: f32, c: f32, d: f32) f32 {
    return c * t / d + b;
}

pub fn easeInQuad(t: f32, b: f32, c: f32, d: f32) f32 {
    var mutT = t;
    mutT /= d;
    return c * mutT * mutT + b;
}

pub fn easeOutQuad(t: f32, b: f32, c: f32, d: f32) f32 {
    var mutT = t;
    mutT /= d;
    return -c * (mutT) * (mutT - 2) + b;
}

pub fn easeInOutQuad(t: f32, b: f32, c: f32, d: f32) f32 {
    var mutT = t;
    mutT /= d / 2;
    if (mutT < 1) {
        return c / 2 * mutT * mutT + b;
    } else {
        --mutT;
        return -c / 2 * ((mutT) * (mutT - 2) - 1) + b;
    }
}

pub fn easeInCubic(t: f32, b: f32, c: f32, d: f32) f32 {
    var mutT = t;
    mutT /= d;
    return c * (mutT) * mutT * mutT + b;
}

pub fn easeOutCubic(t: f32, b: f32, c: f32, d: f32) f32 {
    var mutT = t;
    mutT = mutT / d - 1;
    return c * (mutT * mutT * mutT + 1) + b;
}

pub fn easeInOutCubic(t: f32, b: f32, c: f32, d: f32) f32 {
    var mutT = t;
    mutT /= d / 2;
    if ((mutT) < 1) {
        return c / 2 * mutT * mutT * mutT + b;
    } else {
        mutT -= 2;
        return c / 2 * ((mutT) * mutT * mutT + 2) + b;
    }
}

pub fn easeInQuart(t: f32, b: f32, c: f32, d: f32) f32 {
    var mutT = t;
    mutT /= d;
    return c * (mutT) * mutT * mutT * mutT + b;
}

pub fn easeOutQuart(t: f32, b: f32, c: f32, d: f32) f32 {
    var mutT = t;
    mutT = mutT / d - 1;
    return -c * ((mutT) * mutT * mutT * mutT - 1) + b;
}

pub fn easeInOutQuart(t: f32, b: f32, c: f32, d: f32) f32 {
    var mutT = t;
    mutT /= d / 2;
    if ((mutT) < 1) {
        return c / 2 * mutT * mutT * mutT * mutT + b;
    } else {
        mutT -= 2;
        return -c / 2 * ((mutT) * mutT * mutT * mutT - 2) + b;
    }
}

// Untested funcs below.
pub fn easeOutBounce(t: f32, b: f32, c: f32, d: f32) f32 {
    var mutT = t / d;
    if (mutT < (1.0 / 2.75)) {
        return c * (7.5625 * mutT * mutT) + b;
    } else if (mutT < (2.0 / 2.75)) {
        mutT -= (1.5 / 2.75);
        return c * (7.5625 * mutT * mutT + 0.75) + b;
    } else if (mutT < (2.5 / 2.75)) {
        mutT -= (2.25 / 2.75);
        return c * (7.5625 * mutT * mutT + 0.9375) + b;
    } else {
        mutT -= (2.625 / 2.75);
        return c * (7.5625 * mutT * mutT + 0.984375) + b;
    }
}

pub fn easeInBounce(t: f32, b: f32, c: f32, d: f32) f32 {
    return c - easeOutBounce(d - t, 0, c, d) + b;
}

pub fn easeInOutBounce(t: f32, b: f32, c: f32, d: f32) f32 {
    if (t < d / 2) {
        return easeInBounce(t * 2, 0, c, d) * 0.5 + b;
    } else {
        return easeOutBounce(t * 2 - d, 0, c, d) * 0.5 + c * 0.5 + b;
    }
}
