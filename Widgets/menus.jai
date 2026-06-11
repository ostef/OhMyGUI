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

MenuItem :: (parent : *Node, text : string, style : *ButtonStyle = null, location := #caller_location) -> clicked : bool, *Node {
    EnsureStyle(*style, "menu_item");

    node := GetNode(parent, location);
    {
        SetSize(node, SizeFill(), SizeFit());
        SetMinWidthFit(node, true);

        text_node := GetNode(node, "text");
        SetText(text_node, text);

        button := ButtonBehavior(node);

        state := GetState(node);

        Apply(node, style.states[state].background);
        Apply(text_node, style.states[state].text);

        return button.released, node;
    }
}

Menu :: (parent : *Node, text : string, menu_item_style : *ButtonStyle = null, menu_style : *BoxStyle = null, location := #caller_location) -> menu : *Node, menu_item : *Node {
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
        if menu_item.state_flags & .ActiveLastFrame && !(menu_item.state_flags & .Focused) && IsMouseButtonPressed(.Left) {
            // Traverse the node tree to make sure we are not an ancestor to the focused node
            // If we are an ancestor, we don't deactivate the menu
            found_menu := false;

            ancestor := context.omg.mouse_hovered_node;
            while ancestor {
                if ancestor.id == menu_id {
                    found_menu = true;
                    break;
                }

                ancestor = ancestor.parent;
            }

            if !found_menu {
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
            SetMinSize(menu, 50, 0);
            SetMaxSize(menu, 150, 200);

            menu.offset = .{menu_item.layout_last_frame.rect.x, menu_item.layout_last_frame.rect.w};
            Apply(menu, menu_style);
        }
    }

    return menu, menu_item;
}
