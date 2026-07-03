ButtonResult :: struct {
    pressed : bool;
    double_clicked : bool;
    held : bool;
    released : bool;
}

ButtonBehavior :: (node : *Node) -> ButtonResult {
    node.flags |= .Focusable;

    if (IsMouseButtonReleased(.Left) || IsMouseButtonDown(.Left)) && context.omg.mouse_capturing_node == node {
        SetMouseCapture(node);
        SetMouseFocus(node);
    } else if node.state_flags & .Focused && IsMouseButtonPressed(.Left) {
        SetMouseCapture(node);
    }

    if context.omg.mouse_capturing_node == node {
        node.state_flags |= .Hot;
    }

    result : ButtonResult;
    if node.state_flags & .Hot {
        result.held = true;
        result.pressed = IsHovered(node) && IsMouseButtonPressed(.Left);
        result.double_clicked = IsHovered(node) && IsMouseButtonDoubleClicked(.Left);
        result.released = IsHovered(node) && IsMouseButtonReleased(.Left);
    }

    return result;
}

ButtonStateStyle :: struct {
    background : BoxStyle;
    text : TextStyle;
    cursor : *Cursor;
}

ButtonStyle :: StateStyle(ButtonStateStyle);

SetColors :: (style : *ButtonStyle, base_background_color : RGBA8) {
    SetColors(style, base_background_color, ChooseTextColor(base_background_color));
}

SetColors :: (using style : *ButtonStyle, base_background_color : RGBA8, text_color : RGBA8) {
    normal.background.background_color = base_background_color;
    focused.background.background_color = Whiten(base_background_color, 0.05);
    hot.background.background_color = Darken(base_background_color, 0.05);
    active.background.background_color = Whiten(base_background_color, 0.1);

    normal.text.text_color = text_color;
    focused.text.text_color = text_color;
    hot.text.text_color = text_color;
    active.text.text_color = text_color;
}

Button :: (parent : *Node, width : Size1D, height : Size1D, style : *ButtonStyle = null, location := #caller_location) -> clicked : bool, *Node {
    EnsureStyle(*style, "button");

    node := GetNode(parent, location);
    {
        SetSize(node, width, height);
        SetChildAlign(node, 0.5, 0.5);

        button := ButtonBehavior(node);

        state := GetState(node);

        Apply(node, style.states[state].background);
        if HasCursorControl(node) {
            SetCursor(style.states[state].cursor);
        }

        return button.released, node;
    }
}

Button :: (parent : *Node, text : string, style : *ButtonStyle = null, location := #caller_location) -> clicked : bool, *Node {
    EnsureStyle(*style, "button");

    clicked, node := Button(parent, SizeFit(), SizeFit(), style, location);

    text_node := GetNode(node, "text");
    SetText(text_node, text);

    state := GetState(node);

    Apply(text_node, style.states[state].text);

    return clicked, node;
}

Toggle :: (parent : *Node, width : Size1D, height : Size1D, value : *bool, style : *ButtonStyle = null, location := #caller_location) -> clicked : bool, *Node {
    EnsureStyle(*style, "toggle");

    dummy_value : bool;
    if !value {
        value = *dummy_value;
    }

    node := GetNode(parent, location);
    {
        SetSize(node, width, height);
        SetChildAlign(node, 0.5, 0.5);

        button := ButtonBehavior(node);
        if button.released {
            value.* = !value.*;
        }

        if value.* {
            node.state_flags |= .Active;
        }

        state := GetState(node);

        Apply(node, style.states[state].background);
        if HasCursorControl(node) {
            SetCursor(style.states[state].cursor);
        }

        return button.released, node;
    }
}

Toggle :: (parent : *Node, text : string, value : *bool, style : *ButtonStyle = null, location := #caller_location) -> clicked : bool, *Node {
    EnsureStyle(*style, "toggle");

    clicked, node := Toggle(parent, SizeFit(), SizeFit(), value, style, location);

    text_node := GetNode(node, "text");
    SetText(text_node, text);

    state := GetState(node);

    Apply(text_node, style.states[state].text);

    return clicked, node;
}

