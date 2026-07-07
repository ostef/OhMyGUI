TableData :: struct {
    Column :: struct {
        label : string;
        str_id : string;
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

Table :: (parent : *Node, location := #caller_location) -> *Node {
    table := GetNode(parent, location);
    {
        data := AddUserData(table, TableData);
        ClearTableData(data);

        SetSize(table, SizeFill(), SizeFill());
        SetLayout(table, .LeftToRight);

        SetBorderColor(table, ColorU32(1,1,1,1));
        SetBorderSize(table, 1);
    }

    return table;
}

TableAddColumn :: (table : *Node, label : string, str_id : string) {
    data := GetUserData(table, TableData);
    assert(data != null, "Node is not a table");

    column, is_new := GetNode(table, str_id);

    exists := false;
    for data.columns {
        if it.str_id == str_id {
            exists = true;
            break;
        }
    }

    if !exists {
        array_add(*data.columns, .{label=label, str_id=str_id, node=column});
    }

    SetSize(column, SizeFill(), SizeFill());
    SetLayout(column, .TopToBottom);

    SetBorderColor(column, ColorU32(1,1,1,1));
    SetBorderSize(column, 1);
}

TableAddRow :: (table : *Node) {
    data := GetUserData(table, TableData);
    assert(data != null, "Node is not a table");

    for * data.columns {
        PushIDOffset(it.rows.count);
        defer PopIDOffset();

        row := GetNode(it.node);
        SetSize(row, SizeFill(), SizeFit());
        SetBorderColor(row, ColorU32(1,1,1,1));
        SetBorderSize(row, 1);

        array_add(*it.rows, row);
    }
}

TableHeaderRow :: (table : *Node) {
    data := GetUserData(table, TableData);
    assert(data != null, "Node is not a table");

    TableNextRow(table);
    for data.columns {
        cell := TableGetCell(table);
        assert(cell != null, "Cell node is null");

        Text(cell, "%", it.label);

        TableNextColumn(table);
    }
}

TableNextRow :: (table : *Node) {
    data := GetUserData(table, TableData);
    assert(data != null, "Node is not a table");

    data.current_column = 0;
    TableAddRow(table);
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
