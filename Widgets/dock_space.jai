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
    fill_ratio := 0.5;

    // Was this node created by a window being docked?
    // If that's the case we want to remove the node when it becomes empty, otherwise it should stay empty
    created_by_docking : bool;
    split_request : DockNodeSplit;
    split_dock_requests : [..]ID;

    show_split_hints : bool;
    show_target_split : bool;
    target_split : DockNodeSplit;

    node : *Node;
    tab_bar : *Node;
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
                split.created_by_docking = true;
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

        if dock_node.split_dir != .None {
            child0_empty := dock_node.children[0].split_dir == .None && dock_node.children[0].docked_subwindows.count == 0;
            child1_empty := dock_node.children[1].split_dir == .None && dock_node.children[1].docked_subwindows.count == 0;
            if child0_empty && child1_empty {
                FreeDockNode(dock_node.children[0]);
                FreeDockNode(dock_node.children[1]);

                dock_node.children[0] = null;
                dock_node.children[1] = null;
                dock_node.split_dir = .None;
            }
        }

        // Not an if-else because split_dir might've been modified by removing a child
        if dock_node.split_dir == .None && dock_node.created_by_docking && dock_node.docked_subwindows.count == 0 {
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

DockSpaceStyle :: struct {
    tab_bar : BoxStyle;
    tab : ButtonStyle;
    background : BoxStyle;
    target_split : BoxStyle;
    split_hint : BoxStyle;
}

DockSpace :: (parent : *Node, str_id : string, style : *DockSpaceStyle = null) -> *Node, *DockNode {
    global := AddGlobalUserData(GlobalDockSpaceData, DestroyGlobalDockSpaceData);
    id := GetID(str_id);
    dock_node_ptr := HT.find_or_add(*global.root_dock_nodes, id);

    dock_node := dock_node_ptr.*;
    if !dock_node {
        dock_node = CreateDockNode(null);
        dock_node_ptr.* = dock_node;
    }

    return DockSpace(parent, id, dock_node, style), dock_node;
}

DockSpace :: (parent : *Node, id : ID, dock_node : *DockNode, style : *DockSpaceStyle = null) -> *Node {
    EnsureStyle(*style, "dock_space");

    defer {
        dock_node.show_split_hints = false;
        dock_node.show_target_split = false;
        dock_node.target_split = .None;
    }

    node := GetNode(parent, id);
    {
        if dock_node.parent && dock_node.parent.split_dir != .None {
            fill_value := ifx dock_node == dock_node.parent.children[0]
                then dock_node.parent.fill_ratio
                else 1 - dock_node.parent.fill_ratio;

            if dock_node.parent.split_dir == .Horizontal {
                SetSize(node, SizeFill(), SizeFill(fill_value));
            } else {
                SetSize(node, SizeFill(fill_value), SizeFill());
            }
        } else {
            SetSize(node, SizeFill(), SizeFill());
        }

        Apply(node, style.background);

        dock_node.node = node;
        dock_node.tab_bar = null;
        dock_node.split_hints = .{};

        ResizeHandle :: (node : *Node, dock_node : *DockNode, axis : Axis) -> *Node {
            cross := GetCrossAxis(axis);

            resize_handle := GetNode(node, "resize_handle");
            resize_handle.desired_size[axis] = SizePx(5);
            resize_handle.desired_size[cross] = SizeFill();
            SetBackgroundColor(resize_handle, ColorU32(0,1,0,1));

            resize := ButtonBehavior(resize_handle);
            if resize.held {
                resize_handle.state_flags |= .Active;

                offset := GetMousePosition(node.window)[axis] - node.rect.xy[axis];
                offset = clamp(offset, 32, node.size[axis] - 32);
                dock_node.fill_ratio = offset / node.size[axis];
            }

            return resize_handle;
        }

        if #complete dock_node.split_dir == {
        case .None;
            SetLayout(node, .None);

            content := GetNode(node, "content");
            SetSize(content, SizeFill(), SizeFill());
            SetLayout(content, .TopToBottom);

            dock_node.tab_bar = TabBar(content, "docked_subwindows_tab_bar", style=*style.tab_bar);

            if dock_node.show_target_split {
                if dock_node.target_split == .None {
                    target_split := GetNode(node);
                    SetSize(target_split, SizeFill(), SizeFill());

                    Apply(target_split, style.target_split);
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

                    Apply(target_split, style.target_split);
                }
            }

            split_hints := GetNode(node, "split_hints");
            split_hints.flags |= .NoClip;

            SetSize(split_hints, SizeFill(), SizeFill());
            SetLayout(split_hints, .TopToBottom);
            SetChildAlign(split_hints, 0.5, 0.5);
            SetChildGap(split_hints, 10, 10);

            split_hint_style := ifx dock_node.show_split_hints then style.split_hint;

            dock_node.split_hints.top = GetNode(split_hints, "top");
            {
                SetSize(dock_node.split_hints.top, SizePx(50), SizePx(40));
                Apply(dock_node.split_hints.top, split_hint_style);
            }

            middle := GetNode(split_hints, "middle");
            middle.flags |= .NoClip;

            SetSize(middle, SizeFill(), SizeFit());
            SetLayout(middle, .LeftToRight);
            SetChildAlign(middle, 0.5, 0.5);
            SetChildGap(middle, 10, 10);

            dock_node.split_hints.bottom = GetNode(split_hints);
            {
                SetSize(dock_node.split_hints.bottom, SizePx(50), SizePx(40));

                Apply(dock_node.split_hints.bottom, split_hint_style);
            }

            dock_node.split_hints.left = GetNode(middle, "left");
            {
                SetSize(dock_node.split_hints.left, SizePx(40), SizePx(50));
                Apply(dock_node.split_hints.left, split_hint_style);
            }

            dock_node.split_hints.center = GetNode(middle, "center");
            SetSize(dock_node.split_hints.center, SizePx(50), SizePx(50));
            Apply(dock_node.split_hints.center, split_hint_style);

            dock_node.split_hints.right = GetNode(middle, "right");
            {
                SetSize(dock_node.split_hints.right, SizePx(40), SizePx(50));
                Apply(dock_node.split_hints.right, split_hint_style);
            }

        case .Horizontal;
            SetLayout(node, .TopToBottom);

            DockSpace(node, GetID(GetID("top"), id), dock_node.children[0], style);

            ResizeHandle(node, dock_node, .Y);

            DockSpace(node, GetID(GetID("bottom"), id), dock_node.children[1], style);

        case .Vertical;
            SetLayout(node, .LeftToRight);

            DockSpace(node, GetID(GetID("left"), id), dock_node.children[0], style);

            ResizeHandle(node, dock_node, .X);

            DockSpace(node, GetID(GetID("right"), id), dock_node.children[1], style);
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
            if dock_node.tab_bar && IsHovered(dock_node.tab_bar) {
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
