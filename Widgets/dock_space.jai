DockNodeSplitDirection :: enum u8 {
    None;
    Horizontal;
    Vertical;
}

DockNodeSplit :: enum u8 {
    None;
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

    split_request : DockNodeSplit;
    split_dock_requests : [..]ID;

    show_split_hints : bool;
    show_target_split : bool;
    target_split : DockNodeSplit;

    split_hints : struct {
        left : *Node;
        right : *Node;
        top : *Node;
        bottom : *Node;
        center : *Node;
    };
}

CreateDockNode :: (parent : *DockNode) -> *DockNode {
    node := New(DockNode ,, context.omg.general_purpose_allocator);
    node.parent = parent;
    node.docked_subwindows.allocator = context.omg.general_purpose_allocator;
    node.split_dock_requests.allocator = context.omg.general_purpose_allocator;

    return node;
}

FreeDockNode :: (node : *DockNode) {
    array_reset(*node.docked_subwindows);
    array_reset(*node.split_dock_requests);
    free(node ,, context.omg.general_purpose_allocator);
}

ProcessDockNodeSplitRequests :: () {
    ProcessRequest :: (dock_node : *DockNode) {
        if dock_node.split_request != .None {
            split := SplitDockNode(dock_node, dock_node.split_request);
            if split {
                array_add(*split.docked_subwindows, ..dock_node.split_dock_requests);
            }
        }

        dock_node.split_request = .None;
        array_reset_keeping_memory(*dock_node.split_dock_requests);

        if dock_node.split_dir != .None {
            for dock_node.children {
                ProcessRequest(it);
            }
        }
    }

    global := GetGlobalUserData(GlobalDockSpaceData);
    if !global {
        return;
    }

    for global.root_dock_nodes {
        ProcessRequest(it);
    }
}

RemoveEmptyDockNodes :: () {
    RemoveEmptyDockNodes :: (dock_node : *DockNode) -> bool {
        assert(dock_node != null);

        while dock_node.split_dir != .None {
            has_removed := false;
            for dock_node.children {
                if RemoveEmptyDockNodes(it) {
                    has_removed = true;
                    break;
                }
            }

            if !has_removed {
                break;
            }
        }

        // Not an if-else because split_dir might've been modified by removing a child
        if dock_node.split_dir == .None && dock_node.docked_subwindows.count == 0 {
            return RemoveDockNode(dock_node);
        }

        return false;
    }

    global := GetGlobalUserData(GlobalDockSpaceData);
    if !global {
        return;
    }

    for global.root_dock_nodes {
        RemoveEmptyDockNodes(it);
    }
}

DockSubwindow :: inline (node : *DockNode, subwindow_str_id : string, split : DockNodeSplit = .None) -> bool {
    return DockSubwindow(node, GetID(subwindow_str_id), split);
}

DockSubwindow :: (node : *DockNode, subwindow_id : ID, split : DockNodeSplit = .None) -> bool {
    if node.split_dir != .None {
        return false;
    }

    if split != .None {
        node.split_request = split;
        array_add_if_unique(*node.split_dock_requests, subwindow_id);

        return true;
    }

    array_add_if_unique(*node.docked_subwindows, subwindow_id);

    return true;
}

UndockSubwindow :: (node : *DockNode, subwindow_id : ID) -> bool {
    return array_ordered_remove_by_value(*node.docked_subwindows, subwindow_id);
}

