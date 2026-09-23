// @Todo: reorder tabs
// @Todo: close tabs

GlobalTabBarData :: struct {
    tab_bars : HT.Table(ID, *TabBarData);
}

DestroyGlobalTabBarData :: (node : *Node, data : *void) {
    using _ := cast(*GlobalTabBarData, data);
    for tab_bars {
        free(it ,, context.omg.general_purpose_allocator);
    }

    HT.table_reset(*tab_bars);
}

GetTabBarData :: (id : ID) -> *TabBarData {
    global := AddGlobalUserData(GlobalTabBarData, DestroyGlobalTabBarData);
    if !global.tab_bars.allocator.proc {
        global.tab_bars.allocator = context.omg.general_purpose_allocator;
    }

    ptr := HT.find_or_add(*global.tab_bars, id);
    if !ptr.* {
        ptr.* = New(TabBarData ,, context.omg.general_purpose_allocator);
    }

    return ptr.*;
}

TabBarData :: struct {
    active_tab : ID;
    next_active_tab : ID;
}

/**
 * @brief Tab bar widget
 *
 * @see Tab
 */
TabBar :: inline (parent : *Node, str_id : string, style : *BoxStyle = null) -> *Node {
    return TabBar(parent, GetID(str_id), style);
}

/**
 * @brief Tab bar widget
 *
 * @see Tab
 */
TabBar :: inline (parent : *Node, style : *BoxStyle = null, location := #caller_location) -> *Node {
    return TabBar(parent, GetID(location), style);
}

/**
 * @brief Tab bar widget
 *
 * @see Tab
 */
TabBar :: (parent : *Node, local_id : ID, style : *BoxStyle = null) -> *Node {
    EnsureStyle(*style, "tab_bar");

    node := GetNode(parent, local_id);
    {
        SetSize(node, SizeFill(), SizeFit());
        node.flags |= .SortChildren;

        data := GetTabBarData(node.id);
        data.active_tab = data.next_active_tab;
        data.next_active_tab = 0;

        Apply(node, style);
    }

    return node;
}

/**
 * @brief Tab widget
 *
 * @see TabBar
 */
Tab :: (parent : *Node, label : string, str_id : string, style : *ButtonStyle = null) -> bool, *Node {
    EnsureStyle(*style, "tab");

    node, is_new := GetNode(parent, str_id);
    {
        SetSize(node, SizeFit(), SizeFit());

        // z_index must be even to leave room when we move tabs
        node.z_index *= 2;

        if is_new {
            BringForward(node);
        }

        data := GetTabBarData(parent.id);
        assert(data != null);

        if data && data.active_tab == 0 {
            data.active_tab = node.id;
            data.next_active_tab = node.id;
        }

        using _ := ButtonBehavior(node);

        // Activate tab
        if pressed && data {
            // Set the active tab next frame and not the current frame, otherwise
            // we can get two active tabs at the same time
            data.next_active_tab = node.id;
        }

        // Move tab
        if down {
            mouse := GetMousePosition(node.window);
            prev := node.tree_last_frame.prev_sibling;

            // Move the tab left only if the mouse enters where the rect would be,
            // otherwise it can cause the tab to move left then right then left...
            // each frame
            if prev {
                prev_limit := prev.rect.x + node.size.x;
                if mouse.x < prev_limit {
                    node.z_index -= 3;
                }
            }

            if mouse.x > node.rect.z {
                node.z_index += 3;
            }
        }

        active := data && data.active_tab == node.id;
        if active {
            node.state_flags |= .Active;

            // Keep the tab active for the next frame unless another tab wants to be active
            if data.next_active_tab == 0 {
                data.next_active_tab = node.id;
            }
        }

        state := GetState(node);

        Apply(node, style.states[state].background);
        Text(node, "%", label, style=*style.states[state].text);

        return active, node;
    }
}
