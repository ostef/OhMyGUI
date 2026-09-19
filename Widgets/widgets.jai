#load "buttons.jai";
#load "text_input.jai";
#load "sliders.jai";
#load "menus.jai";
#load "subwindow.jai";
#load "color_picker.jai";
#load "combo.jai";
#load "tables.jai";
#load "tree.jai";
#load "dock_space.jai";
#load "tabs.jai";

LabelAndContentStyle :: struct {
    padding : Vec4b;
    child_gap : Vec2b;
    child_align := Vec2f.{0,0.5};
    text : TextStyle;
    text_fill := 0.35;
}

/**
 * @brief Container widget for label followed by content.
 */
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

/**
 * @brief Image widget.
 */
Image :: (parent : *Node, image : TextureHandle, width : u32, height : u32, uv_bounds : Vec4f = .{0,0,1,1}, location := #caller_location) -> *Node {
    node := GetNode(parent, location);
    SetImage(node, image, uv_bounds);
    SetSize(node, SizePx(xx width), SizePx(xx height));
    SetBackgroundColor(node, 0xffffffff);

    return node;
}

/**
 * @brief Text widget with string formatting.
 */
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

/**
 * @brief Clickable text widget with string formatting.
 */
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

SeparatorStyle :: struct {
    color_start : RGBA8;
    color_end : RGBA8;
    thickness := 1.0;
    spacing := 25.0;
    padding : Vec4b;
    text_gap : s8 = 8;
    text_padding := 12.0;
    text_offset := 10.0;
    text_align := 0.0;
    text : TextStyle;
}

/**
 * @brief Separator line. Horizontal or vertical depending on the parent layout.
 */
Separator :: (parent : *Node, style : *SeparatorStyle = null, location := #caller_location) -> *Node {
    if parent.child_layout_mode == .TopToBottom || parent.child_layout_mode == .BottomToTop {
        return HorizontalSeparator(parent, style, location);
    } else {
        return VerticalSeparator(parent, style, location);
    }
}

/**
 * @brief Horizontal separator line.
 */
HorizontalSeparator :: (parent : *Node, style : *SeparatorStyle = null, location := #caller_location) -> *Node {
    EnsureStyle(*style, "separator");

    node := GetNode(parent, location);
    SetSize(node, SizeFill(), SizePx(style.spacing));
    SetChildAlign(node, 0.5, 0.5);
    SetPadding(node, style.padding);

    separator := GetNode(node);
    SetSize(separator, SizeFill(), SizePx(style.thickness));
    SetBackgroundColors(separator, style.color_start, style.color_end, style.color_start, style.color_end);

    return node;
}

/**
 * @brief Horizontal separator line with formatted text.
 */
HorizontalSeparatorText :: (parent : *Node, fmt_str : string, args : ..Any, style : *SeparatorStyle = null, location := #caller_location) -> *Node {
    EnsureStyle(*style, "separator");

    node := GetNode(parent, location);
    SetSize(node, SizeFill(), SizePx(style.spacing));
    SetChildAlign(node, 0.5, 0.5);
    SetChildGap(node, style.text_gap, 0);
    SetPadding(node, style.padding);
    SetLayout(node, .LeftToRight);

    if style.text_align > 0 || style.text_offset > 0 {
        separator := GetNode(node);
        SetSize(separator, SizeFill(clamp(style.text_align, 0, 1)), SizePx(style.thickness));
        SetMinWidth(separator, style.text_offset);
        SetBackgroundColors(separator, style.color_start, style.color_end, style.color_start, style.color_end);
    }

    Text(node, fmt_str, ..args, style=*style.text);

    if style.text_align < 1 {
        separator := GetNode(node);
        SetSize(separator, SizeFill(max(1 - style.text_align, 0)), SizePx(style.thickness));
        SetBackgroundColors(separator, style.color_start, style.color_end, style.color_start, style.color_end);
    }

    return node;
}

/**
 * @brief Vertical separator line.
 */
VerticalSeparator :: (parent : *Node, style : *SeparatorStyle = null, location := #caller_location) -> *Node {
    EnsureStyle(*style, "separator");

    node := GetNode(parent, location);
    SetSize(node, SizePx(style.spacing), SizeFill());
    SetChildAlign(node, 0.5, 0.5);
    SetPadding(node, style.padding);

    separator := GetNode(node);
    SetSize(separator, SizePx(style.thickness), SizeFill());
    SetBackgroundColors(separator, style.color_start, style.color_start, style.color_end, style.color_end);

    return node;
}

/**
 * @brief Tooltip widget over all the other elements.
 */
