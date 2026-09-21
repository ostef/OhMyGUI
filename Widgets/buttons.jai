/**
 * @brief Button interaction result.
 */
ButtonResult :: struct {
    down : bool;           ///> Was the mouse button down while the node was focused?
    pressed : bool;        ///> Was the mouse button pressed while the node was focused and hovered?
    double_clicked : bool; ///> Was the mouse button double clicked while the node was focused and hovered?
    released : bool;       ///> Was the mouse button released while the node was focused and hovered?
}

/**
 * @brief Perform button interaction logic for a Node.
 *
 * Perform button interaction logic for a Node if the node is not being interacted with by another mouse button.
 * This function is idempotent, so calling ButtonBehavior multiple times for the same mouse button yiels the same result.
 */
ButtonBehavior :: (node : *Node, mouse_button := MouseButton.Left) -> ButtonResult {
    node.flags |= .Focusable;

    button_flags := cast(NodeInteractingMouseButtons, 1 << mouse_button);
    interacting_buttons_last_frame := (node.interacting_mouse_buttons & .LastFrame) >> 3;

    // Prevent interactions with a mouse button while another is happening
    // (e.g. opening a context menu while panning a canvas)
    if interacting_buttons_last_frame != 0 && !(interacting_buttons_last_frame & button_flags) {
        return .{};
    }

    active_from_button := false;
    if IsCapturingMouse(node) && (IsMouseButtonReleased(mouse_button) || IsMouseButtonDown(mouse_button)) {
        SetMouseCapture(node);
        SetMouseFocus(node);
        active_from_button = true;
    } else if node.state_flags & .Focused && IsMouseButtonPressed(mouse_button) {
        SetMouseCapture(node);
        active_from_button = true;
    }

    result : ButtonResult;
    if active_from_button {
        node.interacting_mouse_buttons |= button_flags;
        node.state_flags |= .Hot;

        is_hovered := IsHovered(node);
        result.pressed = is_hovered && IsMouseButtonPressed(mouse_button);
        result.double_clicked = is_hovered && IsMouseButtonDoubleClicked(mouse_button);
        result.released = is_hovered && IsMouseButtonReleased(mouse_button);

        result.down = true;
    }

    return result;
}

/**
 * @brief Button style for one state (background, text and cursor).
 */
ButtonStateStyle :: struct {
    background : BoxStyle;
    text : TextStyle;
    cursor : PlatformCursorHandle;
}

ButtonStyle :: StateStyle(ButtonStateStyle);

/**
 * @brief Set all ButtonStyle's state colors using a base background color.
 *
 * Set all ButtonStyle's state colors using a base background color. Text color is chosen based on the background.
 */
SetColors :: (style : *ButtonStyle, base_background_color : RGBA8) {
    SetColors(style, base_background_color, ChooseTextColor(base_background_color));
}

/**
 * @brief Set all ButtonStyle's state colors using a base background color and text color.
 */
SetColors :: (using style : *ButtonStyle, base_background_color : RGBA8, text_color : RGBA8) {
    SetColors(*normal.background.background_colors, base_background_color);
    SetColors(*focused.background.background_colors, Whiten(base_background_color, 0.05));
    SetColors(*hot.background.background_colors, Darken(base_background_color, 0.05));
    SetColors(*active.background.background_colors, Whiten(base_background_color, 0.1));

    normal.text.text_color = text_color;
    focused.text.text_color = text_color;
    hot.text.text_color = text_color;
    active.text.text_color = text_color;
}

/**
 * @brief Empty button widget.
 */
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

/**
 * @brief Button widget with text.
 */
Button :: (parent : *Node, text : string, style : *ButtonStyle = null, location := #caller_location) -> clicked : bool, *Node {
    EnsureStyle(*style, "button");

    clicked, node := Button(parent, SizeFit(), SizeFit(), style, location);

    text_node := GetNode(node, "text");
    SetText(text_node, text);

    state := GetState(node);

    Apply(text_node, style.states[state].text);

    return clicked, node;
}

/**
 * @brief Empty toggle button widget.
 */
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

/**
 * @brief Toggle button widget with text.
 */
