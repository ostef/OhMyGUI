// Sign distance field based effects and drawing

ShapeKind :: enum u8 {
    CirclePrimitive :: 0;
    BoxPrimitive;
    TrianglePrimitive;

    UnionOperation :: 200;
    SubtractionOperation;
    IntersectionOperation;
    InflateOperation;
    OnionOperation;
    MorphOperation;
    TransformOperation;
}

Shape_Bounds_Invalid :: Vec4f.{-FLOAT32_INFINITY, -FLOAT32_INFINITY, FLOAT32_INFINITY, FLOAT32_INFINITY};

Shape :: struct {
    bounds := Shape_Bounds_Invalid;

    using _ : union kind : ShapeKind {
        .CirclePrimitive ,, circle_prim : struct {
            radius : float;
        };

        .BoxPrimitive ,, box_prim : struct {
            size : Vec2f;
            corner_radiuses : Vec4f;
        };

        .TrianglePrimitive ,, triangle_prim : struct {
            p0 : Vec2f;
            p1 : Vec2f;
            p2 : Vec2f;
        };

        .UnionOperation ,, union_op : struct {
            shape_a : *Shape;
            shape_b : *Shape;
            k : float;
        };

        .SubtractionOperation ,, subtraction_op : struct {
            shape_a : *Shape;
            shape_b : *Shape;
            k : float;
        };

        .IntersectionOperation ,, intersection_op : struct {
            shape_a : *Shape;
            shape_b : *Shape;
            k : float;
        };

        .InflateOperation ,, inflate_op : struct {
            shape : *Shape;
            radius : float;
        };

        .OnionOperation ,, onion_op : struct {
            shape : *Shape;
            radius : float;
        };

        .MorphOperation ,, morph_op : struct {
            shape_a : *Shape;
            shape_b : *Shape;
            t : float;
        };

        .TransformOperation ,, transform_op : struct {
            shape : *Shape;
            transform : Transform2D;
        };
    }
}

Circle :: inline (radius : float) -> *Shape {
    shape := New(Shape ,, temp);
    shape.kind = .CirclePrimitive;
    shape.circle_prim.radius = radius;
    shape.bounds = GetBounds(shape);

    return shape;
}

Box :: inline (width : float, height : float, radius : float = 0) -> *Shape {
    return Box(.{width, height}, .{radius, radius, radius, radius});
}

Box :: inline (width : float, height : float, corner_radiuses : Vec4f) -> *Shape {
    return Box(.{width, height}, corner_radiuses);
}

Box :: inline (width : float, height : float, tl_radius : float, tr_radius : float, bl_radius : float, br_radius : float) -> *Shape {
    return Box(.{width, height}, .{tl_radius, tr_radius, bl_radius, br_radius});
}

Box :: inline (size : Vec2f, radius : float = 0) -> *Shape {
    return Box(size, .{radius, radius, radius, radius});
}

Box :: inline (size : Vec2f, tl_radius : float, tr_radius : float, bl_radius : float, br_radius : float) -> *Shape {
    return Box(size, .{tl_radius, tr_radius, bl_radius, br_radius});
}

Box :: inline (size : Vec2f, corner_radiuses : Vec4f) -> *Shape {
    shape := New(Shape ,, temp);
    shape.kind = .BoxPrimitive;
    shape.box_prim.size = size;
    shape.box_prim.corner_radiuses = corner_radiuses;
    shape.bounds = GetBounds(shape);

    return shape;
}

Triangle :: inline (p0 : Vec2f, p1 : Vec2f, p2 : Vec2f) -> *Shape {
    shape := New(Shape ,, temp);
    shape.kind = .TrianglePrimitive;
    shape.triangle_prim.p0 = p0;
    shape.triangle_prim.p1 = p1;
    shape.triangle_prim.p2 = p2;
    shape.bounds = GetBounds(shape);

    return shape;
}

Union :: inline (a : *Shape, b : *Shape, smoothing_factor := 0.0) -> *Shape {
    shape := New(Shape ,, temp);
    shape.kind = .UnionOperation;
    shape.union_op.shape_a = a;
    shape.union_op.shape_b = b;
    shape.union_op.k = smoothing_factor;
    shape.bounds = GetBounds(shape);

    return shape;
}

Sub :: inline (a : *Shape, b : *Shape, smoothing_factor := 0.0) -> *Shape {
    shape := New(Shape ,, temp);
    shape.kind = .SubtractionOperation;
    shape.subtraction_op.shape_a = a;
    shape.subtraction_op.shape_b = b;
    shape.subtraction_op.k = smoothing_factor;
    shape.bounds = GetBounds(shape);

    return shape;
}

