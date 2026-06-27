Vec2f :: Vector2;
Vec3f :: Vector3;
Vec4f :: Vector4;

operator*[] :: inline (v : Vec2f, index : int) -> *float {
    assert(index >= 0 && index < 2);
    return *v.component[index];
}

operator*[] :: inline (v : Vec2f, axis : Axis) -> *float {
    return *v.component[axis];
}

operator*[] :: inline (v : Vec3f, index : int) -> *float {
    assert(index >= 0 && index < 3);
    return *v.component[index];
}

operator*[] :: inline (v : Vec4f, index : int) -> *float {
    assert(index >= 0 && index < 4);
    return *v.component[index];
}

SignedAngle :: inline (a : Vec2f, b : Vec2f) -> float {
    denominator := sqrt(dot(a, a) * dot(b, b));
    if abs(denominator) < 0.00001 {
        return 0;
    }

    d := clamp(dot(a, b) / denominator, -1, 1);
    s := sign(a.x * b.y - a.y * b.y);

    return s * acos(d);
}

Scale :: inline (a : Vec2f, b : Vec2f) -> Vec2f {
    return .{
        a.x * b.x,
        a.y * b.y,
    };
}

min :: inline (v : Vec2f) -> Vec2f {
    return .{min(v.x), min(v.y)};
}

min :: inline (v : Vec3f) -> Vec3f {
    return .{min(v.x), min(v.y), min(v.z)};
}

min :: inline (v : Vec4f) -> Vec4f {
    return .{min(v.x), min(v.y), min(v.z), min(v.w)};
}

max :: inline (v : Vec2f) -> Vec2f {
    return .{max(v.x), max(v.y)};
}