Toggle :: (parent : *Node, text : string, value : *bool, style : *ButtonStyle = null, location := #caller_location) -> clicked : bool, *Node {
    EnsureStyle(*style, "toggle");

    clicked, node := Toggle(parent, SizeFit(), SizeFit(), value, style, location);

    text_node := GetNode(node, "text");
    SetText(text_node, text);

    state := GetState(node);

    Apply(text_node, style.states[state].text);

    return clicked, node;
}

/**
 * @brief Style for nodes that use the DrawCheckmark drawing function.
 *
 * @see DrawCheckmark
 */
CheckmarkStyle :: struct {
    thickness := 0.2;
    offset := Vec2f.{-0.2, 0};
    left_size := 0.5;
    right_size := 0.9;
    angle := PI * 0.17;

    background_color : RGBA8;
    outer_shadow_size : float;
    outer_shadow_offset : Vec2f;
    outer_shadow_color : RGBA8;
}

Apply :: inline (node : *Node, style : CheckmarkStyle) {
    SetColors(*node.background_colors, style.background_color);
    node.outer_shadow_size = style.outer_shadow_size;
    node.outer_shadow_offset = style.outer_shadow_offset;
    node.outer_shadow_color = style.outer_shadow_color;
}

CheckboxStateStyle :: struct {
    background : BoxStyle;
    checkmark : CheckmarkStyle;
}

CheckboxStyle :: StateStyle(CheckboxStateStyle);

SetColors :: (using style : *CheckboxStyle, base_background_color : RGBA8, checkmark_color : RGBA8) {
    SetColors(*normal.background.background_colors, base_background_color);
    SetColors(*focused.background.background_colors, Whiten(base_background_color, 0.05));
    SetColors(*hot.background.background_colors, Darken(base_background_color, 0.05));
    SetColors(*active.background.background_colors, Whiten(base_background_color, 0.1));

    normal.checkmark.background_color = checkmark_color;
    focused.checkmark.background_color = checkmark_color;
    hot.checkmark.background_color = checkmark_color;
    active.checkmark.background_color = checkmark_color;
}

/**
 * @brief Checkmark Node drawing function.
 *
 * Checkmark Node drawing function. The Node needs to have a StateStyle(CheckmarkStyle) user data attached.
 *
 * @see CheckmarkStyle
 */
DrawCheckmark :: (draw_list : *DrawList, node : *Node) -> bool {
    if IsClipped(draw_list, node.rect) {
        return false;
    }

    checkmark_styles := GetUserData(node, StateStyle(CheckmarkStyle));
    if !checkmark_styles {
        return true;
    }

    if (node.background_colors.top_left & 0xff) == 0 {
        return true;
    }

    position := Vec2f.{(node.rect.x + node.rect.z) * 0.5, node.rect.w};

    size := node.size.y;
    scale := size / 20.0;
    checkmark := checkmark_styles.states[GetState(node)];

    left_height := size * checkmark.left_size;
    right_height := size * checkmark.right_size;
    thickness := size * checkmark.thickness;

    n0 := Rotate(Vec2f.{0, 1}, -checkmark.angle);
    n1 := Rotate(Vec2f.{0, 1},  checkmark.angle);

    p0 := position - n0 * left_height;
    p0 += Vec2f.{size * 0.5 * checkmark.offset.x, -thickness * 0.5 + checkmark.offset.y * size};
    p1 := position;
    p1 += Vec2f.{size * 0.5 * checkmark.offset.x, -thickness * 0.5 + checkmark.offset.y * size};
    p2 := position - n1 * right_height;
    p2 += Vec2f.{size * 0.5 * checkmark.offset.x, -thickness * 0.5 + checkmark.offset.y * size};

    if (node.outer_shadow_color & 0xff) != 0 {
        array_add(*draw_list.path, .{position=p0 + node.outer_shadow_offset, normal=PerpendicularCCW(n0)});
        array_add(*draw_list.path, .{position=p1 + node.outer_shadow_offset});
        array_add(*draw_list.path, .{position=p2 + node.outer_shadow_offset, normal=PerpendicularCW(n1)});

        DrawPolygonLine(draw_list, draw_list.path, false, thickness, node.outer_shadow_color, blur_size=1 + node.outer_shadow_size);

        array_reset_keeping_memory(*draw_list.path);
    }

    array_add(*draw_list.path, .{position=p0, normal=PerpendicularCCW(n0)});
    array_add(*draw_list.path, .{position=p1});
    array_add(*draw_list.path, .{position=p2, normal=PerpendicularCW(n1)});

    DrawPolygonLine(draw_list, draw_list.path, false, thickness, node.background_colors.top_left);

    array_reset_keeping_memory(*draw_list.path);

    return true;
}

