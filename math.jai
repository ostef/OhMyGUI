Vec2f :: Vector2;
Vec4f :: Vector4;

min :: inline (v : Vec2f) -> Vec2f {
    return .{min(v.x), min(v.y)};
}

min :: inline (v : Vec4f) -> Vec4f {
    return .{min(v.x), min(v.y), min(v.z), min(v.w)};
}

max :: inline (v : Vec2f) -> Vec2f {
    return .{max(v.x), max(v.y)};
}

max :: inline (v : Vec4f) -> Vec4f {
    return .{max(v.x), max(v.y), max(v.z), max(v.w)};
}

sign :: inline (x : float) -> float {
    return ifx x < 0 then -1.0 else 1.0;
}

sign :: inline (v : Vec2f) -> Vec2f {
    return .{sign(v.x), sign(v.y)};
}

sign :: inline (v : Vec4f) -> Vec4f {
    return .{sign(v.x), sign(v.y), sign(v.z), sign(v.w)};
}

abs :: inline (v : Vec2f) -> Vec2f {
    return .{abs(v.x), abs(v.y)};
}

abs :: inline (v : Vec4f) -> Vec4f {
    return .{abs(v.x), abs(v.y), abs(v.z), abs(v.w)};
}

clamp :: inline (v : Vec2f, a : Vec2f, b : Vec2f) -> Vec2f {
    return .{clamp(v.x, a.x, b.x), clamp(v.y, a.y, b.y)};
}

clamp :: inline (v : Vec4f, a : Vec4f, b : Vec4f) -> Vec4f {
    return .{clamp(v.x, a.x, b.x), clamp(v.y, a.y, b.y), clamp(v.z, a.z, b.z), clamp(v.w, a.w, b.w)};
}

// Basically a 2x3 matrix
Transform2D :: struct {
    a : float = 1;
    b : float;
    tx : float;

    c : float;
    d : float = 1;
    ty : float;
}

Mul :: inline (a : Transform2D, b : Transform2D) -> Transform2D {
    result : Transform2D = ---;
    result.a  = a.a * b.a  + a.b * b.c;
    result.b  = a.a * b.b  + a.b * b.d;
    result.tx = a.a * b.tx + a.b * b.ty + a.tx;

    result.c  = a.c * b.a  + a.d * b.c;
    result.d  = a.c * b.b  + a.d * b.d;
    result.ty = a.c * b.tx + a.d * b.ty + a.ty;

    return result;
}

operator* :: inline (a : Transform2D, b : Transform2D) -> Transform2D {
    return Mul(a, b);
}

// Creates a translation matrix
Translate2D :: inline (x : float, y : float) -> Transform2D {
    return Translate2D(.{x, y});
}

// Creates a translation matrix
Translate2D :: inline (translation : Vec2f) -> Transform2D {
    return Transform2D.{
        1, 0, translation.x,
        0, 1, translation.y,
    };
}

// Creates a counter-clockwise rotation matrix
Rotate2D :: inline (angle_in_radians : float) -> Transform2D {
    cost := cos(angle_in_radians);
    sint := sin(angle_in_radians);

    return Transform2D.{
        cost, -sint, 0,
        sint,  cost, 0,
    };
}

Invert :: (using transform : Transform2D, epsilon := 0.00001) -> Transform2D {
    det := a * d - b * c;
    if abs(det) < epsilon {
        return .{};
    }

    inv_det := 1 / det;

    // Invert linear part
    ra :=  d * inv_det;
    rb := -b * inv_det;
    rc := -c * inv_det;
    rd :=  a * inv_det;

    // Invert translation
    rtx := (-d * tx + b * ty) * inv_det;
    rty := ( c * tx - a * ty) * inv_det;

    return .{
        ra, rb, rtx,
        rc, rd, rty
    };
}

TransformVector :: inline (p : Vec2f, t : Transform2D) -> Vec2f {
    return .{
        t.a * p.x + t.b * p.y,
        t.c * p.x + t.d * p.y,
    };
}

TransformPoint :: inline (p : Vec2f, t : Transform2D) -> Vec2f {
    return .{
        t.a * p.x + t.b * p.y + t.tx,
        t.c * p.x + t.d * p.y + t.ty,
    };
}
