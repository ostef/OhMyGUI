// Table API heavily inspired by Dear ImGui

TableStyle :: struct {
    corner_radiuses : Vec4f;
    padding : Vec4b;

    border_color : RGBA8;
    border_size : float;

    vertical_inner_border_color : RGBA8;
    vertical_inner_border_size : float;

    rows : TableRowStyle;
    header_row : TableRowStyle;
    header_text : TextStyle;
    header_sort_icon_size : float;
}

TableRowStyle :: struct {
    height : float;

    border_color : RGBA8;
    border_size : float;

    cell_padding : Vec4b;
    cell_child_align : Vec2f;

    background_color : RGBA8;
    background_color2 : RGBA8;
    background_gradient_offset : float;
    background_gradient_vector : Vec2f;
    alternate_background_color : RGBA8;
    alternate_background_color2 : RGBA8;
    alternate_background_gradient_offset : float;
    alternate_background_gradient_vector : Vec2f;
    inner_shadow_blur : float;
    inner_shadow_offset : Vec2f;
    inner_shadow_color : RGBA8;
}

Apply :: inline (node : *Node, style : TableRowStyle, alternate : bool) {
    node.padding = style.cell_padding;
    node.child_align = style.cell_child_align;

    if alternate {
        node.background_color = style.alternate_background_color;
        node.background_color2 = style.alternate_background_color2;
        node.background_gradient_offset = style.alternate_background_gradient_offset;
        node.background_gradient_vector = style.alternate_background_gradient_vector;
    } else {
        node.background_color = style.background_color;
        node.background_color2 = style.background_color2;
        node.background_gradient_offset = style.background_gradient_offset;
        node.background_gradient_vector = style.background_gradient_vector;
    }

    node.inner_shadow_blur = style.inner_shadow_blur;
    node.inner_shadow_offset = style.inner_shadow_offset;
    node.inner_shadow_color = style.inner_shadow_color;
}

TableFlags :: enum_flags {
    FitContent;
}

TableColumnFlags :: enum_flags {
    Resizable;
    Hideable;
    Sortable;
}

TableData :: struct {
    Column :: struct {
        label : string;
        str_id : string;
        flags : TableColumnFlags;
        node : *Node;
        rows : [..]*Node;

        previous_row_border_color : RGBA8;
        previous_row_border_size : float;
    }

    content : *Node;
    sort_params : TableSortParams;
    columns : [..]Column;
    current_column : int;
    flags : TableFlags;
}

TableSortParams :: struct {
    column_params : [..]TableColumnSortParams;
    modified := true;
}

TableSortDirection :: enum u8 {
    None;
    Ascending;
    Descending;
}

TableColumnSortParams :: struct {
    str_id : string;
    direction : TableSortDirection;
}

GetTableSortParams :: (table : *Node) -> *TableSortParams {
    data := GetUserData(table, TableData);
    if !data {
        return null;
    }

    return *data.sort_params;
}

GetColumnSortDirection :: (params : *TableSortParams, str_id : string) -> TableSortDirection, order : int {
    for params.column_params {
        if it.str_id == str_id {
            // Order is reversed, because when we sort it's the last index that has
            // the most effect, so it's more intuitive that the last sorting to be
            // applied algorithmically is the column with the lowest number
            return it.direction, params.column_params.count - it_index;
        }
    }

    return .None, 0;
}

SetColumnSortDirection :: (params : *TableSortParams, str_id : string, dir : TableSortDirection) {
    index := -1;
    for * params.column_params {
        if it.str_id == str_id {
            index = it_index;
            break;
        }
    }

    if dir != .None {
        if index >= 0 {
            params.column_params[index].direction = dir;
        } else {
            array_insert_at(*params.column_params, .{str_id=str_id, direction=dir}, 0);
        }

        params.modified = true;
    } else if index >= 0 {
        array_ordered_remove_by_index(*params.column_params, index);
        params.modified = true;
    }
}

ClearTableData :: (data : *TableData) {
    for data.columns {
        array_free(it.rows);
    }

    array_reset_keeping_memory(*data.columns);

    data.current_column = 0;

    data.content = null;
}

DestroyTableData :: (node : *Node, data : *void) {
    using _ := cast(*TableData, data);
    array_free(columns);
}

Table :: (parent : *Node, flags : TableFlags = 0, style : *TableStyle = null, location := #caller_location) -> *Node {
    EnsureStyle(*style, "table");

    table := GetNode(parent, location);
    {
        data := AddUserData(table, TableData);
        ClearTableData(data);
        data.flags = flags;

        SetUserData(table, style.*);

        SetSize(table, SizeFill(), ifx flags & .FitContent then SizeFit() else SizeFill());
        SetLayout(table, .LeftToRight);

        SetCornerRadiuses(table, style.corner_radiuses);
        SetBorderColor(table, style.border_color);
        SetBorderSize(table, style.border_size);
        SetPadding(table, style.padding);

        content_and_vscrollbar := GetNode(table, "content_and_vscrollbar");
        {
            SetSize(content_and_vscrollbar, SizeFill(), SizeFill());
            SetLayout(content_and_vscrollbar, .LeftToRight);

            content_container := GetNode(content_and_vscrollbar, "content_container");
            {
                SetSize(content_container, SizeFill(), SizeFill());

                data.content = GetNode(content_container, "content");
                {
                    SetSize(data.content, SizeFill(), SizeFit());
                    SetLayout(data.content, .LeftToRight);
                }
            }

            ScrollViewBehavior(content_container, .Y);

            if content_container.layout_last_frame.children_size.y > content_container.layout_last_frame.size.y - content_container.padding.y - content_container.padding.w {
                Scrollbar(content_and_vscrollbar, content_container, .Y);
            }
        }

        return table;
    }
}

