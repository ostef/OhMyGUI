ColorPickerFlags :: enum_flags {
    NoAlpha;
}

HSVTriangleWheelStyle :: struct {
    wheel_thickness := 20.0;
    triangle_inset := 10.0;
    border_size := 2.5;
    border_color : RGBA8;

    wheel_cursor : struct {
        radius := 10.0;
        border_color : RGBA8;
        border_size := 2.0;
    }
    triangle_cursor : type_of(wheel_cursor) = .{
        radius=6
    };
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

GetHSVWheelGeometricData :: (style : *HSVTriangleWheelStyle, rect : Vec4f, hsv : Vec3f) -> struct {
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

    theta := ToRads(hsv.x);

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

HSVTriangleWheel :: (parent : *Node, using data : *ColorPickerData, size : float, style : *HSVTriangleWheelStyle, location := #caller_location) {
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
        using _ := GetHSVWheelGeometricData(style, node.rect, hsv);

        wheel_shape := Onion(Circle(outer_radius - style.wheel_thickness * 0.5), style.wheel_thickness * 0.5 + style.border_size);
        triangle_shape := Inflate(Triangle(hue_point - center, white_point - center, black_point - center), style.border_size);
        DrawShape(draw_list, Union(wheel_shape, triangle_shape, 1), center, style.border_color);
    }

    node := GetNode(parent, location);
    {
        SetSize(node, SizePx(size), SizePx(size));
        SetLayout(node, .None);
        SetDraw(node, Draw);
        SetUserData(node, data);
        SetUserData(node, style.*);

        SaturationValueTriangle(node, data, style);
        HueWheel(node, data, style);
    }
}

SaturationValueTriangle :: (parent : *Node, using data : *ColorPickerData, style : *HSVTriangleWheelStyle, location := #caller_location) {
    IsInside :: (node : *Node, point : Vec2f) -> bool {
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
            c0=ColorU32(HSVToRGB(hsv.x, 1, 1), 1), c1=0xffffffff, c2=0x000000ff,
        });

        cursor := lerp(hue_point, white_point, 1 - hsv.y);
        cursor = lerp(cursor, black_point, 1 - hsv.z);

        DrawBox(draw_list, .{
            position=cursor,
            size=.{style.triangle_cursor.radius * 2, style.triangle_cursor.radius * 2},
            corner_radiuses=Vec4f.{1,1,1,1} * style.triangle_cursor.radius,
            background_color=ColorU32(HSVToRGB(hsv), 1),
            border_color=style.triangle_cursor.border_color,
            border_size=style.triangle_cursor.border_size,
        });
    }

    node := GetNode(parent, location);
    SetSize(node, SizeFill(), SizeFill());
    SetDraw(node, Draw);
    SetIsInside(node, IsInside);

    using _ := GetHSVWheelGeometricData(style, node.layout_last_frame.rect, hsv);

    button := ButtonBehavior(node);
    if button.held {
        mouse := GetMousePosition(node.window);
        mouse = ClampToTriangle(mouse, hue_point, white_point, black_point);

        w_hue, w_white, w_black := BarycentricCoords(mouse, hue_point, white_point, black_point);

        v := clamp(w_hue + w_white, 0, 1);
        s := ifx v > 0 then clamp(w_hue / v, 0, 1) else 0;

        hsv.y = s;
        hsv.z = v;
    }
}

HueWheel :: (parent : *Node, using data : *ColorPickerData, style : *HSVTriangleWheelStyle, location := #caller_location) -> *Node {
    IsInside :: (node : *Node, point : Vec2f) -> bool {
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
            c0 := ColorU32(HSVToRGB(hue0, 1, 1), 1);
            c1 := ColorU32(HSVToRGB(hue1, 1, 1), 1);

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
        angle := ToRads(hsv.x);
        cursor := center + Rotate(.{outer_radius - style.wheel_thickness * 0.5, 0}, angle);
        DrawBox(draw_list, .{
            position=cursor,
            size=.{style.wheel_cursor.radius * 2, style.wheel_cursor.radius * 2},
            corner_radiuses=Vec4f.{1,1,1,1} * style.wheel_cursor.radius,
            background_color=ColorU32(HSVToRGB(hsv.x, 1, 1), 1),
            border_color=style.wheel_cursor.border_color,
            border_size=style.wheel_cursor.border_size,
        });
    }

    node := GetNode(parent);
    {
        SetSize(node, SizeFill(), SizeFill());
        SetDraw(node, Draw);
        SetIsInside(node, IsInside);

        using _ := GetHSVWheelGeometricData(style, node.layout_last_frame.rect, hsv);

        hue := hsv.x;

        button := ButtonBehavior(node);
        if button.held {
            mouse := GetMousePosition(node.window);
            center_to_mouse := normalize(mouse - center);
            hue := ToDegs(SignedAngle(.{1,0}, center_to_mouse));
            hue = fmod_cycling(hue, 360);
            hsv.x = hue;
        }
    }

    return node;
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

        HSVTriangleWheel(picker, data, 250, *style.wheel);

        // if data.modifying_field == .None {
        //     rgbaf := ColorVec4f(color.*);
        //     data.rgb = rgbaf.xyz;
        //     data.alpha = rgbaf.w;
        //     data.hsv = RGBToHSVPreserving(data.rgb, data.hsv.x);
        // }

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

