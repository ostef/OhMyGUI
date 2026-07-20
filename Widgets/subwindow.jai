SubwindowPersistentData :: struct {
    id : ID;
    position : Vec2f;
    size : Vec2f;
    was_docked : bool;
}

GlobalSubwindowsData :: struct {
    entries : [..]SubwindowPersistentData;
}

GetSubwindowPersistentData :: (id : ID) -> *SubwindowPersistentData, is_new : bool {
    storage, new := AddGlobalUserData(GlobalSubwindowsData, DestroyGlobalSubwindowsData);
    if new {
        storage.entries.allocator = context.omg.general_purpose_allocator;
    }

    for * storage.entries {
        if it.id == id {
            return it, false;
        }
    }

    result := array_add(*storage.entries);
    result.id = id;

    return result, true;
}

DestroyGlobalSubwindowsData :: (node : *Node, data : *void) {
    using _ := cast(*GlobalSubwindowsData, data);
    array_reset(*entries);
}

SubwindowFlags :: enum_flags {
    NoTitleBar;
    NoClose;
    NoResize;
    NoMove;
    NoMoveFromBackground;

    NoPersistentStorage;

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
    cursor : PlatformCursorHandle;
}

SubwindowTitleBarStyle :: StateStyle(SubwindowTitleBarStateStyle);

SubwindowStyle :: struct {
    title_bar : SubwindowTitleBarStyle;
    background : BoxStyle;
    vertical_scrollbar : ScrollbarStyle;
    horizontal_scrollbar : ScrollbarStyle;
    resize_handle_size := 8.0;
    resize_handle_inset := -6.0;
    corner_resize_handle_size := 20.0;
}

SubwindowMoveBehavior :: (subwindow : *Node, node : *Node, avail_area : Vec4f, title_bar_size : Vec2f) {
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

        subwindow.offset = clamp(subwindow.offset, avail_area.xy, avail_area.zw - title_bar_size);
    }
}

