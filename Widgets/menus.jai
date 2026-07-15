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

MenuItem :: (parent : *Node, text : string, selected := false, style : *ButtonStyle = null, location := #caller_location) -> clicked : bool, *Node {
    EnsureStyle(*style, "menu_item");

    node := GetNode(parent, location);
    {
        SetSize(node, SizeFill(), SizeFit());
        SetMinWidthFit(node);

        text_node := GetNode(node, "text");
        SetText(text_node, text);

        if selected {
            node.state_flags |= .Active;
        }

        button := ButtonBehavior(node);

        state := GetState(node);

        Apply(node, style.states[state].background);
        Apply(text_node, style.states[state].text);

        return button.released, node;
    }
}

MenuStyle :: struct {
    using background : BoxStyle;
    max_height_px := FLOAT32_INFINITY;
}

Apply :: inline (node : *Node, style : MenuStyle) {
    Apply(node, style.background);
    SetMaxHeight(node, style.max_height_px);
}

Menu :: (parent : *Node, text : string, menu_item_style : *ButtonStyle = null, menu_style : *MenuStyle = null, location := #caller_location) -> menu : *Node, menu_item : *Node {
    EnsureStyle(*menu_item_style, "menu_item");
    EnsureStyle(*menu_style, "menu");

    popup_root := GetPopupRoot(parent.window);
    menu_id := GetID(GetID(location), popup_root.id);

    menu_item := GetNode(parent, location);
    {
        SetSize(menu_item, SizeFit(), SizeFit());

        text_node := GetNode(menu_item, "text");
        SetText(text_node, text);

        should_deactivate := IsKeyPressed(.Escape);
        if menu_item.state_flags & .ActiveLastFrame && !(menu_item.state_flags & .Focused) && IsAnyMouseButtonPressed() {
            if !IsInTree(context.omg.mouse_hovered_node, menu_id) {
                should_deactivate = true;
            }
        }

        button := ButtonBehavior(menu_item);
        if !should_deactivate && (button.released || menu_item.state_flags & .ActiveLastFrame) {
            menu_item.state_flags |= .Active;
        }

        state := GetState(menu_item);

        Apply(menu_item, menu_item_style.states[state].background);
        Apply(text_node, menu_item_style.states[state].text);
    }

    menu : *Node;
    if menu_item.state_flags & .Active {
        menu = GetPopupNode(parent.window, location);
        {
            SetLayout(menu, .TopToBottom);
            SetSize(menu, SizeFit(), SizeFit());
            SetMinWidth(menu, 50);
            SetMaxWidth(menu, 150);

            BringForward(menu);

            menu.offset = .{menu_item.rect.x, menu_item.rect.w};
            Apply(menu, menu_style);
        }
    }

    return menu, menu_item;
}

SubMenu :: (parent : *Node, text : string, menu_item_style : *ButtonStyle = null, menu_style : *MenuStyle = null, location := #caller_location) -> menu : *Node, menu_item : *Node {
    EnsureStyle(*menu_item_style, "menu_item");
    EnsureStyle(*menu_style, "menu");

    popup_root := GetPopupRoot(parent.window);
    menu_id := GetID(GetID(location), popup_root.id);

    menu_item := GetNode(parent, location);
    {
        SetSize(menu_item, SizeFill(), SizeFit());
        SetMinWidthFit(menu_item);

        text_node := GetNode(menu_item, "text");
        SetText(text_node, text);

        should_deactivate := IsKeyPressed(.Escape);
        if menu_item.state_flags & .ActiveLastFrame && !(menu_item.state_flags & .Focused) && IsAnyMouseButtonPressed() {
            if !IsInTree(context.omg.mouse_hovered_node, menu_id) {
                should_deactivate = true;
            }
        }

        button := ButtonBehavior(menu_item);
        if !should_deactivate && (button.released || menu_item.state_flags & .ActiveLastFrame) {
            menu_item.state_flags |= .Active;
        }

        state := GetState(menu_item);

        Apply(menu_item, menu_item_style.states[state].background);
        Apply(text_node, menu_item_style.states[state].text);
    }

    menu : *Node;
    if menu_item.state_flags & .Active {
        menu = GetPopupNode(parent.window, location);
        {
            SetLayout(menu, .TopToBottom);
            SetSize(menu, SizeFit(), SizeFit());
            SetMinWidth(menu, 50);
            SetMaxWidth(menu, 150);

            BringForward(menu);

            menu.offset = .{menu_item.rect.z, menu_item.rect.y};
            Apply(menu, menu_style);
        }
    }

    return menu, menu_item;
}

ContextMenu :: (parent : *Node, style : *MenuStyle = null, location := #caller_location) -> *Node {
    EnsureStyle(*style, "menu");

    popup_root := GetPopupRoot(parent.window);
    menu_id := GetID(GetID(location), popup_root.id);

    should_deactivate := IsKeyPressed(.Escape);
    if parent.state_flags & .ActiveLastFrame && !(parent.state_flags & .Focused) && IsAnyMouseButtonPressed() {
        if !IsInTree(context.omg.mouse_hovered_node, menu_id) {
            should_deactivate = true;
        }
    }

    button := ButtonBehavior(parent, .Right);
    if !should_deactivate && (button.released || parent.state_flags & .ActiveLastFrame) {
        parent.state_flags |= .Active;
    }

    menu : *Node;
    if parent.state_flags & .Active {
        menu = GetPopupNode(parent.window, location);
        {
            SetLayout(menu, .TopToBottom);
            SetSize(menu, SizeFit(), SizeFit());
            SetMinWidth(menu, 50);
            SetMaxWidth(menu, 150);

            BringForward(menu);

            if button.released {
                menu.offset = GetMousePosition(menu.window) - menu.parent.rect.xy;
            }

            Apply(menu, style);
        }
    }

    return menu;
}
