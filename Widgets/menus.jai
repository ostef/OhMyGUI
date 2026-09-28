MenuItemStyle :: struct {
    button : ButtonStyle;
    checkmark : CheckmarkStyle;
    checkmark_size := 0.9;
}

/**
 * @brief Horizontal menu bar widget.
 */
MenuBar :: (parent : *Node, str_id : string, style : *BoxStyle = null) -> *Node {
    EnsureStyle(*style, "menu_bar");

    node := GetNode(parent, str_id);
    {
        SetLayout(node, .LeftToRight);
        SetSize(node, SizeFill(), SizeFit());

        Apply(node, style);
    }

    return node;
}

/**
 * @brief Button widget used inside menus and menu bars.
 */
MenuItem :: (parent : *Node, text : string, selected := false, style : *MenuItemStyle = null, location := #caller_location) -> clicked : bool, *Node {
    EnsureStyle(*style, "menu_item");

    node := GetNode(parent, location);
    {
        SetLayout(node, .LeftToRight);
        SetChildAlign(node, 0, 0.5);

        if parent.child_layout_mode == .TopToBottom || parent.child_layout_mode == .BottomToTop {
            SetSize(node, SizeFill(), SizeFit());
            SetMinWidthFit(node);
        } else {
            SetSize(node, SizeFit(), SizeFit());
        }

        button := ButtonBehavior(node);
        if button.released {
            CloseMenu(parent);
        }

        state := GetState(node);

        text_node := GetNode(node, "text");
        SetText(text_node, text);

        if selected {
            node.state_flags |= .Active;

            fill := GetNode(node);
            SetSize(fill, SizeFill(), SizeFill());

            size := GetLineHeight(style.button.states[state].text.font, style.button.states[state].text.text_size) * style.checkmark_size;

            checkmark := GetNode(node);
            SetSize(checkmark, SizePx(size), SizePx(size));
            SetDraw(checkmark, DrawCheckmark);
            SetUserData(checkmark, style.checkmark);

            checkmark.state_flags |= node.state_flags;
            Apply(checkmark, style.checkmark);
        }

        Apply(node, style.button.states[state].background);
        Apply(text_node, style.button.states[state].text);

        return button.released, node;
    }
}

MenuData :: struct {
    wants_close : bool;
    parent_menu : *Node;
    submenus : [..]*Node;
}

DestroyMenuData :: (node : *Node, data : *void) {
    using _ := cast(*MenuData, data);
    array_reset(*submenus);
}

CloseMenu :: (node : *Node) {
    data := GetUserData(node, MenuData);
    while data {
        data.wants_close = true;

        node = data.parent_menu;
        data = ifx node then GetUserData(node, MenuData);
    }
}

MenuStyle :: struct {
    using background : BoxStyle;
    min_width_px := 50.0;
    max_width_px := 150.0;
    max_height_px := FLOAT32_INFINITY;
}

Apply :: inline (node : *Node, style : MenuStyle) {
    Apply(node, style.background);

    SetMinWidth(node, style.min_width_px);
    SetMaxWidth(node, style.max_width_px);
    SetMaxHeight(node, style.max_height_px);
}

/**
 * @brief Menu item widget that opens a menu.
 */
Menu :: (
    parent : *Node,
    text : string,
    menu_item_style : *MenuItemStyle = null,
    menu_style : *MenuStyle = null,
    location := #caller_location
) -> menu : *Node, menu_item : *Node {
    EnsureStyle(*menu_item_style, "menu_item");
    EnsureStyle(*menu_style, "menu");

    parent_menu_data := GetUserData(parent, MenuData);

    popup_root := GetPopupRoot(parent.window);
    prev_frame_menu := FindPrevFrameNode(popup_root, GetID(location));
    menu_data := ifx prev_frame_menu then GetUserData(prev_frame_menu, MenuData);

    menu_item := GetNode(parent, location);
    {
        if parent_menu_data {
            SetSize(menu_item, SizeFill(), SizeFit());
        } else {
            SetSize(menu_item, SizeFit(), SizeFit());
        }

        text_node := GetNode(menu_item, "text");
        SetText(text_node, text);

        button := ButtonBehavior(menu_item);
        if button.released || menu_item.state_flags & .ActiveLastFrame {
            menu_item.state_flags |= .Active;
        }

        // Deactivate the menu if we pressed outside the hierarchy of the menu or any submenus
        should_deactivate := IsKeyPressed(.Escape);
        should_deactivate |= menu_data != null && menu_data.wants_close;

        if prev_frame_menu && menu_item.state_flags & .ActiveLastFrame && !(menu_item.state_flags & .Focused) && IsAnyMouseButtonPressed() {
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
            menu_item.state_flags &= ~.Active;
        }

        state := GetState(menu_item);

        Apply(menu_item, menu_item_style.button.states[state].background);
        Apply(text_node, menu_item_style.button.states[state].text);
    }

    menu : *Node;
    if menu_item.state_flags & .Active {
        menu = GetNode(popup_root, location);
        assert(prev_frame_menu == null || menu == prev_frame_menu);
        {
            SetLayout(menu, .TopToBottom);
            SetSize(menu, SizeFit(), SizeFit());

            BringForward(menu);

            menu_data = AddUserData(menu, MenuData, DestroyMenuData);
            array_reset_keeping_memory(*menu_data.submenus);

            if parent_menu_data {
                menu_data.parent_menu = parent;
                array_add(*parent_menu_data.submenus, menu);
                menu.offset = .{menu_item.rect.z, menu_item.rect.y};
            } else {
                menu_data.parent_menu = null;
                menu.offset = .{menu_item.rect.x, menu_item.rect.w};
            }

            Apply(menu, menu_style);
        }
    }

    return menu, menu_item;
}

ContextMenuData :: struct {
    opened : bool;
}

/**
 * @brief Open a menu when right clicking on the Node.
 */
ContextMenu :: (parent : *Node, style : *MenuStyle = null, location := #caller_location) -> *Node {
    EnsureStyle(*style, "menu");

    using _ := AddUserData(parent, ContextMenuData);

    button := ButtonBehavior(parent, .Right);

    popup_root := GetPopupRoot(parent.window);
    prev_frame_menu := FindPrevFrameNode(popup_root, GetID(location));
    menu_data := ifx prev_frame_menu then GetUserData(prev_frame_menu, MenuData);

    should_deactivate := IsKeyPressed(.Escape);
    should_deactivate |= menu_data != null && menu_data.wants_close;

    if button.released {
        opened = true;
    } else if opened && IsAnyMouseButtonPressed() && !IsInTree(context.omg.mouse_hovered_node, prev_frame_menu.id) {
        should_deactivate = true;
    }

    if should_deactivate {
        opened = false;
    }

    menu : *Node;
    if opened {
        menu = GetNode(popup_root, location);
        assert(prev_frame_menu == null || menu == prev_frame_menu);
        {
            SetLayout(menu, .TopToBottom);
            SetSize(menu, SizeFit(), SizeFit());
            SetMinWidth(menu, 50);
            SetMaxWidth(menu, 150);

            BringForward(menu);

            menu_data = AddUserData(menu, MenuData, DestroyMenuData);
            array_reset_keeping_memory(*menu_data.submenus);

            if button.released {
                menu.offset = GetMousePosition(menu.window) - menu.parent.rect.xy;
            }

            Apply(menu, style);
        }
    }

    return menu;
}
