Theme :: struct {
    styles : HT.Table(string, Any);
}

SetStyle :: (theme : *Theme, name : string, value : Any) {
    HT.table_set(*theme.styles, name, value);
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

    exists, any := HT.table_find(*theme.styles, name);
    if !exists {
        return null;
    }

    if any.type != type_info(T) {
        return null;
    }

    return xx any.value_pointer;
}

// @Todo: use this
Gradient :: struct {
    color1 : RGBA8;
    color2 : RGBA8;
    offset : float;
    vector : Vec2f;
}

BoxStyle :: struct {
    padding : Vec4b;
    child_gap : Vec2b;

    corner_radiuses : Vec4f;
    background_color : RGBA8;
    background_color2 : RGBA8;
    background_gradient_offset : float;
    background_gradient_vector : Vec2f;
    border_color : RGBA8;
    border_color2 : RGBA8;
    border_gradient_offset : float;
    border_gradient_vector : Vec2f;
    border_size : float;
    border_inset : float;
    outer_shadow_blur : float;
    outer_shadow_offset : Vec2f;
    outer_shadow_color : RGBA8;
    inner_shadow_blur : float;
    inner_shadow_offset : Vec2f;
    inner_shadow_color : RGBA8;
}

Apply :: inline (node : *Node, style : BoxStyle) {
    node.padding = style.padding;
    node.child_gap = style.child_gap;
    node.corner_radiuses = style.corner_radiuses;
    node.background_color = style.background_color;
    node.background_color2 = style.background_color2;
    node.background_gradient_offset = style.background_gradient_offset;
    node.background_gradient_vector = style.background_gradient_vector;
    node.border_color = style.border_color;
    node.border_color2 = style.border_color2;
    node.border_gradient_offset = style.border_gradient_offset;
    node.border_gradient_vector = style.border_gradient_vector;
    node.border_size = style.border_size;
    node.border_inset = style.border_inset;
    node.outer_shadow_blur = style.outer_shadow_blur;
    node.outer_shadow_offset = style.outer_shadow_offset;
    node.outer_shadow_color = style.outer_shadow_color;
    node.inner_shadow_blur = style.inner_shadow_blur;
    node.inner_shadow_offset = style.inner_shadow_offset;
    node.inner_shadow_color = style.inner_shadow_color;
}

TextStyle :: struct {
    font : *Font;
    text_size : float;
    text_color : RGBA8;
    text_color2 : RGBA8;
    text_gradient_offset : float;
    text_gradient_vector : Vec2f;
    text_effects : TextEffects;
    outer_shadow_blur : float;
    outer_shadow_offset : Vec2f;
    outer_shadow_color : RGBA8;
    inner_shadow_blur : float;
    inner_shadow_offset : Vec2f;
    inner_shadow_color : RGBA8;
}

Apply :: inline (node : *Node, style : TextStyle) {
    node.font = style.font;
    node.text_size = style.text_size;
    node.text_color = style.text_color;
    node.text_color2 = style.text_color2;
    node.text_gradient_offset = style.text_gradient_offset;
    node.text_gradient_vector = style.text_gradient_vector;
    node.text_effects = style.text_effects;
    node.outer_shadow_blur = style.outer_shadow_blur;
    node.outer_shadow_offset = style.outer_shadow_offset;
    node.outer_shadow_color = style.outer_shadow_color;
    node.inner_shadow_blur = style.inner_shadow_blur;
    node.inner_shadow_offset = style.inner_shadow_offset;
    node.inner_shadow_color = style.inner_shadow_color;
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
    EyeDropper;

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

    Eyedropper_Contents :: #run ReadCompileTimeFile("eyedropper-cursor.png");
    g_system_cursors[SystemCursor.EyeDropper] = CreateCursorFromFileContents(Eyedropper_Contents, 0, 1);

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
        return context.omg.mouse_capturing_node == node || (node.state_flags & .Focused) != 0;
    }

    return node.state_flags != 0;
}

CreateCursorFromFileContents :: (contents : string, hot_x_01 : float, hot_y_01 : float) -> *Cursor {
    #import "stb_image";

    w, h : s32;
    stbi_set_flip_vertically_on_load(0);
    data := stbi_load_from_memory(contents.data, xx contents.count, *w, *h, null, 4);
    if !data {
        log_error("Could not create cursor image");
        return null;
    }

    defer stbi_image_free(data);

    return CreateCursorFromRGBA8Pixels(data, xx w, xx h, hot_x_01, hot_y_01);
}