TableAddColumn :: (table : *Node, label : string, str_id : string, flags : TableColumnFlags = 0) {
    data := GetUserData(table, TableData);
    assert(data != null, "Node is not a table");

    style := GetUserData(table, TableStyle);

    first := data.columns.count == 0;
    if !first && style.vertical_inner_border_size > 0 {
        border := GetNode(data.content, tprint("%.border_before", str_id));
        SetSize(border, SizePx(xx style.vertical_inner_border_size), SizeFill());
        SetBackgroundColor(border, style.vertical_inner_border_color);
    }

    column, is_new := GetNode(data.content, str_id);

    exists := false;
    for data.columns {
        if it.str_id == str_id {
            exists = true;
            break;
        }
    }

    if !exists {
        array_add(*data.columns, .{label=label, str_id=str_id, flags=flags, node=column});
    }

    SetSize(column, SizeFill(), SizeFit());
    SetLayout(column, .TopToBottom);
}

TableAddRow :: (table : *Node, style : *TableRowStyle) {
    data := GetUserData(table, TableData);
    assert(data != null, "Node is not a table");

    table_style := GetUserData(table, TableStyle);

    for * data.columns {
        PushIDOffset(it.rows.count);
        defer PopIDOffset();

        first := it.rows.count == 0;
        if !first && it.previous_row_border_size > 0 {
            border := GetNode(it.node, "border_before_row");
            SetSize(border, SizeFill(), SizePx(it.previous_row_border_size));
            SetBackgroundColor(border, it.previous_row_border_color);
        }

        cell := GetNode(it.node);
        SetSize(cell, SizeFill(), SizePx(style.height));

        i := it.rows.count;
        Apply(cell, style, i % 2 == 0);

        array_add(*it.rows, cell);

        it.previous_row_border_size = style.border_size;
        it.previous_row_border_color = style.border_color;
    }
}

TableHeadersRow :: (table : *Node) {
    data := GetUserData(table, TableData);
    assert(data != null, "Node is not a table");

    style := GetUserData(table, TableStyle);

    TableNextRow(table, *style.header_row);

    for data.columns {
        cell := TableGetCell(table);
        assert(cell != null, "Cell node is null");

        text := Text(cell, "%", it.label, style=*style.header_text);
        SetWidth(text, SizeFill());

        if it.flags & .Sortable {
            using _ := ButtonBehavior(cell);
            if released {
                current_dir := GetColumnSortDirection(*data.sort_params, it.str_id);
                new_dir := cast(TableSortDirection, (cast(int, current_dir) + 1) % 3);
                SetColumnSortDirection(*data.sort_params, it.str_id, new_dir);
            }

            sort_dir, sort_order := GetColumnSortDirection(*data.sort_params, it.str_id);

            if sort_dir != .None {
                sort_indicator := GetNode(cell, "sort_indicator");
                {
                    SetSize(sort_indicator, SizeFit(), SizeFit());
                    SetLayout(sort_indicator, .LeftToRight);
                    SetChildAlign(sort_indicator, 0, 0.5);

                    if sort_order > 1 {
                        Text(sort_indicator, "%", sort_order);
                    }

                    sort_icon := GetNode(sort_indicator, "icon");
                    {
                        SetSize(sort_icon, SizePx(style.header_sort_icon_size), SizePx(style.header_sort_icon_size));
                        SetBackgroundColor(sort_icon, style.header_text.text_color);

                        if sort_dir == {
                        case .Ascending;
                            SetDraw(sort_icon, (draw_list, node) => {
                                position := (node.rect.xy + node.rect.zw) * 0.5;
                                DrawEquilateralTriangle(draw_list, position, node.size.x, PI, node.background_color);
                            });
                        case .Descending;
                            SetDraw(sort_icon, (draw_list, node) => {
                                position := (node.rect.xy + node.rect.zw) * 0.5;
                                DrawEquilateralTriangle(draw_list, position, node.size.x, 0, node.background_color);
                            });
                        }
                    }
                }
            }
        }

        menu := ContextMenu(cell);
        if menu {
            MenuItem(menu, "Sort Asc");
            MenuItem(menu, "Sort Desc");
            MenuItem(menu, "Hide");
        }

        TableNextColumn(table);
    }
}

TableNextRow :: (table : *Node, style : *TableRowStyle = null) -> cell : *Node {
    data := GetUserData(table, TableData);
    assert(data != null, "Node is not a table");

    if !style {
        table_style := GetUserData(table, TableStyle);
        style = *table_style.rows;
    }

    data.current_column = 0;
    TableAddRow(table, style);

    return TableGetCell(table);
}

TableNextColumn :: (table : *Node) -> cell : *Node {
    data := GetUserData(table, TableData);
    assert(data != null, "Node is not a table");

    data.current_column += 1;

    return TableGetCell(table);
}

TableSetColumn :: (table : *Node, index : int) -> cell : *Node {
    data := GetUserData(table, TableData);
    assert(data != null, "Node is not a table");

    data.current_column = index;

    return TableGetCell(table);
}

TableSetColumn :: (table : *Node, str_id : string) -> cell : *Node {
    data := GetUserData(table, TableData);
    assert(data != null, "Node is not a table");

    for data.columns {
        if it.str_id == str_id {
            data.current_column = it_index;
            break;
        }
    }

    return TableGetCell(table);
}

TableGetCell :: (table : *Node) -> *Node {
    data := GetUserData(table, TableData);
    assert(data != null, "Node is not a table");

    if data.current_column < 0 || data.current_column >= data.columns.count {
        return null;
    }

    column := *data.columns[data.current_column];
    if column.rows.count <= 0 {
        return null;
    }

    return column.rows[column.rows.count - 1];
}