Tooltip :: (window : *Window = null) -> *Node {
    if !window {
        window = GetMouseFocusedWindow();
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

/**
 * @brief Tooltip widget with text contents.
 */
Tooltip :: (fmt_str : string, args : ..Any, window : *Window = null) -> *Node {
    tooltip := Tooltip(window);
    if !tooltip {
        return null;
    }

    style := GetStyle("tooltip", TooltipStyle);
    Text(tooltip, fmt_str, ..args, style=*style.text);

    return tooltip;
}

/**
 * @brief Show a tooltip widget when the Node has been hovered for a certain amount of time.
 */
FocusTooltip :: (node : *Node, min_focus_time := 0.5) -> *Node {
    if IsAnyMouseButtonDown() {
        return null;
    }

    if context.omg.mouse_focused_node == node && context.omg.mouse_focus_time >= min_focus_time {
        return Tooltip(node.window);
    }

    return null;
}

/**
 * @brief Show a tooltip widget with text when the Node has been hovered for a certain amount of time.
 */
FocusTooltip :: (node : *Node, fmt_str : string, args : ..Any, min_focus_time := 0.5) -> *Node {
    tooltip := FocusTooltip(node, min_focus_time);
    if !tooltip {
        return null;
    }

    style := GetStyle("tooltip", TooltipStyle);
    Text(tooltip, fmt_str, ..args, style=*style.text);

    return tooltip;
}

/**
 * @brief Capture mouse wheel for a Node.
 */
ScrollBehavior :: (node : *Node) -> Vec2f {
    node.flags |= .Scrollable;

    if context.omg.scroll_focused_node == node {
        return GetMouseWheel();
    }

    return .{};
}

/**
 * @brief Perform mouse wheel scroll interaction logic for a Node.
 */
 ScrollViewBehavior :: (node : *Node, axis : AxisFlags) {
    ScrollViewBehavior(node, node, axis);
}

/**
 * @brief Perform mouse wheel scroll interaction logic for a Node.
 */
ScrollViewBehavior :: (node : *Node, target : *Node, axis : AxisFlags) {
    scroll := ScrollBehavior(node);

    if axis & .X {
        SetContentScrollX(target, target.scroll.x + scroll.x);
    }

    if axis & .Y {
        SetContentScrollY(target, target.scroll.y + scroll.y);
    }
}

/**
 * @brief Set scroll value, clamped by the content size
 */
SetContentScroll :: inline (node : *Node, axis : Axis, value : float) {
    if axis == .X {
        SetContentScrollX(node, value);
    } else {
        SetContentScrollY(node, value);
    }
}

/**
 * @brief Set scroll value, clamped by the content size
 */
SetContentScrollX :: inline (node : *Node, value : float) {
    avail_scroll := node.size.x - node.padding.x - node.padding.z - node.children_size.x;
    node.scroll.x = clamp(value, avail_scroll, 0);
}

/**
 * @brief Set scroll value, clamped by the content size
 */
SetContentScrollY :: inline (node : *Node, value : float) {
    avail_scroll := node.size.y - node.padding.y - node.padding.w - node.children_size.y;
    node.scroll.y = clamp(value, avail_scroll, 0);
}

/**
 * @brief Perform mouse drag interaction logic for a Node.
 */
DragBehavior :: (subwindow : *Node, node : *Node, avail_area := Vec4f.{-FLOAT32_INFINITY,-FLOAT32_INFINITY,FLOAT32_INFINITY,FLOAT32_INFINITY}) -> ButtonResult {
    interaction := ButtonBehavior(node);

    if interaction.pressed {
        context.omg.mouse_captured_node_value = .{xy=subwindow.offset};
    }

    if interaction.down {
        mouse_delta := GetMousePosition() - context.omg.mouse_captured_at;
        original_offset := context.omg.mouse_captured_node_value.xy;
        subwindow.offset = original_offset + mouse_delta;

        subwindow.offset = clamp(subwindow.offset, avail_area.xy, avail_area.zw);
    }

    return interaction;
}

ProgressBarStyle :: struct {
    height : float;
    background : BoxStyle;
    fill : BoxStyle;
}

/**
 * @brief Progress bar widget.
 */
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

ArrowDirection :: enum {
    Up;
    Down;
    Left;
    Right;
}

DrawArrow :: (draw_list : *DrawList, node : *Node, rotation : float) -> bool {
    if IsClipped(draw_list, node.rect) {
        return false;
    }

    if (node.background_colors.top_left & 0xff) == 0 {
        return true;
    }

    center := (node.rect.xy + node.rect.zw) * 0.5;
    half_w := node.size.x * 0.5;
    half_h := node.size.y * 0.5;

    p0 := Rotate(Vec2f.{half_w, -half_h}, rotation);
    p1 := Rotate(Vec2f.{-half_w, -half_h}, rotation);
    p2 := Rotate(Vec2f.{0, half_h}, rotation);
    p0 += center;
    p1 += center;
    p2 += center;

    DrawTriangle(draw_list, p0, p1, p2, node.background_colors.top_left);

    return true;
}

Arrow :: (parent : *Node, width : Size1D, height : Size1D, direction : ArrowDirection, color : RGBA8, location := #caller_location) -> *Node {
    node := GetNode(parent, location);
    SetSize(node, width, height);
    if #complete direction == {
    case .Up;
        SetDraw(node, #bake_arguments DrawArrow(rotation=PI));
    case .Down;
        SetDraw(node, #bake_arguments DrawArrow(rotation=0));
    case .Left;
        SetDraw(node, #bake_arguments DrawArrow(rotation=PI * 0.5));
    case .Right;
        SetDraw(node, #bake_arguments DrawArrow(rotation=PI * 0.75));
    }
    SetBackgroundColor(node, color);

    return node;
}
