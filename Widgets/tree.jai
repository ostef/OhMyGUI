TreeNodeStyle :: struct {
    tree_item : ButtonStyle;
    triangle_size : float;
    indent : s8;
}

TreeNodeFlags :: enum_flags {
    Leaf;
    Opened;
}

TreeNode :: (parent : *Node, text : string, flags : TreeNodeFlags = 0, style : *TreeNodeStyle = null, location := #caller_location) -> contents : *Node, tree_item : *Node {
    EnsureStyle(*style, "tree_node");

    node := GetNode(parent, location);
    {
        SetSize(node, SizeFill(), SizeFit());
        SetLayout(node, .TopToBottom);

        if !(flags & .Leaf) && flags & .Opened || node.state_flags & .ActiveLastFrame {
            SetTreeNodeOpened(node, true);
        }

        tree_item := GetNode(node);
        {
            SetSize(tree_item, SizeFill(), SizeFit());
            SetLayout(tree_item, .LeftToRight);
            SetChildAlign(tree_item, 0, 0.5);

            using _ := ButtonBehavior(tree_item);
            if !(flags & .Leaf) && released {
                SetTreeNodeOpened(node, !IsTreeNodeOpened(node));
            }

            state := GetState(tree_item);

            icon := GetNode(tree_item, "icon");
            SetSize(icon, SizePx(style.triangle_size), SizePx(style.triangle_size));

            SetBackgroundColor(icon, style.tree_item.states[state].text.text_color);

            if flags & .Leaf {
                SetDraw(icon, null);
            } else {
                SetDraw(icon, (draw_list, node) => {
                    rotation := ifx !(node.parent.parent.state_flags & .Active) then -PI * 0.5 else 0.0;
                    DrawEquilateralTriangle(draw_list, (node.rect.xy + node.rect.zw) * 0.5, node.size.x, rotation, node.background_color);
                });
            }

            Apply(tree_item, style.tree_item.states[state].background);

            Text(tree_item, "%", text, style=*style.tree_item.states[state].text);
        }

        contents : *Node;
        if IsTreeNodeOpened(node) {
            contents = GetNode(node);
            SetSize(contents, SizeFill(), SizeFit());
            SetLayout(contents, .TopToBottom);
            SetPadding(contents, style.indent, 0, 0, 0);
        }

        return contents, tree_item;
    }
}

IsTreeNodeOpened :: (node : *Node) -> bool {
    return node.state_flags & .Active != 0;
}

SetTreeNodeOpened :: (node : *Node, opened : bool) {
    if opened {
        node.state_flags |= .Active;
    } else {
        node.state_flags &= ~.Active;
    }
}

OpenTreeNode :: (node : *Node) {
    SetTreeNodeOpened(node, true);
}

CloseTreeNode :: (node : *Node) {
    SetTreeNodeOpened(node, false);
}
