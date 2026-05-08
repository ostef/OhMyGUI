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
