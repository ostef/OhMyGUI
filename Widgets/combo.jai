ComboStyle :: struct {
    button : ButtonStyle;
    popup : MenuStyle;
    item : ButtonStyle;
    arrow_size := Vec2f.{10, 6};
}

DrawComboArrow :: (draw_list : *DrawList, node : *Node) {
    if (node.text_color & 0xff) == 0 {
        return;
    }

    center := (node.rect.xy + node.rect.zw) * 0.5;
    half_w := node.size.x * 0.5;
    half_h := node.size.y * 0.5;

    p0 := center + .{-half_w, -half_h};
    p1 := center + .{half_w, -half_h};
    p2 := center + .{0, half_h};

    DrawTriangle(draw_list, p0, p1, p2, node.text_color);
}

EnumCombo :: inline (
    parent : *Node,
    value : *$T,
    style : *ComboStyle = null,
    location := #caller_location
) -> modified : bool, *Node
#modify { return cast(*Type_Info, T).type == .ENUM; } {
    values := type_info(T).values;
    names := type_info(T).names;
    _, index := array_find(values, xx,no_check value.*);

    modified, node := Combo(parent, *index, names, style, location);
    if modified {
        value.* = xx,no_check values[index];
    }

    return modified, node;
}

Combo :: inline (
    parent : *Node,
    selected : *int,
    items : []string,
    style : *ComboStyle = null,
    location := #caller_location
) -> modified : bool, *Node {
    modified, node := Combo(parent, selected, items.count, (i, data) => cast(*string, data)[i], items.data, style, location);
    return modified, node;
}

Combo :: (
    parent : *Node,
    selected : *int,
    num_items : int,
    get_item : (index : int, user_data : *void) -> string,
    user_data : *void = null,
    style : *ComboStyle = null,
    location := #caller_location
) -> modified : bool, *Node {
    EnsureStyle(*style, "combo");

    dummy_selected : int;
    if !selected {
        selected = *dummy_selected;
    }

    popup_root := GetPopupRoot(parent.window);
    combo_id := GetID(GetID(location), popup_root.id);

    combo := GetNode(parent, location);
    {
        SetSize(combo, SizeFill(), SizeFit());
        SetLayout(combo, .LeftToRight);
        SetChildAlign(combo, 0.5, 0.5);

        should_deactivate := IsKeyPressed(.Escape);
        if combo.state_flags & .ActiveLastFrame && !(combo.state_flags & .Focused) && IsMouseButtonPressed(.Left) {
            if !IsInTree(context.omg.mouse_hovered_node, combo_id) {
                should_deactivate = true;
            }
        }

        button := ButtonBehavior(combo);
        if !should_deactivate && (button.released || combo.state_flags & .ActiveLastFrame) {
            combo.state_flags |= .Active;
        }

        state := GetState(combo);
        Apply(combo, style.button.states[state].background);
        if HasCursorControl(combo) {
            SetCursor(style.button.states[state].cursor);
        }

        text_node := GetNode(combo, "text");
        SetSize(text_node, SizeFill(), SizeFit());

        if num_items > 0 {
            selected_index := clamp(selected.*, 0, xx num_items - 1);
            SetText(text_node, get_item(selected_index, user_data));
        } else {
            SetText(text_node, "");
        }

        Apply(text_node, style.button.states[state].text);

        arrow := GetNode(combo, "arrow");
        SetSize(arrow, SizePx(style.arrow_size.x), SizePx(style.arrow_size.y));
        SetDraw(arrow, DrawComboArrow);
        SetTextColor(arrow, style.button.states[state].text.text_color);
    }

    modified := false;

    if combo.state_flags & .Active && num_items > 0 {
        popup := GetPopupNode(parent.window, location);
        {
            SetLayout(popup, .TopToBottom);
            SetSize(popup, SizePx(combo.layout_last_frame.size.x), SizeFit());

            popup.flags |= .Focusable;

            BringForward(popup);

            popup.offset = .{combo.layout_last_frame.rect.x, combo.layout_last_frame.rect.w};
            Apply(popup, style.popup);

            ScrollViewBehavior(popup, .Y);

            for i : 0..num_items - 1 {
                item := get_item(i, user_data);
                PushIDOffset(i);
                item_clicked := MenuItem(popup, item, selected=selected.* == i, style=*style.item);
                PopIDOffset();

                if item_clicked {
                    selected.* = i;
                    modified = true;
                    combo.state_flags &= ~.Active;
                }
            }
        }
    }

    return modified, combo;
}
