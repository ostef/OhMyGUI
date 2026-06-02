Text :: (parent : *Node, fmt_str : string, args : ..Any, style : *TextStyle = null, location := #caller_location) -> *Node {
    EnsureStyle(*style, "text");

    node := GetNode(parent, location);
    SetText(node, tprint(fmt_str, ..args));
    SetSize(node, SizeFit(), SizeFit()); // Fit text

    Apply(node, style);

    return node;
}

ButtonStateStyle :: struct {
    background : BoxStyle;
    text : TextStyle;
}

ButtonStyle :: StateStyle(ButtonStateStyle);

Button :: (parent : *Node, text : string, style : *ButtonStyle = null, location := #caller_location) -> clicked : bool, *Node {
    EnsureStyle(*style, "button");

    node := GetNode(parent, location);
    {
        SetSize(node, SizeFit(), SizeFit());

        text_node := GetNode(node, "text");
        SetText(text_node, text);

        button := ButtonBehavior(node);

        state := GetState(node);

        Apply(node, style.states[state].background);
        Apply(text_node, style.states[state].text);

        return button.released, node;
    }
}

SliderStateStyle :: struct {
    background : BoxStyle;
    handle : BoxStyle;
}

SliderStyle :: struct {
    using _ : StateStyle(SliderStateStyle);
    background_size : float;
    handle_size : float;
}

// @Todo: unify slider and scrollbar
Slider :: (parent : *Node, value : *$T, min : T, max : T, step : T, style : *SliderStyle = null, location := #caller_location) -> slider : *Node, background : *Node, handle : *Node {
    EnsureStyle(*style, "slider");

    fvalue := ifx value then cast(float, value.*);
    fmin := cast(float, min);
    fmax := cast(float, max);
    fstep := cast(float, step);

    defer if value {
        value.* = xx fvalue;
    }

    slider, background, handle : *Node;

    slider = GetNode(parent, location=location);
    {
        SetSize(slider, SizeFill(), SizePx(Max(style.background_size, style.handle_size)));
        SetLayout(slider, .None);
        SetChildAlign(slider, 0, 0.5);
        SetDraw(slider, null);

        background = GetNode(slider, "background");
        {
            SetSize(background, SizeFill(), SizePx(style.background_size));
        }

        handle = GetNode(slider, "handle");
        {
            SetSize(handle, SizePx(style.handle_size), SizePx(style.handle_size));

            range := fmax - fmin;
            offset_max := slider.layout_last_frame.size[Axis.X] - style.handle_size;

            // Allow the user to click on the slider to interact with the scrollbar
            slider.flags |= .Focusable;

            handle_result := ButtonBehavior(handle);

            if slider.state_flags & .Focused && IsMouseButtonPressed(.Left) {
                SetMouseCapture(handle);
                SetMouseFocus(handle);
                handle_result.pressed = true;
                handle_result.held = true;

                mouse := GetMousePosition(slider.window)[Axis.X];
                new_offset := mouse - slider.layout_last_frame.rect.xy[Axis.X] - style.handle_size * 0.5;
                new_value := (new_offset / offset_max) * range;

                fvalue = Snap(clamp(new_value, fmin, fmax), fstep);
            }

            if handle_result.pressed {
                context.omg.mouse_captured_node_value = .{};
                context.omg.mouse_captured_node_value[Axis.X] = (fvalue / range) * offset_max;
            }

            if handle_result.held {
                new_offset := GetMousePosition()[Axis.X] - context.omg.mouse_captured_at[Axis.X];
                new_offset += context.omg.mouse_captured_node_value[Axis.X];
                new_value := (new_offset / offset_max) * range;

                fvalue = Snap(clamp(new_value, fmin, fmax), fstep);
            }

            handle.offset[Axis.X] = (fvalue / range) * offset_max;
        }
    }

    state := GetState(handle);
    Apply(background, style.states[state].background);
    Apply(handle, style.states[state].handle);

    return slider, background, handle;
}

