Axis :: enum u8 {
    X;
    Y;
}

GetCrossAxis :: inline (axis : Axis) -> Axis {
    return ifx axis == .X then .Y else .X;
}

Size1D :: struct {
    Kind :: enum u8 {
        Pixels;
        FillParent;
        FitChildren;
        Text;
    }

    kind : Kind;
    value : float;
}

SizePx :: inline (value : float) -> Size1D {
    return .{.Pixels, value};
}

SizeFillParent :: inline (ratio : float) -> Size1D {
    return .{.FillParent, ratio};
}

SizeFitChildren :: inline (ratio : float) -> Size1D {
    return .{.FitChildren, ratio};
}

Size2D :: struct {
    x : Size1D;
    y : Size1D;

    #overlay(x)
    axes : [2]Size1D;
}

LayoutMode :: enum u8 {
    None;
    LeftToRight;
    RightToLeft;
    TopToBottom;
    BottomToTop;
}

GetLayoutAxis :: inline (node : *Node) -> Axis {
    return GetLayoutAxis(node.child_layout_mode);
}

GetLayoutAxis :: inline (mode : LayoutMode) -> Axis {
    if mode == .TopToBottom || mode == .BottomToTop {
        return .Y;
    } else {
        return .X;
    }
}

// for_expansion
LayoutChildren :: (node : *Node, body : Code, flags : For_Flags) #expand {
    reverse := node.layout_mode == .RightToLeft || node.layout_mode == .BottomToTop;
    reverse |= flags & .REVERSE != 0;

    `it := ifx reverse then node.last_child else node.first_child;
    `it_index := ifx reverse then node.num_children - 1 else 0;

    while it {
        next := ifx reverse then it.prev_sibling else it.next_sibling;
        defer it = next;

        #insert body;
    }
}

CalcSize :: (parent : *Node, axis : Axis, size : Size2D) -> float, bool {
    if size.axes[axis].kind == {
    case .Pixels;
        return size.axes[axis].value, true;

    case .FillParent;
        if parent {
            return parent.size[axis] * size.axes[axis].value, true;
        }
    }

    return 0, false;
}

CalcSize :: (node : *Node, axis : Axis) -> bool {
    calculated : bool;
    node.size[axis], calculated = CalcSize(node.parent, axis, node.desired_size);
    if !calculated {
        return false;
    }

    min_size := CalcSize(node.parent, axis, node.min_size);
    max_size := CalcSize(node.parent, axis, node.max_size);
    node.size[axis] = clamp(node.size[axis], min_size, max_size);

    node.rect.zw[axis] = node.rect.xy[axis] + node.size[axis];

    return true;
}

CalcSize :: inline (node : *Node) {
    node.rect.xy = node.relative_position;

    CalcSize(node, .X);
    CalcSize(node, .Y);
}

LayoutNodes :: (node : *Node) {
    if node.child_layout_mode == .None {
        CalcSize(node);

        for :Children node {
            it.relative_position = it.offset;
            LayoutNodes(it);
        }

        return;
    }

    CalcSize(node);

    axis := GetLayoutAxis(node);
    cross := GetCrossAxis(axis);

    cursor := Vec2f.{};
    max_cross_size : float;
    for :Children node {
        it.relative_position = cursor;
        LayoutNodes(it);

        cursor[axis] += it.size[axis];
        max_cross_size = max(max_cross_size, it.size[opposite]);
    }
}

MakeRectsAbsolute :: (node : *Node) {
    for :Children node {
        it.rect.xy += node.rect.xy;
        it.rect.zw += node.rect.xy;
        MakeRectsAbsolute(it);
    }
}
