#load "buttons.jai";
#load "text_input.jai";
#load "sliders.jai";
#load "menus.jai";
#load "subwindow.jai";

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

HorizontalSeparator :: (parent : *Node, style : *BoxStyle = null, location := #caller_location) -> *Node {
    EnsureStyle(*style, "separator");

    node := GetNode(parent, location);
    SetSize(node, SizeFill(), SizePx(1));
    Apply(node, style);

    return node;
}

VerticalSeparator :: (parent : *Node, style : *BoxStyle = null, location := #caller_location) -> *Node {
    EnsureStyle(*style, "separator");

    node := GetNode(parent, location);
    SetSize(node, SizePx(1), SizeFill(1));
    Apply(node, style);

    return node;
}
