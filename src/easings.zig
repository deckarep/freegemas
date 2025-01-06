/// t = current time
/// b = start value
/// c = change in value
/// d = duration
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
        mutT -= 1;
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

pub fn easeOutBounce(t: f32, b: f32, c: f32, d: f32) f32 {
    const n1 = 7.5625;
    const d1 = 2.75;

    var x = t / d; // Normalize t to x in range [0, 1]

    if (x < 1.0 / d1) {
        return c * (n1 * x * x) + b;
    } else if (x < 2.0 / d1) {
        x -= 1.5 / d1;
        return c * (n1 * x * x + 0.75) + b;
    } else if (x < 2.5 / d1) {
        x -= 2.25 / d1;
        return c * (n1 * x * x + 0.9375) + b;
    } else {
        x -= 2.625 / d1;
        return c * (n1 * x * x + 0.984375) + b;
    }
}

// pub fn easeOutBounce(t: f32, b: f32, c: f32, d: f32) f32 {
//     const bounceMultiplier = 4.0; // Reduced amplitude
//     const damping1 = 0.5; // Reduced first bounce
//     const damping2 = 0.7; // Reduced second bounce
//     const damping3 = 0.8; // Reduced final bounce
//     const frequency = 3.0; // Slightly stretched bounces

//     var mutT = t / d;
//     if (mutT < (1.0 / frequency)) {
//         return c * (bounceMultiplier * mutT * mutT) + b;
//     } else if (mutT < (2.0 / frequency)) {
//         mutT -= (1.5 / frequency);
//         return c * (bounceMultiplier * mutT * mutT + damping1) + b;
//     } else if (mutT < (2.5 / frequency)) {
//         mutT -= (2.25 / frequency);
//         return c * (bounceMultiplier * mutT * mutT + damping2) + b;
//     } else {
//         mutT -= (2.625 / frequency);
//         return c * (bounceMultiplier * mutT * mutT + damping3) + b;
//     }
// }

// const bounceMultiplier = 7.5625;

// // Untested funcs below.
// pub fn easeOutBounce(t: f32, b: f32, c: f32, d: f32) f32 {
//     var mutT = t / d;
//     if (mutT < (1.0 / 2.75)) {
//         return c * (bounceMultiplier * mutT * mutT) + b;
//     } else if (mutT < (2.0 / 2.75)) {
//         mutT -= (1.5 / 2.75);
//         return c * (bounceMultiplier * mutT * mutT + 0.75) + b;
//     } else if (mutT < (2.5 / 2.75)) {
//         mutT -= (2.25 / 2.75);
//         return c * (bounceMultiplier * mutT * mutT + 0.9375) + b;
//     } else {
//         mutT -= (2.625 / 2.75);
//         return c * (bounceMultiplier * mutT * mutT + 0.984375) + b;
//     }
// }

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