Inter :: inline (a : *Shape, b : *Shape, smoothing_factor := 0.0) -> *Shape {
    shape := New(Shape ,, temp);
    shape.kind = .IntersectionOperation;
    shape.intersection_op.shape_a = a;
    shape.intersection_op.shape_b = b;
    shape.intersection_op.k = smoothing_factor;
    shape.bounds = GetBounds(shape);

    return shape;
}

Inflate :: inline (subshape : *Shape, amount : float) -> *Shape {
    shape := New(Shape ,, temp);
    shape.kind = .InflateOperation;
    shape.inflate_op.shape = subshape;
    shape.inflate_op.amount = amount;
    shape.bounds = GetBounds(shape);

    return shape;
}

Onion :: inline (subshape : *Shape, radius : float) -> *Shape {
    shape := New(Shape ,, temp);
    shape.kind = .OnionOperation;
    shape.onion_op.shape = subshape;
    shape.onion_op.radius = radius;
    shape.bounds = GetBounds(shape);

    return shape;
}

Morph :: inline (a : *Shape, b : *Shape, t : float) -> *Shape {
    shape := New(Shape ,, temp);
    shape.kind = .MorphOperation;
    shape.morph_op.shape_a = a;
    shape.morph_op.shape_b = b;
    shape.morph_op.t = t;
    shape.bounds = GetBounds(shape);

    return shape;
}

Transform :: inline (subshape : *Shape, transform : Transform2D) -> *Shape {
    shape := New(Shape ,, temp);
    shape.kind = .TransformOperation;
    shape.transform_op.shape = subshape;
    shape.transform_op.transform = transform;
    shape.bounds = GetBounds(shape);

    return shape;
}

Move :: inline (subshape : *Shape, x : float, y : float) -> *Shape {
    return Transform(subshape, Translate2D(x, y));
}

Move :: inline (subshape : *Shape, translation : Vec2f) -> *Shape {
    return Transform(subshape, Translate2D(translation));
}

Rotate :: inline (subshape : *Shape, angle_in_radians : float) -> *Shape {
    return Transform(subshape, Rotate2D(angle_in_radians));
}

Scale :: inline (subshape : *Shape, uniform_scale : float) -> *Shape {
    return Transform(subshape, Scale2D(uniform_scale));
}

Scale :: inline (subshape : *Shape, x : float, y : float) -> *Shape {
    return Transform(subshape, Scale2D(x, y));
}

Scale :: inline (subshape : *Shape, scale : Vec2f) -> *Shape {
    return Transform(subshape, Scale2D(scale));
}

EvalSDF :: (p : Vec2f, shape : *Shape) -> float {
    OpSmoothUnion :: (a : float, b : float, k : float) -> float {
        if abs(k) < 0.00001 {
            return min(a, b);
        }

        k *= 4;
        h := max(k - abs(a - b), 0) / k;

        return min(a, b) - h * h * k * (1 / 4.0);
    }

    if #complete shape.kind == {
    case .CirclePrimitive;
        return length(p) - shape.circle_prim.radius;

    case .BoxPrimitive;
        using shape.box_prim;
        radius : float = ---;
        if p.x > 0 {
            if p.y > 0 {
                radius = corner_radiuses.w;
            } else {
                radius = corner_radiuses.y;
            }
        } else {
            if p.y > 0 {
                radius = corner_radiuses.z;
            } else {
                radius = corner_radiuses.x;
            }
        }

        q := abs(p) - size * 0.5 + Vec2f.{radius, radius};

        return min(max(q.x, q.y), 0.0) + length(max(q, Vec2f.{0,0})) - radius;

    case .TrianglePrimitive;
        using shape.triangle_prim;
        e0 := p1 - p0;
        e1 := p2 - p1;
        e2 := p0 - p2;
        v0 := p - p0;
        v1 := p - p1;
        v2 := p - p2;

        pq0 := v0 - e0 * clamp(dot(v0, e0) / dot(e0, e0), 0, 1);
        pq1 := v1 - e1 * clamp(dot(v1, e1) / dot(e1, e1), 0, 1);
        pq2 := v2 - e2 * clamp(dot(v2, e2) / dot(e2, e2), 0, 1);

        s := sign(e0.x * e2.y - e0.y * e2.x);
        d := min(min(Vec2f.{dot(pq0, pq0), s * (v0.x * e0.y - v0.y * e0.x)},
                     Vec2f.{dot(pq1, pq1), s * (v1.x * e1.y - v1.y * e1.x)}),
                     Vec2f.{dot(pq2, pq2), s * (v2.x * e2.y - v2.y * e2.x)});

        return -sqrt(d.x) * sign(d.y);

    case .UnionOperation;
        a := EvalSDF(p, shape.union_op.shape_a);
        b := EvalSDF(p, shape.union_op.shape_b);
        k := shape.union_op.k;
        return OpSmoothUnion(a, b, k);

    case .SubtractionOperation;
        a := EvalSDF(p, shape.subtraction_op.shape_a);
        b := EvalSDF(p, shape.subtraction_op.shape_b);
        k := shape.subtraction_op.k;
        return -OpSmoothUnion(-a, b, k);

    case .IntersectionOperation;
        a := EvalSDF(p, shape.intersection_op.shape_a);
        b := EvalSDF(p, shape.intersection_op.shape_b);
        k := shape.intersection_op.k;
        return -OpSmoothUnion(-a, -b, k);

    case .InflateOperation;
        a := EvalSDF(p, shape.inflate_op.shape);
        return a - shape.inflate_op.radius;

    case .OnionOperation;
        a := EvalSDF(p, shape.onion_op.shape);
        return abs(a) - shape.onion_op.radius;

    case .MorphOperation;
        a := EvalSDF(p, shape.morph_op.shape_a);
        b := EvalSDF(p, shape.morph_op.shape_b);
        t := shape.morph_op.t;
        return lerp(a, b, t);

    case .TransformOperation;
        p2 := TransformPoint(p, Invert(shape.transform_op.transform));
        return EvalSDF(p2, shape.transform_op.shape);
    }

    return FLOAT32_INFINITY;
}

