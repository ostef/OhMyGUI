Vec2f :: Vector2;
Vec3f :: Vector3;
Vec4f :: Vector4;

Vec2b :: struct {
    x, y : s8;

    #overlay(x)
    component : [2]s8;
}

ToVec2f :: inline (v : Vec2b) -> Vec2f {
    return .{xx v.x, xx v.y};
}

Vec4b :: struct {
    x, y, z, w : s8;

    #overlay(x)
    xy : Vec2b;

    #overlay(y)
    yz : Vec2b;

    #overlay(z)
    zw : Vec2b;

    #overlay(x)
    component : [4]s8;
}

ToVec4f :: inline (v : Vec4b) -> Vec4f {
    return .{xx v.x, xx v.y, xx v.z, xx v.w};
}

operator*[] :: inline (v : Vec2f, $$index : int) -> *float {
    #if is_constant(index) {
        #assert index >= 0 && index < 2;
    } else {
        assert(index >= 0 && index < 2);
    }
    return *v.component[index];
}

operator*[] :: inline (v : Vec2f, axis : Axis) -> *float {
    return *v.component[axis];
}

operator*[] :: inline (v : Vec3f, $$index : int) -> *float {
    #if is_constant(index) {
        #assert index >= 0 && index < 3;
    } else {
        assert(index >= 0 && index < 3);
    }
    return *v.component[index];
}

operator*[] :: inline (v : Vec4f, $$index : int) -> *float {
    #if is_constant(index) {
        #assert index >= 0 && index < 4;
    } else {
        assert(index >= 0 && index < 4);
    }
    return *v.component[index];
}

operator*[] :: inline (v : Vec2b, $$index : int) -> *s8 {
    #if is_constant(index) {
        #assert index >= 0 && index < 2;
    } else {
        assert(index >= 0 && index < 2);
    }
    return *v.component[index];
}

operator*[] :: inline (v : Vec2b, axis : Axis) -> *s8 {
    return *v.component[axis];
}

operator*[] :: inline (v : Vec4b, $$index : int) -> *s8 {
    #if is_constant(index) {
        #assert index >= 0 && index < 4;
    } else {
        assert(index >= 0 && index < 4);
    }
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

MoveRect :: inline (rect : Vec4f, amount : Vec2f) -> Vec4f {
    return .{
        xy=rect.xy + amount,
        zw=rect.zw + amount,
    };
}

InflateRect :: inline (rect : Vec4f, amount : float) -> Vec4f {
    return .{
        rect.x - amount,
        rect.y - amount,
        rect.z + amount,
        rect.w + amount,
    };
}

