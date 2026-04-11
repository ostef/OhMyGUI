// https://shaderfun.com/2018/07/01/signed-distance-fields-part-7-some-simple-effects/
// https://shaderfun.com/2018/07/23/signed-distance-fields-part-8-gradients-bevels-and-noise/

Drawing :: struct {
    position : Vec2f;
    shape : *SDShape;
    effects : [..]Effect;
    should_override_default_effect : bool;
}

g_shapes_to_draw : [..]Drawing;
g_default_effect := Effect.{kind=.SolidColor, solid_color=.{color=.{1,1,1,1}}};

DrawShape :: inline (shape : *SDShape, position : Vec2f = .{}) -> *Drawing {
    array_add(*g_shapes_to_draw, .{shape=shape, position=position});

    drawing := *g_shapes_to_draw[g_shapes_to_draw.count - 1];
    drawing.effects.allocator = temp;

    array_add(*drawing.effects, g_default_effect);
    drawing.should_override_default_effect = true;

    return drawing;
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
        color : Vec4f;
        blur_factor : float;
    };
    .StrokeColor ,, stroke_color : struct {
        color : Vec4f;
        blur_factor : float;
        inset : float;
        size : float;
    };
    .OuterShadow ,, outer_shadow : struct {
        color : Vec4f;
        offset : Vec2f;
        blur_factor : float;
    };
    .InnerShadow ,, inner_shadow : struct {
        color : Vec4f;
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
    effect := PushEffect(drawing);
    effect.kind = .SolidColor;
    effect.solid_color.color = color;
    effect.solid_color.blur_factor = blur_factor;
}

StrokeColor :: inline (using drawing : *Drawing, color : Vec4f, size : float, inset := 0.0, blur_factor := 0.0) {
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
    effect := PushEffect(drawing);
    effect.kind = .InnerShadow;
    effect.inner_shadow.offset = offset;
    effect.inner_shadow.blur_factor = blur_factor;
    effect.inner_shadow.color = color;
}
