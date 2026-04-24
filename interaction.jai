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

SetMouseInteraction :: inline (node : *Node) {
    context.omg.mouse_interacting_node = node;
    context.omg.interacted_this_frame = true;
}

FindMouseFocus :: (node : *Node, window : *Window) {
    omg := context.omg;
    mouse := GetMousePosition(window);

    if !omg.mouse_is_over_node && node.parent && IsInsideRect(mouse, node.clipped_rect) {
        omg.mouse_is_over_node = true;
    }

    if IsInsideRect(mouse, node.clipped_rect) {
        omg.mouse_hovered_node = node;

        if !omg.mouse_interacting_node || omg.mouse_interacting_node == node {
            if node.flags & .Focusable {
                SetMouseFocus(node);
            }
            if node.flags & .Scrollable {
                SetScrollFocus(node);
            }
        }
    }

    for :Children node {
        FindMouseFocus(it, window);
    }
}

