Theme :: struct {
    styles : Table(string, Any);
}

SetStyle :: (theme : *Theme, name : string, value : Any) {
    table_set(*theme.styles, name, value);
}

EnsureStyle :: inline (style : **$T, name : string) {
    if !style.* {
        style.* = GetStyle(name, T);
        assert(style.* != null, "Theme has no style named '%' of type %", name, T);
    }
}

GetStyle :: inline (name : string, $T : Type) -> *T {
    return GetStyle(GetTheme(), name, T);
}

GetStyle :: (theme : *Theme, name : string, $T : Type) -> *T {
    if !theme {
        return null;
    }

    exists, any := table_find(*theme.styles, name);
    if !exists {
        return null;
    }

    if any.type != type_info(T) {
        return null;
    }

    return xx any.value_pointer;
}

BoxStyle :: struct {
    padding : Vec4f;
    child_gap : Vec2f;

    corner_radiuses : Vec4f;
    background_color : RGBA8;
    border_color : RGBA8;
    border_size : float;
    border_inset : float;
    outer_shadow_blur : float;
    outer_shadow_offset : Vec2f;
    outer_shadow_color : RGBA8;
}

Apply :: inline (node : *Node, style : BoxStyle) {
    node.padding = style.padding;
    node.child_gap = style.child_gap;
    node.corner_radiuses = style.corner_radiuses;
    node.background_color = style.background_color;
    node.border_color = style.border_color;
    node.border_size = style.border_size;
    node.border_inset = style.border_inset;
    node.outer_shadow_blur = style.outer_shadow_blur;
    node.outer_shadow_offset = style.outer_shadow_offset;
    node.outer_shadow_color = style.outer_shadow_color;
}

TextStyle :: struct {
    font : *Font;
    text_size : float;
    text_color : RGBA8;
    outer_shadow_blur : float;
    outer_shadow_offset : Vec2f;
    outer_shadow_color : RGBA8;
}

Apply :: inline (node : *Node, style : TextStyle) {
    node.font = style.font;
    node.text_size = style.text_size;
    node.text_color = style.text_color;
    node.outer_shadow_blur = style.outer_shadow_blur;
    node.outer_shadow_offset = style.outer_shadow_offset;
    node.outer_shadow_color = style.outer_shadow_color;
}

StateStyle :: struct(T : Type) {
    disabled : T;
    active : T;
    hot : T;
    focused : T;
    normal : T;

    #overlay(disabled)
    states : [Num_Node_States]T;
}

AnimFunc :: enum u8 {
    Linear;
    CubicIn;
    CubicOut;
    CubicInOut;
    ElasticIn;
    ElasticOut;
    ElasticInOut;
    BackIn;
    BackOut;
    BackInOut;
}

AnimParams :: struct {
    length : float;
    func : AnimFunc;
}

Animate :: inline (a : float, b : float, t : float, func : AnimFunc) -> float {
    if #complete func == {
    case .Linear;
        // t = t
    case .CubicIn;
        t = t * t * t;
    case .CubicOut;
        t = 1 - t;
        t = 1 - (t * t * t);
    case .CubicInOut;
        if t < 0.5 {
            t = 4 * t * t * t;
        } else {
            t = -2 * t;
            t = 1 - (t * t * t) * 0.5;
        }
    case .ElasticIn;
        if t > 0 && t < 1 {
            t = -pow(2, 10 * t - 10) * sin(t * 10 - 10.75) * (2 * PI / 3);
        }
    case .ElasticOut;
        if t > 0 && t < 1 {
            t = 1 + pow(2, -10 * t) * sin((t * 10 - 10.75) * (2 * PI / 3));
        }
    case .ElasticInOut;
        if t > 0 {
            if t < 0.5 {
                t = -pow(2, 20 * t - 10) * sin(t * 20 - 11.125) * (2 * PI / 4.5) / 2;
            } else if t < 1 {
                t = 1 + pow(2, -20 * t + 10) * sin(t * 20 - 11.125) * (2 * PI / 4.5) / 2;
            }
        }
    case .BackIn;
        C1 :: 1.70158;
        C3 :: C1 + 1;
        t = C3 * t * t * t - C1 * t * t;
    case .BackOut;
        C1 :: 1.70158;
        C3 :: C1 + 1;
        t -= 1;
        t = 1 + C3 * t * t * t + C1 * t * t;
    case .BackInOut;
        C1 :: 1.70158;
        C2 :: C1 * 1.525;
        if t < 0.5 {
            t = t * 2;
            t = (t * t * ((C2 + 1) * t - C2)) / 2;
        } else {
            t = t * 2 - 2;
            t = (t * t * ((C2 + 1) * t + C2) + 2) / 2;
        }
    }

    return a * (1 - t) + b * t;
}