GetBounds :: (shape : *Shape) -> Vec4f {
    if shape.bounds != Shape_Bounds_Invalid {
        return shape.bounds;
    }

    if #complete shape.kind == {
    case .CirclePrimitive;
        using shape.circle_prim;
        return .{-radius, -radius, radius, radius};

    case .BoxPrimitive;
        using shape.box_prim;
        return .{
            -size.x * 0.5 - max(corner_radiuses.z, corner_radiuses.w), -size.y * 0.5 - max(corner_radiuses.y, corner_radiuses.w),
             size.x * 0.5 + max(corner_radiuses.x, corner_radiuses.y),  size.y * 0.5 + max(corner_radiuses.x, corner_radiuses.w),
        };

    case .TrianglePrimitive;
        using shape.triangle_prim;
        return .{xy=min(p0, min(p1, p2)), zw=max(p0, max(p1, p2))};

    case .UnionOperation;
        a := GetBounds(shape.union_op.shape_a);
        b := GetBounds(shape.union_op.shape_b);

        k := shape.union_op.k;

        return .{
            xy=min(a.xy, b.xy) - .{k,k},
            zw=max(a.zw, b.zw) + .{k,k},
        };

    case .MorphOperation; #through;
    case .SubtractionOperation; #through; // Not sure this is correct
    case .IntersectionOperation;
        // @Todo: can we find something better fitting?
        a := GetBounds(shape.intersection_op.shape_a);
        b := GetBounds(shape.intersection_op.shape_b);
        return .{
            xy=min(a.xy, b.xy),
            zw=max(a.zw, b.zw),
        };

    case .OnionOperation; #through;
    case .InflateOperation;
        a := GetBounds(shape.inflate_op.shape);
        r := Vec2f.{shape.inflate_op.radius, shape.inflate_op.radius};
        return .{
            xy=min(a.xy - r, a.xy - r),
            zw=max(a.zw + r, a.zw + r),
        };

    case .TransformOperation;
        a := GetBounds(shape.transform_op.shape);
        p0 := TransformPoint(.{a.x, a.y}, shape.transform_op.transform);
        p1 := TransformPoint(.{a.x, a.w}, shape.transform_op.transform);
        p2 := TransformPoint(.{a.z, a.y}, shape.transform_op.transform);
        p3 := TransformPoint(.{a.z, a.w}, shape.transform_op.transform);

        return .{
            xy=min(p0, min(p1, min(p2, p3))),
            zw=max(p0, max(p1, max(p2, p3))),
        };
    }

    return .{};
}

IsInside :: (p : Vec2f, shape : *Shape, offset := Vec2f.{}) -> bool {
    v := EvalSDF(p - offset, shape);
    return v < 0;
}