CheckmarkStyle :: struct {
    rounding := 1.0;
    thickness := 0.2;
    offset := Vec2f.{-0.2, 0};
    left_size := 0.5;
    right_size := 0.9;
    angle := PI * 0.17;

    background_color : RGBA8;
    border_color : RGBA8;
    border_size : float;
    border_inset : float;
    outer_shadow_blur : float;
    outer_shadow_offset : Vec2f;
    outer_shadow_color : RGBA8;
}

Apply :: inline (node : *Node, style : CheckmarkStyle) {
    node.background_color = style.background_color;
    node.border_color = style.border_color;
    node.border_size = style.border_size;
    node.border_inset = style.border_inset;
    node.outer_shadow_blur = style.outer_shadow_blur;
    node.outer_shadow_offset = style.outer_shadow_offset;
    node.outer_shadow_color = style.outer_shadow_color;
}

CheckboxStateStyle :: struct {
    background : BoxStyle;
    checkmark : CheckmarkStyle;
}

CheckboxStyle :: StateStyle(CheckboxStateStyle);

SetColors :: (using style : *CheckboxStyle, base_background_color : RGBA8, checkmark_color : RGBA8) {
    normal.background.background_color = base_background_color;
    focused.background.background_color = Whiten(base_background_color, 0.05);
    hot.background.background_color = Darken(base_background_color, 0.05);
    active.background.background_color = Whiten(base_background_color, 0.1);

    normal.checkmark.background_color = checkmark_color;
    focused.checkmark.background_color = checkmark_color;
    hot.checkmark.background_color = checkmark_color;
    active.checkmark.background_color = checkmark_color;
}

DrawCheckmark :: (draw_list : *DrawList, node : *Node) {
    checkbox_style := GetUserData(node.parent, CheckboxStyle);
    if !checkbox_style {
        return;
    }

    has_background := (node.background_color & 0xff) > 0;
    has_border := (node.border_color & 0xff) > 0 && node.border_size > 0;
    has_shadow := (node.outer_shadow_color & 0xff) > 0;

    if !has_background && !has_border && !has_shadow {
        return;
    }

    position := Vec2f.{(node.rect.x + node.rect.z) * 0.5, node.rect.w};

    size := node.size.y;
    scale := size / 20.0;
    state := GetState(node.parent);
    using style := checkbox_style.states[state];

    left_height := size * checkmark.left_size;
    right_height := size * checkmark.right_size;
    thickness := size * checkmark.thickness;
    radiuses := Vec4f.{checkmark.rounding, checkmark.rounding, 2, 2} * scale;

    left := Box(thickness, left_height, radiuses);
    left = Transform(left, Rotate2D(-checkmark.angle) * Translate2D(0, -left_height * 0.5));

    right := Box(thickness, right_height, radiuses);
    right = Transform(right, Rotate2D(checkmark.angle) * Translate2D(0, -right_height * 0.5));

    shape := Union(left, right, 0.5 * scale);
    shape = Move(shape, size * 0.5 * checkmark.offset.x, -thickness * 0.5 + checkmark.offset.y * size);

    DrawShape(*node.window.draw_list, .{
        shape=shape,
        position=position,
        background_color=node.background_color,
        border_color=node.border_color,
        border_size=node.border_size,
        border_inset=node.border_inset,
        outer_shadow_color=node.outer_shadow_color,
        outer_shadow_offset=node.outer_shadow_offset,
        outer_shadow_blur=node.outer_shadow_blur,
    });
}

Checkbox :: (parent : *Node, value : *bool, size := 20.0, style : *CheckboxStyle = null, location := #caller_location) -> modified : bool, *Node {
    EnsureStyle(*style, "checkbox");

    node := GetNode(parent, location);
    {
        SetSize(node, SizePx(size), SizePx(size));

        SetUserData(node, style.*);

        button := ButtonBehavior(node);
        if button.released {
            value.* = !value.*;
        }

        state := GetState(node);
        Apply(node, style.states[state].background);

        if value.* {
            checkmark := GetNode(node, "text");
            SetDraw(checkmark, DrawCheckmark);
            SetSize(checkmark, SizeFill(), SizeFill());

            Apply(checkmark, style.states[state].checkmark);
        }

        return button.released, node;
    }
}