Animate :: inline (a : Vec2f, b : Vec2f, t : float, func : AnimFunc) -> Vec2f {
    return .{
        Animate(a.x, b.x, t, func),
        Animate(a.y, b.y, t, func),
    };
}

Animate :: inline (a : Vec4f, b : Vec4f, t : float, func : AnimFunc) -> Vec4f {
    return .{
        Animate(a.x, b.x, t, func),
        Animate(a.y, b.y, t, func),
        Animate(a.z, b.z, t, func),
        Animate(a.w, b.w, t, func),
    };
}

Animate :: inline (a : RGBA8, b : RGBA8, t : float, func : AnimFunc) -> RGBA8 {
    a4f := ColorVec4f(a);
    b4f := ColorVec4f(b);

    return ColorU32(
        Animate(a4f.x, b4f.x, t, func),
        Animate(a4f.y, b4f.y, t, func),
        Animate(a4f.z, b4f.z, t, func),
        Animate(a4f.w, b4f.w, t, func),
    );
}

AnimateStyle :: (a : $T, b : T, t : float, func : AnimFunc) -> T {
    if t < 0 {
        return a;
    }
    if t > 1 {
        return b;
    }

    result : T;

    #insert -> string {
        AppendAnimate :: (builder : *String_Builder, name : string, type : *Type_Info) {
            if type == type_info(Vec2f) || type == type_info(Vec4f) || type == type_info(RGBA8) {
                print_to_builder(*builder, "result.%1 = Animate(a.%1, b.%1, t, func);\n", name);
            } else if type.kind == {
            case .VARIANT;
                variant := cast(*Type_Info_Variant, type);
                AppendAnimate(builder, name, variant.variant_of);
            case .FLOAT;
                print_to_builder(*builder, "result.%1 = xx Animate(xx a.%1, b.%1, t, func);\n", name);
            case .INTEGER;
                print_to_builder(*builder, "result.%1 = xx Animate(xx a.%1, b.%1, t, func);\n", name);
            case .STRUCT;
                struct_type := cast(*Type_Info_Struct, type);
                for struct_type.members {
                    AppendAnimate(builder, tprint("%.%", name, it.name), it.type);
                }
            case .ARRAY;
                array_type := cast(*Type_Info_Array, type);
                if array_type.array_type != .FIXED {
                    return;
                }

                print_to_builder(*builder, "for result.%1 {\n", name);
                AppendAnimate(builder, tprint("%[it_index]", name), array_type.element_type);
                print_to_builder(*builder, "}\n");
            }
        }

        builder : String_Builder;

        info := type_info(T);
        for info.members {
            AppendAnimate(*builder, it.name, it.type);
        }

        return builder_to_string(*builder);
    }

    return result;
}

DefaultTheme :: struct {
    #as theme : Theme;

    text : TextStyle;
    button : ButtonStyle;
    slider : SliderStyle;
    scrollbar : SliderStyle;
    text_input : TextInputStyle;
    checkbox : CheckboxStyle;
    menu_bar : BoxStyle;
    menu_item : ButtonStyle;
    menu : BoxStyle;
}

g_default_theme : DefaultTheme;