CreateCursorFromFile :: (filename : string, hot_x_01 : float, hot_y_01 : float) -> *Cursor {
    #import "stb_image";

    w, h : s32;
    stbi_set_flip_vertically_on_load(0);
    data := stbi_load(tprint("%\0", filename).data, *w, *h, null, 4);
    if !data {
        log_error("Could not create cursor image '%'", filename);
        return null;
    }

    defer stbi_image_free(data);

    return CreateCursorFromRGBA8Pixels(data, xx w, xx h, hot_x_01, hot_y_01);
}

CreateCursorFromRGBA8Pixels :: (pixels : *void, width : u32, height : u32, hot_x_01 : float, hot_y_01 : float) -> *Cursor {
    SDL_PIXELFORMAT_RGBA8888 :: 0x16462004;
    SDL_PIXELFORMAT_ABGR8888 :: 0x16762004;

    surface := SDL_CreateRGBSurfaceWithFormatFrom(pixels, width, height, 4, width * 4, SDL_PIXELFORMAT_ABGR8888);
    defer SDL_FreeSurface(surface);

    if !surface {
        log_error("Could not create SDL surface for cursor image");
        return null;
    }

    hot_x := cast(s32, (cast(s32, width) - 1) * hot_x_01);
    hot_y := cast(s32, (cast(s32, height) - 1) * hot_y_01);

    result := SDL_CreateColorCursor(surface, hot_x, hot_y);
    if !result {
        log_error("Could not create SDL cursor: %", to_string(SDL_GetError()));
        return null;
    }

    return result;
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

    // Theme stores pointers so the styles need to be stored somewhere persistent
    base : BoxStyle;
    text : TextStyle;
    label_and_content : LabelAndContentStyle;
    clickable_text : ClickableTextStyle;
    button : ButtonStyle;
    button_accent : ButtonStyle;
    toggle : ButtonStyle;
    slider : SliderStyle;
    fill_slider : SliderStyle;
    knob_slider : SliderStyle;
    scrollbar : ScrollbarStyle;
    text_input : TextInputStyle;
    checkbox : CheckboxStyle;
    menu_bar : BoxStyle;
    menu_item : ButtonStyle;
    menu : MenuStyle;
    separator : BoxStyle;
    subwindow : SubwindowStyle;
    color_picker : ColorPickerStyle;
    color_input : ColorInputStyle;
    combo : ComboStyle;
    tooltip : TooltipStyle;
    table : TableStyle;
    progress_bar : ProgressBarStyle;
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

        normal.background.corner_radiuses = .{6,6,6,6};
        normal.background.padding = .{10,6,10,6};
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

        theme.button_accent = theme.button;

        SetColors(*theme.button_accent, base_accent_color);

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

        background_size = 25;
        handle_size = .{15,19};

        normal.background.corner_radiuses = .{5,5,5,5};
        normal.background.padding = .{3,3,3,3};
        normal.background.border_size = 1;
        normal.background.border_color = MakeTone(button_base_background_color, 0.3);
        normal.background.inner_shadow_blur = 5;
        normal.background.inner_shadow_color = SetAlpha(Darken(button_base_background_color, 0.2), 0.7);
        normal.fill.corner_radiuses = .{3,3,3,3};
        normal.handle.corner_radiuses = .{3,3,3,3};
        normal.text = theme.text;

        focused = normal;
        hot = normal;
        active = normal;
        disabled = normal;

        SetColors(*theme.slider, MakeTone(base_background_color, 0.3), 0, base_accent_color);
    }
    SetStyle(theme, "slider", theme.slider);

    {
        using theme.fill_slider;

        background_size = 25;

        normal.background.corner_radiuses = .{5,5,5,5};
        normal.background.padding = .{3,3,3,3};
        normal.background.border_size = 1;
        normal.background.border_color = MakeTone(button_base_background_color, 0.3);
        normal.background.inner_shadow_blur = 5;
        normal.background.inner_shadow_color = SetAlpha(Darken(button_base_background_color, 0.2), 0.7);
        normal.fill.corner_radiuses = .{3,3,3,3};
        normal.handle.corner_radiuses = .{3,3,3,3};
        normal.text = theme.text;

        focused = normal;
        hot = normal;
        active = normal;
        disabled = normal;

        SetColors(*theme.fill_slider, MakeTone(base_background_color, 0.3), Whiten(base_accent_color, 0.1), 0);
    }
    SetStyle(theme, "fill_slider", theme.fill_slider);

    {
        using theme.knob_slider;

        background_size = 8;
        handle_size = .{15,15};
        handle_outside_background = true;

        normal.background.corner_radiuses = Vec4f.{1,1,1,1} * background_size * 0.5;
        normal.fill.corner_radiuses = Vec4f.{1,1,1,1} * background_size * 0.5;
        normal.handle.corner_radiuses = Vec4f.{1,1,1,1} * handle_size.x * 0.5;

        focused = normal;
        hot = normal;
        active = normal;
        disabled = normal;

        SetColors(*theme.knob_slider, MakeTone(base_background_color, 0.3), Whiten(base_accent_color, 0.1), base_accent_color);
    }
    SetStyle(theme, "knob_slider", theme.knob_slider);

    {
        using theme.scrollbar;

        handle_size = .{32,8};

        normal.background.corner_radiuses = Vec4f.{1,1,1,1} * background_size * 0.5;
        normal.handle.corner_radiuses = Vec4f.{1,1,1,1} * handle_size.y * 0.5;

        focused = normal;
        hot = normal;
        active = normal;
        disabled = normal;

        SetColors(*theme.scrollbar, MakeTone(base_background_color, 0.05), MakeTone(base_background_color, 0.5));

        active.handle.background_color = Whiten(base_accent_color, 0.1);
    }
    SetStyle(theme, "scrollbar", theme.scrollbar);

    {
        using theme.text_input;

        cursor.background_color = ChooseTextColor(base_background_color);

        normal.background.corner_radiuses = .{6,6,6,6};
        normal.background.padding = .{10,6,10,6};
        normal.background.child_gap = .{4,4};
        normal.background.border_size = 1;
        normal.background.border_color = MakeTone(button_base_background_color, 0.3);
        normal.background.inner_shadow_blur = 5;
        normal.background.inner_shadow_color = SetAlpha(Darken(button_base_background_color, 0.2), 0.7);
        normal.text.font = GetDefaultFont();
        normal.text.text_size = 16;

        focused = normal;
        focused.cursor = GetSystemCursor(.IBeam);
        hot = focused;
        active = hot;
        disabled = active;

        active.background.border_size = 2;

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

        max_height_px = 200;
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

        label_and_slider = theme.label_and_content;
        label_and_slider.padding = .{2,2,2,2};
        label_and_slider.text_fill = 0.1;

        dynamic_rgb_slider_color = true;
        dynamic_hsv_slider_color = true;
        dynamic_opacity_slider_color = true;

        slider_base : SliderStyle;
        slider_base.background_size = 21;
        slider_base.handle_size = .{8,25};
        slider_base.handle_outside_background = true;

        slider_base.normal.background.corner_radiuses = .{4,4,4,4};
        slider_base.normal.background.border_size = 1;
        slider_base.normal.background.border_inset = -1;
        slider_base.normal.background.border_color = MakeTone(base_background_color, 0.3);

        // slider_base.normal.handle.background_color = 0;
        // slider_base.normal.handle.corner_radiuses = .{3,3,3,3};
        // slider_base.normal.handle.border_color = wheel.border_color;
        // slider_base.normal.handle.border_size = 2;
        slider_base.normal.handle.background_color = wheel.border_color;
        // slider_base.normal.handle.border_color = MakeTone(button_base_background_color, 0.3);
        // slider_base.normal.handle.border_size = 1;
        slider_base.normal.handle.outer_shadow_color = ColorU32(0,0,0,0.5);
        slider_base.normal.handle.outer_shadow_blur = 2;

        slider_base.focused = slider_base.normal;
        slider_base.hot = slider_base.focused;
        slider_base.active = slider_base.hot;

        red_slider = slider_base;
        green_slider = slider_base;
        blue_slider = slider_base;
        hue_slider = slider_base;
        saturation_slider = slider_base;
        value_slider = slider_base;
        opacity_slider = slider_base;

        red_slider.focused.handle = red_slider.normal.handle;
        red_slider.hot.handle = red_slider.focused.handle;
        red_slider.active.handle = red_slider.hot.handle;

        green_slider.normal.handle = red_slider.normal.handle;
        green_slider.focused.handle = green_slider.normal.handle;
        green_slider.hot.handle = green_slider.focused.handle;
        green_slider.active.handle = green_slider.hot.handle;

        blue_slider.normal.handle = red_slider.normal.handle;
        blue_slider.focused.handle = blue_slider.normal.handle;
        blue_slider.hot.handle = blue_slider.focused.handle;
        blue_slider.active.handle = blue_slider.hot.handle;

        hue_slider.normal.handle = red_slider.normal.handle;
        hue_slider.focused.handle = hue_slider.normal.handle;
        hue_slider.hot.handle = hue_slider.focused.handle;
        hue_slider.active.handle = hue_slider.hot.handle;

        saturation_slider.normal.handle = red_slider.normal.handle;
        saturation_slider.focused.handle = saturation_slider.normal.handle;
        saturation_slider.hot.handle = saturation_slider.focused.handle;
        saturation_slider.active.handle = saturation_slider.hot.handle;

        value_slider.normal.handle = red_slider.normal.handle;
        value_slider.focused.handle = value_slider.normal.handle;
        value_slider.hot.handle = value_slider.focused.handle;
        value_slider.active.handle = value_slider.hot.handle;

        opacity_slider.normal.handle = red_slider.normal.handle;
        opacity_slider.focused.handle = opacity_slider.normal.handle;
        opacity_slider.hot.handle = opacity_slider.focused.handle;
        opacity_slider.active.handle = opacity_slider.hot.handle;

        opacity_checkerboard_white = MakeTone(0xffffffff, 0.5);
        opacity_checkerboard_black = MakeTone(0x000000ff, 0.5);

        preview.corner_radiuses = .{5,5,5,5};
        preview.border_size = 1;
        preview.border_color = wheel.border_color;
        preview.outer_shadow_color = ColorU32(0,0,0,0.5);
        preview.outer_shadow_blur = 2;
        preview.opacity_checkerboard_white = opacity_checkerboard_white;
        preview.opacity_checkerboard_black = opacity_checkerboard_black;
    }
    SetStyle(theme, "color_picker", theme.color_picker);

    {
        using theme.color_input;

        number_input_gap = 4;
        preview_gap = 8;

        label_and_content = theme.label_and_content;
        label_and_content.text_fill = 0.2;
        number_input = theme.text_input;
        preview = theme.color_picker.preview;
    }
    SetStyle(theme, "color_input", theme.color_input);

    {
        using theme.combo;

        button = theme.button;
        popup = theme.menu;
        item = theme.menu_item;

        for * button.states {
            it.background.border_size = 1;
            it.background.border_color = MakeTone(button_base_background_color, 0.3);
        }

        popup.corner_radiuses.xy = .{};
        popup.corner_radiuses.zw = button.normal.background.corner_radiuses.zw;
        button.active.background.corner_radiuses.zw = .{};

        arrow_size = .{10, 6};
    }
    SetStyle(theme, "combo", theme.combo);

    {
        using theme.tooltip;

        background.corner_radiuses = .{3,3,3,3};
        background.padding = .{6,6,6,6};

        background.background_color = base_background_color;
        background.border_color = MakeTone(base_background_color, 0.3);
        background.border_size = 1;

        background.outer_shadow_color = ColorU32(0,0,0,0.5);
        background.outer_shadow_offset = .{3,3};
        background.outer_shadow_blur = 5;

        text = theme.text;
        text.text_size = floor(text.text_size * 0.9);
    }
    SetStyle(theme, "tooltip", theme.tooltip);

    {
        using theme.table;

        padding = .{1,1,1,1};
        corner_radiuses = .{4,4,4,4};
        border_color = MakeTone(base_background_color, 0.5);
        border_size = 1;
        horizontal_inner_border_color = MakeTone(base_background_color, 0.5);
        horizontal_inner_border_size = 0;
        vertical_inner_border_color = MakeTone(base_background_color, 0.5);
        vertical_inner_border_size = 1;

        header_text = theme.text;
        header_text.font = GetDefaultFontMedium();

        header_row.cell_padding = .{6,6,6,6};
        header_row.cell_child_align = .{0, 0.5};
        header_row.background_color = MakeTone(base_background_color, 0.05);
        header_row.alternate_background_color = MakeTone(base_background_color, 0.05);
        header_row_height = 32;

        rows.cell_padding = .{4,4,4,4};
        rows.cell_child_align = .{0, 0.5};
        rows.background_color = MakeTone(base_background_color, 0.1);
        rows.alternate_background_color = MakeTone(base_background_color, 0.2);

        row_height = 30;
    }
    SetStyle(theme, "table", theme.table);

    {
        using theme.progress_bar;

        height = 6;

        background.background_color = MakeTone(base_background_color, 0.1);
        background.border_color = MakeTone(base_background_color, 0.4);
        background.border_size = 1;
        background.corner_radiuses = Vec4f.{1,1,1,1} * height * 0.5;

        fill.background_color = base_accent_color;
        fill.corner_radiuses = Vec4f.{1,1,1,1} * height * 0.5;
    }
    SetStyle(theme, "progress_bar", theme.progress_bar);
}
