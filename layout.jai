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
    }

    kind : Kind;
    value : float;
}

SizePx :: inline (value : float) -> Size1D {
    return .{kind=.Pixels, value=value};
}

SizeFill :: inline (ratio : float) -> Size1D {
    return .{kind=.FillParent, value=ratio};
}

SizeFit :: inline () -> Size1D {
    return .{kind=.FitChildren};
}

Size2D :: struct {
    x : Size1D;
    y : Size1D;

    #overlay(x)
    axes : [2]Size1D;
}

operator*[] :: inline (size : Size2D, index : int) -> *Size1D {
    return *size.axes[index];
}

operator*[] :: inline (size : Size2D, axis : Axis) -> *Size1D {
    return *size.axes[axis];
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

IsLayoutReverseDirection :: inline (node : *Node) -> bool, float {
    reverse, sign := IsLayoutReverseDirection(node.child_layout_mode);
    return reverse, sign;
}

IsLayoutReverseDirection :: inline (mode : LayoutMode) -> bool, float {
    return mode == .RightToLeft || mode == .BottomToTop, cast(float, mode == .RightToLeft || mode == .BottomToTop) * 2 - 1;
}

// for_expansion
LayoutDirection :: (node : *Node, body : Code, flags : For_Flags) #expand {
    reverse := IsLayoutReverseDirection(node);
    reverse |= flags & .REVERSE != 0;

    `it := ifx reverse then node.last_child else node.first_child;
    `it_index := ifx reverse then node.num_children - 1 else 0;

    while it {
        next := ifx reverse then it.prev_sibling else it.next_sibling;
        defer it = next;

        #insert body;
    }
}

LayoutNodes :: (root : *Node) {
    assert(root.parent == null);
    assert(root.desired_size.x.kind == .Pixels);
    assert(root.desired_size.y.kind == .Pixels);

    LayoutFixedAndFitSizing(root);
    LayoutFillSizing(root);

    root.relative_position = .{0,0};
    root.rect.xy = .{0,0};
    root.rect.zw = root.size;

    LayoutPosition(root);
}

LayoutFixedAndFitSizing :: (node : *Node) {
    axis := GetLayoutAxis(node);
    cross := GetCrossAxis(axis);

    for :Children node {
        LayoutFixedAndFitSizing(it);
        node.children_size[axis] += it.size[axis];
        node.children_size[cross] = max(node.children_size[cross], it.size[cross]);
    }

    if node.flags & .TextNode {
        node.size = CalculateTextSize(node.font, node.text_size, node.text);
        return;
    }

    for axis : Axis.[.X, .Y] {
        if node.desired_size[axis].kind == {
        case .FitChildren;
            node.size[axis] = node.children_size[axis] + 2 * node.padding[axis];
            node.size[axis] = clamp(node.size[axis], node.min_size[axis], node.max_size[axis]);
        case .Pixels;
            node.size[axis] = node.desired_size[axis].value;
            node.size[axis] = clamp(node.size[axis], node.min_size[axis], node.max_size[axis]);
        }
    }

    if node.desired_size[axis].kind == .FitChildren {
        node.size[axis] += (node.num_children - 1) * node.child_gap[axis];
        node.size[axis] = clamp(node.size[axis], node.min_size[axis], node.max_size[axis]);
    }
}

LayoutFillSizing :: (node : *Node) {
    axis := GetLayoutAxis(node);
    cross := GetCrossAxis(axis);

    total_weights := 0.0;
    num_fill_children := 0;
    for :Children node {
        if it.desired_size[axis].kind != .FillParent || it.flags & .TextNode {
            continue;
        }

        total_weights += clamp(it.desired_size[axis].value, 0, 1);

        if abs(it.size[axis] - it.min_size[axis]) < 0.00001 || abs(it.size[axis] - it.max_size[axis]) < 0.00001 {
            continue;
        }

        num_fill_children += 1;
    }

    remaining_size := node.size[axis] - 2 * node.padding[axis]
        - node.children_size[axis]
        - (node.num_children - 1) * node.child_gap[axis];
    iter := 0;
    while iter < 10 && num_fill_children > 0 && abs(remaining_size) > 0.00001 {
        defer iter += 1;

        for :Children node {
            if it.desired_size[axis].kind != .FillParent || it.flags & .TextNode  {
                continue;
            }

            if abs(it.size[axis] - it.min_size[axis]) < 0.00001 || abs(it.size[axis] - it.max_size[axis]) < 0.00001 {
                continue;
            }

            prev_size := it.size[axis];
            if total_weights > 0 {
                it.size[axis] += remaining_size * it.desired_size[axis].value / total_weights;
            }
            it.size[axis] = clamp(it.size[axis], it.min_size[axis], it.max_size[axis]);

            if abs(it.size[axis] - it.min_size[axis]) < 0.00001 || abs(it.size[axis] - it.max_size[axis]) < 0.00001 {
                num_fill_children -= 1;
            }

            added_size := it.size[axis] - prev_size;
            node.children_size[axis] += added_size;
        }

        if total_weights <= 0 {
            break;
        }

        remaining_size = node.size[axis] - 2 * node.padding[axis]
            - node.children_size[axis]
            - (node.num_children - 1) * node.child_gap[axis];
    }

    for :Children node {
        if it.desired_size[cross].kind == .FillParent && !(it.flags & .TextNode) {
            it.size[cross] = node.size[cross] * it.desired_size[cross].value - 2 * node.padding[cross];
            it.size[cross] = clamp(it.size[cross], node.min_size[cross], node.max_size[cross]);
            node.children_size[cross] = max(node.children_size[cross], it.size[cross]);
        }

        LayoutFillSizing(it);
    }
}

LayoutPosition :: (node : *Node) {
    axis := GetLayoutAxis(node);
    cross := GetCrossAxis(axis);
    reverse := IsLayoutReverseDirection(node);

    cursor := ifx reverse then node.size[axis] - node.padding[axis] else node.padding[axis];
    first := true;
    for :LayoutDirection node {
        defer first = false;

        if reverse {
            cursor -= it.size[axis] + node.child_gap[axis] * cast(float, !first);
        }

        it.relative_position[axis] = cursor;
        it.relative_position[cross] = node.padding[cross];

        if !reverse {
            cursor += it.size[axis] + node.child_gap[axis];
        }

        it.rect.xy = node.rect.xy + it.relative_position;
        it.rect.zw = node.rect.xy + it.relative_position + it.size;

        LayoutPosition(it);
    }
}
