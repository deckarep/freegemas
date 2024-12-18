fn easeLinear(t: f32, b: f32, c: f32, d: f32) f32 {
    return c * t / d + b;
}

fn easeInQuad(t: f32, b: f32, c: f32, d: f32) f32 {
    t /= d;
    return c * t * t + b;
}

fn easeOutQuad(t: f32, b: f32, c: f32, d: f32) f32 {
    t /= d;
    return -c * (t) * (t - 2) + b;
}

fn easeInOutQuad(t: f32, b: f32, c: f32, d: f32) f32 {
    t /= d / 2;
    if (t < 1) {
        return c / 2 * t * t + b;
    } else {
        --t;
        return -c / 2 * ((t) * (t - 2) - 1) + b;
    }
}

fn easeInCubic(t: f32, b: f32, c: f32, d: f32) f32 {
    t /= d;
    return c * (t) * t * t + b;
}

fn easeOutCubic(t: f32, b: f32, c: f32, d: f32) f32 {
    t = t / d - 1;
    return c * (t * t * t + 1) + b;
}

fn easeInOutCubic(t: f32, b: f32, c: f32, d: f32) f32 {
    t /= d / 2;
    if ((t) < 1) {
        return c / 2 * t * t * t + b;
    } else {
        t -= 2;
        return c / 2 * ((t) * t * t + 2) + b;
    }
}

fn easeInQuart(t: f32, b: f32, c: f32, d: f32) f32 {
    t /= d;
    return c * (t) * t * t * t + b;
}

fn easeOutQuart(t: f32, b: f32, c: f32, d: f32) f32 {
    t = t / d - 1;
    return -c * ((t) * t * t * t - 1) + b;
}

fn easeInOutQuart(t: f32, b: f32, c: f32, d: f32) f32 {
    t /= d / 2;
    if ((t) < 1) {
        return c / 2 * t * t * t * t + b;
    } else {
        t -= 2;
        return -c / 2 * ((t) * t * t * t - 2) + b;
    }
}