SplitDockNode :: (node : *DockNode, split : DockNodeSplit) -> *DockNode {
    if split == .None {
        return node;
    }

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

    if node.split_dir != .None {
        return false;
    }

    sibling_index := ifx node.parent.children[0] == node then 1 else 0;
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

    for parent.children {
        if it {
            it.parent = parent;
        }
    }

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
    defer {
        dock_node.show_split_hints = false;
        dock_node.show_target_split = false;
        dock_node.target_split = .None;
    }

    node := GetNode(parent, id);
    {
        SetSize(node, SizeFill(), SizeFill());
        SetBorderColor(node, 0xffffffff);
        SetBorderSize(node, 1);

        dock_node.node = node;
        dock_node.split_hints = .{};

        if #complete dock_node.split_dir == {
        case .None;
            SetLayout(node, .None);

            content := GetNode(node, "content");
            SetSize(content, SizeFill(), SizeFill());
            SetLayout(content, .TopToBottom);

            TabBar(content, "docked_subwindows_tab_bar");

            if dock_node.show_target_split {
                color := ColorU32(0,0,1,0.2);

                if dock_node.target_split == .None {
                    target_split := GetNode(node);
                    SetSize(target_split, SizeFill(), SizeFill());
                    SetBackgroundColor(target_split, color);
                } else {
                    horizontal := dock_node.target_split == .Left || dock_node.target_split == .Right;

                    helper := GetNode(node);
                    SetSize(helper, SizeFill(), SizeFill());
                    if horizontal {
                        SetLayout(helper, .LeftToRight);
                    } else {
                        SetLayout(helper, .TopToBottom);
                    }

                    if dock_node.target_split == .Right {
                        SetChildAlign(helper, 1, 0);
                    } else if dock_node.target_split == .Bottom {
                        SetChildAlign(helper, 0, 1);
                    }

                    target_split := GetNode(helper);
                    if horizontal {
                        SetSize(target_split, SizePercent(0.5), SizeFill());
                    } else {
                        SetSize(target_split, SizeFill(), SizePercent(0.5));
                    }

                    SetBackgroundColor(target_split, color);
                }
            }

            split_hints := GetNode(node, "split_hints");
            SetSize(split_hints, SizeFill(), SizeFill());
            SetLayout(split_hints, .TopToBottom);
            SetChildAlign(split_hints, 0.5, 0.5);
            SetChildGap(split_hints, 10, 10);

            split_color := ifx dock_node.show_split_hints then ColorU32(0,0,1,0.5);

            dock_node.split_hints.top = GetNode(split_hints, "top");
            {
                SetSize(dock_node.split_hints.top, SizePx(50), SizePx(40));
                SetBackgroundColor(dock_node.split_hints.top, split_color);
            }

            middle := GetNode(split_hints, "middle");
            SetSize(middle, SizeFill(), SizeFit());
            SetLayout(middle, .LeftToRight);
            SetChildAlign(middle, 0.5, 0.5);
            SetChildGap(middle, 10, 10);

            dock_node.split_hints.bottom = GetNode(split_hints);
            {
                SetSize(dock_node.split_hints.bottom, SizePx(50), SizePx(40));
                SetBackgroundColor(dock_node.split_hints.bottom, split_color);
            }

            dock_node.split_hints.left = GetNode(middle, "left");
            {
                SetSize(dock_node.split_hints.left, SizePx(40), SizePx(50));
                SetBackgroundColor(dock_node.split_hints.left, split_color);
            }

            dock_node.split_hints.center = GetNode(middle, "center");
            SetSize(dock_node.split_hints.center, SizePx(50), SizePx(50));
            SetBackgroundColor(dock_node.split_hints.center, split_color);

            dock_node.split_hints.right = GetNode(middle, "right");
            {
                SetSize(dock_node.split_hints.right, SizePx(40), SizePx(50));
                SetBackgroundColor(dock_node.split_hints.right, split_color);
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

GetHoveredDockSpaceAndSplit :: () -> *DockNode, is_hovering_split : bool, DockNodeSplit {
    FindHoveredDockSpaceAndSplit :: (dock_node : *DockNode, mouse_position : Vec2f) -> *DockNode, bool, DockNodeSplit {
        if dock_node.split_dir == .None {
            if IsHovered(dock_node.split_hints.left) {
                return dock_node, true, .Left;
            }
            if IsHovered(dock_node.split_hints.right) {
                return dock_node, true, .Right;
            }
            if IsHovered(dock_node.split_hints.top) {
                return dock_node, true, .Top;
            }
            if IsHovered(dock_node.split_hints.bottom) {
                return dock_node, true, .Bottom;
            }
            if IsHovered(dock_node.split_hints.center) {
                return dock_node, true, .None;
            }

            if IsHovered(dock_node.node) {
                return dock_node, false, .None;
            }
        } else {
            for dock_node.children {
                hovered, is_hovering_split, split := FindHoveredDockSpaceAndSplit(it, mouse_position);
                if hovered {
                    return hovered, is_hovering_split, split;
                }
            }
        }

        return null, false, .None;
    }

    global := GetGlobalUserData(GlobalDockSpaceData);
    if !global {
        return null, false, .None;
    }

    mouse_position := GetMousePosition();

    for global.root_dock_nodes {
        hovered, is_hovering_split, split := FindHoveredDockSpaceAndSplit(it, mouse_position);
        if hovered {
            return hovered, is_hovering_split, split;
        }
    }

    return null, false, .None;
}
