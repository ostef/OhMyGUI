SDShapeKind :: enum u8 {
    CirclePrimitive :: 0;
    BoxPrimitive;
    TrianglePrimitive;

    UnionOperation :: 200;
    SmoothUnionOperation;
    SubtractionOperation;
    IntersectionOperation;
    RoundOperation;
    OnionOperation;
    TransformOperation;
}

Shape_Bounds_Invalid :: Vec4f.{-FLOAT32_INFINITY, -FLOAT32_INFINITY, FLOAT32_INFINITY, FLOAT32_INFINITY};

SDShape :: struct {
    bounds := Shape_Bounds_Invalid;

    using _ : union kind : SDShapeKind {
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
            shape_a : *SDShape;
            shape_b : *SDShape;
        };

        .SmoothUnionOperation ,, smooth_union_op : struct {
            shape_a : *SDShape;
            shape_b : *SDShape;
            k : float;
        };

        .SubtractionOperation ,, subtraction_op : struct {
            shape_a : *SDShape;
            shape_b : *SDShape;
        };

        .IntersectionOperation ,, intersection_op : struct {
            shape_a : *SDShape;
            shape_b : *SDShape;
        };

        .RoundOperation ,, round_op : struct {
            shape : *SDShape;
            radius : float;
        };

        .OnionOperation ,, onion_op : struct {
            shape : *SDShape;
            radius : float;
        };

        .TransformOperation ,, transform_op : struct {
            shape : *SDShape;
            transform : Transform2D;
        };
    }
}

SDShapeToDraw :: struct {
    position : Vec2f;
    shape : *SDShape;
}

g_shapes_to_draw : [..]SDShapeToDraw;

DrawShape :: inline (shape : *SDShape, position : Vec2f = .{})  {
    array_add(*g_shapes_to_draw, .{shape=shape, position=position});
}

Circle :: inline (radius : float) -> *SDShape {
    shape := New(SDShape ,, temp);
    shape.kind = .CirclePrimitive;
    shape.circle_prim.radius = radius;
    shape.bounds = GetBounds(shape);

    return shape;
}

Box :: inline (width : float, height : float, radius : float = 0) -> *SDShape {
    return Box(.{width, height}, .{radius, radius, radius, radius});
}

Box :: inline (width : float, height : float, corner_radiuses : Vec4f) -> *SDShape {
    return Box(.{width, height}, corner_radiuses);
}

Box :: inline (width : float, height : float, tl_radius : float, tr_radius : float, bl_radius : float, br_radius : float) -> *SDShape {
    return Box(.{width, height}, .{tl_radius, tr_radius, bl_radius, br_radius});
}

Box :: inline (size : Vec2f, radius : float = 0) -> *SDShape {
    return Box(size, .{radius, radius, radius, radius});
}

Box :: inline (size : Vec2f, tl_radius : float, tr_radius : float, bl_radius : float, br_radius : float) -> *SDShape {
    return Box(size, .{tl_radius, tr_radius, bl_radius, br_radius});
}

Box :: inline (size : Vec2f, corner_radiuses : Vec4f) -> *SDShape {
    shape := New(SDShape ,, temp);
    shape.kind = .BoxPrimitive;
    shape.box_prim.size = size;
    shape.box_prim.corner_radiuses = corner_radiuses;
    shape.bounds = GetBounds(shape);

    return shape;
}

Triangle :: inline (p0 : Vec2f, p1 : Vec2f, p2 : Vec2f) -> *SDShape {
    shape := New(SDShape ,, temp);
    shape.kind = .TrianglePrimitive;
    shape.triangle_prim.p0 = p0;
    shape.triangle_prim.p1 = p1;
    shape.triangle_prim.p2 = p2;
    shape.bounds = GetBounds(shape);

    return shape;
}

Union :: inline (a : *SDShape, b : *SDShape) -> *SDShape {
    shape := New(SDShape ,, temp);
    shape.kind = .UnionOperation;
    shape.union_op.shape_a = a;
    shape.union_op.shape_b = b;
    shape.bounds = GetBounds(shape);

    return shape;
}

SmoothUnion :: inline (a : *SDShape, b : *SDShape, k : float) -> *SDShape {
    shape := New(SDShape ,, temp);
    shape.kind = .SmoothUnionOperation;
    shape.smooth_union_op.shape_a = a;
    shape.smooth_union_op.shape_b = b;
    shape.smooth_union_op.k = k;
    shape.bounds = GetBounds(shape);

    return shape;
}

Sub :: inline (a : *SDShape, b : *SDShape) -> *SDShape {
    shape := New(SDShape ,, temp);
    shape.kind = .SubtractionOperation;
    shape.subtraction_op.shape_a = a;
    shape.subtraction_op.shape_b = b;
    shape.bounds = GetBounds(shape);

    return shape;
}

Inter :: inline (a : *SDShape, b : *SDShape) -> *SDShape {
    shape := New(SDShape ,, temp);
    shape.kind = .IntersectionOperation;
    shape.intersection_op.shape_a = a;
    shape.intersection_op.shape_b = b;
    shape.bounds = GetBounds(shape);

    return shape;
}

