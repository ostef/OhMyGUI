Axis :: enum u8 {
    X;
    Y;
}

AxisFlags :: enum_flags u8 {
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

SizeFill :: inline (ratio := 1.0) -> Size1D {
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
    root.clipped_rect = root.rect;

    LayoutPosition(root);
}

LayoutFixedAndFitSizing :: (node : *Node) {
    axis := GetLayoutAxis(node);
    cross := GetCrossAxis(axis);

    for :Children node {
        LayoutFixedAndFitSizing(it);

        if node.child_layout_mode != .None {
            node.children_size[axis] += it.size[axis];
            node.children_size[cross] = max(node.children_size[cross], it.size[cross]);
        }
    }

    text_size : Vec2f;
    if node.flags & .TextNode && (node.desired_size.x.kind == .FitChildren || node.desired_size.y.kind == .FitChildren) {
        text_size = CalculateTextSize(node.font, node.text_size, node.text);
    }

    for axis : Axis.[.X, .Y] {
        if node.desired_size[axis].kind == {
        case .FitChildren;
            if node.flags & .TextNode {
                node.size[axis] = ceil(text_size[axis]);
            } else {
                node.size[axis] = ceil(node.children_size[axis] + node.padding.xy[axis] + node.padding.zw[axis]);
            }
            node.size[axis] = clamp(node.size[axis], node.min_size[axis], node.max_size[axis]);
        case .Pixels;
            node.size[axis] = node.desired_size[axis].value;
            node.size[axis] = clamp(node.size[axis], node.min_size[axis], node.max_size[axis]);
        }
    }

    if node.desired_size[axis].kind == .FitChildren && !(node.flags & .TextNode) {
        node.size[axis] += ceil((node.num_children - 1) * node.child_gap[axis]);
        node.size[axis] = clamp(node.size[axis], node.min_size[axis], node.max_size[axis]);
    }
}

// @Todo: the behavior does not seem to be the most intuitive: 2 fill children with weight 1 and 1 will both have the same
// size of half the available area, because the weights are normalized. If the weights are 2 and 2 the result will be the same.
// It's likely people will expect instead that both children will be 100% of the available area, and overflow outside the
// parent's rect
LayoutFillSizing :: (node : *Node) {
    axis := GetLayoutAxis(node);
    cross := GetCrossAxis(axis);

    if node.child_layout_mode == .None {
        remaining_size := node.size[axis] - node.padding.xy[axis] - node.padding.zw[axis]
            - node.children_size[axis]
            - (node.num_children - 1) * node.child_gap[axis];
        remaining_size = floor(remaining_size);
        for :Children node {
            if it.desired_size[axis].kind != .FillParent {
                continue;
            }

            prev_size := it.size[axis];
            it.size[axis] = floor(remaining_size * it.desired_size[axis].value);
            it.size[axis] = clamp(it.size[axis], it.min_size[axis], it.max_size[axis]);
        }
    } else {
        total_weights := 0.0;
        num_fill_children := 0;
        for :Children node {
            if it.desired_size[axis].kind != .FillParent {
                continue;
            }

            total_weights += clamp(it.desired_size[axis].value, 0, 1);

            if abs(it.size[axis] - it.min_size[axis]) < 0.00001 || abs(it.size[axis] - it.max_size[axis]) < 0.00001 {
                continue;
            }

            num_fill_children += 1;
        }

        remaining_size := node.size[axis] - node.padding.xy[axis] - node.padding.zw[axis]
            - node.children_size[axis]
            - (node.num_children - 1) * node.child_gap[axis];
        remaining_size = floor(remaining_size);
        iter := 0;
        while iter < 10 && num_fill_children > 0 && abs(remaining_size) > 0.00001 {
            defer iter += 1;

            for :Children node {
                if it.desired_size[axis].kind != .FillParent  {
                    continue;
                }

                if abs(it.size[axis] - it.min_size[axis]) < 0.00001 || abs(it.size[axis] - it.max_size[axis]) < 0.00001 {
                    continue;
                }

                prev_size := it.size[axis];
                if total_weights > 0 {
                    it.size[axis] += floor(remaining_size * it.desired_size[axis].value / total_weights);
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

            remaining_size = node.size[axis] - node.padding.xy[axis] - node.padding.zw[axis]
                - node.children_size[axis]
                - (node.num_children - 1) * node.child_gap[axis];
            remaining_size = floor(remaining_size);
        }
    }

    for :Children node {
        if it.desired_size[cross].kind == .FillParent {
            it.size[cross] = floor(node.size[cross] * it.desired_size[cross].value - node.padding.xy[cross] - node.padding.zw[cross]);
            it.size[cross] = clamp(it.size[cross], node.min_size[cross], node.max_size[cross]);
            node.children_size[cross] = max(node.children_size[cross], it.size[cross]);
        }

        LayoutFillSizing(it);
    }
}

LayoutPosition :: (node : *Node) {
    axis := GetLayoutAxis(node);
    cross := GetCrossAxis(axis);
    no_positioning := node.child_layout_mode == .None;
    reverse := IsLayoutReverseDirection(node);

    remaining_size := node.size[axis] - node.padding.xy[axis] - node.padding.zw[axis]
            - node.children_size[axis]
            - (node.num_children - 1) * node.child_gap[axis];
    axis_align_offset := remaining_size * node.child_align[axis];
    cross_size := node.size[cross] - node.padding.xy[cross] - node.padding.zw[cross];

    cursor := ifx reverse then floor(node.size[axis] - node.padding.zw[axis] - axis_align_offset + node.scroll[axis]) else ceil(node.padding.xy[axis] + axis_align_offset + node.scroll[axis]);
    first := true;
    for :LayoutDirection node {
        defer first = false;

        if !no_positioning && reverse {
            cursor -= it.size[axis] + node.child_gap[axis] * cast(float, !first);
            cursor = floor(cursor);
        }

        it.relative_position[axis] = cursor;
        it.relative_position[cross] = ceil(node.padding.xy[cross] + (cross_size - it.size[cross]) * node.child_align[cross]);

        if !no_positioning && !reverse {
            cursor += it.size[axis] + node.child_gap[axis];
            cursor = ceil(cursor);
        }

        it.relative_position += Round(it.offset);

        it.rect.xy = node.rect.xy + it.relative_position;
        it.rect.zw = node.rect.xy + it.relative_position + it.size;
        it.clipped_rect = ClipRect(it.rect, node.rect);

        LayoutPosition(it);
    }
}
