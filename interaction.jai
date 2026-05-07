IsHovered :: (node : *Node) -> bool {
    mouse := GetMousePosition(node.window);

    return IsInsideRect(mouse, node.layout_last_frame.clipped_rect);
}

ButtonBehavior :: (node : *Node) -> bool {
    omg := context.omg;

    node.flags |= .Focusable;

    if (IsMouseButtonReleased(.Left) || IsMouseButtonDown(.Left)) && omg.mouse_capturing_node == node {
        SetMouseCapture(node);
        SetMouseFocus(node);
    } else if node.state_flags & .Focused && IsMouseButtonDown(.Left) {
        SetMouseCapture(node);
    }

    if omg.mouse_capturing_node == node {
        node.state_flags |= .Active;
    }

    if node.state_flags & .Active {
        node.color = .{1,0,0,1};
    } else if node.state_flags & .Focused {
        node.color = .{0,1,0,1};
    }

    return node.state_flags & .Active && IsHovered(node) && IsMouseButtonReleased(.Left);
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
    context.omg.mouse_capturing_node = node;
    context.omg.mouse_captured_this_frame = true;
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
