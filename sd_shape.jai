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

SDShape :: union kind : SDShapeKind {
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
        exponent : float;
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

g_shapes_to_draw : [..]*SDShape;

DrawShape :: inline (subshape : *SDShape)  {
    array_add(*g_shapes_to_draw, subshape);
}

Circle :: inline (radius : float) -> *SDShape {
    shape := New(SDShape ,, temp);
    shape.kind = .CirclePrimitive;
    shape.circle_prim.radius = radius;

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

    return shape;
}

Triangle :: inline (p0 : Vec2f, p1 : Vec2f, p2 : Vec2f) -> *SDShape {
    shape := New(SDShape ,, temp);
    shape.kind = .TrianglePrimitive;
    shape.triangle_prim.p0 = p0;
    shape.triangle_prim.p1 = p1;
    shape.triangle_prim.p2 = p2;

    return shape;
}

Union :: inline (a : *SDShape, b : *SDShape) -> *SDShape {
    shape := New(SDShape ,, temp);
    shape.kind = .UnionOperation;
    shape.union_op.shape_a = a;
    shape.union_op.shape_b = b;

    return shape;
}

SmoothUnion :: inline (a : *SDShape, b : *SDShape, k : float, exponent := 3.0) -> *SDShape {
    shape := New(SDShape ,, temp);
    shape.kind = .SmoothUnionOperation;
    shape.smooth_union_op.shape_a = a;
    shape.smooth_union_op.shape_b = b;
    shape.smooth_union_op.k = k;
    shape.smooth_union_op.exponent = exponent;

    return shape;
}

Sub :: inline (a : *SDShape, b : *SDShape) -> *SDShape {
    shape := New(SDShape ,, temp);
    shape.kind = .SubtractionOperation;
    shape.subtraction_op.shape_a = a;
    shape.subtraction_op.shape_b = b;

    return shape;
}

Inter :: inline (a : *SDShape, b : *SDShape) -> *SDShape {
    shape := New(SDShape ,, temp);
    shape.kind = .IntersectionOperation;
    shape.intersection_op.shape_a = a;
    shape.intersection_op.shape_b = b;

    return shape;
}

Round :: inline (subshape : *SDShape, radius : float) -> *SDShape {
    shape := New(SDShape ,, temp);
    shape.kind = .RoundOperation;
    shape.round_op.shape = subshape;
    shape.round_op.radius = radius;

    return shape;
}

Onion :: inline (subshape : *SDShape, radius : float) -> *SDShape {
    shape := New(SDShape ,, temp);
    shape.kind = .OnionOperation;
    shape.onion_op.shape = subshape;
    shape.onion_op.radius = radius;

    return shape;
}

Transform :: inline (subshape : *SDShape, transform : Transform2D) -> *SDShape {
    shape := New(SDShape ,, temp);
    shape.kind = .TransformOperation;
    shape.transform_op.shape = subshape;
    shape.transform_op.transform = transform;

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
        e := shape.smooth_union_op.exponent;
        e2 := e * 2;
        k := shape.smooth_union_op.k;
        k *= e2;
        h := max(k - abs(a - b), 0) / k;

        return min(a, b) - pow(h, e) * k * (1 / e2);

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

IsInside :: (p : Vec2f, shape : *SDShape) -> bool {
    v := EvalSDF(p, shape);
    return v < 0;
}
