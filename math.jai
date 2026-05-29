Vec2f :: Vector2;
Vec4f :: Vector4;

operator*[] :: inline (v : Vec2f, index : int) -> *float {
    assert(index >= 0 && index < 2);
    return *v.component[index];
}

operator*[] :: inline (v : Vec2f, axis : Axis) -> *float {
    return *v.component[axis];
}

operator*[] :: inline (v : Vec4f, index : int) -> *float {
    assert(index >= 0 && index < 4);
    return *v.component[index];
}

operator*[] :: inline (v : Vec4f, axis : Axis) -> *float {
    return *v.component[axis];
}

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

InflateBounds :: inline (bounds : Vec4f, amount : Vec4f) -> Vec4f {
    return .{
        xy=bounds.xy - amount.xy,
        zw=bounds.zw + amount.zw,
    };
}

IsInsideRect :: inline (p : Vec2f, rect : Vec4f) -> bool {
    return p.x > rect.x && p.x < rect.z && p.y > rect.y && p.y < rect.w;
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

RGBA8 :: #type,isa u32;

SetAlpha :: inline (color : *RGBA8, alpha : float) {
    color.* = SetAlpha(color.*, alpha);
}

SetAlpha :: inline (color : RGBA8, alpha : float) -> RGBA8 {
    rgba := ColorVec4f(color);
    rgba.alpha = alpha;
    return ColorU32(rgba);
}

ColorU32 :: inline (rgba : Vec4f) -> RGBA8 {
    return ColorU32(rgba.x, rgba.y, rgba.z, rgba.w);
}

ColorU32 :: inline (r : float, g : float, b : float, a : float) -> RGBA8 {
    ur := cast(u32, clamp(r * 255, 0, 255));
    ug := cast(u32, clamp(g * 255, 0, 255));
    ub := cast(u32, clamp(b * 255, 0, 255));
    ua := cast(u32, clamp(a * 255, 0, 255));

    return cast(RGBA8, (ur << 24) | (ug << 16) | (ub << 8) | ua);
}

ColorVec4f :: inline (rgba : RGBA8) -> Vec4f {
    r := (cast(u32, rgba) >> 24) & 0xff;
    g := (cast(u32, rgba) >> 16) & 0xff;
    b := (cast(u32, rgba) >> 8)  & 0xff;
    a := (cast(u32, rgba) >> 0)  & 0xff;

    return .{r / 255.0, g / 255.0, b / 255.0, a / 255.0};
}
