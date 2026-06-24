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
    text_effects : TextEffects;
    outer_shadow_blur : float;
    outer_shadow_offset : Vec2f;
    outer_shadow_color : RGBA8;
}

Apply :: inline (node : *Node, style : TextStyle) {
    node.font = style.font;
    node.text_size = style.text_size;
    node.text_color = style.text_color;
    node.text_effects = style.text_effects;
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

Cursor :: SDL_Cursor;

SystemCursor :: enum u8 {
    Arrow;
    IBeam;
    Busy;
    Crosshair;
    ArrowBusy;
    ResizeNWSE;
    ResizeNESW;
    ResizeHorizontal;
    ResizeVertical;
    ResizeAll;
    Forbidden;
    Hand;

    Count;
}

SetCursor :: inline (cursor : *Cursor) {
    context.omg.cursor_this_frame = cursor;
}

#scope_file

g_system_cursors : [SystemCursor.Count]*Cursor;

#scope_export

InitSystemCursors :: () {
    g_system_cursors[SystemCursor.Arrow] = SDL_CreateSystemCursor(ARROW);
    g_system_cursors[SystemCursor.IBeam] = SDL_CreateSystemCursor(IBEAM);
    g_system_cursors[SystemCursor.Busy] = SDL_CreateSystemCursor(WAIT);
    g_system_cursors[SystemCursor.Crosshair] = SDL_CreateSystemCursor(CROSSHAIR);
    g_system_cursors[SystemCursor.ArrowBusy] = SDL_CreateSystemCursor(WAITARROW);
    g_system_cursors[SystemCursor.ResizeNWSE] = SDL_CreateSystemCursor(SIZENWSE);
    g_system_cursors[SystemCursor.ResizeNESW] = SDL_CreateSystemCursor(SIZENESW);
    g_system_cursors[SystemCursor.ResizeHorizontal] = SDL_CreateSystemCursor(SIZEWE);
    g_system_cursors[SystemCursor.ResizeVertical] = SDL_CreateSystemCursor(SIZENS);
    g_system_cursors[SystemCursor.ResizeAll] = SDL_CreateSystemCursor(SIZEALL);
    g_system_cursors[SystemCursor.Forbidden] = SDL_CreateSystemCursor(NO);
    g_system_cursors[SystemCursor.Hand] = SDL_CreateSystemCursor(HAND);

    SetCursor(g_system_cursors[SystemCursor.Arrow]);
}

DestroySystemCursors :: () {
    for * g_system_cursors {
        SDL_FreeCursor(it.*);
        it.* = null;
    }
}

GetSystemCursor :: inline (cursor : SystemCursor) -> *Cursor {
    return g_system_cursors[cursor];
}

HasCursorControl :: (node : *Node) -> bool {
    if node.state_flags & .Disabled {
        return false;
    }
    if node.state_flags & .Active {
        return context.omg.mouse_capturing_node == node;
    }

    return node.state_flags != 0;
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

    base : BoxStyle;
    text : TextStyle;
    label_and_content : LabelAndContentStyle;
    clickable_text : ClickableTextStyle;
    button : ButtonStyle;
    button_accent : ButtonStyle;
    toggle : ButtonStyle;
    slider : SliderStyle;
    scrollbar : SliderStyle;
    text_input : TextInputStyle;
    checkbox : CheckboxStyle;
    menu_bar : BoxStyle;
    menu_item : ButtonStyle;
    menu : BoxStyle;
    separator : BoxStyle;
    subwindow : SubwindowStyle;
    color_picker : ColorPickerStyle;
}

g_default_theme_light : DefaultTheme;
g_default_theme_dark : DefaultTheme;

GetDefaultThemes :: inline () -> light : *Theme, dark : *Theme {
    return *g_default_theme_light, *g_default_theme_dark;
}

SetupDefaultTheme :: (theme : *DefaultTheme, base_background_color : RGBA8, base_accent_color : RGBA8) {
    button_base_background_color := MakeTone(base_background_color, 0.25);

    {
        using theme.base;

        background_color = base_background_color;
    }
    SetStyle(theme, "base", theme.base);

    {
        using theme.text;

        font = GetDefaultFont();
        text_size = 16;
        text_color = ChooseTextColor(base_background_color);
    }
    SetStyle(theme, "text", theme.text);

    {
        using theme.clickable_text;

        normal.text.font = GetDefaultFont();
        normal.text.text_size = 16;

        focused = normal;
        focused.text.text_effects |= .Underline;
        focused.cursor = GetSystemCursor(.Hand);

        hot = focused;
        active = focused;
        disabled = focused;

        normal.text.text_color = ChooseTextColor(base_background_color);
        focused.text.text_color = base_accent_color;
        hot.text.text_color = Whiten(base_accent_color, 0.05);
        active.text.text_color = Whiten(base_accent_color, 0.1);
    }
    SetStyle(theme, "clickable_text", theme.clickable_text);

    {
        using theme.label_and_content;

        text = theme.text;
        child_gap = .{6,6};
    }
    SetStyle(theme, "label_and_content", theme.label_and_content);

    {
        using theme.button;

        normal.background.corner_radiuses = .{10,10,10,10};
        normal.background.padding = .{10,10,10,10};
        normal.background.child_gap = .{4,4};
        normal.text.font = GetDefaultFont();
        normal.text.text_size = 16;

        focused = normal;
        hot = normal;
        active = normal;
        disabled = normal;

        SetColors(*theme.button, button_base_background_color);

        SetAlpha(*disabled.text.text_color, 0.5);
    }
    SetStyle(theme, "button", theme.button);

    {
        using theme.button_accent;

        normal.background.corner_radiuses = .{10,10,10,10};
        normal.background.padding = .{10,10,10,10};
        normal.background.child_gap = .{4,4};
        normal.text.font = GetDefaultFont();
        normal.text.text_size = 16;

        focused = normal;
        hot = normal;
        active = normal;
        disabled = normal;

        SetColors(*theme.button_accent, base_accent_color);

        disabled = normal;
        SetAlpha(*disabled.text.text_color, 0.5);
    }
    SetStyle(theme, "button_accent", theme.button_accent);

    {
        theme.toggle = theme.button;

        using theme.toggle;

        active.background.background_color = normal.background.background_color;
        active.background.border_size = 2;
        active.background.border_color = base_accent_color;
    }
    SetStyle(theme, "toggle", theme.toggle);

    {
        using theme.slider;

        background_size = 8;
        handle_size = 15;

        normal.background.corner_radiuses = Vec4f.{1,1,1,1} * background_size * 0.5;
        normal.handle.corner_radiuses = Vec4f.{1,1,1,1} * handle_size * 0.5;

        focused = normal;
        hot = normal;
        active = normal;
        disabled = normal;

        SetColors(*theme.slider, MakeTone(base_background_color, 0.3), Whiten(base_accent_color, 0.1), base_accent_color);

    }
    SetStyle(theme, "slider", theme.slider);

    {
        using theme.scrollbar;

        handle_size = 8;

        normal.background.corner_radiuses = Vec4f.{1,1,1,1} * background_size * 0.5;
        normal.handle.corner_radiuses = Vec4f.{1,1,1,1} * handle_size * 0.5;

        focused = normal;
        hot = normal;
        active = normal;
        disabled = normal;

        SetColors(*theme.scrollbar, MakeTone(base_background_color, 0.05), 0, MakeTone(base_background_color, 0.5));

        active.handle.background_color = Whiten(base_accent_color, 0.1);
    }
    SetStyle(theme, "scrollbar", theme.scrollbar);

    {
        using theme.text_input;

        cursor.background_color = ChooseTextColor(base_background_color);

        normal.background.corner_radiuses = .{10,10,10,10};
        normal.background.padding = .{10,10,10,10};
        normal.background.child_gap = .{4,4};
        normal.text.font = GetDefaultFont();
        normal.text.text_size = 16;

        focused = normal;
        hot = normal;
        active = normal;
        disabled = normal;

        SetColors(*theme.text_input, button_base_background_color, base_accent_color);

        SetAlpha(*disabled.text.text_color, 0.5);
        SetAlpha(*disabled.background.background_color, 0.5);
    }
    SetStyle(theme, "text_input", theme.text_input);

    {
        using theme.checkbox;

        normal.background.corner_radiuses = .{4,4,4,4};
        normal.background.padding = .{2,2,2,2};
        normal.background.border_color = MakeTone(button_base_background_color, 0.3);
        normal.background.border_size = 1;
        normal.checkmark.rounding = 1;

        focused = normal;
        hot = normal;
        active = normal;
        disabled = normal;

        SetColors(*theme.checkbox, button_base_background_color, base_accent_color);

        SetAlpha(*disabled.background.background_color, 0.5);
        SetAlpha(*disabled.checkmark.background_color, 0.5);
    }
    SetStyle(theme, "checkbox", theme.checkbox);

    {
        using theme.menu_bar;

        child_gap = .{3,3};
        background_color = base_background_color;
    }
    SetStyle(theme, "menu_bar", theme.menu_bar);

    {
        using theme.menu_item;

        normal.background.corner_radiuses = .{3,3,3,3};
        normal.background.padding = .{4,4,4,4};
        normal.background.child_gap = .{4,4};
        normal.text.font = GetDefaultFont();
        normal.text.text_size = 14;

        focused = normal;
        hot = normal;
        active = normal;
        disabled = normal;

        SetColors(*theme.menu_item, Darken(button_base_background_color, 0.1), ChooseTextColor(base_background_color));
        normal.background.background_color = 0;

        SetAlpha(*disabled.text.text_color, 0.5);
    }
    SetStyle(theme, "menu_item", theme.menu_item);

    {
        using theme.menu;

        corner_radiuses = .{3,3,3,3};
        padding = .{2,2,2,2};

        background_color = base_background_color;
        border_color = MakeTone(base_background_color, 0.3);
        border_size = 1;

        outer_shadow_color = ColorU32(0,0,0,0.5);
        outer_shadow_offset = .{3,3};
        outer_shadow_blur = 5;
    }
    SetStyle(theme, "menu", theme.menu);

    {
        using theme.separator;

        background_color = ColorU32(0.5, 0.5, 0.5, 1);
    }
    SetStyle(theme, "separator", theme.separator);

    {
        using theme.subwindow;

        background.padding = .{10,10,10,10};
        background.child_gap = .{4,4};

        background.corner_radiuses = .{6,6,6,6};

        background.background_color = base_background_color;
        background.border_color = MakeTone(base_background_color, 0.3);
        background.border_size = 1;

        background.outer_shadow_color = ColorU32(0,0,0,0.5);
        background.outer_shadow_offset = .{6,6};
        background.outer_shadow_blur = 5;

        {
            using title_bar;

            normal.background.padding = .{6,6,6,6};
            normal.background.corner_radiuses = .{6,6,0,0};

            normal.text.font = GetDefaultFont();
            normal.text.text_size = 16;

            normal.background.background_color = MakeTone(base_background_color, 0.1);
            normal.text.text_color = ChooseTextColor(normal.background.background_color);

            focused = normal;
            hot = normal;
            active = normal;
            disabled = normal;
        }

        horizontal_scrollbar = theme.scrollbar;
        vertical_scrollbar = theme.scrollbar;
    }
    SetStyle(theme, "subwindow", theme.subwindow);

    {
        using theme.color_picker;

        wheel.padding = .{5,5,5,5};

        wheel.border_color = MakeTone(0xffffffff, 0.3);
        wheel.outer_shadow_offset = .{wheel.border_size * 0.5, wheel.border_size * 0.5};
        wheel.outer_shadow_color = ColorU32(0,0,0,0.5);
        wheel.outer_shadow_blur = 5;

        wheel.wheel_cursor.normal.border_color = wheel.border_color;
        wheel.wheel_cursor.normal.outer_shadow_color = ColorU32(0,0,0,0.5);
        wheel.wheel_cursor.normal.outer_shadow_blur = 2;

        wheel.wheel_cursor.focused = wheel.wheel_cursor.normal;

        wheel.wheel_cursor.hot = wheel.wheel_cursor.focused;
        wheel.wheel_cursor.hot.radius += 5;

        wheel.wheel_cursor.active = wheel.wheel_cursor.hot;

        wheel.triangle_cursor.normal.radius = 6;
        wheel.triangle_cursor.normal.border_color = wheel.border_color;
        wheel.triangle_cursor.normal.outer_shadow_color = ColorU32(0,0,0,0.5);
        wheel.triangle_cursor.normal.outer_shadow_blur = 2;

        wheel.triangle_cursor.focused = wheel.triangle_cursor.normal;

        wheel.triangle_cursor.hot = wheel.triangle_cursor.focused;
        wheel.triangle_cursor.hot.radius += 5;

        wheel.triangle_cursor.active = wheel.triangle_cursor.hot;

        red_slider = theme.slider;
        green_slider = theme.slider;
        blue_slider = theme.slider;
        hue_slider = theme.slider;
        saturation_slider = theme.slider;
        value_slider = theme.slider;
        opacity_slider = theme.slider;

        red := MakeTone(ColorU32(1,0,0,1), 0.3);
        green := MakeTone(ColorU32(0,1,0,1), 0.3);
        blue := MakeTone(ColorU32(0,0,1,1), 0.3);
        SetColors(*red_slider, MakeTone(base_background_color, 0.3), Whiten(red, 0.1), red);
        SetColors(*green_slider, MakeTone(base_background_color, 0.3), Whiten(green, 0.1), green);
        SetColors(*blue_slider, MakeTone(base_background_color, 0.3), Whiten(blue, 0.1), blue);
    }
    SetStyle(theme, "color_picker", theme.color_picker);
}
