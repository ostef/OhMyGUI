ColorPickerFlags :: enum_flags {
    NoAlpha;
}

HSVTriangleWheelStyle :: struct {
    padding : Vec4f;

    wheel_thickness := 20.0;
    triangle_inset := 10.0;
    border_size := 2.0;
    border_color : RGBA8;
    outer_shadow_color : RGBA8;
    outer_shadow_blur : float;
    outer_shadow_offset : Vec2f;

    CursorStateStyle :: struct {
        radius := 10.0;
        border_color : RGBA8;
        border_size := 2.0;
        outer_shadow_color : RGBA8;
        outer_shadow_blur : float;
        outer_shadow_offset : Vec2f;
    }

    wheel_cursor : StateStyle(CursorStateStyle);
    triangle_cursor : StateStyle(CursorStateStyle);
}

ColorPickerStyle :: struct {
    wheel : HSVTriangleWheelStyle;

    red_slider : SliderStyle;
    green_slider : SliderStyle;
    blue_slider : SliderStyle;

    hue_slider : SliderStyle;
    saturation_slider : SliderStyle;
    value_slider : SliderStyle;

    opacity_slider : SliderStyle;
}

ColorPickerData :: struct {
    hsv : HSV;
    modifying_hsv : bool;
}

GetHSVWheelGeometricData :: (style : *HSVTriangleWheelStyle, rect : Vec4f, hsv : HSV) -> struct {
    center : Vec2f;
    inner_radius : float;
    outer_radius : float;
    hue_point : Vec2f;
    white_point : Vec2f;
    black_point : Vec2f;
} {
    center := (rect.xy + rect.zw) * 0.5;
    outer_radius := min(rect.z - rect.x, rect.w - rect.y) * 0.5 - style.border_size;
    inner_radius := max(outer_radius - style.wheel_thickness, outer_radius * 0.5);

    theta := ToRads(hsv.hue);

    hue_point := Rotate(.{inner_radius - style.triangle_inset, 0}, theta);
    white_point := Rotate(hue_point, PI * 0.666667);
    black_point := Rotate(white_point, PI * 0.666667);

    return .{
        center,
        inner_radius,
        outer_radius,
        center + hue_point,
        center + white_point,
        center + black_point,
    };
}

HSVTriangleWheel :: (parent : *Node, using data : *ColorPickerData, size : float, style : *HSVTriangleWheelStyle, location := #caller_location) -> bool {
    Draw :: (draw_list : *DrawList, node : *Node) {
        data := GetUserData(node, *ColorPickerData);
        if !data {
            return;
        }

        style := GetUserData(node, HSVTriangleWheelStyle);
        if !style {
            return;
        }

        using _ := data.*;
        using _ := GetHSVWheelGeometricData(style, InflateBounds(node.rect, node.padding * -1), hsv);

        wheel_shape := Onion(Circle(outer_radius - style.wheel_thickness * 0.5), style.wheel_thickness * 0.5 + style.border_size);
        triangle_shape := Inflate(Triangle(hue_point - center, white_point - center, black_point - center), style.border_size);

        DrawShape(draw_list, .{
            shape=Union(wheel_shape, triangle_shape, 1),
            position=center,
            background_color=style.border_color,
            outer_shadow_color=style.outer_shadow_color,
            outer_shadow_offset=style.outer_shadow_offset,
            outer_shadow_blur=style.outer_shadow_blur,
        });
    }

    modified := false;

    node := GetNode(parent, location);
    {
        SetSize(node, SizePx(size), SizePx(size));
        SetLayout(node, .None);
        SetDraw(node, Draw);
        SetUserData(node, data);
        SetUserData(node, style.*);
        SetPadding(node, style.padding);

        modified |= SaturationValueTriangle(node, data, style);
        modified |= HueWheel(node, data, style);
    }

    return modified;
}

