Text :: (parent : *Node, fmt_str : string, args : ..Any, style : *TextStyle = null, location := #caller_location) -> *Node {
    EnsureStyle(*style, "text");

    node := GetNode(parent, location);
    SetText(node, tprint(fmt_str, ..args));
    SetSize(node, SizeFit(), SizeFit()); // Fit text
    SetBackgroundColor(node, 0, 0, 0, 0);
    SetBorderColor(node, 0, 0, 0, 0);

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
    handle_size : float;
}

// @Todo: unify slider and scrollbar
Slider :: (parent : *Node, value : *$T, min : T, max : T, step : T, style : *SliderStyle = null, location := #caller_location) -> background : *Node, handle : *Node {
    EnsureStyle(*style, "slider");

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
        SetSize(background, SizeFill(), SizeFit());

        handle = GetNode(background, "handle");
        {
            SetSize(handle, SizePx(style.handle_size), SizePx(style.handle_size));

            range := fmax - fmin;
            offset_max := background.layout_last_frame.size[Axis.X] - style.handle_size;

            // Allow the user to click on the background to interact with the scrollbar
            background.flags |= .Focusable;

            handle_result := ButtonBehavior(handle);

            if background.state_flags & .Focused && IsMouseButtonPressed(.Left) {
                SetMouseCapture(handle);
                SetMouseFocus(handle);
                handle_result.pressed = true;
                handle_result.held = true;

                mouse := GetMousePosition(background.window)[Axis.X];
                new_offset := mouse - background.layout_last_frame.rect.xy[Axis.X] - style.handle_size * 0.5;
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

    return background, handle;
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
        SetPadding(input_field, 5, 2);
        SetChildAlign(input_field, 0, 0.5);

        input, submitted, input_button := TextInputBehavior(input_field);

        if input_field.state_flags & .Active {
            input_field.border_color = ColorU32(0, 1, 0, 1);
        } else {
            input_field.border_color = ColorU32(0, 0, 0, 1);
        }

        text_node := GetNode(input_field, "text");
        {
            SetDraw(text_node, DrawTextInputText);

            SetBackgroundColor(text_node, 0, 0, 0, 0);
            SetBorderColor(text_node, 0, 0, 0, 0);

            text := EncodeStringAsUtf8(input.buffer ,, temp);
            SetText(text_node, text);

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
