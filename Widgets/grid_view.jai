GridViewStyle :: struct {
    background : BoxStyle;
}

GridViewData :: struct {
    item_size : Vec2f;
    item_count : int;
    num_columns : int;
    next_item_index : int;
    first_visible_row : int;
    last_visible_row : int;
    current_row : *Node;
    added_bottom_spacer : bool;
}

/**
 * @brief Grid of fixed size items, wrapping to the available width.
 *
 * Items are added with GridViewNextItem. When the number of items is known, rows that are far from the
 * visible area are replaced by spacers and GridViewNextItem returns null for their items, which keeps large grids cheap.
 *
 * @param item_count Number of items that will be added, or -1 if unknown (all items are declared).
 *
 * @see GridViewNextItem
 */
GridView :: (parent : *Node, item_size : Vec2f, item_count := -1, style : *GridViewStyle = null, location := #caller_location) -> *Node {
    EnsureStyle(*style, "grid_view");

    node, is_new := GetNode(parent, location);
    {
        SetSize(node, SizeFill(), SizeFit());
        SetLayout(node, .TopToBottom);

        node.flags |= .NoPaddedClip;

        Apply(node, style.background);

        data := AddUserData(node, GridViewData);
        data.item_size = item_size;
        data.item_count = item_count;
        data.next_item_index = 0;
        data.current_row = null;
        data.added_bottom_spacer = false;

        // Sizes are those of the previous frame
        gap := ToVec2f(node.child_gap);
        avail_width := node.size.x - node.padding.x - node.padding.z;
        data.num_columns = max(cast(int, (avail_width + gap.x) / max(item_size.x + gap.x, 1)), 1);

        data.first_visible_row = 0;
        data.last_visible_row = S64_MAX;

        if item_count >= 0 {
            view_top := node.clipped_rect.y - node.rect.y - node.padding.y;
            view_height := node.clipped_rect.w - node.clipped_rect.y;

            if is_new || node.size.x <= 0 {
                // We don't know the available width yet, wait for the next frame
                data.last_visible_row = -1;
            } else if view_height <= 0 {
                data.last_visible_row = -1;
            } else {
                // Keep a margin of one view height above and below to hide the one frame delay when scrolling
                row_stride := item_size.y + gap.y;
                data.first_visible_row = max(cast(int, floor((view_top - view_height) / row_stride)), 0);
                data.last_visible_row = cast(int, floor((view_top + view_height * 2) / row_stride));
            }
        }
    }

    return node;
}

/**
 * @brief Add an item to a GridView.
 *
 * @returns The cell to fill, or null if the item is not visible and should be skipped.
 */
GridViewNextItem :: (grid : *Node) -> cell : *Node {
    GridViewSpacer :: (grid : *Node, data : *GridViewData, str_id : string, num_rows : int) {
        if num_rows <= 0 {
            return;
        }

        spacer := GetNode(grid, GetID(str_id, false));
        SetSize(spacer, SizeFill(), SizePx(num_rows * data.item_size.y + (num_rows - 1) * cast(float, grid.child_gap.y)));
    }

    data := GetUserData(grid, GridViewData);
    assert(data != null, "Node is not a GridView");

    index := data.next_item_index;
    data.next_item_index += 1;

    row_index := index / data.num_columns;
    column_index := index % data.num_columns;

    if row_index < data.first_visible_row || row_index > data.last_visible_row {
        if data.item_count >= 0 {
            num_rows := (data.item_count + data.num_columns - 1) / data.num_columns;

            if index == 0 && row_index < data.first_visible_row {
                GridViewSpacer(grid, data, "top_spacer", min(data.first_visible_row, num_rows));
            } else if row_index > data.last_visible_row && !data.added_bottom_spacer {
                GridViewSpacer(grid, data, "bottom_spacer", num_rows - row_index);
                data.added_bottom_spacer = true;
            }
        }

        return null;
    }

    if column_index == 0 || !data.current_row {
        row := GetNode(grid, GetID(row_index));
        SetSize(row, SizeFit(), SizeFit());
        SetLayout(row, .LeftToRight);
        SetChildGap(row, grid.child_gap.x, 0);
        row.flags |= .NoClip;

        data.current_row = row;
    }

    cell := GetNode(data.current_row, GetID(column_index + 1));
    SetSize(cell, SizePx(data.item_size.x), SizePx(data.item_size.y));

    return cell;
}
