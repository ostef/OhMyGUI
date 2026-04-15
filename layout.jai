LayoutNodes :: (node : *Node) {
    node.size = .{node.desired_size.x.value, node.desired_size.y.value};

    node.rect = .{xy=node.relative_position, zw=node.relative_position + node.size};
    node.inner_rect = node.rect;

    cursor := Vec2f.{};
    for :Children node {
        it.relative_position = cursor;
        LayoutNodes(it);

        cursor.x += it.size.x;
    }
}

MakeRectsAbsolute :: (node : *Node) {
    for :Children node {
        it.rect.xy += node.rect.xy;
        it.rect.zw += node.rect.xy;
        MakeRectsAbsolute(it);
    }
}
