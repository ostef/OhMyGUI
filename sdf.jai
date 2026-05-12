// Sign distance field based effects and drawing

SDShapeKind :: enum u8 {
    CirclePrimitive :: 0;
    BoxPrimitive;
    TrianglePrimitive;
    TexturePrimitive;

    UnionOperation :: 200;
    SmoothUnionOperation;
    SubtractionOperation;
    SmoothSubtractionOperation;
    IntersectionOperation;
    SmoothIntersectionOperation;
    RoundOperation;
    OnionOperation;
    MorphOperation;
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

        .TexturePrimitive ,, texture_prim : struct {
            texture : TextureHandle;
            uvs : Vec4f;
            size : Vec2f;
            dist_range : Vec2f;
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

        .SmoothSubtractionOperation ,, smooth_subtraction_op : struct {
            shape_a : *SDShape;
            shape_b : *SDShape;
            k : float;
        };

        .IntersectionOperation ,, intersection_op : struct {
            shape_a : *SDShape;
            shape_b : *SDShape;
        };

        .SmoothIntersectionOperation ,, smooth_intersection_op : struct {
            shape_a : *SDShape;
            shape_b : *SDShape;
            k : float;
        };

        .RoundOperation ,, round_op : struct {
            shape : *SDShape;
            radius : float;
        };

        .OnionOperation ,, onion_op : struct {
            shape : *SDShape;
            radius : float;
        };

        .MorphOperation ,, morph_op : struct {
            shape_a : *SDShape;
            shape_b : *SDShape;
            t : float;
        };

        .TransformOperation ,, transform_op : struct {
            shape : *SDShape;
            transform : Transform2D;
        };
    }
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

SDTexture :: inline (texture : TextureHandle, size : Vec2f, uvs := Vec4f.{0,0,1,1}, dist_range := Vec2f.{-1, 1}) -> *SDShape {
    shape := New(SDShape ,, temp);
    shape.kind = .TexturePrimitive;
    shape.texture_prim.texture = texture;
    shape.texture_prim.uvs = uvs;
    shape.texture_prim.size = size;
    shape.texture_prim.dist_range = dist_range;
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

Union :: inline (a : *SDShape, b : *SDShape, smoothing_factor : float) -> *SDShape {
    if smoothing_factor < 0.00001 {
        return Union(a, b);
    }

    shape := New(SDShape ,, temp);
    shape.kind = .SmoothUnionOperation;
    shape.smooth_union_op.shape_a = a;
    shape.smooth_union_op.shape_b = b;
    shape.smooth_union_op.k = smoothing_factor;
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

Sub :: inline (a : *SDShape, b : *SDShape, smoothing_factor : float) -> *SDShape {
    if smoothing_factor < 0.00001 {
        return Sub(a, b);
    }

    shape := New(SDShape ,, temp);
    shape.kind = .SmoothSubtractionOperation;
    shape.smooth_subtraction_op.shape_a = a;
    shape.smooth_subtraction_op.shape_b = b;
    shape.smooth_subtraction_op.k = smoothing_factor;
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

Inter :: inline (a : *SDShape, b : *SDShape, smoothing_factor : float) -> *SDShape {
    if smoothing_factor < 0.00001 {
        return Inter(a, b);
    }

    shape := New(SDShape ,, temp);
    shape.kind = .SmoothIntersectionOperation;
    shape.smooth_intersection_op.shape_a = a;
    shape.smooth_intersection_op.shape_b = b;
    shape.smooth_intersection_op.k = smoothing_factor;
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

Morph :: inline (a : *SDShape, b : *SDShape, t : float) -> *SDShape {
    shape := New(SDShape ,, temp);
    shape.kind = .MorphOperation;
    shape.morph_op.shape_a = a;
    shape.morph_op.shape_b = b;
    shape.morph_op.t = t;
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

Scale :: inline (subshape : *SDShape, uniform_scale : float) -> *SDShape {
    return Transform(subshape, Scale2D(uniform_scale));
}

Scale :: inline (subshape : *SDShape, x : float, y : float) -> *SDShape {
    return Transform(subshape, Scale2D(x, y));
}

Scale :: inline (subshape : *SDShape, scale : Vec2f) -> *SDShape {
    return Transform(subshape, Scale2D(scale));
}

EvalSDF :: (p : Vec2f, shape : *SDShape) -> float {
    OpSmoothUnion :: (a : float, b : float, k : float) -> float {
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

    case .TexturePrimitive; // Can't do much here!
        return 0;

    case .UnionOperation;
        a := EvalSDF(p, shape.union_op.shape_a);
        b := EvalSDF(p, shape.union_op.shape_b);
        return min(a, b);

    case .SmoothUnionOperation;
        a := EvalSDF(p, shape.smooth_union_op.shape_a);
        b := EvalSDF(p, shape.smooth_union_op.shape_b);
        k := shape.smooth_union_op.k;
        return OpSmoothUnion(a, b, k);

    case .SubtractionOperation;
        a := EvalSDF(p, shape.subtraction_op.shape_a);
        b := EvalSDF(p, shape.subtraction_op.shape_b);
        return max(a, -b);

    case .SmoothSubtractionOperation;
        a := EvalSDF(p, shape.smooth_subtraction_op.shape_a);
        b := EvalSDF(p, shape.smooth_subtraction_op.shape_b);
        k := shape.smooth_subtraction_op.k;
        return -OpSmoothUnion(-a, b, k);

    case .IntersectionOperation;
        a := EvalSDF(p, shape.intersection_op.shape_a);
        b := EvalSDF(p, shape.intersection_op.shape_b);
        return max(a, b);

    case .SmoothIntersectionOperation;
        a := EvalSDF(p, shape.smooth_intersection_op.shape_a);
        b := EvalSDF(p, shape.smooth_intersection_op.shape_b);
        k := shape.smooth_intersection_op.k;
        return -OpSmoothUnion(-a, -b, k);

    case .RoundOperation;
        a := EvalSDF(p, shape.round_op.shape);
        return a - shape.round_op.radius;

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

    case .TexturePrimitive;
        using shape.texture_prim;
        return .{
            -size.x * 0.5, -size.y * 0.5,
             size.x * 0.5,  size.y * 0.5,
        };

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

    case .SubtractionOperation; #through;
    case .SmoothIntersectionOperation; // Not sure this is correct
        return GetBounds(shape.subtraction_op.shape_a);

    case .MorphOperation; #through;
    case .SmoothSubtractionOperation; #through; // Not sure this is correct
    case .IntersectionOperation;
        // @Todo: can we find something better fitting?
        a := GetBounds(shape.intersection_op.shape_a);
        b := GetBounds(shape.intersection_op.shape_b);
        return .{
            xy=min(a.xy, b.xy),
            zw=max(a.zw, b.zw),
        };

    case .OnionOperation; #through;
    case .RoundOperation;
        a := GetBounds(shape.round_op.shape);
        r := Vec2f.{shape.round_op.radius, shape.round_op.radius};
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

IsInside :: (p : Vec2f, shape : *SDShape, offset := Vec2f.{}) -> bool {
    v := EvalSDF(p - offset, shape);
    return v < 0;
}

// https://shaderfun.com/2018/07/01/signed-distance-fields-part-7-some-simple-effects/
// https://shaderfun.com/2018/07/23/signed-distance-fields-part-8-gradients-bevels-and-noise/

TextureHandle :: u64;

Drawing :: struct {
    position : Vec2f;
    shape : *SDShape;
    clip_shape : *SDShape;
    effects : [..]Effect;
    should_override_default_effect : bool;
}

DrawShape :: (shape : *SDShape, position : Vec2f = .{}) -> *Drawing {
    array_add(*context.omg.shapes_to_draw, .{shape=shape, position=position});

    drawing := *context.omg.shapes_to_draw[context.omg.shapes_to_draw.count - 1];
    drawing.effects.allocator = temp;

    array_add(*drawing.effects, context.omg.default_effect);
    drawing.should_override_default_effect = true;

    return drawing;
}

Clip :: inline (drawing : *Drawing, shape : *SDShape) {
    drawing.clip_shape = shape;
}

ColorU32 :: inline (rgba : Vec4f) -> u32 {
    return ColorU32(rgba.x, rgba.y, rgba.z, rgba.w);
}

ColorU32 :: inline (r : float, g : float, b : float, a : float) -> u32 {
    ur := cast(u32, clamp(r * 255, 0, 255));
    ug := cast(u32, clamp(g * 255, 0, 255));
    ub := cast(u32, clamp(b * 255, 0, 255));
    ua := cast(u32, clamp(a * 255, 0, 255));

    return (ur << 24) | (ug << 16) | (ub << 8) | ua;
}

ColorVec4f :: inline (rgba : u32) -> Vec4f {
    r := (rgba >> 24) & 0xff;
    g := (rgba >> 16) & 0xff;
    b := (rgba >> 8)  & 0xff;
    a := (rgba >> 0)  & 0xff;

    return .{r / 255.0, g / 255.0, b / 255.0, a / 255.0};
}

EffectKind :: enum u8 {
    SolidColor;
    StrokeColor;
    OuterShadow;
    InnerShadow;
}

// We could add a blend mode feature?
Effect :: union kind : EffectKind {
    .SolidColor ,, solid_color : struct {
        color : u32;
        blur_factor : float;
    };
    .StrokeColor ,, stroke_color : struct {
        color : u32;
        blur_factor : float;
        inset : float;
        size : float;
    };
    .OuterShadow ,, outer_shadow : struct {
        color : u32;
        offset : Vec2f;
        blur_factor : float;
    };
    .InnerShadow ,, inner_shadow : struct {
        color : u32;
        offset : Vec2f;
        blur_factor : float;
    };
}

PushEffect :: inline (using drawing : *Drawing) -> *Effect {
    if should_override_default_effect {
        should_override_default_effect = false;
        effect := *effects[0];
        effect.* = .{};

        return effect;
    }

    return array_add(*effects);
}

SolidColor :: inline (using drawing : *Drawing, color : Vec4f, blur_factor := 0.0) {
    SolidColor(drawing, ColorU32(color), blur_factor);
}

SolidColor :: inline (using drawing : *Drawing, color : u32, blur_factor := 0.0) {
    effect := PushEffect(drawing);
    effect.kind = .SolidColor;
    effect.solid_color.color = color;
    effect.solid_color.blur_factor = blur_factor;
}

StrokeColor :: inline (using drawing : *Drawing, color : Vec4f, size : float, inset := 0.0, blur_factor := 0.0) {
    StrokeColor(drawing, ColorU32(color), size, inset, blur_factor);
}

StrokeColor :: inline (using drawing : *Drawing, color : u32, size : float, inset := 0.0, blur_factor := 0.0) {
    effect := PushEffect(drawing);
    effect.kind = .StrokeColor;
    effect.stroke_color.color = color;
    effect.stroke_color.size = size;
    effect.stroke_color.inset = inset;
    effect.stroke_color.blur_factor = blur_factor;
}

OuterShadow :: inline (using drawing : *Drawing, offset : Vec2f, blur_factor : float, opacity : float) {
    OuterShadow(drawing, offset, blur_factor, .{0,0,0,opacity});
}

OuterShadow :: inline (using drawing : *Drawing, offset : Vec2f, blur_factor : float, color := Vec4f.{0,0,0,0.5}) {
    OuterShadow(drawing, offset, blur_factor, ColorU32(color));
}

OuterShadow :: inline (using drawing : *Drawing, offset : Vec2f, blur_factor : float, color : u32) {
    effect := PushEffect(drawing);
    effect.kind = .OuterShadow;
    effect.outer_shadow.offset = offset;
    effect.outer_shadow.blur_factor = blur_factor;
    effect.outer_shadow.color = color;
}

InnerShadow :: inline (using drawing : *Drawing, blur_factor : float, opacity : float, offset := Vec2f.{0,0}) {
    InnerShadow(drawing, blur_factor, .{0,0,0,opacity}, offset);
}

InnerShadow :: inline (using drawing : *Drawing, blur_factor : float, color := Vec4f.{0,0,0,1}, offset := Vec2f.{0,0}) {
    InnerShadow(drawing, blur_factor, ColorU32(color), offset);
}

InnerShadow :: inline (using drawing : *Drawing, blur_factor : float, color : u32, offset := Vec2f.{0,0}) {
    effect := PushEffect(drawing);
    effect.kind = .InnerShadow;
    effect.inner_shadow.offset = offset;
    effect.inner_shadow.blur_factor = blur_factor;
    effect.inner_shadow.color = color;
}

GetBounds :: (bounds : Vec4f, effect : *Effect) -> Vec4f {
    if effect.kind == {
    case .OuterShadow;
        using effect.outer_shadow;

        inflate : Vec4f;
        if blur_factor > 0 {
            inflate.xy = max(inflate.xy, Vec2f.{blur_factor, blur_factor});
            inflate.zw = max(inflate.zw, Vec2f.{blur_factor, blur_factor});
        }
        if offset.x > 0 {
            inflate.z += offset.x;
        }
        if offset.y > 0 {
            inflate.w += offset.y;
        }
        if offset.x < 0 {
            inflate.x -= offset.x;
        }
        if offset.y < 0 {
            inflate.y -= offset.y;
        }

        return InflateBounds(bounds, inflate);

    case .StrokeColor;
        using effect.stroke_color;

        inflate : Vec4f;
        if inset < 0 {
            inflate.xy = max(inflate.xy, -Vec2f.{inset, inset});
            inflate.zw = max(inflate.zw, -Vec2f.{inset, inset});
        }
        if blur_factor > 0 {
            inflate.xy = max(inflate.xy, Vec2f.{blur_factor, blur_factor});
            inflate.zw = max(inflate.zw, Vec2f.{blur_factor, blur_factor});
        }

        return InflateBounds(bounds, inflate);

    case .SolidColor;
        using effect.solid_color;

        inflate : Vec4f;
        if blur_factor > 0 {
            inflate.xy = max(inflate.xy, Vec2f.{blur_factor, blur_factor});
            inflate.zw = max(inflate.zw, Vec2f.{blur_factor, blur_factor});
        }

        return InflateBounds(bounds, inflate);

    case;
        return bounds;
    }
}

#scope_module

ShaderSDInstance :: struct {
    bounds : Vec4f;
    position : Vec2f;
    first_shape_index : u32;
    num_shapes : u32;
    first_effect_index : u32;
    num_effects : u32;
    first_clip_shape_index : u32;
    num_clip_shapes : u32;
}

ShaderSDShape :: struct {
    kind : u32;
    padding : [3]u32;
    params : [8]float;
}

ShaderEffect :: struct {
    kind : u32;
    params0 : [3]u32;
    params1 : [4]float;
}

DrawCall :: struct {
    texture : TextureHandle;
    base_instance : u32;
    num_instances : u32;
}

FlattenShapes :: (shape : *SDShape, buffer : *[..]ShaderSDShape, textures : *[..]TextureHandle) -> u32 {
    num_shapes : u32;

    shshape : ShaderSDShape;
    shshape.kind = xx shape.kind;

    if #complete shape.kind == {
    case .CirclePrimitive;
        shshape.params[0] = shape.circle_prim.radius;

    case .BoxPrimitive;
        shshape.params[0] = shape.box_prim.size.x;
        shshape.params[1] = shape.box_prim.size.y;
        shshape.params[2] = shape.box_prim.corner_radiuses.x;
        shshape.params[3] = shape.box_prim.corner_radiuses.y;
        shshape.params[4] = shape.box_prim.corner_radiuses.z;
        shshape.params[5] = shape.box_prim.corner_radiuses.w;

    case .TrianglePrimitive;
        shshape.params[0] = shape.triangle_prim.p0.x;
        shshape.params[1] = shape.triangle_prim.p0.y;
        shshape.params[2] = shape.triangle_prim.p1.x;
        shshape.params[3] = shape.triangle_prim.p1.y;
        shshape.params[4] = shape.triangle_prim.p2.x;
        shshape.params[5] = shape.triangle_prim.p2.y;

    case .TexturePrimitive;
        array_add_if_unique(textures, xx shape.texture_prim.texture);
        shshape.params[0] = shape.texture_prim.uvs.x;
        shshape.params[1] = shape.texture_prim.uvs.y;
        shshape.params[2] = shape.texture_prim.uvs.z;
        shshape.params[3] = shape.texture_prim.uvs.w;
        shshape.params[4] = shape.texture_prim.size.x;
        shshape.params[5] = shape.texture_prim.size.y;
        shshape.params[6] = shape.texture_prim.dist_range.x;
        shshape.params[7] = shape.texture_prim.dist_range.y;

    case .SmoothSubtractionOperation; #through;
    case .SmoothIntersectionOperation; #through;
    case .SmoothUnionOperation;
        shshape.params[0] = shape.smooth_union_op.k;
        #through;

    case .UnionOperation; #through;
    case .SubtractionOperation; #through;
    case .IntersectionOperation;
        num_shapes += FlattenShapes(shape.union_op.shape_a, buffer, textures);
        num_shapes += FlattenShapes(shape.union_op.shape_b, buffer, textures);

    case .RoundOperation;
        num_shapes += FlattenShapes(shape.round_op.shape, buffer, textures);

        shshape.params[0] = shape.round_op.radius;

    case .OnionOperation;
        num_shapes += FlattenShapes(shape.onion_op.shape, buffer, textures);

        shshape.params[0] = shape.onion_op.radius;

    case .MorphOperation;
        shshape.params[0] = shape.morph_op.t;
        num_shapes += FlattenShapes(shape.morph_op.shape_a, buffer, textures);
        num_shapes += FlattenShapes(shape.morph_op.shape_b, buffer, textures);

    case .TransformOperation;
        // For transform operations, we push 1 transformation to the coordinate
        // system, then we push the shape, then we push another transformation
        // back to the original coordinate system
        t := Invert(shape.transform_op.transform);
        shshape.params[0] = t.a;
        shshape.params[1] = t.b;
        shshape.params[2] = t.tx;
        shshape.params[3] = t.c;
        shshape.params[4] = t.d;
        shshape.params[5] = t.ty;

        array_add(buffer, shshape);
        num_shapes += 1;

        num_shapes += FlattenShapes(shape.transform_op.shape, buffer, textures);

        t = shape.transform_op.transform;
        shshape.params[0] = t.a;
        shshape.params[1] = t.b;
        shshape.params[2] = t.tx;
        shshape.params[3] = t.c;
        shshape.params[4] = t.d;
        shshape.params[5] = t.ty;
    }

    array_add(buffer, shshape);
    num_shapes += 1;

    return num_shapes;
}

PrepareRenderingBuffers :: (instances : *[..]ShaderSDInstance, shapes : *[..]ShaderSDShape, effects : *[..]ShaderEffect, draw_calls : *[..]DrawCall) {
    textures : [..]TextureHandle;
    defer array_free(textures);

    for context.omg.shapes_to_draw {
        last_call := ifx draw_calls.count > 0 then *draw_calls.*[draw_calls.count - 1];
        textures.count = 0;

        instance : ShaderSDInstance;
        instance.position = it.position;
        instance.bounds = GetBounds(it.shape);
        instance.first_shape_index = xx shapes.count;
        instance.num_shapes = FlattenShapes(it.shape, shapes, *textures);
        instance.first_effect_index = xx effects.count;
        instance.num_effects = xx it.effects.count;
        if it.clip_shape {
            instance.first_clip_shape_index = xx shapes.count;
            instance.num_clip_shapes = FlattenShapes(it.clip_shape, shapes, *textures);
        }

        if textures.count > 1 {
            log_error("Too many textures on shape");
            continue;
        }

        if !last_call || (last_call.texture != 0 && textures.count > 0 && textures[0] != last_call.texture)  {
            last_call = array_add(draw_calls);
            last_call.base_instance = xx instances.count;
        }

        if textures.count > 0 {
            last_call.texture = textures[0];
        }

        extended_bounds := instance.bounds;
        for * fx : it.effects {
            effect := array_add(effects);
            effect.kind = xx fx.kind;

            new_bounds := GetBounds(instance.bounds, fx);
            extended_bounds = .{
                xy=min(new_bounds.xy, extended_bounds.xy),
                zw=max(new_bounds.zw, extended_bounds.zw),
            };

            if #complete fx.kind == {
            case .SolidColor;
                effect.params0[0] = fx.solid_color.color;
                effect.params1[0] = fx.solid_color.blur_factor;

            case .StrokeColor;
                effect.params0[0] = fx.stroke_color.color;
                effect.params1[0] = fx.stroke_color.blur_factor;
                effect.params1[1] = fx.stroke_color.inset;
                effect.params1[2] = fx.stroke_color.size;

            case .InnerShadow; #through;
            case .OuterShadow;
                effect.params0[0] = fx.outer_shadow.color;
                effect.params1[0] = fx.outer_shadow.offset.x;
                effect.params1[1] = fx.outer_shadow.offset.y;
                effect.params1[2] = fx.outer_shadow.blur_factor;
            }
        }

        instance.bounds = extended_bounds;
        array_add(instances, instance);
        last_call.num_instances += 1;
    }
}
