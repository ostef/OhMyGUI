ComboStyle :: struct {
    button: ButtonStyle;
    popup: MenuStyle;
    item: MenuItemStyle;
    arrow_size := Vec2f.{10, 6};
    arrow_style: enum {
        Arrow;
        Chevron;
    };
}

/**
 * @brief Combo box widget for enum values.
 */
EnumCombo :: inline (
    parent: *Node,
    value: *$T,
    style: *ComboStyle = null,
    location := #caller_location
) -> modified: bool, *Node
#modify { return cast(*Type_Info, T).type == .ENUM; } {
    GetItem :: (index: int, user_data: *void) -> string, selected: bool {
        value := cast(*T, user_data).*;

        info := type_info(T);
        if info.enum_type_flags & .FLAGS {
            item := info.values[index];
            selected := (value & cast,no_check(T, item)) == cast,no_check(T, item);

            return info.names[index], selected;
        } else {
            _, value_index := array_find(info.values, xx,no_check value);
            return info.names[index], index == value_index;
        }
    }

    info := type_info(T);
    clicked_item, node := Combo(parent, tprint("%", value.*), info.values.count, GetItem, value, style, location);
    if clicked_item >= 0 {
        if info.enum_type_flags & .FLAGS {
            item := cast,no_check(T, info.values[clicked_item]);
            if value.* & item == item {
                value.* &= ~item;
            } else {
                value.* |= item;
            }
        } else {
            value.* = xx,no_check info.values[clicked_item];
        }
    }

    return clicked_item >= 0, node;
}

/**
 * @brief Combo box widget with string values.
 */
Combo :: inline (
    parent: *Node,
    selected: *int,
    items: []string,
    style: *ComboStyle = null,
    location := #caller_location
) -> modified: bool, *Node {
    data: struct {
        selected: *int;
        items: []string;
    } = .{selected, items};

    GetItem :: (index: int, user_data: *void) -> string, selected: bool {
        using _ := cast(*type_of(data), user_data);

        return items[index], selected.* == index;
    }

    clicked_item, node := Combo(parent, items[selected.*], items.count, GetItem, *data, style, location);
    if clicked_item >= 0 {
        selected.* = clicked_item;
    }

    return clicked_item >= 0, node;
}

/**
 * @brief Combo box widget with callback.
 */
Combo :: (
    parent: *Node,
    preview_text: string,
    num_items: int,
    get_item: (index: int, user_data: *void) -> (string, selected: bool),
    user_data: *void = null,
    style: *ComboStyle = null,
    location := #caller_location
) -> clicked_item: int, *Node {
    EnsureStyle(*style, "combo");

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
        SetText(text_node, preview_text);

        Apply(text_node, style.button.states[state].text);

        if #complete style.arrow_style == {
        case .Arrow;
            Arrow(combo, SizePx(style.arrow_size.x), SizePx(style.arrow_size.y), .Down, style.button.states[state].text.text_color);
        case .Chevron;
            Chevron(combo, SizePx(style.arrow_size.x), SizePx(style.arrow_size.y), .Down, style.button.states[state].text.text_color);
        }
    }

    clicked_item := -1;

    if combo.state_flags & .Active && num_items > 0 {
        popup := GetPopupNode(parent.window, location);
        assert(prev_frame_menu == null || popup == prev_frame_menu);
        {
            SetLayout(popup, .TopToBottom);
            SetSize(popup, SizePx(combo.size.x), SizeFit());

            BringForward(popup);

            menu_data = AddUserData(popup, MenuData);
            array_reset_keeping_memory(*menu_data.submenus);

            menu_data.parent_menu = null;
            popup.offset = .{combo.rect.x, combo.rect.w};

            Apply(popup, style.popup);

            ScrollViewBehavior(popup, .Y);

            for i: 0..num_items - 1 {
                item, is_selected := get_item(i, user_data);
                PushID(GetID(i));
                defer PopID();

                if MenuItem(popup, item, selected=is_selected, style=*style.item) {
                    clicked_item = i;
                }
            }
        }
    }

    return clicked_item, combo;
}