SaturationValueTriangle :: (parent : *Node, using data : *ColorPickerData, style : *HSVTriangleWheelStyle, location := #caller_location) -> bool {
    HitTest :: (node : *Node, point : Vec2f) -> bool {
        if !node.parent {
            return false;
        }

        data := GetUserData(node.parent, *ColorPickerData);
        if !data {
            return false;
        }

        style := GetUserData(node.parent, HSVTriangleWheelStyle);
        if !style {
            return false;
        }

        using _ := data.*;
        using _ := GetHSVWheelGeometricData(style, node.rect, hsv);

        return IsInsideTriangle(point, hue_point, white_point, black_point);
    }

    Draw :: (draw_list : *DrawList, node : *Node) {
        if !node.parent {
            return;
        }

        data := GetUserData(node.parent, *ColorPickerData);
        if !data {
            return;
        }

        style := GetUserData(node.parent, HSVTriangleWheelStyle);
        if !style {
            return;
        }

        using _ := data.*;
        using _ := GetHSVWheelGeometricData(style, node.rect, hsv);

        DrawTriangle(draw_list, .{
            p0=hue_point, p1=white_point, p2=black_point,
            c0=ColorU32(HSVToRGB(.{hsv.hue, 1, 1}), 1), c1=0xffffffff, c2=0x000000ff,
        });

        cursor := lerp(hue_point, white_point, 1 - hsv.saturation);
        cursor = lerp(cursor, black_point, 1 - hsv.value);
        cursor_style := style.triangle_cursor.states[GetState(node)];

        DrawBox(draw_list, .{
            position=cursor,
            size=Vec2f.{1,1} * (cursor_style.radius * 2),
            corner_radiuses=Vec4f.{1,1,1,1} * cursor_style.radius,
            background_color=ColorU32(HSVToRGB(hsv), 1),
            border_color=cursor_style.border_color,
            border_size=cursor_style.border_size,
            outer_shadow_color=cursor_style.outer_shadow_color,
            outer_shadow_offset=cursor_style.outer_shadow_offset,
            outer_shadow_blur=cursor_style.outer_shadow_blur,
        });
    }

    node := GetNode(parent, location);
    SetSize(node, SizeFill(), SizeFill());
    SetDraw(node, Draw);
    SetHitTest(node, HitTest);

    using _ := GetHSVWheelGeometricData(style, node.layout_last_frame.rect, hsv);

    button := ButtonBehavior(node);
    if button.held {
        mouse := GetMousePosition(node.window);
        mouse = ClampToTriangle(mouse, hue_point, white_point, black_point);

        w_hue, w_white, w_black := BarycentricCoords(mouse, hue_point, white_point, black_point);

        v := clamp(w_hue + w_white, 0, 1);
        s := ifx v > 0 then clamp(w_hue / v, 0, 1) else 0;

        hsv.saturation = s;
        hsv.value = v;
    }

    return button.held;
}

HueWheel :: (parent : *Node, using data : *ColorPickerData, style : *HSVTriangleWheelStyle, location := #caller_location) -> bool {
    HitTest :: (node : *Node, point : Vec2f) -> bool {
        if !node.parent {
            return false;
        }

        data := GetUserData(node.parent, *ColorPickerData);
        if !data {
            return false;
        }

        style := GetUserData(node.parent, HSVTriangleWheelStyle);
        if !style {
            return false;
        }

        using _ := data.*;
        using _ := GetHSVWheelGeometricData(style, node.rect, hsv);

        return IsInsideRing(point, center, inner_radius, outer_radius);
    }

    Draw :: (draw_list : *DrawList, node : *Node) {
        if !node.parent {
            return;
        }

        data := GetUserData(node.parent, *ColorPickerData);
        if !data {
            return;
        }

        style := GetUserData(node.parent, HSVTriangleWheelStyle);
        if !style {
            return;
        }

        using _ := data.*;
        using _ := GetHSVWheelGeometricData(style, node.rect, hsv);

        Resolution :: 100;
        theta := PI * 2 / Resolution;
        cost := cos(theta);
        sint := sin(theta);
        p := Vec2f.{1,0};

        for i : 0..Resolution - 1 {
            hue0 := i / cast(float, Resolution) * 360;
            hue1 := hue0 + ToDegs(theta);
            c0 := ColorU32(HSVToRGB(.{hue0, 1, 1}), 1);
            c1 := ColorU32(HSVToRGB(.{hue1, 1, 1}), 1);

            p0 := center + inner_radius * p;
            p1 := center + outer_radius * p;

            p = .{
                p.x * cost - p.y * sint,
                p.x * sint + p.y * cost,
            };

            p2 := center + outer_radius * p;
            p3 := center + inner_radius * p;

            DrawTriangle(draw_list, .{
                p0=p0, p1=p1, p2=p2,
                c0=c0, c1=c0, c2=c1,
            });
            DrawTriangle(draw_list, .{
                p0=p0, p1=p2, p2=p3,
                c0=c0, c1=c1, c2=c1,
            });
        }

        // Draw cursor ring
        angle := ToRads(hsv.hue);
        cursor := center + Rotate(.{outer_radius - style.wheel_thickness * 0.5, 0}, angle);
        cursor_style := style.wheel_cursor.states[GetState(node)];

        DrawBox(draw_list, .{
            position=cursor,
            size=Vec2f.{1,1} * (cursor_style.radius * 2),
            corner_radiuses=Vec4f.{1,1,1,1} * cursor_style.radius,
            background_color=ColorU32(HSVToRGB(.{hsv.hue, 1, 1}), 1),
            border_color=cursor_style.border_color,
            border_size=cursor_style.border_size,
            outer_shadow_color=cursor_style.outer_shadow_color,
            outer_shadow_offset=cursor_style.outer_shadow_offset,
            outer_shadow_blur=cursor_style.outer_shadow_blur,
        });
    }

    node := GetNode(parent);
    SetSize(node, SizeFill(), SizeFill());
    SetDraw(node, Draw);
    SetHitTest(node, HitTest);

    using _ := GetHSVWheelGeometricData(style, node.layout_last_frame.rect, hsv);

    hue := hsv.hue;

    button := ButtonBehavior(node);
    if button.held {
        mouse := GetMousePosition(node.window);
        center_to_mouse := normalize(mouse - center);
        hue := ToDegs(SignedAngle(.{1,0}, center_to_mouse));
        hue = fmod_cycling(hue, 360);
        hsv.hue = hue;
    }

    return button.held;
}

