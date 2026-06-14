IsHovered :: (node : *Node) -> bool {
    mouse := GetMousePosition(node.window);

    return IsInsideRect(mouse, node.layout_last_frame.clipped_rect);
}

ButtonResult :: struct {
    pressed : bool;
    double_clicked : bool;
    held : bool;
    released : bool;
}

ButtonBehavior :: (node : *Node) -> ButtonResult {
    node.flags |= .Focusable;

    if (IsMouseButtonReleased(.Left) || IsMouseButtonDown(.Left)) && context.omg.mouse_capturing_node == node {
        SetMouseCapture(node);
        SetMouseFocus(node);
    } else if node.state_flags & .Focused && IsMouseButtonPressed(.Left) {
        SetMouseCapture(node);
    }

    if context.omg.mouse_capturing_node == node {
        node.state_flags |= .Hot;
    }

    result : ButtonResult;
    if node.state_flags & .Hot {
        result.held = true;
        result.pressed = IsHovered(node) && IsMouseButtonPressed(.Left);
        result.double_clicked = IsHovered(node) && IsMouseButtonDoubleClicked(.Left);
        result.released = IsHovered(node) && IsMouseButtonReleased(.Left);
    }

    return result;
}

SetContentScroll :: inline (node : *Node, axis : Axis, value : float) {
    if axis == .X {
        SetContentScrollX(node, value);
    } else {
        SetContentScrollY(node, value);
    }
}

SetContentScrollX :: inline (node : *Node, value : float) {
    avail_scroll := node.layout_last_frame.size.x - node.padding.x - node.padding.z - node.layout_last_frame.children_size.x;
    node.scroll.x = clamp(value, avail_scroll, 0);
}

SetContentScrollY :: inline (node : *Node, value : float) {
    avail_scroll := node.layout_last_frame.size.y - node.padding.y - node.padding.w - node.layout_last_frame.children_size.y;
    node.scroll.y = clamp(value, avail_scroll, 0);
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

SetMouseCapture :: inline (node : *Node, node_value : Vec4f) {
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

ScreenToWindow :: (window : *Window, rect : Vec4f) -> Vec4f {
    wx, wy : s32;
    SDL_GetWindowPosition(window.sdl_window, *wx, *wy);

    return .{
        xy=rect.xy - Vec2f.{xx wx, xx wy},
        zw=rect.zw - Vec2f.{xx wx, xx wy},
    };
}

WindowToScreen :: (window : *Window, point : Vec2f) -> Vec2f {
    wx, wy : s32;
    SDL_GetWindowPosition(window.sdl_window, *wx, *wy);

    return point + Vec2f.{xx wx, xx wy};
}

WindowToScreen :: (window : *Window, rect : Vec4f) -> Vec4f {
    wx, wy : s32;
    SDL_GetWindowPosition(window.sdl_window, *wx, *wy);

    return .{
        xy=rect.xy + Vec2f.{xx wx, xx wy},
        zw=rect.zw + Vec2f.{xx wx, xx wy},
    };
}

FindMouseFocus :: (node : *Node) {
    omg := context.omg;
    mouse := GetMousePosition(node.window);

    if node.parent && IsInsideRect(mouse, node.layout_last_frame.clipped_rect) {
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
