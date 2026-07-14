TreeNodeStyle :: struct {
    tree_item : ButtonStyle;
    indent : float;
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

        if flags & .Opened || node.state_flags & .ActiveLastFrame {
            SetTreeNodeOpened(node, true);
        }

        tree_item := GetNode(node);
        {
            SetSize(tree_item, SizeFill(), SizeFit());
            SetLayout(tree_item, .LeftToRight);

            if !(flags & .Leaf) {
                using _ := ButtonBehavior(tree_item);
                if released {
                    SetTreeNodeOpened(node, !IsTreeNodeOpened(node));
                }
            }

            state := GetState(tree_item);
            Apply(tree_item, style.tree_item.states[state].background);

            Text(tree_item, "%", text, style=*style.tree_item.states[state].text);
        }

        contents : *Node;
        if IsTreeNodeOpened(node) {
            expanded_node := GetNode(node);
            SetSize(expanded_node, SizeFill(), SizeFit());
            SetLayout(expanded_node, .LeftToRight);

            indentation := GetNode(expanded_node);
            SetSize(indentation, SizePx(style.indent), SizeFill());

            contents = GetNode(expanded_node);
            SetSize(contents, SizeFill(), SizeFit());
            SetLayout(contents, .TopToBottom);
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
