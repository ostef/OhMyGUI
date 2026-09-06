ColorPickerFlags :: enum_flags {
    NoAlpha;
}

HSVTriangleWheelStyle :: struct {
    padding : Vec4b;

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

    label_and_slider : LabelAndContentStyle;

    red_slider : SliderStyle;
    green_slider : SliderStyle;
    blue_slider : SliderStyle;
    dynamic_rgb_slider_color := true;

    hue_slider : SliderStyle;
    saturation_slider : SliderStyle;
    value_slider : SliderStyle;
    dynamic_hsv_slider_color := true;

    opacity_slider : SliderStyle;
    dynamic_opacity_slider_color := true;
    opacity_checkerboard_white : RGBA8;
    opacity_checkerboard_black : RGBA8;

    preview : ColorPreviewStyle;
}

ColorPickerData :: struct {
    mode : enum {
        HSVWheel;
        Sliders;
        Inputs;
    } = .Sliders;

    hsv : HSV;
    modifying_hsv : bool;
    color_before_picking : Vec4f;
    picking_color : bool;
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

HSVTriangleWheel :: (parent : *Node, using data : *ColorPickerData, style : *HSVTriangleWheelStyle, location := #caller_location) -> bool, *Node {
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
        using _ := GetHSVWheelGeometricData(style, InflateBounds(node.rect, ToVec4f(node.padding) * -1), hsv);

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
        SetSize(node, SizeFill(), SizeFill());
        SetLayout(node, .None);
        // SetDraw(node, Draw);
        SetUserData(node, data);
        SetUserData(node, style.*);
        SetPadding(node, style.padding);
        node.flags |= .NoPaddedClip;

        modified |= HueWheel(node, data, style);
        modified |= SaturationValueTriangle(node, data, style);
    }

    return modified, node;
}