Scrollbar :: (parent : *Node, target : *Node, axis : Axis, style : *SliderStyle = null, location := #caller_location) -> background : *Node, handle : *Node {
    EnsureStyle(*style, "scrollbar");

    background, handle : *Node;

    background = GetNode(parent, location);
    {
        background.desired_size[axis] = SizeFill();
        background.desired_size[GetCrossAxis(axis)] = SizeFit();

        ScrollViewBehavior(background, target, xx (1 << axis));

        handle = GetNode(background, "handle");
        {
            ratio := target.layout_last_frame.size[axis] / target.layout_last_frame.children_size[axis];

            handle.desired_size[axis] = SizeFill(ratio);
            handle.desired_size[GetCrossAxis(axis)] = SizePx(style.handle_size);

            // offset = (scroll / scrollable) * offset_max
            // offset / offset_max = scroll / scrollable
            // => scroll = (offset / offset_max) * scrollable

            scrollable := target.layout_last_frame.size[axis] - target.layout_last_frame.children_size[axis];
            offset_max := background.layout_last_frame.size[axis] - handle.layout_last_frame.size[axis];

            // Allow the user to click on the background to interact with the scrollbar
            background.flags |= .Focusable;

            handle_result := ButtonBehavior(handle);

            if background.state_flags & .Focused && IsMouseButtonPressed(.Left) {
                SetMouseCapture(handle);
                SetMouseFocus(handle);
                handle_result.pressed = true;
                handle_result.held = true;

                mouse := GetMousePosition(background.window)[axis];
                new_offset := mouse - background.layout_last_frame.rect.xy[axis] - handle.layout_last_frame.size[axis] * 0.5;
                new_scroll := (new_offset / offset_max) * scrollable;

                SetContentScroll(target, axis, new_scroll);
            }

            if handle_result.pressed {
                context.omg.mouse_captured_node_value = .{};
                context.omg.mouse_captured_node_value[axis] = (target.scroll[axis] / scrollable) * offset_max;
            }

            if handle_result.held {
                handle.state_flags |= .Active;

                new_offset := GetMousePosition()[axis] - context.omg.mouse_captured_at[axis];
                new_offset += context.omg.mouse_captured_node_value[axis];
                new_scroll := (new_offset / offset_max) * scrollable;

                SetContentScroll(target, axis, new_scroll);
            }

            handle.offset[axis] = (target.scroll[axis] / scrollable) * offset_max;
        }
    }

    state := GetState(background.state_flags | handle.state_flags);
    Apply(background, style.states[state].background);

    state = GetState(handle.state_flags);
    Apply(handle, style.states[state].handle);

    return background, handle;
}

TextInputStateStyle :: struct {
    background : BoxStyle;
    text : TextStyle;
}

TextInputStyle :: struct {
    using _ : StateStyle(TextInputStateStyle);
    cursor : BoxStyle;
    selection : BoxStyle;
}