ColorPicker :: (parent : *Node, color : *Vec4f, flags : ColorPickerFlags = 0, style : *ColorPickerStyle = null, location := #caller_location) -> *Node {
    RGBToHSVPreserving :: (rgb : Vec3f, current : HSV) -> HSV {
        hsv := RGBToHSV(rgb);
        if hsv.saturation == 0 || hsv.value == 0 {
            hsv.hue = current.hue;
        }
        if hsv.value == 0 {
            hsv.saturation = current.saturation;
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
        SetLayout(picker, .LeftToRight);
        SetSize(picker, SizeFill(), SizeFit());
        SetMinWidthFit(picker);
        SetChildGap(picker, 12, 12);

        data := AddUserData(picker, ColorPickerData);
        if !data.modifying_hsv {
            data.hsv = RGBToHSVPreserving(color.xyz, data.hsv);
            data.modifying_hsv = false;
        }

        left := GetNode(picker);
        SetSize(left, SizeFit(), SizeFit());
        SetLayout(left, .TopToBottom);

        VerticalSeparator(picker);

        right := GetNode(picker);
        SetSize(right, SizeFill(), SizeFit());
        SetMinWidth(right, 200);
        SetLayout(right, .TopToBottom);

        if LabelSlider(right, "Red", *color.x, 0, 1, 0.01, style=*style.red_slider) {
            data.hsv = RGBToHSVPreserving(color.xyz, data.hsv);
        }
        if LabelSlider(right, "Green", *color.y, 0, 1, 0.01, style=*style.green_slider) {
            data.hsv = RGBToHSVPreserving(color.xyz, data.hsv);
        }
        if LabelSlider(right, "Blue", *color.z, 0, 1, 0.01, style=*style.blue_slider) {
            data.hsv = RGBToHSVPreserving(color.xyz, data.hsv);
        }

        HorizontalSeparator(right);

        data.modifying_hsv = HSVTriangleWheel(left, data, 250, *style.wheel);
        data.modifying_hsv |= LabelSlider(right, "Hue", *data.hsv.hue, 0, 360, 1, style=*style.hue_slider);
        data.modifying_hsv |= LabelSlider(right, "Saturation", *data.hsv.saturation, 0, 1, 0.01, style=*style.saturation_slider);
        data.modifying_hsv |= LabelSlider(right, "Value", *data.hsv.value, 0, 1, 0.01, style=*style.value_slider);

        if data.modifying_hsv {
            color.xyz = HSVToRGB(data.hsv);
        }

        HorizontalSeparator(right);

        LabelSlider(right, "Opacity", *color.w, 0, 1, 0.01, style=*style.opacity_slider);
    }

    return picker;
}

