ColorPickerFlags :: enum_flags {
    NoAlpha;
}

ColorPickerStyle :: struct {
    red_slider : SliderStyle;
    green_slider : SliderStyle;
    blue_slider : SliderStyle;
    alpha_slider : SliderStyle;
}

ColorPicker :: (parent : *Node, color : *RGBA8, flags : ColorPickerFlags = 0, style : *ColorPickerStyle = null, location := #caller_location) -> *Node {
    EnsureStyle(*style, "color_picker");

    as_float := ColorVec4f(color.*);

    picker := GetNode(parent, location);
    {
        SetSize(picker, SizeFill(), SizeFit());
        SetLayout(picker, .TopToBottom);

        r := LabelAndContent(picker, "Red");

        if Slider(r, *as_float.x, 0, 1, 0.01, style=*style.red_slider) {
            color.* = ColorU32(as_float);
        }

        r_text := Text(r, "%", FormatFloat.{value=as_float.x, trailing_width=2});
        SetWidth(r_text, SizeFill(0.2));

        g := LabelAndContent(picker, "Green");

        if Slider(g, *as_float.y, 0, 1, 0.01, style=*style.green_slider) {
            color.* = ColorU32(as_float);
        }

        g_text := Text(g, "%", FormatFloat.{value=as_float.y, trailing_width=2});
        SetWidth(g_text, SizeFill(0.2));

        b := LabelAndContent(picker, "Blue");

        if Slider(b, *as_float.z, 0, 1, 0.01, style=*style.blue_slider) {
            color.* = ColorU32(as_float);
        }

        b_text := Text(b, "%", FormatFloat.{value=as_float.z, trailing_width=2});
        SetWidth(b_text, SizeFill(0.2));

        a := LabelAndContent(picker, "Alpha");

        if Slider(a, *as_float.w, 0, 1, 0.01, style=*style.alpha_slider) {
            color.* = ColorU32(as_float);
        }

        a_text := Text(a, "%", FormatFloat.{value=as_float.w, trailing_width=2});
        SetWidth(a_text, SizeFill(0.2));
    }

    return picker;
}

