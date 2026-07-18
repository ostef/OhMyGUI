GlobalDockSpaceData :: struct {
    subwindow_dock_nodes : HT.Table(ID, ID);
}

DestroyGlobalDockSpaceData :: (_ : *Node, data : *void) {
    using _ := cast(*GlobalDockSpaceData, data);
    HT.deinit(*subwindow_dock_nodes);
}

DockSpaceNodeFlags :: enum_flags u8 {
    CentralNode;
}

DockSpaceData :: struct {
    split : enum u8 {
        None;
        Horizontal;
        Vertical;
    };

    flags : DockSpaceNodeFlags;
    docked_subwindows : [..]ID;
    content : *Node;
    top_dock : *Node;
    bottom_dock : *Node;
    left_dock : *Node;
    right_dock : *Node;
}

DestroyDockSpaceData :: (node : *Node, data : *void) {
    using _ := cast(*DockSpaceData, data);
    array_free(docked_subwindows);
}

GetSubwindowDockNode :: inline (subwindow_str_id : string) -> content : *Node, dock_node : *Node {
    content, dock_node := GetSubwindowDockNode(GetID(subwindow_str_id));
    return content, dock_node;
}

GetSubwindowDockNode :: (subwindow_id : ID) -> content : *Node, dock_node : *Node {
    using global := GetGlobalUserData(GlobalDockSpaceData);
    if !global {
        return null, null;
    }

    exists, dock_id := HT.table_find(*subwindow_dock_nodes, subwindow_id);
    if !exists {
        return null, null;
    }

    exists=, dock_node := HT.table_find(*context.omg.nodes_by_id, dock_id);
    if !exists {
        return null, null;
    }

    data := GetUserData(dock_node, DockSpaceData);
    assert(data != null, "Node is not a dock space");

    return data.content, dock_node;
}

DockSubwindow :: inline (dock_node : *Node, subwindow_str_id : string) -> bool {
    return DockSubwindow(dock_node, GetID(subwindow_str_id));
}

DockSubwindow :: (dock_node : *Node, subwindow_id : ID) -> bool {
    global := AddGlobalUserData(GlobalDockSpaceData, DestroyGlobalDockSpaceData);

    data := GetUserData(dock_node, DockSpaceData);
    assert(data != null, "Node is not a dock space");

    if data.split != .None {
        return false;
    }

    array_add_if_unique(*data.docked_subwindows, subwindow_id);

    dock_id := HT.find_or_add(*global.subwindow_dock_nodes, subwindow_id);
    dock_id.* = dock_node.id;

    return true;
}

UndockSubwindow :: (subwindow_id : ID) {
    global := GetGlobalUserData(GlobalDockSpaceData);
    if !global {
        return;
    }

    _, dock_node := GetSubwindowDockNode(subwindow_id);
    if !dock_node {
        return;
    }

    data := GetUserData(dock_node, DockSpaceData);
    array_ordered_remove_by_value(*data.docked_subwindows, subwindow_id);
    HT.table_remove(*global.subwindow_dock_nodes, subwindow_id);

    RemoveDockSpace(dock_node);
}

RemoveDockSpace :: (dock_node : *Node) {

}

DockSpace :: (parent : *Node, str_id : string, flags : DockSpaceNodeFlags = .CentralNode) -> *Node {
    node := GetNode(parent, str_id);
    {
        data := AddUserData(node, DockSpaceData, DestroyDockSpaceData);
        data.flags = flags;
        data.content = null;
        data.top_dock = null;
        data.bottom_dock = null;
        data.left_dock = null;
        data.right_dock = null;

        SetSize(node, SizeFill(), SizeFill());
        SetBorderColor(node, 0xffffffff);
        SetBorderSize(node, 1);

        if #complete data.split == {
        case .None;
            SetLayout(node, .None);

            data.content = GetNode(node, "content");
            SetSize(data.content, SizeFill(), SizeFill());

            overlay := GetNode(node, "overlay");
            SetSize(overlay, SizeFill(), SizeFill());
            SetLayout(overlay, .TopToBottom);
            SetChildAlign(overlay, 0.5, 0.5);
            SetChildGap(overlay, 10, 10);

            top := GetNode(overlay);
            {
                SetSize(top, SizePx(50), SizePx(40));
                SetBackgroundColor(top, ColorU32(0,0,1,0.5));

                using _ := ButtonBehavior(top);
                if released {
                    data.split = .Horizontal;
                }
            }


            middle := GetNode(overlay);
            SetSize(middle, SizeFill(), SizeFit());
            SetLayout(middle, .LeftToRight);
            SetChildAlign(middle, 0.5, 0.5);
            SetChildGap(middle, 10, 10);

            bottom := GetNode(overlay);
            {
                SetSize(bottom, SizePx(50), SizePx(40));
                SetBackgroundColor(bottom, ColorU32(0,0,1,0.5));

                using _ := ButtonBehavior(bottom);
                if released {
                    data.split = .Horizontal;
                }
            }

            left := GetNode(middle);
            {
                SetSize(left, SizePx(40), SizePx(50));
                SetBackgroundColor(left, ColorU32(0,0,1,0.5));

                using _ := ButtonBehavior(left);
                if released {
                    data.split = .Vertical;
                }
            }

            center := GetNode(middle);
            SetSize(center, SizePx(50), SizePx(50));
            SetBackgroundColor(center, ColorU32(0,0,1,0.5));

            right := GetNode(middle);
            {
                SetSize(right, SizePx(40), SizePx(50));
                SetBackgroundColor(right, ColorU32(0,0,1,0.5));

                using _ := ButtonBehavior(right);
                if released {
                    data.split = .Vertical;
                }
            }

        case .Horizontal;
            SetLayout(node, .TopToBottom);

            data.top_dock = DockSpace(node, "top", 0);

            resize_handle := GetNode(node, "resize");
            SetSize(resize_handle, SizeFill(), SizePx(2));
            SetBackgroundColor(resize_handle, ColorU32(0,1,0,1));

            data.bottom_dock = DockSpace(node, "bottom`", 0);

        case .Vertical;
            SetLayout(node, .LeftToRight);

            data.left_dock = DockSpace(node, "left", 0);

            resize_handle := GetNode(node, "resize");
            SetSize(resize_handle, SizePx(2), SizeFill());
            SetBackgroundColor(resize_handle, ColorU32(0,1,0,1));

            data.right_dock = DockSpace(node, "right`", 0);
        }
    }

    return node;
}

DockLeft :: (dockspace : *Node) -> *Node {
    using data := GetUserData(dockspace, DockSpaceData);
    assert(data != null, "Node is not a dock space");

    if #complete split == {
    case .None;
        split = .Vertical;
        return null;

    case .Horizontal;
        return null;

    case .Vertical;
        if !left_dock {
            return null;
        }

        left_data := GetUserData(left_dock, DockSpaceData);
        assert(left_data != null, "Node is not a dock space");

        return left_data.content;
    }
}
