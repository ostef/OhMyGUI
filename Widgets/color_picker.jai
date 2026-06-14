ColorPickerFlags :: enum_flags {
    NoAlpha;
}

ColorPickerStyle :: struct {
    red_slider : SliderStyle;
    green_slider : SliderStyle;
    blue_slider : SliderStyle;

    hue_slider : SliderStyle;
    saturation_slider : SliderStyle;
    value_slider : SliderStyle;

    opacity_slider : SliderStyle;
}

ColorPickerData :: struct {
    rgb : Vec3f;
    hsv : Vec3f;
    alpha : float;

    modifying_field : enum u8 {
        None;
        Red;
        Green;
        Blue;
        Hue;
        Saturation;
        Value;
        Alpha;
    };
}

ColorPicker :: (parent : *Node, color : *RGBA8, flags : ColorPickerFlags = 0, style : *ColorPickerStyle = null, location := #caller_location) -> *Node {
    RGBToHSVPreserving :: (rgb : Vec3f, base_hue : float) -> Vec3f {
        hsv := RGBToHSV(rgb);
        if hsv.y == 0 || hsv.z == 0 {
            hsv.x = base_hue; // Preserve hue
        }

        return hsv;
    }

    LabelSlider :: (parent : *Node, label : string, value : *float, min : float, max : float, step : float, style : *SliderStyle, location := #caller_location) -> bool {
        content := LabelAndContent(parent, label, location=location);

        _, slider := Slider(content, value, min, max, step, style=style);

        text := Text(content, "%", FormatFloat.{value=value.*, trailing_width=2});
        approx_max_text_size := CalculateTextSize(text.font, text.text_size, "00.00");
        SetWidth(text, SizePx(approx_max_text_size.x));

        return slider.state_flags & .Active != 0;
    }

    EnsureStyle(*style, "color_picker");

    picker := GetNode(parent, location);
    {
        data := AddUserData(picker, ColorPickerData);

        if data.modifying_field == .None {
            rgbaf := ColorVec4f(color.*);
            data.rgb = rgbaf.xyz;
            data.alpha = rgbaf.w;
            data.hsv = RGBToHSVPreserving(data.rgb, data.hsv.x);
        }

        data.modifying_field = .None;

        SetSize(picker, SizeFill(), SizeFit());
        SetLayout(picker, .TopToBottom);

        if LabelSlider(picker, "Red", *data.rgb.x, 0, 1, 0.01, style=*style.red_slider) {
            data.modifying_field = .Red;
            data.hsv = RGBToHSVPreserving(data.rgb, data.hsv.x);
            color.* = ColorU32(data.rgb, data.alpha);
        }
        if LabelSlider(picker, "Green", *data.rgb.y, 0, 1, 0.01, style=*style.green_slider) {
            data.modifying_field = .Green;
            data.hsv = RGBToHSVPreserving(data.rgb, data.hsv.x);
            color.* = ColorU32(data.rgb, data.alpha);
        }
        if LabelSlider(picker, "Blue", *data.rgb.z, 0, 1, 0.01, style=*style.blue_slider) {
            data.modifying_field = .Blue;
            data.hsv = RGBToHSVPreserving(data.rgb, data.hsv.x);
            color.* = ColorU32(data.rgb, data.alpha);
        }

        HorizontalSeparator(picker);

        if LabelSlider(picker, "Hue", *data.hsv.x, 0, 360, 1, style=*style.hue_slider) {
            data.modifying_field = .Hue;
            data.rgb = HSVToRGB(data.hsv);
            color.* = ColorU32(data.rgb, data.alpha);
        }
        if LabelSlider(picker, "Saturation", *data.hsv.y, 0, 1, 0.01, style=*style.saturation_slider) {
            data.modifying_field = .Saturation;
            data.rgb = HSVToRGB(data.hsv);
            color.* = ColorU32(data.rgb, data.alpha);
        }
        if LabelSlider(picker, "Value", *data.hsv.z, 0, 1, 0.01, style=*style.value_slider) {
            data.modifying_field = .Value;
            data.rgb = HSVToRGB(data.hsv);
            color.* = ColorU32(data.rgb, data.alpha);
        }

        HorizontalSeparator(picker);

        if LabelSlider(picker, "Opacity", *data.alpha, 0, 1, 0.01, style=*style.opacity_slider) {
            data.modifying_field = .Alpha;
            color.* = ColorU32(data.rgb, data.alpha);
        }
    }

    return picker;
}

