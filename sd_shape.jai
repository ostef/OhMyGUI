SDShapeKind :: enum u8 {
    CirclePrimitive;
    BoxPrimitive;
    TrianglePrimitive;

    UnionOperation;
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
        width : float;
    };

    .TransformOperation ,, transform_op : struct {
        shape : *SDShape;
        transform : Transform2D;
    };
}

g_shapes_to_draw : [..]*SDShape;

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

Onion :: inline (subshape : *SDShape, width : float) -> *SDShape {
    shape := New(SDShape ,, temp);
    shape.kind = .OnionOperation;
    shape.round_op.shape = subshape;
    shape.round_op.width = width;

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

DrawShape :: inline (subshape : *SDShape)  {
    array_add(*g_shapes_to_draw, subshape);
}