SubwindowTitleBar :: (subwindow : *Node, parent : *Node, title : string, style : *SubwindowTitleBarStyle) -> *Node {
    node := GetNode(parent, "title_bar");
    {
        SetSize(node, SizeFill(), SizeFit());

        text := GetNode(node, "text");
        SetText(text, title);

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

SubwindowResizeBehavior :: (subwindow : *Node, handle : *Node, min_size : Vec2f, avail_area : Vec4f, direction : ResizeHandle) {
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
        context.omg.mouse_captured_node_value = WindowToScreen(subwindow.window, subwindow.rect);
    }

    if button.held {
        mouse_delta := GetMousePosition() - context.omg.mouse_captured_at;
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
            new_rect.x = clamp(new_rect.x + mouse_delta.x, avail_area.x, new_rect.z - min_size.x);
        }
        if to_modify.y {
            new_rect.y = clamp(new_rect.y + mouse_delta.y, avail_area.y, new_rect.w - min_size.y);
            new_rect.y = min(new_rect.y, avail_area.w - min_size.y); // Keep title bar visible
        }
        if to_modify.z {
            new_rect.z = clamp(new_rect.z + mouse_delta.x, new_rect.x + min_size.x, avail_area.z);
        }
        if to_modify.w {
            new_rect.w = clamp(new_rect.w + mouse_delta.y, new_rect.y + min_size.y, avail_area.w);
        }

        new_offset := new_rect.xy - subwindow.parent.rect.xy;
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
    SetLayout(title_and_content, .TopToBottom);

    resize_handles := GetNode(subwindow, "resize_handles");
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
    SetChildAlign(bottom, 0, 1);

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

    resize_handles_expand := Vec2f.{1,1} * max(-style.resize_handle_inset, 0);
    avail_area := subwindow.parent.rect;
    avail_area = InflateBounds(avail_area, Vec4f.{xy=resize_handles_expand,zw=resize_handles_expand});

    SubwindowResizeBehavior(subwindow, resize_t, min_size + resize_handles_expand * 2, avail_area, .Top);
    SubwindowResizeBehavior(subwindow, resize_b, min_size + resize_handles_expand * 2, avail_area, .Bottom);
    SubwindowResizeBehavior(subwindow, resize_l, min_size + resize_handles_expand * 2, avail_area, .Left);
    SubwindowResizeBehavior(subwindow, resize_r, min_size + resize_handles_expand * 2, avail_area, .Right);
    SubwindowResizeBehavior(subwindow, resize_tl, min_size + resize_handles_expand * 2, avail_area, .TopLeft);
    SubwindowResizeBehavior(subwindow, resize_tr, min_size + resize_handles_expand * 2, avail_area, .TopRight);
    SubwindowResizeBehavior(subwindow, resize_bl, min_size + resize_handles_expand * 2, avail_area, .BottomLeft);
    SubwindowResizeBehavior(subwindow, resize_br, min_size + resize_handles_expand * 2, avail_area, .BottomRight);

    resize_handles.desired_size = subwindow.desired_size;

    title_and_content.desired_size = subwindow.desired_size;
    title_and_content.desired_size.x.value -= resize_handles_expand.x * 2;
    title_and_content.desired_size.y.value -= resize_handles_expand.y * 2;
    title_and_content.offset = resize_handles_expand;

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

    resize_handles_expand := ifx !(flags & .NoResize) then Vec2f.{1,1} * max(-style.resize_handle_inset, 0);
    avail_area : Vec4f;
    title_bar_size : Vec2f;

    subwindow_id := GetID(str_id);

    persistent_data : *SubwindowPersistentData;
    is_new_persistent_data : bool;
    if !(flags & .NoPersistentStorage) {
        persistent_data, is_new_persistent_data = GetSubwindowPersistentData(subwindow_id);
    }

    content, subwindow : *Node;
    dock_node := GetSubwindowDockNode(subwindow_id);
    defer persistent_data.was_docked = dock_node != null;

    hscroll := (flags & .NoHorizontalScroll) == 0;
    vscroll := (flags & .NoVerticalScroll) == 0;
    hscrollbar := (flags & .NoHorizontalScrollbar) == 0 && (flags & .NoHorizontalScroll) == 0;
    vscrollbar := (flags & .NoVerticalScrollbar) == 0 && (flags & .NoVerticalScroll) == 0;
    content_parent : *Node;

    if !dock_node {
        defer if persistent_data {
            persistent_data.position = subwindow.offset;
            persistent_data.size = .{subwindow.desired_size.x.value, subwindow.desired_size.y.value};
        }

        subwindow=, is_new := GetPopupNode(window, subwindow_id, is_global_id=true);

        if is_new {
            if !persistent_data || is_new_persistent_data || persistent_data.was_docked {
                SetSize(subwindow, SizePx(initial_size.x), SizePx(initial_size.y));

                subwindow.desired_size.x.value += resize_handles_expand.x * 2;
                subwindow.desired_size.y.value += resize_handles_expand.y * 2;

                subwindow.offset -= resize_handles_expand;
            } else {
                SetSize(subwindow, SizePx(persistent_data.size.x), SizePx(persistent_data.size.y));
                subwindow.offset = persistent_data.position;
            }
        } else {
            SetSize(subwindow, SizePx(subwindow.size.x), SizePx(subwindow.size.y));
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

        avail_area = subwindow.parent.rect;
        if !(flags & .NoResize) {
            avail_area = InflateBounds(avail_area, Vec4f.{xy=resize_handles_expand,zw=resize_handles_expand});
        }

        title_bar := ifx !(flags & .NoTitleBar)
            then SubwindowTitleBar(subwindow, title_and_content, title, *style.title_bar);

        title_bar_size = ifx title_bar then title_bar.size;
        if title_bar && !(flags & .NoResize) {
            title_bar_size += resize_handles_expand * 2;
        }

        if title_bar && !(flags & .NoMove) {
            SubwindowMoveBehavior(subwindow, title_bar, avail_area, title_bar_size);
        }

        content_parent = title_and_content;

        Apply(title_and_content, style.background);

        subwindow.flags |= .NoClip;
        title_and_content.padding = .{};
        title_and_content.child_gap = .{};
    } else {
        content_parent = dock_node;

        Apply(content_parent, style.background);
    }

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

        if subwindow && !(flags & .NoMove) && !(flags & .NoMoveFromBackground) {
            SubwindowMoveBehavior(subwindow, content, avail_area, title_bar_size);
        }

        axes : AxisFlags;
        if hscroll {
            axes |= .X;
        }
        if vscroll {
            axes |= .Y;
        }

        ScrollViewBehavior(content, axes);

        if hscrollbar && content.children_size.x > content.size.x - content.padding.x - content.padding.z {
            Scrollbar(content_and_hscrollbar, content, .X, style=*style.horizontal_scrollbar);
        }
        if vscrollbar && content.children_size.y > content.size.y - content.padding.y - content.padding.w {
            Scrollbar(content_and_vscrollbar, content, .Y, style=*style.vertical_scrollbar);
        }
    }

    return content, subwindow;
}