InflateRect :: inline (rect : Vec4f, amount : Vec4f) -> Vec4f {
    return .{
        xy=rect.xy - amount.xy,
        zw=rect.zw + amount.zw,
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
    return p.x >= rect.x && p.x < rect.z && p.y >= rect.y && p.y < rect.w;
}

IsInsideRing :: inline (p : Vec2f, center : Vec2f, inner_radius : float, outer_radius : float) -> bool {
    sq_dist := length_squared(p - center);
    return sq_dist > inner_radius * inner_radius && sq_dist < outer_radius * outer_radius;
}

IsInsideCircle :: inline (p : Vec2f, center : Vec2f, radius : float) -> bool {
    sq_dist := length_squared(p - center);
    return sq_dist < radius * radius;
}

RectIntersectsRect :: inline (a : Vec4f, b : Vec4f) -> bool {
    return (a.x <= b.x && b.x <= a.z || a.x <= b.z && b.z <= a.z)
        && (a.y <= b.y && b.y <= a.w || a.y <= b.w && b.w <= a.w);
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

PerpendicularCCW :: inline (v : Vec2f) -> Vec2f {
    return .{-v.y, v.x};
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

InverseLerp :: inline (a : float, b : float, t : float) -> float {
    return (t - a) / (b - a);
}

ClosestPointOnLine :: (p0 : Vec2f, p1 : Vec2f, point : Vec2f) -> Vec2f {
    p0_point := point - p0;
    dir := p1 - p0;
    d := dot(p0_point, dir);
    if d < 0 {
        return p0;
    }

    sq_length := dot(dir, dir);
    if d > sq_length {
        return p1;
    }

    return p0 + dir * d / sq_length;
}

LineIntersection :: (a_p0 : Vec2f, a_p1 : Vec2f, b_p0 : Vec2f, b_p1 : Vec2f) -> bool, Vec2f {
    ax := a_p1.x - a_p0.x;
    ay := a_p1.y - a_p0.y;
    bx := b_p1.x - b_p0.x;
    by := b_p1.y - b_p0.y;

    denom := ax * by - ay * bx;

    if abs(denom) < 0.000001 {
        return false, .{};
    }

    dx := b_p0.x - a_p0.x;
    dy := b_p0.y - a_p0.y;

    t := (dx * by - dy * bx) / denom;
    u := (dx * ay - dy * ax) / denom;

    return true, a_p0 + t * Vec2f.{ax, ay};
}

BezierQuadratic :: inline (p0 : Vec2f, p1 : Vec2f, p2 : Vec2f, t : float) -> Vec2f {
    u := 1 - t;
    w0 := u * u;
    w1 := 2 * u * t;
    w2 := t * t;

    return .{
        w0 * p0.x + w1 * p1.x + w2 * p2.x,
        w0 * p0.y + w1 * p1.y + w2 * p2.y,
    };
}

BezierQuadraticTangent :: inline (p0 : Vec2f, p1 : Vec2f, p2 : Vec2f, t : float) -> Vec2f {
    return normalize(2 * (1 - t) * (p1 - p0) + 2 * t * (p2 - p1));
}

BezierQuadraticNormal :: inline (p0 : Vec2f, p1 : Vec2f, p2 : Vec2f, t : float) -> Vec2f {
    return PerpendicularCW(BezierQuadraticTangent(p0, p1, p2, t));
}

ClosestPointOnBezierQuadratic :: (p0 : Vec2f, p1 : Vec2f, p2 : Vec2f, point : Vec2f, num_segments := 0) -> Vec2f {
    if num_segments <= 0 {
        a := Vec2f.{abs(p0.x - p1.x), abs(p0.y - p1.y)};
        b := Vec2f.{abs(p1.x - p2.x), abs(p1.y - p2.y)};
        max_dist := max(a.x, a.y, b.x, b.y);

        num_segments = xx max(max_dist / 5 * context.omg.global_polygon_resolution, 5);
    }

    current_p := p0;
    closest_point := p0;
    closest_sq_dist := FLOAT32_INFINITY;
    for i : 1..num_segments {
        t := i / cast(float, num_segments);
        next_p := BezierQuadratic(p0, p1, p2, t);
        point_on_line := ClosestPointOnLine(current_p, next_p, point);
        current_p = next_p;

        sq_dist := length_squared(point - point_on_line);
        if sq_dist < closest_sq_dist {
            closest_point = point_on_line;
            closest_sq_dist = sq_dist;
        }
    }

    return closest_point;
}

// https://iquilezles.org/articles/bezierbbox/
BezierQuadraticBounds :: (p0 : Vec2f, p1 : Vec2f, p2 : Vec2f) -> Vec4f {
    min_ := min(p0, p2);
    max_ := max(p0, p2);

    if p1.x < min_.x || p1.y < min_.y || p1.x > max_.x || p1.y > max_.y {
        t := clamp((p0 - p1) / (p0 - 2 * p1 + p2), .{0, 0}, .{1, 1});
        u := Vec2f.{
            1 - t.x,
            1 - t.y,
        };
        q := Vec2f.{
            u.x * u.x * p0.x + 2 * u.x * t.x * p1.x + t.x * t.x * p2.x,
            u.y * u.y * p0.y + 2 * u.y * t.y * p1.y + t.y * t.y * p2.y,
        };

        min_ = min(min_, q);
        max_ = max(max_, q);
    }

    return .{xy=min_, zw=max_};
}

BezierCubic :: inline (p0 : Vec2f, p1 : Vec2f, p2 : Vec2f, p3 : Vec2f, t : float) -> Vec2f {
    u := 1 - t;
    w0 := u * u * u;
    w1 := 3 * u * u * t;
    w2 := 3 * u * t * t;
    w3 := t * t * t;

    return .{
        w0 * p0.x + w1 * p1.x + w2 * p2.x + w3 * p3.x,
        w0 * p0.y + w1 * p1.y + w2 * p2.y + w3 * p3.y,
    };
}

BezierCubicTangent :: inline (p0 : Vec2f, p1 : Vec2f, p2 : Vec2f, p3 : Vec2f, t : float) -> Vec2f {
    u := 1 - t;

    return normalize(3 * u * u * (p1 - p0) + 6 * u * t * (p2 - p1) + 3 * t * t * (p3 - p2));
}

BezierCubicNormal :: inline (p0 : Vec2f, p1 : Vec2f, p2 : Vec2f, p3 : Vec2f, t : float) -> Vec2f {
    return PerpendicularCW(BezierCubicTangent(p0, p1, p2, p3, t));
}

ClosestPointOnBezierCubic :: (p0 : Vec2f, p1 : Vec2f, p2 : Vec2f, p3 : Vec2f, point : Vec2f, num_segments := 0) -> Vec2f {
    if num_segments <= 0 {
        a := Vec2f.{abs(p0.x - p1.x), abs(p0.y - p1.y)};
        b := Vec2f.{abs(p1.x - p2.x), abs(p1.y - p2.y)};
        c := Vec2f.{abs(p2.x - p3.x), abs(p2.y - p3.y)};
        max_dist := max(a.x, a.y, b.x, b.y, c.x, c.y);

        num_segments = xx max(max_dist / 5 * context.omg.global_polygon_resolution, 5);
    }

    current_p := p0;
    closest_point := p0;
    closest_sq_dist := FLOAT32_INFINITY;
    for i : 1..num_segments {
        t := i / cast(float, num_segments);
        next_p := BezierCubic(p0, p1, p2, p3, t);
        point_on_line := ClosestPointOnLine(current_p, next_p, point);
        current_p = next_p;

        sq_dist := length_squared(point - point_on_line);
        if sq_dist < closest_sq_dist {
            closest_point = point_on_line;
            closest_sq_dist = sq_dist;
        }
    }

    return closest_point;
}

// https://iquilezles.org/articles/bezierbbox/
BezierCubicBounds :: (p0 : Vec2f, p1 : Vec2f, p2 : Vec2f, p3 : Vec2f) -> Vec4f {
    min_ := min(p0, p3);
    max_ := max(p0, p3);

    d := p0;
    c := -p0 + p1;
    b :=  p0 - 2 * p1 + p2;
    a := -p0 + 3 * p1 - 3 * p2 + p3;

    h := b * b - a * c;
    i := ifx h.x > 0 then 0 else 1;

    if h.x > 0 {
        h.x = sqrt(h.x);

        t := (-b.x - h.x) / a.x;
        if t > 0 && t < 1 {
            t2 := t * t;
            t3 := t * t2;
            u := 1 - t;
            u2 := u * u;
            u3 := u * u2;

            q := u3 * p0.x + 3 * u2 * t * p1.x + 3 * u * t2 * p2.x + t3 * p3.x;

            min_.x = min(min_.x, q);
            max_.x = max(max_.x, q);
        }

        t = (-b.x + h.x) / a.x;

        if t > 0 && t < 1 {
            t2 := t * t;
            t3 := t * t2;
            u := 1 - t;
            u2 := u * u;
            u3 := u * u2;

            q := u3 * p0.x + 3 * u2 * t * p1.x + 3 * u * t2 * p2.x + t3 * p3.x;

            min_.x = min(min_.x, q);
            max_.x = max(max_.x, q);
        }
    }

    if h.y > 0 {
        h.y = sqrt(h.y);

        t := (-b.y - h.y) / a.y;
        if t > 0 && t < 1 {
            t2 := t * t;
            t3 := t * t2;
            u := 1 - t;
            u2 := u * u;
            u3 := u * u2;

            q := u3 * p0.y + 3 * u2 * t * p1.y + 3 * u * t2 * p2.y + t3 * p3.y;

            min_.y = min(min_.y, q);
            max_.y = max(max_.y, q);
        }

        t = (-b.y + h.y) / a.y;

        if t > 0 && t < 1 {
            t2 := t * t;
            t3 := t * t2;
            u := 1 - t;
            u2 := u * u;
            u3 := u * u2;

            q := u3 * p0.y + 3 * u2 * t * p1.y + 3 * u * t2 * p2.y + t3 * p3.y;

            min_.y = min(min_.y, q);
            max_.y = max(max_.y, q);
        }
    }

    return .{xy=min_, zw=max_};
}
