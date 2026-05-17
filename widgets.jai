Text :: (parent : *Node, font : *Font, size : float, text : string, location := #caller_location) -> *Node {
    node := GetNode(parent, location);
    SetText(node, font, size, text);

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

TextInput :: (parent : *Node, location := #caller_location) -> *Node {
    input_field := GetNode(parent, location=location);
    {
        SetChildAlign(input_field, 0, 0.5);

        input := TextInputBehavior(input_field);

        if input_field.state_flags & .Active {
            input_field.border_color = ColorU32(0, 1, 0, 1);
            input_field.border_size = 4;
            input_field.border_inset = -4;
        } else {
            input_field.border_color = ColorU32(0, 0, 0, 1);
            input_field.border_size = 1;
            input_field.border_inset = 0;
        }

        text_node := GetNode(input_field, "text");
        text := EncodeStringAsUtf8(input.buffer ,, temp);
        SetText(text_node, context.omg.fonts, 16, text);
    }

    return input_field;
}