DrawTextInputText :: (node : *Node, clip_shape : *SDShape) {
    if !node.font || (node.text_color & 0xff) == 0 {
        return;
    }

    input := GetUserData(node.parent, TextInputData);
    if !input {
        DrawText(*node.window.draw_list, node.font, node.rect.xy, node.text_size, node.text, node.text_color, clip_shape);
        return;
    }

    sdf_range := node.font.sdf_range * node.text_size;

    selection_drawing := ifx node.parent.state_flags & .Active && input.selection != 0
        then DrawShape(*node.window.draw_list, null, .{});

    selection_position := node.rect.xy;
    cursor_position := node.rect.xy;
    iter := IterText(node);
    for iter {
        glyph_position := node.rect.xy + iter.pen + it.hori_bearing * iter.size;
        glyph_position += it.size * iter.size * 0.5;

        s := SDTexture(node.font.texture, it.texture_size * iter.size, it.uv_rect, .{sdf_range, -sdf_range});
        d := DrawShape(*node.window.draw_list, s, glyph_position);
        SetClipShape(d, clip_shape);
        SolidColor(d, node.text_color);

        if it_index == input.cursor {
            cursor_position += Vec2f.{iter.pen.x, iter.pen.y - iter.font.ascent * iter.size};
        }
        if it_index == input.cursor + input.selection {
            selection_position += Vec2f.{iter.pen.x, iter.pen.y - iter.font.ascent * iter.size};
        }
    }

    if input.cursor == input.buffer.count {
        cursor_position += Vec2f.{iter.pen.x, iter.pen.y - iter.font.ascent * iter.size};
    }
    if input.cursor + input.selection == input.buffer.count {
        selection_position += Vec2f.{iter.pen.x, iter.pen.y - iter.font.ascent * iter.size};
    }

    cursor_position.x = ceil(cursor_position.x);
    cursor_position.y = ceil(cursor_position.y);

    if node.parent.state_flags & .Active && (fmod_cycling(input.cursor_blink_time, 1) < 0.5 || input.cursor_blink_time > 5) {
        cursor_size := Vec2f.{1, node.rect.w - node.rect.y};

        d := DrawShape(*node.window.draw_list, Box(cursor_size), cursor_position + cursor_size * 0.5);
        SetClipShape(d, clip_shape);
        SolidColor(d, node.text_color);
    }

    if selection_drawing {
        selection_size := Vec2f.{abs(cursor_position.x - selection_position.x), node.rect.w - node.rect.y};
        selection_size.x = ceil(selection_size.x);
        selection_size.y = ceil(selection_size.y);

        selection_position = min(cursor_position, selection_position);
        selection_position.x = floor(selection_position.x);
        selection_position.y = floor(selection_position.y);

        selection_drawing.shape = Box(selection_size);
        selection_drawing.position = selection_position + selection_size * 0.5;
        SetClipShape(selection_drawing, clip_shape);
        SolidColor(selection_drawing, ColorU32(0.1, 0.2, 0.6, 0.5));
    }
}

TextInput :: (parent : *Node, style : *TextInputStyle = null, location := #caller_location) -> submitted : bool, *Node {
    EnsureStyle(*style, "text_input");

    input_field := GetNode(parent, location=location);
    {
        SetSize(input_field, SizeFill(), SizeFit());
        SetChildAlign(input_field, 0, 0.5);

        input, submitted, input_button := TextInputBehavior(input_field);

        text_node := GetNode(input_field, "text");
        {
            SetDraw(text_node, DrawTextInputText);

            text := EncodeStringAsUtf8(input.buffer ,, temp);
            SetText(text_node, text);

            state := GetState(input_field);
            Apply(input_field, style.states[state].background);
            Apply(text_node, style.states[state].text);

            if input_field.state_flags & .Active {
                cursor_position : Vec2f;

                is_selecting := context.omg.mouse_capturing_node == input_field;
                mouse := GetMousePosition(input_field.window);

                if is_selecting && mouse.x < text_node.layout_last_frame.rect.x {
                    SetCursor(input, 0, !input_button.pressed);
                }

                iter := IterText(text_node);
                for iter {
                    glyph_rect : Vec4f;
                    glyph_rect.xy = text_node.layout_last_frame.rect.xy + iter.pen - Vec2f.{0, iter.font.ascent * iter.size};
                    glyph_rect.zw = glyph_rect.xy + Vec2f.{it.hori_advance, iter.font.ascent + iter.font.descent} * iter.size;

                    if is_selecting && mouse.x >= glyph_rect.x && mouse.x < glyph_rect.z {
                        SetCursor(input, xx it_index, !input_button.pressed);
                    }

                    if it_index == input.cursor {
                        cursor_position = .{iter.pen.x, iter.pen.y - iter.font.ascent * iter.size};
                    }
                }

                if is_selecting && mouse.x >= text_node.layout_last_frame.rect.x + iter.pen.x {
                    SetCursor(input, xx input.buffer.count, !input_button.pressed);
                }

                if input.cursor == input.buffer.count {
                    cursor_position = .{iter.pen.x, iter.pen.y - iter.font.ascent * iter.size};
                }

                if text_node.layout_last_frame.rect.x + cursor_position.x < input_field.layout_last_frame.rect.x + input_field.padding.x {
                    input_field.scroll.x = ceil(-cursor_position.x);
                }

                if text_node.layout_last_frame.rect.x + cursor_position.x >= input_field.layout_last_frame.rect.z - input_field.padding.z {
                    input_field.scroll.x = floor(-cursor_position.x + input_field.layout_last_frame.size.x - input_field.padding.x - input_field.padding.z - 1);
                }

                input_field.scroll.x = clamp(input_field.scroll.x, -text_node.layout_last_frame.size.x, 0);
            } else if input_field.state_flags & .ActiveLastFrame {
                input_field.scroll.x = 0;
            }
        }

        return submitted, input_field;
    }
}

