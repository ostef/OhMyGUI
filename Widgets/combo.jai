ComboStyle :: struct {
    button : ButtonStyle;
    popup : MenuStyle;
    item : MenuItemStyle;
    arrow_size := Vec2f.{10, 6};
}

/**
 * @brief Combo box widget for enum values.
 */
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

/**
 * @brief Combo box widget with string values.
 */
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

/**
 * @brief Combo box widget with callback.
 */
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
    prev_frame_menu := FindPrevFrameNode(popup_root, GetID(location));
    menu_data := ifx prev_frame_menu then GetUserData(prev_frame_menu, MenuData);
    combo_id := GetID(GetID(location), popup_root.id);

    combo := GetNode(parent, location);
    {
        SetSize(combo, SizeFill(), SizeFit());
        SetLayout(combo, .LeftToRight);
        SetChildAlign(combo, 0.5, 0.5);

        button := ButtonBehavior(combo);
        if button.released || (combo.state_flags & .ActiveLastFrame) {
            combo.state_flags |= .Active;
        }

        should_deactivate := IsKeyPressed(.Escape);
        should_deactivate |= menu_data != null && menu_data.wants_close;

        if prev_frame_menu && (combo.state_flags & .ActiveLastFrame) && !(combo.state_flags & .Focused) && IsAnyMouseButtonPressed() {
            is_in_menu := IsInTree(context.omg.mouse_hovered_node, prev_frame_menu);

            if menu_data && !is_in_menu {
                for menu_data.submenus {
                    if IsInTree(context.omg.mouse_hovered_node, it) {
                        is_in_menu = true;
                        break;
                    }
                }
            }

            should_deactivate = !is_in_menu;
        }

        if should_deactivate {
            combo.state_flags &= ~.Active;
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

        Arrow(combo, SizePx(style.arrow_size.x), SizePx(style.arrow_size.y), .Down, style.button.states[state].text.text_color);
    }

    modified := false;

    if combo.state_flags & .Active && num_items > 0 {
        popup := GetPopupNode(parent.window, location);
        assert(prev_frame_menu == null || popup == prev_frame_menu);
        {
            SetLayout(popup, .TopToBottom);
            SetSize(popup, SizePx(combo.size.x), SizeFit());

            BringForward(popup);

            menu_data = AddUserData(popup, MenuData, DestroyMenuData);
            array_reset_keeping_memory(*menu_data.submenus);

            menu_data.parent_menu = null;
            popup.offset = .{combo.rect.x, combo.rect.w};

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
