Drawing :: struct {
    position : Vec2f;
    shape : *SDShape;
    effects : [..]Effect;
    should_override_default_effect : bool;
}

g_shapes_to_draw : [..]Drawing;
g_default_effect := Effect.{kind=.SolidColor, solid_color=.{color=.{0,1,1,1}}};

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
    BorderColor;
    OuterShadow;
}

// We could add a blend mode feature?
Effect :: union kind : EffectKind {
    .SolidColor ,, solid_color : struct {
        color : Vec4f;
        blur_factor : float;
    };
    .BorderColor ,, border_color : struct {
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

BorderColor :: inline (using drawing : *Drawing, color : Vec4f, size : float, inset := 0.0, blur_factor := 0.0) {
    effect := PushEffect(drawing);
    effect.kind = .BorderColor;
    effect.border_color.color = color;
    effect.border_color.size = size;
    effect.border_color.inset = inset;
    effect.border_color.blur_factor = blur_factor;
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
