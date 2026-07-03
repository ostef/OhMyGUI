#load "buttons.jai";
#load "text_input.jai";
#load "sliders.jai";
#load "menus.jai";
#load "subwindow.jai";
#load "color_picker.jai";

LabelAndContentStyle :: struct {
    padding : Vec4f;
    child_gap : Vec2f;
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
    cursor : *Cursor;
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
