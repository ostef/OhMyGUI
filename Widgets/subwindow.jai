SubwindowFlags :: enum_flags {
    NoTitleBar;
    NoClose;
    NoResize;
    NoMove;
}

SubwindowTitleBarStateStyle :: struct {
    background : BoxStyle;
    text : TextStyle;
    text_align := Vec2f.{0, 0.5};
    cursor : *Cursor;
}

SubwindowTitleBarStyle :: StateStyle(SubwindowTitleBarStateStyle);

SubwindowStyle :: struct {
    title_bar : SubwindowTitleBarStyle;
    background : BoxStyle;
    resize_handle_size := 2.0;
}

SubwindowTitleBar :: (subwindow : *Node, parent : *Node, title : string, flags : SubwindowFlags, style : *SubwindowTitleBarStyle) -> *Node {
    node := GetNode(parent, "title_bar");
    {
        SetSize(node, SizeFill(), SizeFit());

        text := GetNode(node, "text");
        SetText(text, title);

        title_button : ButtonResult;
        if !(flags & .NoMove) {
            title_button = ButtonBehavior(node);
        }

        if node.state_flags & .Focused && IsMouseButtonPressed(.Left) {
            SetMouseCapture(node);
            SetMouseFocus(node);

            title_button.pressed = true;
            title_button.held = true;
        }

        if title_button.pressed {
            context.omg.mouse_captured_node_value = subwindow.offset;
        }

        if title_button.held {
            mouse_delta := GetMousePosition() - context.omg.mouse_captured_at;
            original_offset := context.omg.mouse_captured_node_value;
            subwindow.offset = original_offset + mouse_delta;

            title_bar_size := node.layout_last_frame.size;
            avail_area := subwindow.parent.layout_last_frame.size;
            subwindow.offset = clamp(subwindow.offset, .{0, 0}, avail_area - title_bar_size);
        }

        state := GetState(node);
        Apply(node, style.states[state].background);
        Apply(text, style.states[state].text);
        SetChildAlign(node, style.states[state].text_align);

        if HasCursorControl(node) {
            SetCursor(style.states[state].cursor);
        }
    }

    return node;
}

SubwindowResizeHandles :: (subwindow : *Node, style : *SubwindowStyle) -> *Node {
    top := GetNode(subwindow, "top");
    SetSize(top, SizeFill(), SizeFit());
    SetLayout(top, .LeftToRight);
    middle := GetNode(subwindow, "middle");
    SetSize(middle, SizeFill(), SizeFill());
    SetLayout(middle, .LeftToRight);
    bottom := GetNode(subwindow, "bottom");
    SetSize(bottom, SizeFill(), SizeFit());
    SetLayout(bottom, .LeftToRight);

    resize_tl := GetNode(top, "resize_tl");
    SetSize(resize_tl, SizePx(style.resize_handle_size), SizePx(style.resize_handle_size));
    resize_t  := GetNode(top, "resize_t");
    SetSize(resize_t, SizeFill(), SizePx(style.resize_handle_size));
    resize_tr := GetNode(top, "resize_tr");
    SetSize(resize_tr, SizePx(style.resize_handle_size), SizePx(style.resize_handle_size));

    resize_l := GetNode(middle, "resize_l");
    SetSize(resize_l, SizePx(style.resize_handle_size), SizeFill());

    title_and_content := GetNode(middle, "title_and_content");
    SetSize(title_and_content, SizeFill(), SizeFill());
    SetLayout(title_and_content, .TopToBottom);

    resize_r := GetNode(middle, "resize_r");
    SetSize(resize_r, SizePx(style.resize_handle_size), SizeFill());

    resize_bl := GetNode(bottom, "resize_bl");
    SetSize(resize_bl, SizePx(style.resize_handle_size), SizePx(style.resize_handle_size));
    resize_b  := GetNode(bottom, "resize_b");
    SetSize(resize_b, SizeFill(), SizePx(style.resize_handle_size));
    resize_br := GetNode(bottom, "resize_br");
    SetSize(resize_br, SizePx(style.resize_handle_size), SizePx(style.resize_handle_size));

    return title_and_content;
}

Subwindow :: (
    window : *Window,
    title : string,
    str_id : string,
    initial_size : Vec2f,
    opened : *bool = null,
    flags : SubwindowFlags = 0,
    style : *SubwindowStyle = null
) -> content : *Node, subwindow : *Node {
    EnsureStyle(*style, "subwindow");

    content, subwindow : *Node;
    subwindow=, is_new := GetPopupNode(window, str_id);
    {
        if is_new {
            SetSize(subwindow, SizePx(initial_size.x), SizePx(initial_size.y));
        } else {
            SetSize(subwindow, SizePx(subwindow.layout_last_frame.size.x), SizePx(subwindow.layout_last_frame.size.y));
        }

        SetLayout(subwindow, .TopToBottom);

        subwindow.flags |= .Focusable;

        // Bring forward if any element inside the window is pressed
        if IsMouseButtonPressed(.Left) && IsInTree(context.omg.mouse_hovered_node, subwindow) {
            BringForward(subwindow);
        }

        title_and_content := ifx flags & .NoResize
            then subwindow
            else SubwindowResizeHandles(subwindow, style);

        if !(flags & .NoTitleBar) {
            SubwindowTitleBar(subwindow, title_and_content, title, flags, *style.title_bar);
        }

        content = GetNode(title_and_content, "content");
        {
            SetSize(content, SizeFill(), SizeFill());
        }

        Apply(subwindow, style.background);
    }

    return content, subwindow;
}
