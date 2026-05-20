Text :: (parent : *Node, font : *Font, size : float, text : string, location := #caller_location) -> *Node {
    node := GetNode(parent, location);
    SetText(node, font, size, text);
    SetSize(node, SizeFit(), SizeFit()); // Fit text
    SetBackgroundColor(node, 0, 0, 0, 0);
    SetBorderColor(node, 0, 0, 0, 0);

    return node;
}

Scrollbar :: (parent : *Node, target : *Node, axis : Axis, width := 10.0, location := #caller_location) -> background : *Node, handle : *Node {
    background, handle : *Node;

    background = GetNode(parent, location=location);
    {
        SetSize(background, SizePx(width), SizeFill());

        ScrollViewBehavior(background, target, xx (1 << axis));

        handle = GetNode(background, "handle");
        {
            ratio := target.layout_last_frame.size[axis] / target.layout_last_frame.children_size[axis];
            SetSize(handle, SizeFill(), SizeFill(ratio));

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
                new_offset := GetMousePosition()[axis] - context.omg.mouse_captured_at[axis];
                new_offset += context.omg.mouse_captured_node_value[axis];
                new_scroll := (new_offset / offset_max) * scrollable;

                SetContentScroll(target, axis, new_scroll);
            }

            handle.offset[axis] = (target.scroll[axis] / scrollable) * offset_max;
        }
    }

    return background, handle;
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
    }

    if input.cursor == input.buffer.count {
        cursor_position += Vec2f.{iter.pen.x, iter.pen.y - iter.font.ascent * iter.size};
    }

    draw_cursor := node.parent.state_flags & .Active && (fmod_cycling(input.cursor_blink_time, 1) < 0.5 || input.cursor_blink_time > 5);
    if draw_cursor {
        cursor_size := Vec2f.{1, node.rect.w - node.rect.y};
        cursor_position.x = ceil(cursor_position.x);
        cursor_position.y = ceil(cursor_position.y);
        cursor_position += cursor_size * 0.5;

        draw_cursor := DrawShape(*node.window.draw_list, Box(cursor_size), cursor_position);
        SetClipShape(draw_cursor, clip_shape);
        SolidColor(draw_cursor, node.text_color);
    }
}

TextInput :: (parent : *Node, location := #caller_location) -> *Node {
    input_field := GetNode(parent, location=location);
    {
        SetChildAlign(input_field, 0, 0.5);

        input := TextInputBehavior(input_field);

        if input_field.state_flags & .Active {
            input_field.border_color = ColorU32(0, 1, 0, 1);
        } else {
            input_field.border_color = ColorU32(0, 0, 0, 1);
        }

        text_node := GetNode(input_field, "text");
        {
            text_node.draw = DrawTextInputText;

            text := EncodeStringAsUtf8(input.buffer ,, temp);
            SetText(text_node, context.omg.fonts, 16, text);
            SetBackgroundColor(text_node, 0, 0, 0, 0);
            SetBorderColor(text_node, 0, 0, 0, 0);
        }
    }

    return input_field;
}

Slider :: (parent : *Node, value : *$T, min : T, max : T, step : T, handle_size := 10.0, height := 10.0, location := #caller_location) -> background : *Node, handle : *Node {
    fvalue := ifx value then cast(float, value.*);
    fmin := cast(float, min);
    fmax := cast(float, max);
    fstep := cast(float, step);

    defer if value {
        value.* = xx fvalue;
    }

    background, handle : *Node;

    background = GetNode(parent, location=location);
    {
        SetSize(background, SizeFill(), SizePx(height));

        handle = GetNode(background, "handle");
        {
            SetSize(handle, SizePx(handle_size), SizePx(handle_size));

            range := fmax - fmin;
            offset_max := background.layout_last_frame.size[Axis.X] - handle_size;

            // Allow the user to click on the background to interact with the scrollbar
            background.flags |= .Focusable;

            handle_result := ButtonBehavior(handle);

            if background.state_flags & .Focused && IsMouseButtonPressed(.Left) {
                SetMouseCapture(handle);
                SetMouseFocus(handle);
                handle_result.pressed = true;
                handle_result.held = true;

                mouse := GetMousePosition(background.window)[Axis.X];
                new_offset := mouse - background.layout_last_frame.rect.xy[Axis.X] - handle_size * 0.5;
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

    return background, handle;
}
