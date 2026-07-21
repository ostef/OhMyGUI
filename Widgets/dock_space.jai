DockNodeSplitDirection :: enum u8 {
    None;
    Horizontal;
    Vertical;
}

DockNodeSplit :: enum u8 {
    Top;
    Bottom;
    Left;
    Right;
}

DockNode :: struct {
    parent : *DockNode;
    children : [2]*DockNode;
    docked_subwindows : [..]ID;
    split_dir : DockNodeSplitDirection;
    node : *Node;
}

CreateDockNode :: (parent : *DockNode) -> *DockNode {
    node := New(DockNode ,, context.omg.general_purpose_allocator);
    node.parent = parent;
    node.docked_subwindows.allocator = context.omg.general_purpose_allocator;

    return node;
}

FreeDockNode :: (node : *DockNode) {
    array_reset(*node.docked_subwindows);
    free(node ,, context.omg.general_purpose_allocator);
}

DockSubwindow :: inline (node : *DockNode, subwindow_str_id : string) -> bool {
    return DockSubwindow(node, GetID(subwindow_str_id));
}

DockSubwindow :: (node : *DockNode, subwindow_id : ID) -> bool {
    if node.split_dir != .None {
        return false;
    }

    array_add_if_unique(*node.docked_subwindows, subwindow_id);

    return true;
}

SplitDockNode :: (node : *DockNode, split : DockNodeSplit) -> *DockNode {
    split_dir := ifx split == .Top || split == .Bottom then DockNodeSplitDirection.Horizontal else .Vertical;

    if node.split_dir == split_dir {
        return ifx split == .Top || split == .Left then node.children[0] else node.children[1];
    }

    if node.split_dir != .None {
        return null;
    }

    node.split_dir = ifx split == .Top || split == .Bottom then .Horizontal else .Vertical;
    node.children[0] = CreateDockNode(node);
    node.children[1] = CreateDockNode(node);

    split_node := ifx split == .Top || split == .Left then node.children[0] else node.children[1];
    opposite := ifx split == .Top || split == .Left then node.children[1] else node.children[0];

    // Move windows into the opposite side
    swap(*opposite.docked_subwindows, *node.docked_subwindows);

    return split_node;
}

RemoveDockNode :: (node : *DockNode) -> bool {
    if !node.parent {
        return false;
    }

    sibling_index := ifx node.parent.children[0] == node then 0 else 1;
    MergeDockNode(node.parent, sibling_index);
    FreeDockNode(node);

    return true;
}

MergeDockNode :: (parent : *DockNode, child_index : int) -> bool {
    if parent.split_dir == .None {
        return false;
    }

    child := parent.children[child_index];
    parent.split_dir = child.split_dir;
    parent.children[0] = child.children[0];
    parent.children[1] = child.children[1];

    swap(*parent.docked_subwindows, *child.docked_subwindows);
    FreeDockNode(child);

    return true;
}

GlobalDockSpaceData :: struct {
    root_dock_nodes : HT.Table(ID, *DockNode);
}

DestroyGlobalDockSpaceData :: (_ : *Node, data : *void) {
    using _ := cast(*GlobalDockSpaceData, data);
    HT.table_reset(*root_dock_nodes);
}

GetSubwindowDockNode :: inline (subwindow_str_id : string) -> content : *Node, dock_node : *DockNode {
    content, dock_node := GetSubwindowDockNode(GetID(subwindow_str_id));
    return content, dock_node;
}

// @Todo: make this a simple hash map lookup
GetSubwindowDockNode :: (subwindow_id : ID) -> content : *Node, dock_node : *DockNode {
    FindSubwindowDockNode :: (dock_node : *DockNode, subwindow_id : ID) -> *DockNode {
        if dock_node.split_dir == .None {
            for dock_node.docked_subwindows {
                if it == subwindow_id {
                    return dock_node;
                }
            }
        } else {
            for dock_node.children {
                found := FindSubwindowDockNode(it, subwindow_id);
                if found {
                    return found;
                }
            }
        }

        return null;
    }

    global := GetGlobalUserData(GlobalDockSpaceData);
    if !global {
        return null, null;
    }

    for global.root_dock_nodes {
        found := FindSubwindowDockNode(it, subwindow_id);
        if found {
            return ifx found.node then GetNode(found.node, "content"), found;
        }
    }

    return null, null;
}

DockSpace :: (parent : *Node, str_id : string) -> *Node, *DockNode {
    global := AddGlobalUserData(GlobalDockSpaceData, DestroyGlobalDockSpaceData);
    id := GetID(str_id);
    dock_node_ptr := HT.find_or_add(*global.root_dock_nodes, id);

    dock_node := dock_node_ptr.*;
    if !dock_node {
        dock_node = CreateDockNode(null);
        dock_node_ptr.* = dock_node;
    }

    return DockSpace(parent, id, dock_node), dock_node;
}

DockSpace :: (parent : *Node, id : ID, dock_node : *DockNode) -> *Node {
    node := GetNode(parent, id);
    {
        SetSize(node, SizeFill(), SizeFill());
        SetBorderColor(node, 0xffffffff);
        SetBorderSize(node, 1);

        dock_node.node = node;

        if #complete dock_node.split_dir == {
        case .None;
            SetLayout(node, .None);

            content := GetNode(node, "content");
            SetSize(content, SizeFill(), SizeFill());
            SetLayout(content, .TopToBottom);

            TabBar(content);

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
                    SplitDockNode(dock_node, .Top);
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
                    SplitDockNode(dock_node, .Bottom);
                }
            }

            left := GetNode(middle);
            {
                SetSize(left, SizePx(40), SizePx(50));
                SetBackgroundColor(left, ColorU32(0,0,1,0.5));

                using _ := ButtonBehavior(left);
                if released {
                    SplitDockNode(dock_node, .Left);
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
                    SplitDockNode(dock_node, .Right);
                }
            }

        case .Horizontal;
            SetLayout(node, .TopToBottom);

            DockSpace(node, GetID(GetID("top"), id), dock_node.children[0]);

            resize_handle := GetNode(node, "resize");
            SetSize(resize_handle, SizeFill(), SizePx(2));
            SetBackgroundColor(resize_handle, ColorU32(0,1,0,1));

            DockSpace(node, GetID(GetID("bottom"), id), dock_node.children[1]);

        case .Vertical;
            SetLayout(node, .LeftToRight);

            DockSpace(node, GetID(GetID("left"), id), dock_node.children[0]);

            resize_handle := GetNode(node, "resize");
            SetSize(resize_handle, SizePx(2), SizeFill());
            SetBackgroundColor(resize_handle, ColorU32(0,1,0,1));

            DockSpace(node, GetID(GetID("right"), id), dock_node.children[1]);
        }
    }

    return node;
}