max :: inline (v : Vec3f) -> Vec3f {
    return .{max(v.x), max(v.y), max(v.z)};
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

sign :: inline (v : Vec3f) -> Vec3f {
    return .{sign(v.x), sign(v.y), sign(v.z)};
}

sign :: inline (v : Vec4f) -> Vec4f {
    return .{sign(v.x), sign(v.y), sign(v.z), sign(v.w)};
}

abs :: inline (v : Vec2f) -> Vec2f {
    return .{abs(v.x), abs(v.y)};
}

abs :: inline (v : Vec3f) -> Vec3f {
    return .{abs(v.x), abs(v.y), abs(v.z)};
}

abs :: inline (v : Vec4f) -> Vec4f {
    return .{abs(v.x), abs(v.y), abs(v.z), abs(v.w)};
}

clamp :: inline (v : Vec2f, a : Vec2f, b : Vec2f) -> Vec2f {
    return .{clamp(v.x, a.x, b.x), clamp(v.y, a.y, b.y)};
}

clamp :: inline (v : Vec3f, a : Vec3f, b : Vec3f) -> Vec3f {
    return .{clamp(v.x, a.x, b.x), clamp(v.y, a.y, b.y), clamp(v.z, a.z, b.z)};
}

clamp :: inline (v : Vec4f, a : Vec4f, b : Vec4f) -> Vec4f {
    return .{clamp(v.x, a.x, b.x), clamp(v.y, a.y, b.y), clamp(v.z, a.z, b.z), clamp(v.w, a.w, b.w)};
}

fract :: inline (x : float) -> float {
    return x - floor(x);
}

InflateBounds :: inline (bounds : Vec4f, amount : Vec4f) -> Vec4f {
    return .{
        xy=bounds.xy - amount.xy,
        zw=bounds.zw + amount.zw,
    };
}

BarycentricCoords :: (p : Vec2f, p0 : Vec2f, p1 : Vec2f, p2 : Vec2f) -> float, float, float {
    denom := (p1.y - p2.y) * (p0.x - p2.x) + (p2.x - p1.x) * (p0.y - p2.y);
    w0 := ((p1.y - p2.y) * (p.x - p2.x) + (p2.x - p1.x) * (p.y - p2.y)) / denom;
    w1 := ((p2.y - p0.y) * (p.x - p2.x) + (p0.x - p2.x) * (p.y - p2.y)) / denom;
    w2 := 1 - w0 - w1;

    return w0, w1, w2;
}

ClampToTriangle :: (p : Vec2f, p0 : Vec2f, p1 : Vec2f, p2 : Vec2f) -> Vec2f {
    w0, w1, w2 := BarycentricCoords(p, p0, p1, p2);

    w0 = max(w0, 0);
    w1 = max(w1, 0);
    w2 = max(w2, 0);

    sum := w0 + w1 + w2;
    w0 /= sum;
    w1 /= sum;
    w2 /= sum;

    return {
        w0 * p0.x + w1 * p1.x + w2 * p2.x,
        w0 * p0.y + w1 * p1.y + w2 * p2.y,
    };
}

IsInsideTriangle :: inline (p : Vec2f, p0 : Vec2f, p1 : Vec2f, p2 : Vec2f) -> bool {
    Sign :: (p : Vec2f, p0 : Vec2f, p1 : Vec2f) -> float {
        return (p.x - p1.x) * (p0.y - p1.y) - (p0.x - p1.x) * (p.y - p1.y);
    }

    d0 := Sign(p, p0, p1);
    d1 := Sign(p, p1, p2);
    d2 := Sign(p, p2, p0);

    has_neg := (d0 < 0) || (d1 < 0) || (d2 < 0);
    has_pos := (d0 > 0) || (d1 > 0) || (d2 > 0);

    return !(has_neg && has_pos);
}

IsInsideRect :: inline (p : Vec2f, rect : Vec4f) -> bool {
    return p.x > rect.x && p.x < rect.z && p.y > rect.y && p.y < rect.w;
}

IsInsideRing :: inline (p : Vec2f, center : Vec2f, inner_radius : float, outer_radius : float) -> bool {
    sq_dist := length_squared(p - center);
    return sq_dist > inner_radius * inner_radius && sq_dist < outer_radius * outer_radius;
}

IsInsideCircle :: inline (p : Vec2f, center : Vec2f, radius : float) -> bool {
    sq_dist := length_squared(p - center);
    return sq_dist < radius * radius;
}

ClipRect :: inline (rect : Vec4f, clip_by : Vec4f) -> Vec4f {
    return .{
        xy=max(rect.xy, clip_by.xy),
        zw=min(rect.zw, clip_by.zw),
    };
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
    return .{
        1, 0, translation.x,
        0, 1, translation.y,
    };
}

// Creates a counter-clockwise rotation matrix
Rotate2D :: inline (angle_in_radians : float) -> Transform2D {
    cost := cos(angle_in_radians);
    sint := sin(angle_in_radians);

    return .{
        cost, -sint, 0,
        sint,  cost, 0,
    };
}

// Creates a uniform scale matrix
Scale2D :: inline (uniform_scale : float) -> Transform2D {
    return Scale2D(.{uniform_scale, uniform_scale});
}

// Creates a scale matrix
Scale2D :: inline (x : float, y : float) -> Transform2D {
    return Scale2D(.{x, y});
}

// Creates a scale matrix
Scale2D :: inline (scale : Vec2f) -> Transform2D {
    return .{
        scale.x, 0, 0,
        0, scale.y, 0,
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

PerpendicularCW :: inline (v : Vec2f) -> Vec2f {
    return .{v.y, -v.x};
}

Rotate :: inline (v : Vec2f, angle : float) -> Vec2f {
    ct := cos(angle);
    st := sin(angle);

    return .{
        v.x * ct - v.y * st,
        v.x * st + v.y * ct,
    };
}

ceil :: inline (value : Vec2f) -> Vec2f {
    return .{ceil(value.x), ceil(value.y)};
}

Round :: inline (value : float) -> float {
    if value < 0 {
        return cast(float, cast(int, value - 0.5));
    }

    return cast(float, cast(int, value + 0.5));
}

Round :: inline (value : Vec2f) -> Vec2f {
    return .{
        ifx value.x < 0 then cast(float, cast(int, value.x - 0.5)) else cast(float, cast(int, value.x + 0.5)),
        ifx value.y < 0 then cast(float, cast(int, value.y - 0.5)) else cast(float, cast(int, value.y + 0.5)),
    };
}

SnapDown :: inline (value : float, grid_size : float) -> float {
    if grid_size == 0 {
        return value;
    }
    return floor(value / grid_size) * grid_size;
}

Snap :: (value : float, grid_size : float) -> float {
    if grid_size == 0 {
        return value;
    }
    return Round(value / grid_size) * grid_size;
}

SnapUp :: (value : float, grid_size : float) -> float {
    if grid_size == 0 {
        return value;
    }
    return ceil(value / grid_size) * grid_size;
}

ToRads :: inline (angle_in_degrees : float) -> float {
    return angle_in_degrees * PI / 180.0;
}

ToDegs :: inline (angle_in_radians : float) -> float {
    return angle_in_radians * 180.0 / PI;
}
