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
