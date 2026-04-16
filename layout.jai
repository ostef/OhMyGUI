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
    return .{kind=.Pixels, value=value};
}

SizeFillParent :: inline (ratio : float) -> Size1D {
    return .{kind=.FillParent, value=ratio};
}

SizeFitChildren :: inline () -> Size1D {
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
        node.content_size[axis] += it.size[axis];
        node.content_size[cross] = max(node.content_size[cross], it.size[cross]);
    }

    for axis : Axis.[.X, .Y] {
        if node.desired_size[axis].kind == {
        case .FitChildren;
            node.size[axis] = node.content_size[axis];
        case .Pixels;
            node.size[axis] = node.desired_size[axis].value;
        }
    }
}

LayoutFillSizing :: (node : *Node) {
    axis := GetLayoutAxis(node);
    cross := GetCrossAxis(axis);

    remaining_size := node.size[axis] - node.content_size[axis];
    while remaining_size > 0 {
        to_add := remaining_size;
        smallest := FLOAT32_INFINITY;
        second_smallest := FLOAT32_INFINITY;
        num_fill_children := 0;
        for :Children node {
            if it.desired_size[axis].kind != .FillParent {
                continue;
            }

            if smallest == FLOAT32_INFINITY {
                smallest = it.size[axis];
            } else if it.size[axis] < smallest {
                second_smallest = smallest;
                smallest = it.size[axis];
            } else if it.size[axis] > smallest {
                second_smallest = min(second_smallest, it.size[axis]);
                to_add = second_smallest - smallest;
            }

            num_fill_children += 1;
        }

        if num_fill_children == 0 {
            break;
        }

        to_add = min(to_add, remaining_size / num_fill_children);

        for :Children node {
            if it.desired_size[axis].kind != .FillParent {
                continue;
            }

            if it.size[axis] == smallest {
                it.size[axis] += to_add;
                node.content_size[axis] += to_add;
                remaining_size -= to_add;
            }
        }
    }

    for :Children node {
        if it.desired_size[cross].kind == .FillParent {
            it.size[cross] = node.size[cross];
        }

        LayoutFillSizing(it);
    }
}

LayoutPosition :: (node : *Node) {
    axis := GetLayoutAxis(node);
    cross := GetCrossAxis(axis);
    reverse := IsLayoutReverseDirection(node);

    cursor := ifx reverse then node.size[axis] else 0;
    for :LayoutDirection node {
        if reverse {
            cursor -= it.size[axis];
        }

        it.relative_position[axis] = cursor;

        if !reverse {
            cursor += it.size[axis];
        }

        it.rect.xy = node.rect.xy + it.relative_position;
        it.rect.zw = node.rect.xy + it.relative_position + it.size;

        LayoutPosition(it);
    }
}
