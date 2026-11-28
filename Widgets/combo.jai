ComboStyle :: struct {
    button: ButtonStyle;
    menu: MenuStyle;
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
) -> modified: bool, button: *Node, menu: *Node
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
    clicked_item, button, menu := Combo(parent, tprint("%", value.*), info.values.count, GetItem, value, style, location);
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

    return clicked_item >= 0, button, menu;
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
) -> modified: bool, button: *Node, menu: *Node {
    data: struct {
        selected: *int;
        items: []string;
    } = .{selected, items};

    GetItem :: (index: int, user_data: *void) -> string, selected: bool {
        using _ := cast(*type_of(data), user_data);

        return items[index], selected.* == index;
    }

    clicked_item, button, menu := Combo(parent, items[selected.*], items.count, GetItem, *data, style, location);
    if clicked_item >= 0 {
        selected.* = clicked_item;
    }

    return clicked_item >= 0, button, menu;
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
) -> clicked_item: int, button: *Node, menu: *Node {
    EnsureStyle(*style, "combo");

    clicked_item := -1;
    combo_menu, combo := ComboMenu(parent, preview_text, style, location);
    if combo_menu {
        for i: 0..num_items - 1 {
            item, is_selected := get_item(i, user_data);
            PushID(GetID(i));
            defer PopID();

            if MenuItem(combo_menu, item, selected=is_selected, style=*style.item) {
                clicked_item = i;
            }
        }
    }

    return clicked_item, combo, combo_menu;
}

/**
 * @brief Combo box widget with empty menu.
 */
ComboMenu :: (
    parent: *Node,
    preview_text: string,
    style: *ComboStyle = null,
    location := #caller_location
) -> menu: *Node, button: *Node {
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

    menu: *Node;
    if combo.state_flags & .Active {
        menu = GetPopupNode(parent.window, location);
        assert(prev_frame_menu == null || menu == prev_frame_menu);
        {
            SetLayout(menu, .TopToBottom);
            SetSize(menu, SizePx(combo.size.x), SizeFit());

            BringForward(menu);

            menu_data = AddUserData(menu, MenuData);
            menu_data.parent_menu = null;
            menu.offset = .{combo.rect.x, combo.rect.w};
            array_reset_keeping_memory(*menu_data.submenus);

            Apply(menu, style.menu);

            ScrollViewBehavior(menu, .Y);
        }
    }

    return menu, combo;
}