SaturationValueTriangle :: (parent : *Node, using data : *ColorPickerData, style : *HSVTriangleWheelStyle, location := #caller_location) -> bool {
    HitTest :: (node : *Node, point : Vec2f) -> bool {
        if !IsInsideRect(point, node.clipped_rect) {
            return false;
        }

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

        cursor := lerp(hue_point, white_point, 1 - hsv.saturation);
        cursor = lerp(cursor, black_point, 1 - hsv.value);
        cursor_style := style.triangle_cursor.states[GetState(node)];

        return IsInsideTriangle(point, hue_point, white_point, black_point)
            || IsInsideCircle(point, cursor, cursor_style.radius);
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
    node.flags |= .NoClip;
    SetSize(node, SizeFill(), SizeFill());
    // SetDraw(node, Draw);
    SetHitTest(node, HitTest);

    using _ := GetHSVWheelGeometricData(style, node.rect, hsv);

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
        if !IsInsideRect(point, node.clipped_rect) {
            return false;
        }

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

        angle := ToRads(hsv.hue);
        cursor := center + Rotate(.{outer_radius - style.wheel_thickness * 0.5, 0}, angle);
        cursor_style := style.wheel_cursor.states[GetState(node)];

        return IsInsideRing(point, center, inner_radius, outer_radius)
            || IsInsideCircle(point, cursor, cursor_style.radius);
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
    node.flags |= .NoClip;
    SetSize(node, SizeFill(), SizeFill());
    // SetDraw(node, Draw);
    SetHitTest(node, HitTest);

    using _ := GetHSVWheelGeometricData(style, node.rect, hsv);

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

ColoredSliderData :: struct {
    hue : bool;
    hsv : HSV;
    checkerboard_white : RGBA8;
    checkerboard_black : RGBA8;
    start_color : RGBA8;
    end_color : RGBA8;
}

ColoredSlider :: (parent : *Node, value : *float, min : float, max : float, step : float, style : *SliderStyle, dynamic_color : bool, location := #caller_location) -> bool, slider : *Node, background : *Node, handle : *Node {
    DrawTriangularCursor :: (draw_list : *DrawList, node : *Node) {
        if !node.parent {
            return;
        }

        axis := ifx node.parent.desired_size.x.kind == .FitChildren
            then Axis.Y else Axis.X;
        cross := GetCrossAxis(axis);

        a := ifx axis == .X then node.rect.xy else Vec2f.{node.rect.x, node.rect.w};
        b := ifx axis == .X then Vec2f.{node.rect.z, node.rect.y} else node.rect.xy;

        c := ifx axis == .X then Vec2f.{node.size.x,0} else Vec2f.{0,-node.size.y};
        c = a + Rotate(c, PI / 3);

        DrawShape(draw_list, .{
            shape=Triangle(a, b, c),
            background_color=node.background_color,
            border_color=node.border_color,
            border_size=node.border_size,
            border_inset=node.border_inset,
            outer_shadow_color=node.outer_shadow_color,
            outer_shadow_offset=node.outer_shadow_offset,
            outer_shadow_blur=node.outer_shadow_blur,
        });

        a = ifx axis == .X then Vec2f.{node.rect.x, node.rect.w} else node.rect.zw;
        b = ifx axis == .X then node.rect.zw else Vec2f.{node.rect.z, node.rect.y};

        c = ifx axis == .X then Vec2f.{node.size.x,0} else Vec2f.{0,-node.size.y};
        c = a + Rotate(c, -PI / 3);

        DrawShape(draw_list, .{
            shape=Triangle(a, b, c),
            background_color=node.background_color,
            border_color=node.border_color,
            border_size=node.border_size,
            border_inset=node.border_inset,
            outer_shadow_color=node.outer_shadow_color,
            outer_shadow_offset=node.outer_shadow_offset,
            outer_shadow_blur=node.outer_shadow_blur,
        });
    }

    DrawBackground :: (draw_list : *DrawList, node : *Node) {
        if !node.parent {
            return;
        }

        using data := GetUserData(node.parent, ColoredSliderData);
        if !data {
            return;
        }

        axis := ifx node.parent.desired_size.x.kind == .FitChildren
            then Axis.Y else Axis.X;
        cross := GetCrossAxis(axis);

        PushClipBox(draw_list, node.rect, node.corner_radiuses);

        DrawCheckerboard(draw_list, node.rect, node.size[cross] * 0.5, checkerboard_white, checkerboard_black);

        if hue {
            resolution := cast(int, Max(node.size.x / 5.0, 30));

            t := 0.0;
            for i : 0..resolution - 1 {
                t0 := node.rect.xy[axis] + t * node.size[axis];
                h0 := ifx axis == .X then t * 360 else 360 - t * 360;
                c0 := ColorU32(HSVToRGB(.{h0, hsv.saturation, hsv.value}), 1);

                t += 1.0 / resolution;

                t1 := node.rect.xy[axis] + t * node.size[axis];
                h1 := ifx axis == .X then t * 360 else 360 - t * 360;
                c1 := ColorU32(HSVToRGB(.{h1, hsv.saturation, hsv.value}), 1);

                p0 : Vec2f;
                p0[axis] = t0;
                p0[cross] = node.rect.zw[cross];

                p1 : Vec2f;
                p1[axis] = t0;
                p1[cross] = node.rect.xy[cross];

                p2 : Vec2f;
                p2[axis] = t1;
                p2[cross] = node.rect.xy[cross];

                DrawTriangle(draw_list, .{p0=p0, p1=p1, p2=p2, c0=c0, c1=c0, c2=c1});

                p1 = p2;

                p2[axis] = t1;
                p2[cross] = node.rect.zw[cross];

                DrawTriangle(draw_list, .{p0=p0, p1=p1, p2=p2, c0=c0, c1=c1, c2=c1});
            }
        } else {
            // We do not use gradients because gradients use smoothstep instead of linear interpolation

            c0 := start_color;
            c1 := ifx axis == .X then start_color else end_color;
            c2 := end_color;

            DrawTriangle(draw_list, .{
                p0=.{node.rect.x, node.rect.w}, p1=.{node.rect.x, node.rect.y}, p2=.{node.rect.z, node.rect.y},
                c0=c0, c1=c1, c2=c2,
            });

            c0 = start_color;
            c1 = end_color;
            c2 = ifx axis == .X then end_color else start_color;

            DrawTriangle(draw_list, .{
                p0=.{node.rect.x, node.rect.w}, p1=.{node.rect.z, node.rect.y}, p2=.{node.rect.z, node.rect.w},
                c0=c0, c1=c1, c2=c2,
            });
        }

        PopClipBox(draw_list);

        DrawNodeDefault(draw_list, node);
    }

    modified, slider, background, handle := Slider(parent, value, min, max, step, style=style, location=location);
    if dynamic_color {
        // SetDraw(background, DrawBackground);
    }

    // SetDraw(handle, DrawTriangularCursor);

    return modified, slider, background, handle;
}

ColorPreviewStyle :: struct {
    using box : BoxStyle;
    opacity_checkerboard_white : RGBA8;
    opacity_checkerboard_black : RGBA8;
}

ColorPreview :: (parent : *Node, color : RGBA8, style : *ColorPreviewStyle, location := #caller_location) -> *Node {
    Draw :: (draw_list : *DrawList, node : *Node) {
        DrawBox(draw_list, .{
            size=node.size,
            position=(node.rect.xy + node.rect.zw) * 0.5,
            corner_radiuses=node.corner_radiuses,
            background_color=0xffffffff,
            outer_shadow_color=node.outer_shadow_color,
            outer_shadow_offset=node.outer_shadow_offset,
            outer_shadow_blur=node.outer_shadow_blur,
        });

        style := GetUserData(node, ColorPreviewStyle);
        if style {
            PushClipBox(draw_list, node.rect, node.corner_radiuses);
            DrawCheckerboard(draw_list, node.rect, node.size.y / 3, style.opacity_checkerboard_white, style.opacity_checkerboard_black);
            PopClipBox(draw_list);
        }

        DrawBox(draw_list, .{
            size=.{node.size.x * 0.5, node.size.y},
            position=(node.rect.xy + node.rect.zw) * 0.5 - .{node.size.x * 0.25, 0},
            corner_radiuses=.{node.corner_radiuses.x,0,node.corner_radiuses.z,0},
            background_color=SetAlpha(node.background_color, 1),
        });

        DrawBox(draw_list, .{
            size=.{node.size.x * 0.5 + 1, node.size.y},
            position=(node.rect.xy + node.rect.zw) * 0.5 + .{node.size.x * 0.25 - 1, 0},
            corner_radiuses=.{0,node.corner_radiuses.y,0,node.corner_radiuses.w},
            background_color=node.background_color,
        });

        DrawBox(draw_list, .{
            size=node.size,
            position=(node.rect.xy + node.rect.zw) * 0.5,
            corner_radiuses=node.corner_radiuses,
            border_color=node.border_color,
            border_size=node.border_size,
            border_inset=node.border_inset,
        });
    }

    node := GetNode(parent, location=location);
    node.flags |= .Focusable;

    SetSize(node, SizePx(50), SizePx(40));
    // SetDraw(node, Draw);
    SetUserData(node, style.*);
    Apply(node, style.box);
    SetBackgroundColor(node, color);

    if node == context.omg.mouse_hovered_node {
        r, g, b, a := GetRGBAU8(color);
        rgba := ColorVec4f(color);
        hsv := RGBToHSV(rgba.xyz);
        Tooltip(
            "R: %  G: %  B: %  A: %\n%, %, %, %\n\n#%",
            FormatInt.{value=r, minimum_digits=3, padding=" "},
            FormatInt.{value=g, minimum_digits=3, padding=" "},
            FormatInt.{value=b, minimum_digits=3, padding=" "},
            FormatInt.{value=a, minimum_digits=3, padding=" "},
            FormatFloat.{value=rgba.x, trailing_width=3, zero_removal=.NO},
            FormatFloat.{value=rgba.y, trailing_width=3, zero_removal=.NO},
            FormatFloat.{value=rgba.z, trailing_width=3, zero_removal=.NO},
            FormatFloat.{value=rgba.w, trailing_width=3, zero_removal=.NO},
            FormatInt.{value=cast(u32, color), base=16, minimum_digits=8},
        );
    }

    return node;
}

PickColorButton :: (parent : *Node, color : *Vec4f, previous_color : Vec4f, data : *ColorPickerData, location := #caller_location) -> *Node {
    DrawPickColorIcon :: (draw_list : *DrawList, position : Vec2f, size : float, color : RGBA8) {
        width := size * 0.17;
        height := size - width;

        shaft := Union(
            Box(width, height, width * 0.5),
            Move(Circle(width * 0.2), 0, height * 0.5 + width * 0.2),
            size * 0.01
        );

        outline_thickness := size * 0.03;

        handle_size := height * 0.35;
        handle := Union(
            Move(Box(width + 2 * outline_thickness, handle_size, width * 0.5, width * 0.5, 0, 0), 0, -height * 0.5 + handle_size * 0.5),
            Move(Box((width + 2 * outline_thickness) * 1.4, width * 0.5, size * 0.03), 0, -height * 0.5 + handle_size)
        );

        shaft = Rotate(shaft, PI * 0.25);
        handle = Rotate(handle, PI * 0.25);

        shaft_outline := Onion(shaft, outline_thickness * 0.5);
        ink := Inter(shaft, Move(Box(size, size * 0.5), 0, size * 0.4));
        shape := Union(Union(shaft_outline, ink), handle);

        DrawShape(draw_list, shape, position, color);
    }

    DrawPickColorIcon :: (draw_list : *DrawList, node : *Node) {
        size := min(node.size.x, node.size.y);
        size = sqrt(2 * size * size);

        DrawPickColorIcon(draw_list, (node.rect.xy + node.rect.zw) * 0.5, size, node.text_color);
    }

    clicked, pick_button := Toggle(parent, SizePx(32), SizePx(32), *data.picking_color, location=location);
    pick_button.flags |= .NoPaddedClip;
    pick_button.padding = .{7,7,7,7};

    if clicked {
        data.color_before_picking = color.*;
    }

    accept := IsMouseButtonPressed(.Left);
    cancel := IsMouseButtonPressed(.Right) || IsKeyPressed(.Escape);

    if data.picking_color && accept {
        color.* = ColorVec4f(GetColorAtMousePosition());
        data.hsv = RGBToHSVPreserving(color.xyz, data.hsv);
        data.picking_color = false;
    }
    if data.picking_color && cancel {
        color.* = data.color_before_picking;
        data.hsv = RGBToHSVPreserving(color.xyz, data.hsv);
        data.picking_color = false;
    }

    if data.picking_color {
        SetMouseCapture(pick_button);
        SetCursor(GetSystemCursor(.EyeDropper));

        color.* = ColorVec4f(GetColorAtMousePosition());
        data.hsv = RGBToHSVPreserving(color.xyz, data.hsv);
    }

    btn_style := GetStyle("button", ButtonStyle);

    pick_icon := GetNode(pick_button);
    SetSize(pick_icon, SizeFill(), SizeFill());
    // SetDraw(pick_icon, DrawPickColorIcon);

    state := GetState(pick_button);
    SetTextColor(pick_icon, btn_style.states[state].text.text_color);

    return pick_button;
}

GetColorAtMousePosition :: inline () -> RGBA8 {
    mouse := GetMousePosition();
    return GetColorFromScreen(xx mouse.x, xx mouse.y);
}

#if OS == .WINDOWS {

GetColorFromScreen :: (x : int, y : int) -> RGBA8 {
    User32 :: #library,system "User32";
    Gdi32 :: #library,system "Gdi32";

    GetDC :: (hwnd : *void) -> *void #foreign User32;
    ReleaseDC :: (hwnd : *void, hdc : *void) -> s32 #foreign User32;
    GetPixel :: (hdc : *void, x : s32, y : s32) -> u32 #foreign Gdi32;

    monitor := GetDC(null);
    defer ReleaseDC(null, monitor);

    color := GetPixel(monitor, xx x, xx y);
    r := cast(u32, (color >>  0) & 0xff);
    g := cast(u32, (color >>  8) & 0xff);
    b := cast(u32, (color >> 16) & 0xff);
    a := cast(u32, 0xff);
    rgba := cast(RGBA8, (r << 24) | (g << 16) | (b << 8) | (a << 0));

    return rgba;
}

} else {

GetColorFromScreen :: (x : int, y : int) -> RGBA8 {
    return 0;
}

}

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

ColorPicker :: (
    parent : *Node,
    color : *Vec4f,
    previous_color := Vec4f.{0,0,0,0},
    flags : ColorPickerFlags = 0,
    style : *ColorPickerStyle = null,
    location := #caller_location
) -> ok : bool, cancel : bool, *Node {
    LabelSlider :: (
        parent : *Node,
        label : string,
        value : *float, min : float, max : float, step : float,
        label_and_content_style : *LabelAndContentStyle, style : *SliderStyle, dynamic_color : bool,
        location := #caller_location
    ) -> bool, slider : *Node {
        node := GetNode(parent, location);
        SetSize(node, SizeFill(), SizeFit());
        SetChildAlign(node, label_and_content_style.child_align);
        SetLayout(node, .LeftToRight);

        SetPadding(node, label_and_content_style.padding);

        text := Text(node, "%", label, style=*label_and_content_style.text);
        SetSize(text, SizeFill(label_and_content_style.text_fill), SizeFit());
        SetLayout(text, .LeftToRight);

        content := GetNode(node);
        SetSize(content, SizeFill(), SizeFit());

        SetLayout(content, .LeftToRight);
        SetChildGap(content, label_and_content_style.child_gap);

        _, slider := ColoredSlider(content, value, min, max, step, style, dynamic_color);

        value_text := Text(content, "%", FormatFloat.{value=value.*, trailing_width=2}, style=*label_and_content_style.text);
        approx_max_text_size := CalculateTextSize(value_text.font, value_text.text_size, "00.00");
        SetWidth(value_text, SizePx(approx_max_text_size.x));

        return slider.state_flags & .Active != 0, slider;
    }

    EnsureStyle(*style, "color_picker");

    picker := GetNode(parent, location);
    {
        SetLayout(picker, .LeftToRight);
        SetSize(picker, SizeFill(), SizeFill());
        SetChildGap(picker, 0, 10);

        data := AddUserData(picker, ColorPickerData);
        if !data.modifying_hsv {
            data.hsv = RGBToHSVPreserving(color.xyz, data.hsv);
            data.modifying_hsv = false;
        }

        left := GetNode(picker);
        SetLayout(left, .TopToBottom);
        SetSize(left, SizeFill(0.8), SizeFill());
        SetPadding(left, 5, 5);

        right := GetNode(picker);
        SetLayout(right, .TopToBottom);
        SetSize(right, SizeFill(0.2), SizeFill());
        SetMinWidthFit(right);

        top := GetNode(left);
        SetSize(top, SizeFill(), SizeFit());
        SetLayout(top, .LeftToRight);
        SetPadding(top, 4, 4);
        SetChildAlign(top, 0.5, 0.5);
        SetChildGap(top, 4, 4);

        if MenuItem(top, "HSV Wheel", selected=data.mode == .HSVWheel) {
            data.mode = .HSVWheel;
        }
        if MenuItem(top, "Sliders", selected=data.mode == .Sliders) {
            data.mode = .Sliders;
        }
        if MenuItem(top, "Inputs", selected=data.mode == .Inputs) {
            data.mode = .Inputs;
        }

        bottom := GetNode(left);
        SetSize(bottom, SizeFill(), SizeFill());
        SetLayout(bottom, .TopToBottom);

        if !(flags & .NoAlpha) {
            _, opacity_slider := LabelSlider(bottom, "A", *color.w, 0, 1, 0.01, *style.label_and_slider, *style.opacity_slider, style.dynamic_opacity_slider_color);

            if style.dynamic_opacity_slider_color {
                SetUserData(opacity_slider, ColoredSliderData.{
                    checkerboard_white=style.opacity_checkerboard_white,
                    checkerboard_black=style.opacity_checkerboard_black,
                    start_color=ColorU32(color.xyz, 0),
                    end_color  =ColorU32(color.xyz, 1),
                });
            }

            Separator(bottom);
        }

        if data.mode == {
        case .HSVWheel;
            hsv_wheel : *Node;
            data.modifying_hsv, hsv_wheel = HSVTriangleWheel(bottom, data, *style.wheel);
            SetMinSize(hsv_wheel, 200, 200);

        case .Sliders;
            h_modified, h_slider := LabelSlider(bottom, "H", *data.hsv.hue, 0, 360, 1, *style.label_and_slider, *style.hue_slider, style.dynamic_hsv_slider_color);
            s_modified, s_slider := LabelSlider(bottom, "S", *data.hsv.saturation, 0, 1, 0.01, *style.label_and_slider, *style.saturation_slider, style.dynamic_hsv_slider_color);
            v_modified, v_slider := LabelSlider(bottom, "V", *data.hsv.value, 0, 1, 0.01, *style.label_and_slider, *style.value_slider, style.dynamic_hsv_slider_color);

            data.modifying_hsv |= h_modified | s_modified | v_modified;

            if style.dynamic_hsv_slider_color {
                SetUserData(h_slider, ColoredSliderData.{hue=true, hsv=data.hsv});
                SetUserData(s_slider, ColoredSliderData.{
                    start_color=ColorU32(HSVToRGB(.{data.hsv.hue, 0, data.hsv.value}), 1),
                    end_color  =ColorU32(HSVToRGB(.{data.hsv.hue, 1, data.hsv.value}), 1),
                });
                SetUserData(v_slider, ColoredSliderData.{
                    start_color=ColorU32(HSVToRGB(.{data.hsv.hue, data.hsv.saturation, 0}), 1),
                    end_color  =ColorU32(HSVToRGB(.{data.hsv.hue, data.hsv.saturation, 1}), 1),
                });
            }

            Separator(bottom);

            r_modified, r_slider := LabelSlider(bottom, "R", *color.x, 0, 1, 0.01, *style.label_and_slider, *style.red_slider, style.dynamic_rgb_slider_color);
            g_modified, g_slider := LabelSlider(bottom, "G", *color.y, 0, 1, 0.01, *style.label_and_slider, *style.green_slider, style.dynamic_rgb_slider_color);
            b_modified, b_slider := LabelSlider(bottom, "B", *color.z, 0, 1, 0.01, *style.label_and_slider, *style.blue_slider, style.dynamic_rgb_slider_color);

            if style.dynamic_rgb_slider_color {
                SetUserData(r_slider, ColoredSliderData.{
                    start_color=ColorU32(0, color.y, color.z, 1),
                    end_color  =ColorU32(1, color.y, color.z, 1),
                });
                SetUserData(g_slider, ColoredSliderData.{
                    start_color=ColorU32(color.x, 0, color.z, 1),
                    end_color  =ColorU32(color.x, 1, color.z, 1),
                });
                SetUserData(b_slider, ColoredSliderData.{
                    start_color=ColorU32(color.x, color.y, 0, 1),
                    end_color  =ColorU32(color.x, color.y, 1, 1),
                });
            }

            if r_modified || g_modified || b_modified {
                data.hsv = RGBToHSVPreserving(color.xyz, data.hsv);
            }

        case .Inputs;
            label_and_content_style := GetStyle("label_and_content", LabelAndContentStyle).*;
            label_and_content_style.text_fill = 0.2;

            inputs := GetNode(bottom);
            SetSize(inputs, SizeFill(), SizeFit());
            SetLayout(inputs, .TopToBottom);
            SetChildGap(inputs, 4, 6);

            hsv_inputs := GetNode(inputs);
            SetSize(hsv_inputs, SizeFill(), SizeFit());
            SetLayout(hsv_inputs, .LeftToRight);
            SetChildGap(hsv_inputs, 4, 0);

            h_field := LabelAndContent(hsv_inputs, "H", style=*label_and_content_style);
            data.modifying_hsv |= FloatInput(h_field, *data.hsv.hue, 0, 360, 1, trailing_digits=2);

            s_field := LabelAndContent(hsv_inputs, "S", style=*label_and_content_style);
            data.modifying_hsv |= FloatInput(s_field, *data.hsv.saturation, 0, 1, 0.1);

            v_field := LabelAndContent(hsv_inputs, "V", style=*label_and_content_style);
            data.modifying_hsv |= FloatInput(v_field, *data.hsv.value, 0, 1, 0.1);

            hsva_field := LabelAndContent(hsv_inputs, "A", style=*label_and_content_style);
            FloatInput(hsva_field, *color.w, 0, 1, 0.1);

            rgb_inputs := GetNode(inputs);
            SetSize(rgb_inputs, SizeFill(), SizeFit());
            SetLayout(rgb_inputs, .LeftToRight);
            SetChildGap(rgb_inputs, 4, 0);

            r_field := LabelAndContent(rgb_inputs, "R", style=*label_and_content_style);
            rgb_modified := FloatInput(r_field, *color.x, 0, 1, 0.1);

            g_field := LabelAndContent(rgb_inputs, "G", style=*label_and_content_style);
            rgb_modified |= FloatInput(g_field, *color.y, 0, 1, 0.1);

            b_field := LabelAndContent(rgb_inputs, "B", style=*label_and_content_style);
            rgb_modified |= FloatInput(b_field, *color.z, 0, 1, 0.1);

            rgba_field := LabelAndContent(rgb_inputs, "A", style=*label_and_content_style);
            FloatInput(rgba_field, *color.w, 0, 1, 0.1);

            hex_field := LabelAndContent(inputs, "Hex", style=*label_and_content_style);

            hex := cast(u32, ColorU32(color));
            if IntInput(hex_field, *hex, 0, 0xffffffff, flags=.NoIncreaseDecreaseButtons, base=16, min_digits=8) {
                color.* = ColorVec4f(xx hex);
                rgb_modified = true;
            }

            if rgb_modified {
                data.hsv = RGBToHSVPreserving(color.xyz, data.hsv);
            }
        }

        if data.modifying_hsv {
            color.xyz = HSVToRGB(data.hsv);
        }

        SetPadding(right, 10, 10);
        SetChildGap(right, 5, 5);

        SetChildAlign(right, 0.5, 0.5);
        right.flags |= .NoPaddedClip;

        previews := GetNode(right);
        previews.flags |= .NoClip;
        SetLayout(previews, .LeftToRight);
        SetSize(previews, SizeFit(), SizeFit());
        SetChildGap(previews, 5, 5);
        SetChildAlign(previews, 0.5, 1);
        SetPadding(previews, 0, 10);

        current := GetNode(previews);
        SetLayout(current, .TopToBottom);
        SetSize(current, SizeFit(), SizeFit());

        Text(current, "New");
        ColorPreview(current, ColorU32(color), *style.preview);

        previous := GetNode(previews);
        SetLayout(previous, .TopToBottom);
        SetSize(previous, SizeFit(), SizeFit());

        Text(previous, "Old");
        previous_preview := ColorPreview(previous, ColorU32(previous_color), *style.preview);

        if ButtonBehavior(previous_preview).released {
            color.* = previous_color;
            data.hsv = RGBToHSVPreserving(color.xyz, data.hsv);
        }

        if previous_preview.state_flags & .Focused {
            SetCursor(GetSystemCursor(.Hand));
        }

        PickColorButton(previews, color, previous_color, data);

        ok_cancel := GetNode(right);
        SetLayout(ok_cancel, .LeftToRight);
        SetChildGap(ok_cancel, 5, 5);
        SetHeight(ok_cancel, SizeFill());
        SetChildAlign(ok_cancel, 0, 1);

        ok, ok_node := Button(ok_cancel, "Ok", style=GetStyle("button_accent", ButtonStyle));
        SetMinWidth(ok_node, 60);
        cancel, cancel_node := Button(ok_cancel, "Cancel");

        return ok, cancel, picker;
    }
}

ColorPickerWindow :: struct {
    bring_forward : bool;
    opened : bool;
    opened_in_window : *Window;
    color : *Vec4f;
    previous_color : Vec4f;
}

OpenGlobalColorPicker :: (window : *Window, color : *Vec4f) {
    data := AddGlobalUserData("color_picker", ColorPickerWindow);

    data.opened_in_window = window;
    data.color = color;
    data.previous_color = color.*;
    data.opened = true;
    data.bring_forward = true;
}

ColorPickerSubwindow :: () {
    using data := GetGlobalUserData("color_picker", ColorPickerWindow);
    if !data || !opened || !color {
        return;
    }

    subwindow, subwindow_node := Subwindow(opened_in_window, "Color Picker", "color_picker", .{550, 400});
    if !subwindow {
        return;
    }

    if subwindow_node && data.bring_forward {
        BringForward(subwindow_node);
        data.bring_forward = false;
    }

    ok, cancel := ColorPicker(subwindow, color, previous_color);
    if cancel {
        color.* = previous_color;
        color = null;
        opened = false;
    } else if ok {
        color = null;
        opened = false;
    }
}

ColorInputFlags :: enum_flags {
    NoAlpha;
    NoPreview;
    NoColorPickerWindow;
}

ColorInputStyle :: struct {
    label_and_content : LabelAndContentStyle;
    number_input : NumberInputStyle;
    preview : ColorPreviewStyle;
    number_input_gap : s8;
    preview_gap : s8;
}

ColorInput :: (
    parent : *Node,
    value : *RGBA8,
    flags : ColorInputFlags = 0,
    style : *ColorInputStyle = null,
    location := #caller_location
) -> modified : bool {
    rgba := ColorVec4f(value.*);

    modified := ColorInput(parent, *rgba, flags, style, location);

    if modified {
        value.* = ColorU32(rgba);
    }

    return modified;
}

ColorInput :: (
    parent : *Node,
    value : *Vec3f,
    flags : ColorInputFlags = 0,
    style : *ColorInputStyle = null,
    location := #caller_location
) -> modified : bool {
    rgba := Vec4f.{xyz=value.*, w=1};

    modified := ColorInput(parent, *rgba, flags | .NoAlpha, style, location);

    if modified {
        value.* = rgba.xyz;
    }

    return modified;
}

ColorInput :: (
    parent : *Node,
    value : *Vec4f,
    flags : ColorInputFlags = 0,
    style : *ColorInputStyle = null,
    location := #caller_location
) -> modified : bool {
    EnsureStyle(*style, "color_input");

    modified := false;

    parent = GetNode(parent, location);
    {
        SetSize(parent, SizeFill(), SizeFit());
        SetLayout(parent, .LeftToRight);
        SetChildGap(parent, style.preview_gap, 0);
        SetChildAlign(parent, 0, 0.5);

        inputs := GetNode(parent);
        SetSize(inputs, SizeFill(), SizeFit());
        SetLayout(inputs, .LeftToRight);
        SetChildGap(inputs, style.number_input_gap, 0);

        r_field := LabelAndContent(inputs, "R", style=*style.label_and_content);
        modified |= FloatInput(r_field, *value.x, 0, 1, 0.1, style=*style.number_input);

        g_field := LabelAndContent(inputs, "G", style=*style.label_and_content);
        modified |= FloatInput(g_field, *value.y, 0, 1, 0.1, style=*style.number_input);

        b_field := LabelAndContent(inputs, "B", style=*style.label_and_content);
        modified |= FloatInput(b_field, *value.z, 0, 1, 0.1, style=*style.number_input);

        if !(flags & .NoAlpha) {
            a_field := LabelAndContent(inputs, "A", style=*style.label_and_content);
            modified |= FloatInput(a_field, *value.w, 0, 1, 0.1, style=*style.number_input);
        }

        if !(flags & .NoPreview) {
            preview := ColorPreview(parent, ColorU32(value.*), *style.preview);

            if !(flags & .NoColorPickerWindow) {
                preview_button := ButtonBehavior(preview);

                if preview_button.released {
                    OpenGlobalColorPicker(parent.window, value);
                }
            }
        }
    }

    return modified;
}
