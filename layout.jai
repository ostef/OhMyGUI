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
        ParentPercent;
        FillParent;
        FitChildren;
    }

    kind : Kind;
    value : float;
}

SizePx :: inline (value : float) -> Size1D {
    return .{kind=.Pixels, value=value};
}

SizePercent :: inline (value : float) -> Size1D {
    return .{kind=.ParentPercent, value=value};
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

MergeSort :: (first : *Node) -> *Node {
    Split :: (first : *Node) -> *Node {
        fast := first;
        slow := first;

        // Fast moves twice as fast as slow, so when fast reaches the end
        // slow is at the middle
        while fast && fast.next_sibling && fast.next_sibling.next_sibling {
            fast = fast.next_sibling.next_sibling;
            slow = slow.next_sibling;
        }

        tmp := slow.next_sibling;
        slow.next_sibling = null;
        if tmp {
            tmp.prev_sibling = null;
        }

        return tmp;
    }

    Merge :: (first : *Node, second : *Node) -> *Node {
        if !first {
            return second;
        }
        if !second {
            return first;
        }

        if first.z_index < second.z_index {
            first.next_sibling = Merge(first.next_sibling, second);
            if first.next_sibling {
                first.next_sibling.prev_sibling = first;
            }
            first.prev_sibling = null;

            return first;
        } else {
            second.next_sibling = Merge(first, second.next_sibling);
            if second.next_sibling {
                second.next_sibling.prev_sibling = second;
            }
            second.prev_sibling = null;

            return second;
        }
    }

    if !first || !first.next_sibling {
        return first;
    }

    second := Split(first);

    first = MergeSort(first);
    second = MergeSort(second);

    return Merge(first, second);
}

SortChildren :: (node : *Node) {
    if node.flags & .SortChildren {
        node.first_child = MergeSort(node.first_child);

        index : s32 = 0;
        node.last_child = node.first_child;
        while node.last_child && node.last_child.next_sibling {
            node.last_child.z_index = index;
            index += 1;

            node.last_child = node.last_child.next_sibling;
        }

        if node.last_child {
            node.last_child.z_index = index;
        }
    }

    for :Children node {
        SortChildren(it);
    }
}

LayoutNodes :: (root : *Node) {
    assert(root.parent == null);
    assert(root.desired_size.x.kind == .Pixels);
    assert(root.desired_size.y.kind == .Pixels);

    SortChildren(root);

    LayoutFixedAndFitSizing(root, .X);
    LayoutFillAndPercentSizing(root, .X);

    LayoutWrapText(root);

    LayoutFixedAndFitSizing(root, .Y);
    LayoutFillAndPercentSizing(root, .Y);

    root.relative_position = .{0,0};
    root.rect.xy = .{0,0};
    root.rect.zw = root.size;
    root.clipped_rect = root.rect;

    LayoutPosition(root);
}

LayoutFixedAndFitSizing :: (node : *Node, axis : Axis) {
    layout_axis := GetLayoutAxis(node);

    for :Children node {
        LayoutFixedAndFitSizing(it, axis);

        if node.child_layout_mode != .None && layout_axis == axis {
            node.children_size[axis] += it.size[axis];
        } else {
            node.children_size[axis] = max(node.children_size[axis], it.size[axis]);
        }
    }

    text_size : Vec2f;
    if (node.flags & .TextNode) && (axis == .X || !(node.flags & .WrapText)) && node.desired_size[axis].kind == .FitChildren {
        text_size = CalculateTextSize(node.font, node.text_size, node.text);
    }

    if node.min_size_fit & xx (1 << axis) {
        node.min_size[axis] = ceil(node.children_size[axis] + node.padding.xy[axis] + node.padding.zw[axis]);
    }

    // We should set the size to fit also if min size is set to fit and we want to fill the parent
    // We need this because otherwise a we can't have a parent that wants to fit with children that wants to fill with a min size of fit
    should_fit := node.desired_size[axis].kind == .FitChildren || (node.desired_size[axis].kind == .FillParent && (node.min_size_fit & xx (1 << axis)) != 0);

    if should_fit {
        if node.flags & .TextNode {
            if axis == .X || !(node.flags & .WrapText) {
                node.size[axis] = ceil(text_size[axis]);
            }
        } else {
            node.size[axis] = ceil(node.children_size[axis] + node.padding.xy[axis] + node.padding.zw[axis]);
        }
        node.size[axis] = clamp(node.size[axis], node.min_size[axis], node.max_size[axis]);
    } else if node.desired_size[axis].kind == .Pixels {
        node.size[axis] = node.desired_size[axis].value;
        node.size[axis] = clamp(node.size[axis], node.min_size[axis], node.max_size[axis]);
    }

    // Add child gap
    if node.child_layout_mode != .None && layout_axis == axis && should_fit && !(node.flags & .TextNode) {
        node.size[axis] += ceil((node.num_children - 1) * cast(float, node.child_gap[axis]));
        node.size[axis] = clamp(node.size[axis], node.min_size[axis], node.max_size[axis]);
    }
}

LayoutFillAndPercentSizing :: (node : *Node, axis : Axis) {
    layout_axis := GetLayoutAxis(node);

    for :Children node {
        if it.desired_size[axis].kind != .ParentPercent {
            continue;
        }

        prev_size := it.size[axis];

        it.size[axis] = max(it.desired_size[axis].value * (node.size[axis] - node.padding.xy[axis] - node.padding.zw[axis]), prev_size);
        it.size[axis] = clamp(it.size[axis], it.min_size[axis], it.max_size[axis]);

        added_size := it.size[axis] - prev_size;
        node.children_size[axis] += added_size;
    }

    // @Todo: should we remove this? I think None layout mode should work the same as the other modes
    // This branch was useful because we often wanted to fill a percentage of the parent without taking
    // siblings into account but we now have ParentPercent sizing
    if node.child_layout_mode == .None {
        // Warning: the weight does not take into account siblings in None layout mode!
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

            added_size := it.size[axis] - prev_size;
            node.children_size[axis] += added_size;
        }
    } else if layout_axis == axis {
        remaining_size := node.size[axis] - node.padding.xy[axis] - node.padding.zw[axis]
            - node.children_size[axis]
            - (node.num_children - 1) * node.child_gap[axis];
        remaining_size = floor(remaining_size);

        total_weights := 0.0;
        num_fill_children := 0;

        for :Children node {
            if it.desired_size[axis].kind != .FillParent {
                continue;
            }

            total_weights += clamp(it.desired_size[axis].value, 0, 1);

            if (remaining_size < 0 && abs(it.size[axis] - it.min_size[axis]) < 0.00001)
            || (remaining_size > 0 && abs(it.size[axis] - it.max_size[axis]) < 0.00001) {
                continue;
            }

            num_fill_children += 1;
        }

        iter := 0;
        while iter < 10 && num_fill_children > 0 && abs(remaining_size) > 0.00001 {
            defer iter += 1;

            for :Children node {
                if it.desired_size[axis].kind != .FillParent  {
                    continue;
                }

                if (remaining_size < 0 && abs(it.size[axis] - it.min_size[axis]) < 0.00001)
                || (remaining_size > 0 && abs(it.size[axis] - it.max_size[axis]) < 0.00001) {
                    continue;
                }

                prev_size := it.size[axis];
                if total_weights > 0 {
                    it.size[axis] += floor(remaining_size * it.desired_size[axis].value / total_weights);
                }
                it.size[axis] = clamp(it.size[axis], it.min_size[axis], it.max_size[axis]);

                if (remaining_size < 0 && abs(it.size[axis] - it.min_size[axis]) < 0.00001)
                || (remaining_size > 0 && abs(it.size[axis] - it.max_size[axis]) < 0.00001) {
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
        if (node.child_layout_mode == .None || layout_axis != axis) && it.desired_size[axis].kind == .FillParent {
            it.size[axis] = floor(node.size[axis] * it.desired_size[axis].value - node.padding.xy[axis] - node.padding.zw[axis]);
            it.size[axis] = clamp(it.size[axis], it.min_size[axis], it.max_size[axis]);
            node.children_size[axis] = max(node.children_size[axis], it.size[axis]);
        }

        LayoutFillAndPercentSizing(it, axis);
    }
}

LayoutPosition :: (node : *Node) {
    if node.child_layout_mode == .None {
        remaining_size := node.size - ToVec2f(node.padding.xy) - ToVec2f(node.padding.zw) - node.children_size;

        for :Children node {
            it.relative_position = ceil(ToVec2f(node.padding.xy) + Scale(node.size - it.size, node.child_align));
            it.relative_position += Round(it.offset);
            it.relative_position += Round(node.scroll);

            it.rect.xy = node.rect.xy + it.relative_position;
            it.rect.zw = node.rect.xy + it.relative_position + it.size;
            it.clipped_rect = ClipRect(it.rect, node.clipped_rect);

            LayoutPosition(it);
        }

        return;
    }

    axis := GetLayoutAxis(node);
    cross := GetCrossAxis(axis);
    reverse := IsLayoutReverseDirection(node);

    remaining_size := node.size[axis] - node.padding.xy[axis] - node.padding.zw[axis]
            - node.children_size[axis]
            - (node.num_children - 1) * node.child_gap[axis];
    axis_align_offset := remaining_size * node.child_align[axis];
    cross_size := node.size[cross] - node.padding.xy[cross] - node.padding.zw[cross];

    cursor := ifx reverse
        then floor(node.size[axis] - node.padding.zw[axis] - axis_align_offset)
        else ceil(node.padding.xy[axis] + axis_align_offset);

    first := true;
    for :Children node {
        defer first = false;

        if reverse {
            cursor -= it.size[axis] + node.child_gap[axis] * cast(float, !first);
            cursor = floor(cursor);
        }

        it.relative_position[axis] = cursor;
        it.relative_position[cross] = ceil(node.padding.xy[cross] + (cross_size - it.size[cross]) * node.child_align[cross]);

        if !reverse {
            cursor += it.size[axis] + node.child_gap[axis];
            cursor = ceil(cursor);
        }

        it.relative_position += Round(it.offset);
        it.relative_position += Round(node.scroll);

        it.rect.xy = node.rect.xy + it.relative_position;
        it.rect.zw = node.rect.xy + it.relative_position + it.size;
        it.clipped_rect = ClipRect(it.rect, node.clipped_rect);

        LayoutPosition(it);
    }
}

LayoutWrapText :: (node : *Node) {
    if (node.flags & .TextNode) && (node.flags & .WrapText) && node.desired_size.y.kind == .FitChildren {
        iter : TextGlyphIterator;
        iter.font = node.font;
        iter.font_size = node.text_size;
        iter.text = node.text;
        iter.bounds = node.size;
        for :WordWrap iter {
        }

        node.size.y = iter.computed_size.y;
    }

    for :Children node {
        LayoutWrapText(it);
    }
}
