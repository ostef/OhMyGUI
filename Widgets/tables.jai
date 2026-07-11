TableRowStyle :: struct {
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

TableStyle :: struct {
    corner_radiuses : Vec4f;
    padding : Vec4b;

    border_color : RGBA8;
    border_size : float;
    horizontal_inner_border_color : RGBA8;
    horizontal_inner_border_size : float;
    vertical_inner_border_color : RGBA8;
    vertical_inner_border_size : float;

    rows : TableRowStyle;
    row_height : float;

    header : ButtonStyle;
    header_row_height : float;
}

TableColumnFlags :: enum_flags {
    Resizable;
}

TableData :: struct {
    Column :: struct {
        label : string;
        str_id : string;
        flags : TableColumnFlags;
        node : *Node;
        rows : [..]*Node;
    }

    columns : [..]Column;
    current_column : int;
}

ClearTableData :: (data : *TableData) {
    for data.columns {
        array_free(it.rows);
    }

    array_reset_keeping_memory(*data.columns);
}

DestroyTableData :: (node : *Node, data : *void) {
    using _ := cast(*TableData, data);
    array_free(columns);
}

Table :: (parent : *Node, style : *TableStyle = null, location := #caller_location) -> *Node {
    EnsureStyle(*style, "table");

    table := GetNode(parent, location);
    {
        data := AddUserData(table, TableData);
        ClearTableData(data);

        SetUserData(table, style.*);

        SetSize(table, SizeFill(), SizeFit());
        SetLayout(table, .LeftToRight);

        SetCornerRadiuses(table, style.corner_radiuses);
        SetBorderColor(table, style.border_color);
        SetBorderSize(table, style.border_size);
        SetPadding(table, style.padding);
    }

    return table;
}

TableAddColumn :: (table : *Node, label : string, str_id : string, flags : TableColumnFlags = 0) {
    data := GetUserData(table, TableData);
    assert(data != null, "Node is not a table");

    style := GetUserData(table, TableStyle);

    first := data.columns.count == 0;
    if !first && style.vertical_inner_border_size > 0 {
        border := GetNode(table, tprint("%.border_before", str_id));
        SetSize(border, SizePx(xx style.vertical_inner_border_size), SizeFill());
        SetBackgroundColor(border, style.vertical_inner_border_color);
    }

    column, is_new := GetNode(table, str_id);

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

TableAddRow :: (table : *Node, height : float) {
    data := GetUserData(table, TableData);
    assert(data != null, "Node is not a table");

    style := GetUserData(table, TableStyle);

    for * data.columns {
        PushIDOffset(it.rows.count);
        defer PopIDOffset();

        first := it.rows.count == 0;
        if !first && style.horizontal_inner_border_size > 0 {
            border := GetNode(it.node, "border_before_row");
            SetSize(border, SizeFill(), SizePx(xx style.horizontal_inner_border_size));
            SetBackgroundColor(border, style.horizontal_inner_border_color);
        }

        cell := GetNode(it.node);
        SetSize(cell, SizeFill(), SizePx(height));

        i := it.rows.count;
        Apply(cell, style.rows, i % 2 == 0);

        array_add(*it.rows, cell);
    }
}

TableHeaderRow :: (table : *Node) {
    data := GetUserData(table, TableData);
    assert(data != null, "Node is not a table");

    style := GetUserData(table, TableStyle);

    data.current_column = 0;
    TableAddRow(table, style.header_row_height);

    for data.columns {
        cell := TableGetCell(table);
        assert(cell != null, "Cell node is null");

        Apply(cell, style.header.normal.background);

        Text(cell, "%", it.label, style=*style.header.normal.text);

        TableNextColumn(table);
    }
}

TableNextRow :: (table : *Node) {
    data := GetUserData(table, TableData);
    assert(data != null, "Node is not a table");

    style := GetUserData(table, TableStyle);

    data.current_column = 0;
    TableAddRow(table, style.row_height);
}

TableNextColumn :: (table : *Node) {
    data := GetUserData(table, TableData);
    assert(data != null, "Node is not a table");

    data.current_column += 1;
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