Round :: inline (subshape : *SDShape, radius : float) -> *SDShape {
    shape := New(SDShape ,, temp);
    shape.kind = .RoundOperation;
    shape.round_op.shape = subshape;
    shape.round_op.radius = radius;
    shape.bounds = GetBounds(shape);

    return shape;
}

Onion :: inline (subshape : *SDShape, radius : float) -> *SDShape {
    shape := New(SDShape ,, temp);
    shape.kind = .OnionOperation;
    shape.onion_op.shape = subshape;
    shape.onion_op.radius = radius;
    shape.bounds = GetBounds(shape);

    return shape;
}

Transform :: inline (subshape : *SDShape, transform : Transform2D) -> *SDShape {
    shape := New(SDShape ,, temp);
    shape.kind = .TransformOperation;
    shape.transform_op.shape = subshape;
    shape.transform_op.transform = transform;
    shape.bounds = GetBounds(shape);

    return shape;
}

Move :: inline (subshape : *SDShape, x : float, y : float) -> *SDShape {
    return Transform(subshape, Translate2D(x, y));
}

Move :: inline (subshape : *SDShape, translation : Vec2f) -> *SDShape {
    return Transform(subshape, Translate2D(translation));
}

Rotate :: inline (subshape : *SDShape, angle_in_radians : float) -> *SDShape {
    return Transform(subshape, Rotate2D(angle_in_radians));
}

EvalSDF :: (p : Vec2f, shape : *SDShape) -> float {
    if #complete shape.kind == {
    case .CirclePrimitive;
        return length(p) - shape.circle_prim.radius;

    case .BoxPrimitive;
        using shape.box_prim;
        radius : float = ---;
        if p.x > 0 {
            if p.y > 0 {
                radius = corner_radiuses.x;
            } else {
                radius = corner_radiuses.y;
            }
        } else {
            if p.y > 0 {
                radius = corner_radiuses.z;
            } else {
                radius = corner_radiuses.w;
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
        return min(a, b);

    case .SmoothUnionOperation;
        a := EvalSDF(p, shape.smooth_union_op.shape_a);
        b := EvalSDF(p, shape.smooth_union_op.shape_b);

        k := shape.smooth_union_op.k;
        k *= 4;
        h := max(k - abs(a - b), 0) / k;

        return min(a, b) - h * h * k * (1 / 4.0);

    case .SubtractionOperation;
        a := EvalSDF(p, shape.subtraction_op.shape_a);
        b := EvalSDF(p, shape.subtraction_op.shape_b);
        return max(a, -b);

    case .IntersectionOperation;
        a := EvalSDF(p, shape.intersection_op.shape_a);
        b := EvalSDF(p, shape.intersection_op.shape_b);
        return max(a, b);

    case .RoundOperation;
        a := EvalSDF(p, shape.round_op.shape);
        return a - shape.round_op.radius;

    case .OnionOperation;
        a := EvalSDF(p, shape.onion_op.shape);
        return abs(a) - shape.onion_op.radius;

    case .TransformOperation;
        p2 := TransformPoint(p, Invert(shape.transform_op.transform));
        return EvalSDF(p2, shape.transform_op.shape);
    }

    return FLOAT32_INFINITY;
}

GetBounds :: (shape : *SDShape) -> Vec4f {
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
        return .{
            xy=min(a.xy, b.xy),
            zw=max(a.zw, b.zw),
        };

    case .SmoothUnionOperation;
        a := GetBounds(shape.smooth_union_op.shape_a);
        b := GetBounds(shape.smooth_union_op.shape_b);

        k := shape.smooth_union_op.k;

        return .{
            xy=min(a.xy, b.xy) - .{k,k},
            zw=max(a.zw, b.zw) + .{k,k},
        };

    case .SubtractionOperation;
        // @Todo: can we find something better fitting?
        a := GetBounds(shape.subtraction_op.shape_a);
        b := GetBounds(shape.subtraction_op.shape_b);
        return .{
            xy=min(a.xy, b.xy),
            zw=max(a.zw, b.zw),
        };

    case .IntersectionOperation;
        // @Todo: can we find something better fitting?
        a := GetBounds(shape.intersection_op.shape_a);
        b := GetBounds(shape.intersection_op.shape_b);
        return .{
            xy=min(a.xy, b.xy),
            zw=max(a.zw, b.zw),
        };

    case .RoundOperation;
        a := GetBounds(shape.round_op.shape);
        r := Vec2f.{shape.round_op.radius, shape.round_op.radius};
        return .{
            xy=min(a.xy - r, a.xy - r),
            zw=max(a.zw + r, a.zw + r),
        };

    case .OnionOperation;
        a := GetBounds(shape.onion_op.shape);
        r := Vec2f.{shape.onion_op.radius, shape.onion_op.radius};
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

IsInside :: (p : Vec2f, shape : *SDShape) -> bool {
    v := EvalSDF(p, shape);
    return v < 0;
}
