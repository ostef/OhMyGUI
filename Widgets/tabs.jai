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

TabBar :: inline (parent : *Node, str_id : string, style : *BoxStyle = null) -> *Node {
    return TabBar(parent, GetID(str_id), style);
}

TabBar :: inline (parent : *Node, style : *BoxStyle = null, location := #caller_location) -> *Node {
    return TabBar(parent, GetID(location), style);
}

TabBar :: (parent : *Node, local_id : ID, style : *BoxStyle = null) -> *Node {
    EnsureStyle(*style, "tab_bar");

    node := GetNode(parent, local_id);
    {
        SetSize(node, SizeFill(), SizeFit());
        node.flags |= .SortChildren;

        data := GetTabBarData(node.id);

        if data.next_active_tab {
            data.active_tab = data.next_active_tab;
            data.next_active_tab = 0;
        } else {
            data.active_tab = 0;
        }

        Apply(node, style);
    }

    return node;
}

Tab :: (parent : *Node, label : string, str_id : string, style : *ButtonStyle = null) -> bool, *Node {
    EnsureStyle(*style, "tab");

    node, is_new := GetNode(parent, str_id);
    {
        SetSize(node, SizeFit(), SizeFit());

        if is_new {
            BringForward(node);
        }

        data := GetTabBarData(parent.id);

        if data && data.active_tab == 0 {
            data.active_tab = node.id;
            data.next_active_tab = node.id;
        }

        using _ := ButtonBehavior(node);
        if released && data {
            data.next_active_tab = node.id;
        }

        active := data && data.active_tab == node.id;
        if active {
            node.state_flags |= .Active;
            if !data.next_active_tab {
                data.next_active_tab = node.id;
            }
        }

        state := GetState(node);

        Apply(node, style.states[state].background);
        Text(node, "%", label, style=*style.states[state].text);

        return active, node;
    }
}