/**
 * @brief Checkbox widget.
 *
 * @param size Size of the checkbox. If size <= 0 it is calculated based on the text size of the "text" style.
 */
Checkbox :: (parent : *Node, value : *bool, size := 0.0, style : *CheckboxStyle = null, location := #caller_location) -> modified : bool, *Node {
    EnsureStyle(*style, "checkbox");

    if size <= 0 {
        text := GetStyle("text", TextStyle);
        size = text.text_size / 14.0 * 20.0;
    }

    node := GetNode(parent, location);
    {
        SetSize(node, SizePx(size), SizePx(size));

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

            checkmark_styles : StateStyle(CheckmarkStyle);
            for * checkmark_styles.states {
                it.* = style.states[it_index].checkmark;
            }

            SetUserData(checkmark, checkmark_styles);

            checkmark.state_flags |= node.state_flags;
            Apply(checkmark, style.states[state].checkmark);
        }

        return button.released, node;
    }
}

RadioButtonStateStyle :: struct {
    background : BoxStyle;
    active_mark : BoxStyle;
}

RadioButtonStyle :: StateStyle(RadioButtonStateStyle);

SetColors :: (using style : *RadioButtonStyle, base_background_color : RGBA8, active_mark_color : RGBA8) {
    SetColors(*normal.background.background_colors, base_background_color);
    SetColors(*focused.background.background_colors, Whiten(base_background_color, 0.05));
    SetColors(*hot.background.background_colors, Darken(base_background_color, 0.05));
    SetColors(*active.background.background_colors, Whiten(base_background_color, 0.1));

    SetColors(*normal.active_mark.background_colors, active_mark_color);
    SetColors(*focused.active_mark.background_colors, active_mark_color);
    SetColors(*hot.active_mark.background_colors, active_mark_color);
    SetColors(*active.active_mark.background_colors, active_mark_color);
}

/**
 * @brief Radio button widget.
 *
 * @param size Size of the button. If size <= 0 it is calculated based on the text size of the "text" style.
 */
RadioButton :: (parent : *Node, value : *$T, for_value : T, size := 0.0, style : *RadioButtonStyle = null, location := #caller_location) -> clicked : bool, *Node {
    clicked, node := RadioButton(parent, value.* == for_value, size, style, location);
    if clicked {
        value.* = for_value;
    }

    return clicked, node;
}

/**
 * @brief Radio button widget.
 *
 * @param size Size of the button. If size <= 0 it is calculated based on the text size of the "text" style.
 */
RadioButton :: (parent : *Node, active : bool, size := 0.0, style : *RadioButtonStyle = null, location := #caller_location) -> clicked : bool, *Node {
    EnsureStyle(*style, "radio_button");

    if size <= 0 {
        text := GetStyle("text", TextStyle);
        size = text.text_size / 14.0 * 20.0;
    }

    node := GetNode(parent, location);
    {
        SetSize(node, SizePx(size), SizePx(size));
        node.flags |= .NoClip;

        SetUserData(node, style.*);

        button := ButtonBehavior(node);

        state := GetState(node);
        style_state := style.states[state];
        Apply(node, style_state.background);
        SetCornerRadiuses(node, style_state.background.corner_radiuses * size * 0.5);

        if active {
            active_mark := GetNode(node, "text");
            SetSize(active_mark, SizeFill(), SizeFill());

            Apply(active_mark, style_state.active_mark);

            radiuses := style_state.active_mark.corner_radiuses;
            radiuses.x *= (size - max(style_state.background.padding.x, style_state.background.padding.y)) * 0.5;
            radiuses.y *= (size - max(style_state.background.padding.z, style_state.background.padding.y)) * 0.5;
            radiuses.z *= (size - max(style_state.background.padding.x, style_state.background.padding.w)) * 0.5;
            radiuses.w *= (size - max(style_state.background.padding.z, style_state.background.padding.w)) * 0.5;
            SetCornerRadiuses(active_mark, radiuses);
        }

        return button.released, node;
    }
}
