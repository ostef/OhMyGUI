// https://shaderfun.com/2018/07/01/signed-distance-fields-part-7-some-simple-effects/
// https://shaderfun.com/2018/07/23/signed-distance-fields-part-8-gradients-bevels-and-noise/

DrawList :: struct {
    drawings : [..]Drawing;
    clip_shapes : [..]*SDShape;
}

DestroyDrawList :: (draw_list : *DrawList) {
    array_free(draw_list.drawings);
    array_free(draw_list.clip_shapes);
}

PushClipShape :: (draw_list : *DrawList, shape : *SDShape) {
    array_add(*draw_list.clip_shapes, shape);
}

PopClipShape :: (draw_list : *DrawList) -> *SDShape {
    assert(draw_list.clip_shapes.count > 0);

    shape := GetClipShape(draw_list);
    pop(*draw_list.clip_shapes);

    return shape;
}

GetClipShape :: inline (draw_list : *DrawList) -> *SDShape {
    if draw_list.clip_shapes.count <= 0 {
        return null;
    }

    return draw_list.clip_shapes[draw_list.clip_shapes.count - 1];
}

DrawShape :: (draw_list : *DrawList, shape : *SDShape, position : Vec2f) -> *Drawing {
    array_add(*draw_list.drawings, .{shape=shape, position=position});

    drawing := *draw_list.drawings[draw_list.drawings.count - 1];
    drawing.effects.allocator = temp;
    drawing.clip_shape = GetClipShape(draw_list);

    array_add(*drawing.effects, context.omg.default_effect);
    drawing.should_override_default_effect = true;

    return drawing;
}

TextureHandle :: u64;

Drawing :: struct {
    position : Vec2f;
    shape : *SDShape;
    clip_shape : *SDShape;
    effects : [..]Effect;
    should_override_default_effect : bool;
}

SetClipShape :: inline (drawing : *Drawing, shape : *SDShape) {
    drawing.clip_shape = shape;
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

DrawText :: inline (draw_list : *DrawList, font : *Font, position : Vec2f, size : float, text : string, color : Vec4f, clip_shape : *SDShape = null) {
    DrawText(draw_list, font, position ,size, text, ColorU32(color), clip_shape);
}

DrawText :: (draw_list : *DrawList, font : *Font, position : Vec2f, size : float, text : string, color : u32, clip_shape : *SDShape = null) {
    if !font || (color & 0xff) == 0 {
        return;
    }

    sdf_range := font.sdf_range * size;

    iter : TextGlyphIterator;
    iter.font = font;
    iter.size = size;
    iter.text = text;
    for iter {
        glyph_position := position + iter.pen + it.hori_bearing * iter.size;
        glyph_position += it.size * iter.size * 0.5;

        s := SDTexture(font.texture, it.texture_size * iter.size, it.uv_rect, .{sdf_range, -sdf_range});
        d := DrawShape(draw_list, s, glyph_position);
        SetClipShape(d, clip_shape);
        SolidColor(d, color);
    }
}

DrawNodeDefault :: (node : *Node, clip_shape : *SDShape) {
    DrawBox :: inline (node : *Node, clip_shape : *SDShape) {
        has_background := (node.background_color & 0xff) > 0;
        has_border := (node.border_color & 0xff) > 0 && node.border_size > 0;
        has_shadow := (node.outer_shadow_color & 0xff) > 0;

        if !has_background && !has_border && !has_shadow {
            return;
        }

        position := (node.rect.xy + node.rect.zw) * 0.5;

        d := DrawShape(*node.window.draw_list, Box(node.size, node.corner_radiuses), position);

        if has_shadow {
            OuterShadow(d, node.outer_shadow_offset, node.outer_shadow_blur, node.outer_shadow_color);
        }
        if has_background {
            SolidColor(d, node.background_color);
        }
        if has_border {
            StrokeColor(d, node.border_color, node.border_size, node.border_inset);
        }

        SetClipShape(d, clip_shape);
    }

    DrawText :: (node : *Node, clip_shape : *SDShape) {
        if !node.font || node.text_size <= 0 || !node.text || (node.text_color & 0xff) == 0 {
            return;
        }

        DrawText(*node.window.draw_list, node.font, node.rect.xy, node.text_size, node.text, node.text_color, clip_shape);
    }

    DrawBox(node, clip_shape);
    DrawText(node, clip_shape);
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

    case .InflateOperation;
        num_shapes += FlattenShapes(shape.inflate_op.shape, buffer, textures);

        shshape.params[0] = shape.inflate_op.radius;

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

    window := context.omg.windows;
    while window {
        defer {
            window.draw_list.drawings.count = 0;
            window.draw_list.clip_shapes.count = 0;
            window = window.next;
        }

        for window.draw_list.drawings {
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
}
