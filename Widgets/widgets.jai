#load "buttons.jai";
#load "text_input.jai";
#load "sliders.jai";
#load "menus.jai";
#load "subwindow.jai";
#load "color_picker.jai";
#load "combo.jai";
#load "tables.jai";
#load "tree.jai";

LabelAndContentStyle :: struct {
    padding : Vec4b;
    child_gap : Vec2b;
    child_align := Vec2f.{0,0.5};
    text : TextStyle;
    text_fill := 0.35;
}

LabelAndContent :: (parent : *Node, label : string, style : *LabelAndContentStyle = null, location := #caller_location) -> *Node {
    EnsureStyle(*style, "label_and_content");

    node := GetNode(parent, location);
    SetSize(node, SizeFill(), SizeFit());
    SetChildAlign(node, style.child_align);
    SetLayout(node, .LeftToRight);
    SetPadding(node, style.padding);

    text := Text(node, "%", label, style=*style.text);
    SetSize(text, SizeFill(style.text_fill), SizeFit());
    SetLayout(text, .LeftToRight);

    content := GetNode(node);
    SetSize(content, SizeFill(1 - style.text_fill), SizeFit());
    SetLayout(content, .LeftToRight);
    SetChildGap(content, style.child_gap);

    return content;
}

Image :: (parent : *Node, image : TextureHandle, width : u32, height : u32, uv_bounds : Vec4f = .{0,0,1,1}, location := #caller_location) -> *Node {
    node := GetNode(parent, location);
    SetImage(node, image, uv_bounds);
    SetSize(node, SizePx(xx width), SizePx(xx height));
    SetBackgroundColor(node, 0xffffffff);

    return node;
}

Text :: (parent : *Node, fmt_str : string, args : ..Any, style : *TextStyle = null, location := #caller_location) -> *Node {
    EnsureStyle(*style, "text");

    node := GetNode(parent, location);
    SetText(node, tprint(fmt_str, ..args));
    SetSize(node, SizeFit(), SizeFit()); // Fit text

    Apply(node, style);

    return node;
}

ClickableTextStateStyle :: struct {
    text : TextStyle;
    cursor : PlatformCursorHandle;
}

ClickableTextStyle :: StateStyle(ClickableTextStateStyle);

ClickableText :: (parent : *Node, fmt_str : string, args : ..Any, style : *ClickableTextStyle = null, location := #caller_location) -> clicked : bool, double_clicked : bool, *Node {
    EnsureStyle(*style, "clickable_text");

    node := GetNode(parent, location);
    SetText(node, tprint(fmt_str, ..args));
    SetSize(node, SizeFit(), SizeFit()); // Fit text

    button := ButtonBehavior(node);

    state := GetState(node);
    Apply(node, style.states[state].text);
    if HasCursorControl(node) {
        SetCursor(style.states[state].cursor);
    }

    return button.released, button.double_clicked, node;
}

Separator :: (parent : *Node, space := 25.0, width := 1.0, style : *BoxStyle = null, location := #caller_location) -> *Node {
    if parent.child_layout_mode == .TopToBottom || parent.child_layout_mode == .BottomToTop {
        return HorizontalSeparator(parent, space, width, style, location);
    } else {
        return VerticalSeparator(parent, space, width, style, location);
    }
}

HorizontalSeparator :: (parent : *Node, space := 25.0, width := 1.0, style : *BoxStyle = null, location := #caller_location) -> *Node {
    EnsureStyle(*style, "separator");

    node := GetNode(parent, location);
    SetSize(node, SizeFill(), SizePx(space));
    SetChildAlign(node, 0.5, 0.5);

    separator := GetNode(node);
    SetSize(separator, SizeFill(), SizePx(width));

    Apply(separator, style);

    return node;
}

VerticalSeparator :: (parent : *Node, space := 25.0, width := 1.0, style : *BoxStyle = null, location := #caller_location) -> *Node {
    EnsureStyle(*style, "separator");

    node := GetNode(parent, location);
    SetSize(node, SizePx(space), SizeFill());
    SetChildAlign(node, 0.5, 0.5);

    separator := GetNode(node);
    SetSize(separator, SizePx(width), SizeFill());

    Apply(separator, style);


    return node;
}

Tooltip :: (window : *Window = null) -> *Node {
    if !window {
        window = GetMouseHoveredWindow();
        if !window {
            return null;
        }
    }

    style := GetStyle("tooltip", TooltipStyle);
    mouse_pos := GetMousePosition(window);

    node := GetPopupNode(window, "tooltip");
    {
        BringForward(node);

        SetSize(node, SizeFit(), SizeFit());
        node.offset = mouse_pos + .{16, 16};

        Apply(node, style.background);
    }

    return node;
}

TooltipStyle :: struct {
    background : BoxStyle;
    text : TextStyle;
}

Tooltip :: (fmt_str : string, args : ..Any, window : *Window = null) -> *Node {
    tooltip := Tooltip(window);
    if !tooltip {
        return null;
    }

    style := GetStyle("tooltip", TooltipStyle);

    Text(tooltip, fmt_str, ..args, style=*style.text);

    return tooltip;
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

SetContentScroll :: inline (node : *Node, axis : Axis, value : float) {
    if axis == .X {
        SetContentScrollX(node, value);
    } else {
        SetContentScrollY(node, value);
    }
}

SetContentScrollX :: inline (node : *Node, value : float) {
    avail_scroll := node.size.x - node.padding.x - node.padding.z - node.children_size.x;
    node.scroll.x = clamp(value, avail_scroll, 0);
}

SetContentScrollY :: inline (node : *Node, value : float) {
    avail_scroll := node.size.y - node.padding.y - node.padding.w - node.children_size.y;
    node.scroll.y = clamp(value, avail_scroll, 0);
}

ProgressBarStyle :: struct {
    height : float;
    background : BoxStyle;
    fill : BoxStyle;
}

ProgressBar :: (parent : *Node, value : float, style : *ProgressBarStyle = null, location := #caller_location) -> *Node {
    EnsureStyle(*style, "progress_bar");

    node := GetNode(parent, location);
    {
        SetLayout(node, .None);
        SetSize(node, SizeFill(), SizePx(style.height));

        Apply(node, style.background);

        fill := GetNode(node);
        SetSize(fill, SizeFill(value), SizeFill());

        Apply(fill, style.fill);
    }

    return node;
}