SetupDefaultTheme :: (theme : *DefaultTheme, accent_color : RGBA8) {
    {
        using theme.text;

        font = GetDefaultFont();
        text_size = 16;
        text_color = ColorU32(0,0,0,1);
    }
    SetStyle(theme, "text", theme.text);

    {
        using theme.button;

        normal.background.corner_radiuses = .{10,10,10,10};
        normal.background.padding = .{10,10,10,10};
        normal.background.child_gap = .{4,4};
        normal.background.background_color = ColorU32(0.9,0.9,0.9,1);
        normal.text = theme.text;

        focused = normal;
        focused.background.background_color = ColorU32(0.8,0.8,0.8,1);

        hot = normal;
        hot.background.background_color = ColorU32(0.7,0.7,0.7,1);

        active = normal;

        disabled = normal;
        disabled.text.text_color = ColorU32(0.5,0.5,0.5,1);
    }
    SetStyle(theme, "button", theme.button);

    {
        using theme.slider;

        background_size = 8;
        handle_size = 15;

        normal.background.corner_radiuses = Vec4f.{1,1,1,1} * background_size * 0.5;
        normal.background.background_color = ColorU32(0.5, 0.5, 0.5, 1);
        normal.handle.background_color = theme.button.normal.background.background_color;
        normal.handle.corner_radiuses = Vec4f.{1,1,1,1} * handle_size * 0.5;

        focused = normal;
        focused.handle.background_color = theme.button.focused.background.background_color;

        hot = focused;
        hot.handle.background_color = theme.button.hot.background.background_color;

        active = hot;
        active.handle.background_color = ColorU32(0.9, 0.9, 0.9, 1);
        active.handle.background_color = theme.button.active.background.background_color;

        disabled.background.background_color = ColorU32(0.5, 0.5, 0.5, 0.5);
        disabled.handle.background_color = ColorU32(0.5, 0.5, 0.5, 1);
    }
    SetStyle(theme, "slider", theme.slider);

    {
        using theme.scrollbar;

        handle_size = 10;

        normal.background.background_color = ColorU32(0.7, 0.7, 0.7, 0.4);
        normal.handle.background_color = ColorU32(0.8, 0.8, 0.8, 1);
        normal.handle.corner_radiuses = .{5,5,5,5};

        focused = normal;
        focused.background.background_color = ColorU32(0.4, 0.4, 0.4, 0.8);

        hot = focused;

        active = hot;
        active.handle.background_color = ColorU32(0.9, 0.9, 0.9, 1);

        disabled.background.background_color = ColorU32(0.5, 0.5, 0.5, 0.5);
        disabled.handle.background_color = ColorU32(0.5, 0.5, 0.5, 1);
    }
    SetStyle(theme, "scrollbar", theme.scrollbar);

    {
        using theme.text_input;

        normal.background.corner_radiuses = .{10,10,10,10};
        normal.background.padding = .{10,10,10,10};
        normal.background.child_gap = .{4,4};
        normal.background.background_color = ColorU32(0.9,0.9,0.9,1);
        normal.text = theme.text;

        focused = normal;
        focused.background.background_color = ColorU32(0.8,0.8,0.8,1);

        hot = normal;
        hot.background.background_color = ColorU32(0.7, 0.7, 0.7,1);

        active = normal;
        active.background.border_size = 2;
        active.background.border_color = accent_color;

        disabled = normal;
        disabled.text.text_color = ColorU32(0.5,0.5,0.5,1);
    }
    SetStyle(theme, "text_input", theme.text_input);

    {
        using theme.checkbox;

        normal.background.corner_radiuses = .{4,4,4,4};
        normal.background.padding = .{2,2,2,2};
        normal.background.background_color = ColorU32(0.9,0.9,0.9,1);
        normal.checkmark.background_color = accent_color;
        normal.checkmark.rounding = 1;

        focused = normal;
        focused.background.background_color = ColorU32(0.8,0.8,0.8,1);

        hot = normal;
        hot.background.background_color = ColorU32(0.7,0.7,0.7,1);

        active = normal;

        disabled = normal;
        disabled.checkmark.background_color = ColorU32(0.5,0.5,0.5,1);
    }
    SetStyle(theme, "checkbox", theme.checkbox);

    {
        using theme.menu_bar;

        background_color = ColorU32(0.9,0.9,0.9,1);
    }
    SetStyle(theme, "menu_bar", theme.menu_bar);

    {
        using theme.menu_item;

        normal.background.padding = .{4,4,4,4};
        normal.background.child_gap = .{4,4};
        normal.background.background_color = ColorU32(0.9,0.9,0.9,1);
        normal.text = theme.text;
        normal.text.text_size = floor(normal.text.text_size * 0.9);

        focused = normal;
        focused.background.background_color = ColorU32(0.8,0.8,0.8,1);

        hot = normal;
        hot.background.background_color = ColorU32(0.7,0.7,0.7,1);

        active = normal;

        disabled = normal;
        disabled.text.text_color = ColorU32(0.5,0.5,0.5,1);
    }
    SetStyle(theme, "menu_item", theme.menu_item);

    {
        using theme.menu;

        corner_radiuses = .{2,2,2,2};
        padding = .{2,2,2,2};
        background_color = ColorU32(0.9,0.9,0.9,1);

        outer_shadow_color = ColorU32(0,0,0,0.5);
        outer_shadow_offset = .{3,3};
        outer_shadow_blur = 5;
    }
    SetStyle(theme, "menu", theme.menu);
}
