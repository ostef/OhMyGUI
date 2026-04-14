LayoutNodes :: (node : *Node) {
    node.size = .{node.desired_size.x.value, node.desired_size.y.value};
    node.relative_position = .{0,0};

    absolute_position := node.relative_position;
    if node.parent {
        absolute_position += node.parent.rect.xy;
    }

    node.rect = .{xy=absolute_position, zw=absolute_position + node.size};
    node.inner_rect = node.rect;

    for :Children node {
        LayoutNodes(it);
    }
}
