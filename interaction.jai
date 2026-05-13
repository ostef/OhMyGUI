IsHovered :: (node : *Node) -> bool {
    mouse := GetMousePosition(node.window);

    return IsInsideRect(mouse, node.layout_last_frame.clipped_rect);
}

ButtonResult :: struct {
    pressed : bool;
    held : bool;
    released : bool;
}

ButtonBehavior :: (node : *Node) -> ButtonResult {
    omg := context.omg;

    node.flags |= .Focusable;

    if (IsMouseButtonReleased(.Left) || IsMouseButtonDown(.Left)) && omg.mouse_capturing_node == node {
        SetMouseCapture(node);
        SetMouseFocus(node);
    } else if node.state_flags & .Focused && IsMouseButtonPressed(.Left) {
        SetMouseCapture(node);
    }

    if omg.mouse_capturing_node == node {
        node.state_flags |= .Hot;
    }

    if node.state_flags & .Hot {
        SetBackgroundColor(node, 1, 0, 0, 1);
    } else if node.state_flags & .Focused {
        SetBackgroundColor(node, 0, 1, 0, 1);
    } else {
        SetBackgroundColor(node, 1, 1, 1, 1);
    }

    result : ButtonResult;
    if node.state_flags & .Hot {
        result.held = true;
        result.pressed = IsHovered(node) && IsMouseButtonPressed(.Left);
        result.released = IsHovered(node) && IsMouseButtonReleased(.Left);
    }

    return result;
}

TextInputData :: struct {
    buffer : [..]u32;
}

DestroyTextInputData :: (node : *Node, data : *void) {
    using _ := cast(*TextInputData, data);
    array_free(buffer);
}

GetTextInputResultUtf32 :: (node : *Node) -> []u32 {
    data := GetUserData(node, TextInputData, create=false);
    if !data {
        return .[];
    }

    return array_copy(data.buffer);
}

GetTextInputResult :: (node : *Node) -> string {
    data := GetUserData(node, TextInputData, create=false);
    if !data {
        return "";
    }

    return EncodeStringAsUtf8(data.buffer);
}

TextInputBehavior :: (node : *Node) -> *TextInputData {
    input, is_new := GetUserData(node, TextInputData, DestroyTextInputData);
    if is_new {
        input.buffer.allocator = context.omg.general_purpose_allocator;
    }

    should_deactivate := !(node.state_flags & .Focused) && IsMouseButtonPressed(.Left);
    should_deactivate |= IsKeyPressed(.Escape);

    button_result := ButtonBehavior(node);
    if !should_deactivate && (button_result.released || node.state_flags & .ActiveLastFrame) {
        node.state_flags |= .Active;
    }

    if node.state_flags & .Active {
        for context.omg.input.text {
            array_add(*input.buffer, it);
        }

        if IsKeyPressed(.Backspace) && input.buffer.count > 0 {
            pop(*input.buffer);
        }
    }

    return input;
}

SetContentScroll :: inline (node : *Node, axis : Axis, value : float) {
    if axis == .X {
        SetContentScrollX(node, value);
    } else {
        SetContentScrollY(node, value);
    }
}

SetContentScrollX :: inline (node : *Node, value : float) {
    node.scroll.x = value;

    avail_scroll := node.layout_last_frame.size.x - node.layout_last_frame.children_size.x;
    node.scroll.x = clamp(node.scroll.x, avail_scroll, 0);
}

SetContentScrollY :: inline (node : *Node, value : float) {
    node.scroll.y = value;

    avail_scroll := node.layout_last_frame.size.y - node.layout_last_frame.children_size.y;
    node.scroll.y = clamp(node.scroll.y, avail_scroll, 0);
}

ScrollBehavior :: (node : *Node) -> Vec2f {
    node.flags |= .Scrollable;

    if context.omg.scroll_focused_node == node {
        return GetMouseWheel();
    }

    return .{};
}

ScrollViewBehavior :: (node : *Node, axis : AxisFlags) {
    ScrollViewBehavior(node, node, axis);
}

ScrollViewBehavior :: (node : *Node, target : *Node, axis : AxisFlags) {
    scroll := ScrollBehavior(node);
    if axis & .X {
        SetContentScrollX(target, target.scroll.x + scroll.x);
    }

    if axis & .Y {
        SetContentScrollY(target, target.scroll.y + scroll.y);
    }
}

SetMouseFocus :: inline (node : *Node) {
    if context.omg.mouse_focused_node {
        context.omg.mouse_focused_node.state_flags &= ~.Focused;
    }

    context.omg.mouse_focused_node = node;

    if node {
        node.state_flags |= .Focused;
    }
}

SetScrollFocus :: inline (node : *Node) {
    context.omg.scroll_focused_node = node;
}

SetMouseCapture :: inline (node : *Node) {
    SetMouseCapture(node, .{});
}

SetMouseCapture :: inline (node : *Node, node_value : Vec2f) {
    if context.omg.mouse_capturing_node != node {
        context.omg.mouse_captured_at = GetMousePosition();
        context.omg.mouse_captured_node_value = node_value;
    }

    context.omg.mouse_capturing_node = node;
    context.omg.mouse_captured_this_frame = true;
}

ScreenToWindow :: (window : *Window, point : Vec2f) -> Vec2f {
    wx, wy : s32;
    SDL_GetWindowPosition(window.sdl_window, *wx, *wy);

    return point - Vec2f.{xx wx, xx wy};
}

WindowToScreen :: (window : *Window, point : Vec2f) -> Vec2f {
    wx, wy : s32;
    SDL_GetWindowPosition(window.sdl_window, *wx, *wy);

    return point + Vec2f.{xx wx, xx wy};
}

FindMouseFocus :: (node : *Node) {
    omg := context.omg;
    mouse := GetMousePosition(node.window);

    if node.parent && IsInsideRect(mouse, node.clipped_rect) {
        omg.mouse_is_over_node = true;
    }

    if IsInsideRect(mouse, node.clipped_rect) {
        omg.mouse_hovered_node = node;

        if !omg.mouse_capturing_node || omg.mouse_capturing_node == node {
            if node.flags & .Focusable {
                omg.mouse_focused_node = node;
            }
            if node.flags & .Scrollable {
                omg.scroll_focused_node = node;
            }
        }
    }

    for :Children node {
        FindMouseFocus(it);
    }
}
