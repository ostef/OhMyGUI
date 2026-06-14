#load "buttons.jai";
#load "text_input.jai";
#load "sliders.jai";
#load "menus.jai";
#load "subwindow.jai";
#load "color_picker.jai";

LabelAndContentStyle :: struct {
    padding : Vec4f;
    child_gap : Vec2f;
    text : TextStyle;
    text_fill := 0.35;
}

LabelAndContent :: (parent : *Node, label : string, style : *LabelAndContentStyle = null, location := #caller_location) -> *Node {
    EnsureStyle(*style, "label_and_content");

    node := GetNode(parent, location);
    SetSize(node, SizeFill(), SizeFit());
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

ClickableText :: (parent : *Node, fmt_str : string, args : ..Any, style : *ClickableTextStyle = null, location := #caller_location) -> clicked : bool, *Node {
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

    return button.released, node;
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
