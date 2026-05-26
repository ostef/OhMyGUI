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
    background_color : u32;
    border_color : u32;
    border_size : float;
    border_inset : float;
    outer_shadow_blur : float;
    outer_shadow_offset : Vec2f;
    outer_shadow_color : u32;
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
    text_color : u32;
    outer_shadow_blur : float;
    outer_shadow_offset : Vec2f;
    outer_shadow_color : u32;
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

// AnimateProc :: #type (a : float, b : float, t : float) -> float;

// AnimateStyle :: (a : $T, b : T, time : float, speed : float, animate : AnimateProc) {
//     t := time / speed;

//     #insert -> string {
//         AppendAnimate :: (

//         builder : String_Builder;

//         info := type_info(T);
//         for info.members {
//             type := it.type;
//             if type == type_info(Vec2f) {
//             } else if type == type_info(Vec4f) {
//             } else if type == type_info(RGBA8) {
//             } else if type.kind == {
//             }
//         }

//         return builder_to_string(*builder);
//     }
// }

#scope_file

g_default_theme : struct {
    theme : Theme;

    text : TextStyle;
    button : ButtonStyle;
    slider : SliderStyle;
    scrollbar : SliderStyle;
    text_input : TextInputStyle;
    checkbox : CheckboxStyle;
};

#scope_export

InitDefaultTheme :: () {
    using g_default_theme;

    {
        using text;

        font = GetDefaultFont();
        text_size = 16;
        text_color = ColorU32(0,0,0,1);
    }
    SetStyle(*theme, "text", text);

    {
        using button;

        normal.background.corner_radiuses = .{10,10,10,10};
        normal.background.padding = .{10,10,10,10};
        normal.background.child_gap = .{4,4};
        normal.background.background_color = ColorU32(0.9,0.9,0.9,1);
        normal.text = text;

        focused = normal;
        focused.background.background_color = ColorU32(0.8,0.8,0.8,1);

        hot = normal;
        hot.background.background_color = ColorU32(0.7,0.7,0.7,1);

        active = normal;

        disabled = normal;
        disabled.text.text_color = ColorU32(0.5,0.5,0.5,1);
    }
    SetStyle(*theme, "button", button);

    {
        using slider;

        handle_size = 15;

        normal.background.corner_radiuses = .{2,2,2,2};
        normal.background.background_color = ColorU32(0.7, 0.7, 0.7, 0.4);
        normal.handle.background_color = ColorU32(0.8, 0.8, 0.8, 1);
        normal.handle.corner_radiuses = .{2,2,2,2};

        focused = normal;
        focused.background.background_color = ColorU32(0.4, 0.4, 0.4, 0.8);

        hot = focused;

        active = hot;
        active.handle.background_color = ColorU32(0.9, 0.9, 0.9, 1);

        disabled.background.background_color = ColorU32(0.5, 0.5, 0.5, 0.5);
        disabled.handle.background_color = ColorU32(0.5, 0.5, 0.5, 1);
    }
    SetStyle(*theme, "slider", slider);

    {
        using scrollbar;

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
    SetStyle(*theme, "scrollbar", scrollbar);

    {
        using text_input;

        normal.background.corner_radiuses = .{10,10,10,10};
        normal.background.padding = .{10,10,10,10};
        normal.background.child_gap = .{4,4};
        normal.background.background_color = ColorU32(0.9,0.9,0.9,1);
        normal.text = text;

        focused = normal;
        focused.background.background_color = ColorU32(0.8,0.8,0.8,1);

        hot = normal;
        hot.background.background_color = ColorU32(0.7, 0.7, 0.7,1);

        active = normal;
        active.background.border_size = 2;
        active.background.border_color = ColorU32(0.1, 0.3, 0.8, 1);

        disabled = normal;
        disabled.text.text_color = ColorU32(0.5,0.5,0.5,1);
    }
    SetStyle(*theme, "text_input", text_input);

    {
        using checkbox;

        normal.background.corner_radiuses = .{4,4,4,4};
        normal.background.padding = .{2,2,2,2};
        normal.background.background_color = ColorU32(0.9,0.9,0.9,1);
        normal.checkmark.background_color = ColorU32(0.3, 0.5, 0.8, 1);
        normal.checkmark.rounding = 1;

        focused = normal;
        focused.background.background_color = ColorU32(0.8,0.8,0.8,1);

        hot = normal;
        hot.background.background_color = ColorU32(0.7,0.7,0.7,1);

        active = normal;

        disabled = normal;
        disabled.checkmark.background_color = ColorU32(0.5,0.5,0.5,1);
    }
    SetStyle(*theme, "checkbox", checkbox);

    SetTheme(*theme);
}