CheckmarkStyle :: struct {
    rounding := 1.0;
    thickness := 0.2;
    offset := Vec2f.{-0.2, 0};
    left_size := 0.5;
    right_size := 0.9;
    angle := PI * 0.17;

    background_color : RGBA8;
    border_color : RGBA8;
    border_size : float;
    border_inset : float;
    outer_shadow_blur : float;
    outer_shadow_offset : Vec2f;
    outer_shadow_color : RGBA8;
}

Apply :: inline (node : *Node, style : CheckmarkStyle) {
    node.background_color = style.background_color;
    node.border_color = style.border_color;
    node.border_size = style.border_size;
    node.border_inset = style.border_inset;
    node.outer_shadow_blur = style.outer_shadow_blur;
    node.outer_shadow_offset = style.outer_shadow_offset;
    node.outer_shadow_color = style.outer_shadow_color;
}

CheckboxStateStyle :: struct {
    background : BoxStyle;
    checkmark : CheckmarkStyle;
}

CheckboxStyle :: StateStyle(CheckboxStateStyle);

DrawCheckmark :: (node : *Node, clip_shape : *SDShape) {
    checkbox_style := GetUserData(node.parent, CheckboxStyle);
    if !checkbox_style {
        return;
    }

    has_background := (node.background_color & 0xff) > 0;
    has_border := (node.border_color & 0xff) > 0 && node.border_size > 0;
    has_shadow := (node.outer_shadow_color & 0xff) > 0;

    if !has_background && !has_border && !has_shadow {
        return;
    }

    position := Vec2f.{(node.rect.x + node.rect.z) * 0.5, node.rect.w};

    size := node.size.y;
    scale := size / 20.0;
    state := GetState(node.parent);
    using style := checkbox_style.states[state];

    left_height := size * checkmark.left_size;
    right_height := size * checkmark.right_size;
    thickness := size * checkmark.thickness;
    radiuses := Vec4f.{checkmark.rounding, checkmark.rounding, 2, 2} * scale;

    left := Box(thickness, left_height, radiuses);
    left = Transform(left, Rotate2D(-checkmark.angle) * Translate2D(0, -left_height * 0.5));

    right := Box(thickness, right_height, radiuses);
    right = Transform(right, Rotate2D(checkmark.angle) * Translate2D(0, -right_height * 0.5));

    shape := Union(left, right, 0.5 * scale);
    shape = Move(shape, size * 0.5 * checkmark.offset.x, -thickness * 0.5 + checkmark.offset.y * size);

    d := DrawShape(*node.window.draw_list, shape, position);

    if has_shadow {
        OuterShadow(d, node.outer_shadow_offset * scale, node.outer_shadow_blur * scale, node.outer_shadow_color);
    }
    if has_background {
        SolidColor(d, node.background_color);
    }
    if has_border {
        StrokeColor(d, node.border_color, node.border_size, node.border_inset);
    }

    SetClipShape(d, clip_shape);
}

Checkbox :: (parent : *Node, value : *bool, style : *CheckboxStyle = null, location := #caller_location) -> modified : bool, *Node {
    EnsureStyle(*style, "checkbox");

    node := GetNode(parent, location);
    {
        SetSize(node, SizePx(20), SizePx(20));

        SetUserData(node, style.*);

        button := ButtonBehavior(node);
        if button.released {
            value.* = !value.*;
        }

        state := GetState(node);
        Apply(node, style.states[state].background);

        if value.* {
            checkmark := GetNode(node, "text");
            SetDraw(checkmark, DrawCheckmark);
            SetSize(checkmark, SizeFill(), SizeFill());

            Apply(checkmark, style.states[state].checkmark);
        }

        return button.released, node;
    }
}
