GlobalTreeNodeData :: struct {
    tree_node_open_states : HT.Table(ID, bool);
}

DestroyGlobalTreeNodeData :: (node : *Node, data : *void) {
    using _ := cast(*GlobalTreeNodeData, data);
    HT.table_reset(*tree_node_open_states);
}

IsTreeNodeOpened :: (id : ID) -> bool {
    global := GetGlobalUserData(GlobalTreeNodeData);
    if !global {
        return false;
    }

    ok, result := HT.table_find(*global.tree_node_open_states, id);
    if !ok {
        return false;
    }

    return result;
}

SetTreeNodeOpened :: (id : ID, opened : bool) {
    global := AddGlobalUserData(GlobalTreeNodeData, DestroyGlobalTreeNodeData);
    HT.table_set(*global.tree_node_open_states, id, opened);
}

AddTreeNodeState :: (id : ID, default_value : bool) -> opened : bool {
    global := AddGlobalUserData(GlobalTreeNodeData, DestroyGlobalTreeNodeData);
    entry, new := HT.find_or_add(*global.tree_node_open_states, id);
    if new {
        entry.* = default_value;
    }

    return entry.*;
}

TreeNodeStyle :: struct {
    tree_item : ButtonStyle;
    triangle_size : float;
    indent : s8;
}

TreeNodeFlags :: enum_flags {
    Leaf;
    OpenByDefault;
    NoIndent;
    Selected;
    OpenOnArrowClick;
    OpenOnDoubleClick;
}

/**
 * @brief Collapsible tree node widget.
 */
TreeNode :: (parent : *Node, text : string, flags : TreeNodeFlags = 0, style : *TreeNodeStyle = null, location := #caller_location) -> contents : *Node, tree_item : *Node {
    EnsureStyle(*style, "tree_node");

    node, is_new := GetNode(parent, location);
    {
        SetSize(node, SizeFill(), SizeFit());
        SetLayout(node, .TopToBottom);

        opened : bool;
        if !(flags & .Leaf) {
            opened = AddTreeNodeState(node.id, (flags & .OpenByDefault) != 0);
        }

        if opened {
            node.state_flags |= .Active;
        }

        tree_item := GetNode(node);
        {
            SetSize(tree_item, SizeFill(), SizeFit());
            SetLayout(tree_item, .LeftToRight);
            SetChildAlign(tree_item, 0, 0.5);

            if !(flags & .OpenOnArrowClick) && !(flags & .Leaf) {
                button := ButtonBehavior(tree_item);
                interact := ifx (flags & .OpenOnDoubleClick) != 0 then button.double_clicked else button.released;
                if interact {
                    opened = !opened;
                    SetTreeNodeOpened(node, opened);
                }
            }

            if flags & .Selected {
                tree_item.state_flags |= .Active;
            }

            icon := GetNode(tree_item, "icon");
            SetSize(icon, SizePx(style.triangle_size), SizePx(style.triangle_size));

            if (flags & .OpenOnArrowClick) && !(flags & .Leaf) {
                button := ButtonBehavior(icon);
                interact := ifx (flags & .OpenOnDoubleClick) != 0 then button.double_clicked else button.released;
                if interact {
                    opened = !opened;
                    SetTreeNodeOpened(node, opened);
                }

                tree_item.state_flags |= icon.state_flags;
            }

            state := GetState(tree_item);

            SetBackgroundColor(icon, style.tree_item.states[state].text.text_color);

            if flags & .Leaf {
                SetDraw(icon, null);
            } else {
                SetDraw(icon, (draw_list : *DrawList, node : *Node) -> bool {
                    if IsClipped(draw_list, node.rect) {
                        return false;
                    }

                    rotation := ifx !(node.parent.parent.state_flags & .Active) then -PI * 0.5 else 0.0;
                    DrawArrow(draw_list, node, rotation);

                    return true;
                });
            }

            Apply(tree_item, style.tree_item.states[state].background);

            Text(tree_item, "%", text, style=*style.tree_item.states[state].text);
        }

        contents : *Node;
        if opened {
            contents = GetNode(node);
            SetSize(contents, SizeFill(), SizeFit());
            SetLayout(contents, .TopToBottom);

            if !(flags & .NoIndent) {
                SetPadding(contents, style.indent, 0, 0, 0);
            }
        }

        return contents, tree_item;
    }
}

IsTreeNodeOpened :: inline (node : *Node) -> bool {
    return IsTreeNodeOpened(node.id);
}

SetTreeNodeOpened :: (node : *Node, opened : bool) {
    SetTreeNodeOpened(node.id, opened);

    if opened {
        node.state_flags |= .Active;
    } else {
        node.state_flags &= ~.Active;
    }
}
