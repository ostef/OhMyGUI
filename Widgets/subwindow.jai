SubwindowFlags :: enum_flags {
    NoTitleBar;
    NoClose;
    NoResize;
    NoMove;
    NoMoveFromBackground;

    NoVerticalScrollbar;
    NoHorizontalScrollbar;

    NoVerticalScroll;
    NoHorizontalScroll;

    NoScrollbar :: NoVerticalScrollbar | NoHorizontalScrollbar;
    NoScroll :: NoVerticalScroll | NoHorizontalScroll;
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
    vertical_scrollbar : SliderStyle;
    horizontal_scrollbar : SliderStyle;
    resize_handle_size := 8.0;
    corner_resize_handle_size := 12.0;
}

SubwindowMoveBehavior :: (subwindow : *Node, node : *Node, title_bar_size : Vec2f) {
    interaction := ButtonBehavior(node);

    if node.state_flags & .Focused && IsMouseButtonPressed(.Left) {
        SetMouseCapture(node);
        SetMouseFocus(node);

        interaction.pressed = true;
        interaction.held = true;
    }

    if interaction.pressed {
        context.omg.mouse_captured_node_value = .{xy=subwindow.offset};
    }

    if interaction.held {
        mouse_delta := GetMousePosition() - context.omg.mouse_captured_at;
        original_offset := context.omg.mouse_captured_node_value.xy;
        subwindow.offset = original_offset + mouse_delta;

        avail_area := subwindow.parent.layout_last_frame.size;
        subwindow.offset = clamp(subwindow.offset, .{0, 0}, avail_area - title_bar_size);
    }
}

SubwindowTitleBar :: (subwindow : *Node, parent : *Node, title : string, flags : SubwindowFlags, style : *SubwindowTitleBarStyle) -> *Node {
    node := GetNode(parent, "title_bar");
    {
        SetSize(node, SizeFill(), SizeFit());

        text := GetNode(node, "text");
        SetText(text, title);

        if !(flags & .NoMove) {
            SubwindowMoveBehavior(subwindow, node, node.layout_last_frame.size);
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

ResizeHandle :: enum {
    Top;
    Bottom;
    Left;
    Right;
    TopLeft;
    TopRight;
    BottomLeft;
    BottomRight;
}

SubwindowResize :: (subwindow : *Node, handle : *Node, min_size : Vec2f, direction : ResizeHandle) {
    Cursors :: SystemCursor.[
        .ResizeVertical,
        .ResizeVertical,
        .ResizeHorizontal,
        .ResizeHorizontal,
        .ResizeNWSE,
        .ResizeNESW,
        .ResizeNESW,
        .ResizeNWSE,
    ];

    button := ButtonBehavior(handle);

    if handle.state_flags & .Focused && IsMouseButtonPressed(.Left) {
        SetMouseCapture(handle);
        SetMouseFocus(handle);

        button.pressed = true;
        button.held = true;
    }

    if button.pressed {
        context.omg.mouse_captured_node_value = WindowToScreen(subwindow.window, subwindow.layout_last_frame.rect);
    }

    if button.held {
        mouse_delta := GetMousePosition() - context.omg.mouse_captured_at;
        parent_rect := subwindow.parent.layout_last_frame.rect;
        new_rect := ScreenToWindow(subwindow.window, context.omg.mouse_captured_node_value);
        to_modify : struct {x: bool; y: bool; z: bool; w: bool;}

        if #complete direction == {
        case .Top; to_modify.y = true;
        case .Bottom; to_modify.w = true;
        case .Left; to_modify.x = true;
        case .Right; to_modify.z = true;
        case .TopLeft; to_modify.x = true; to_modify.y = true;
        case .TopRight; to_modify.z = true; to_modify.y = true;
        case .BottomLeft; to_modify.x = true; to_modify.w = true;
        case .BottomRight; to_modify.z = true; to_modify.w = true;
        }

        if to_modify.x {
            new_rect.x = clamp(new_rect.x + mouse_delta.x, parent_rect.x, new_rect.z - min_size.x);
        }
        if to_modify.y {
            new_rect.y = clamp(new_rect.y + mouse_delta.y, parent_rect.y, new_rect.w - min_size.y);
            new_rect.y = min(new_rect.y, parent_rect.w - min_size.y); // Keep title bar visible
        }
        if to_modify.z {
            new_rect.z = clamp(new_rect.z + mouse_delta.x, new_rect.x + min_size.x, parent_rect.z);
        }
        if to_modify.w {
            new_rect.w = clamp(new_rect.w + mouse_delta.y, new_rect.y + min_size.y, parent_rect.w);
        }

        new_offset := new_rect.xy - parent_rect.xy;
        new_size := new_rect.zw - new_rect.xy;

        subwindow.offset = new_offset;
        SetSize(subwindow, SizePx(new_size.x), SizePx(new_size.y));
    }

    if HasCursorControl(handle) {
        SetCursor(GetSystemCursor(Cursors[direction]));
    }
}

SubwindowResizeHandles :: (subwindow : *Node, min_size : Vec2f, style : *SubwindowStyle) -> *Node {
    SetLayout(subwindow, .None);

    title_and_content := GetNode(subwindow, "title_and_content");
    SetSize(title_and_content, SizeFill(), SizeFill());
    SetLayout(title_and_content, .TopToBottom);

    resize_handles := GetNode(subwindow, "resize_handles");
    SetSize(resize_handles, SizeFill(), SizeFill());
    SetLayout(resize_handles, .TopToBottom);

    top := GetNode(resize_handles, "top");
    SetSize(top, SizeFill(), SizeFit());
    SetLayout(top, .LeftToRight);

    middle := GetNode(resize_handles, "middle");
    SetSize(middle, SizeFill(), SizeFill());
    SetLayout(middle, .LeftToRight);

    bottom := GetNode(resize_handles, "bottom");
    SetSize(bottom, SizeFill(), SizeFit());
    SetLayout(bottom, .LeftToRight);

    resize_tl := GetNode(top, "resize_tl");
    SetSize(resize_tl, SizePx(style.corner_resize_handle_size), SizePx(style.corner_resize_handle_size));
    resize_t  := GetNode(top, "resize_t");
    SetSize(resize_t, SizeFill(), SizePx(style.resize_handle_size));
    resize_tr := GetNode(top, "resize_tr");
    SetSize(resize_tr, SizePx(style.corner_resize_handle_size), SizePx(style.corner_resize_handle_size));

    resize_l := GetNode(middle, "resize_l");
    SetSize(resize_l, SizePx(style.resize_handle_size), SizeFill());
    center_fill := GetNode(middle, "center");
    SetSize(center_fill, SizeFill(), SizeFill());
    resize_r := GetNode(middle, "resize_r");
    SetSize(resize_r, SizePx(style.resize_handle_size), SizeFill());

    resize_bl := GetNode(bottom, "resize_bl");
    SetSize(resize_bl, SizePx(style.corner_resize_handle_size), SizePx(style.corner_resize_handle_size));
    resize_b  := GetNode(bottom, "resize_b");
    SetSize(resize_b, SizeFill(), SizePx(style.resize_handle_size));
    resize_br := GetNode(bottom, "resize_br");
    SetSize(resize_br, SizePx(style.corner_resize_handle_size), SizePx(style.corner_resize_handle_size));

    SubwindowResize(subwindow, resize_t, min_size, .Top);
    SubwindowResize(subwindow, resize_b, min_size, .Bottom);
    SubwindowResize(subwindow, resize_l, min_size, .Left);
    SubwindowResize(subwindow, resize_r, min_size, .Right);
    SubwindowResize(subwindow, resize_tl, min_size, .TopLeft);
    SubwindowResize(subwindow, resize_tr, min_size, .TopRight);
    SubwindowResize(subwindow, resize_bl, min_size, .BottomLeft);
    SubwindowResize(subwindow, resize_br, min_size, .BottomRight);

    return title_and_content;
}

Subwindow :: (
    window : *Window,
    title : string,
    str_id : string,
    initial_size : Vec2f,
    min_size : Vec2f = .{32,32},
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

        subwindow.flags |= .Focusable | .Scrollable; // Prevent the mouse from getting used through the window

        // Bring forward if any element inside the window is pressed
        if IsMouseButtonPressed(.Left) && IsInTree(context.omg.mouse_hovered_node, subwindow) {
            BringForward(subwindow);
        }

        title_and_content := ifx flags & .NoResize
            then subwindow
            else SubwindowResizeHandles(subwindow, min_size, style);

        title_bar : *Node;
        if !(flags & .NoTitleBar) {
            title_bar = SubwindowTitleBar(subwindow, title_and_content, title, flags, *style.title_bar);
        }

        hscroll := (flags & .NoHorizontalScroll) == 0;
        vscroll := (flags & .NoVerticalScroll) == 0;
        hscrollbar := (flags & .NoHorizontalScrollbar) == 0 && (flags & .NoHorizontalScroll) == 0;
        vscrollbar := (flags & .NoVerticalScrollbar) == 0 && (flags & .NoVerticalScroll) == 0;

        content_parent := title_and_content;
        content_and_hscrollbar, content_and_vscrollbar : *Node;
        if hscrollbar {
            content_and_hscrollbar = GetNode(content_parent, "content_and_hscrollbar");
            SetLayout(content_and_hscrollbar, .TopToBottom);
            SetSize(content_and_hscrollbar, SizeFill(), SizeFill());
            content_parent = content_and_hscrollbar;
        }

        if vscrollbar {
            content_and_vscrollbar = GetNode(content_parent, "content_and_vscrollbar");
            SetLayout(content_and_vscrollbar, .LeftToRight);
            SetSize(content_and_vscrollbar, SizeFill(), SizeFill());
            content_parent = content_and_vscrollbar;
        }

        content = GetNode(content_parent, "content");
        {
            SetSize(content, SizeFill(), SizeFill());
            SetLayout(content, .TopToBottom);

            content.padding = style.background.padding;
            content.child_gap = style.background.child_gap;

            if !(flags & .NoMove) && !(flags & .NoMoveFromBackground) {
                SubwindowMoveBehavior(subwindow, content, ifx title_bar then title_bar.layout_last_frame.size);
            }

            axes : AxisFlags;
            if hscroll {
                axes |= .X;
            }
            if vscroll {
                axes |= .Y;
            }
            ScrollViewBehavior(content, axes);

            if hscrollbar && content.layout_last_frame.children_size.x > content.layout_last_frame.size.x - content.padding.x - content.padding.z {
                Scrollbar(content_and_hscrollbar, content, .X, style=*style.horizontal_scrollbar);
            }
            if vscrollbar && content.layout_last_frame.children_size.y > content.layout_last_frame.size.y - content.padding.y - content.padding.w {
                Scrollbar(content_and_vscrollbar, content, .Y, style=*style.vertical_scrollbar);
            }
        }

        Apply(subwindow, style.background);
        subwindow.padding = .{};
        subwindow.child_gap = .{};
    }

    return content, subwindow;
}
