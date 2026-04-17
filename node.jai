ID :: u64;

Node :: struct {
    id : ID;
    local_id : ID;

    parent : *Node;
    first_child : *Node;
    last_child : *Node; // Reset when declaring the node
    next_sibling : *Node;
    prev_sibling : *Node;
    num_children : int;

    last_used_on_frame : u64;

    // User controlled properties
    offset : Vec2f; // If parent.child_layout_mode is None
    desired_size : Size2D;
    min_size := Vec2f.{-FLOAT32_INFINITY, -FLOAT32_INFINITY};
    max_size := Vec2f.{ FLOAT32_INFINITY,  FLOAT32_INFINITY};
    padding := Vec2f.{10,10};
    child_layout_mode := LayoutMode.LeftToRight;
    child_gap := Vec2f.{5,5}; // If child_layout_mode is not None
    child_align : Vec2f; // If child_layout_mode is not None
    text : string;

    // Computed during the layout phase at the end of the frame
    using layout_results : struct {
        size : Vec2f;
        children_size : Vec2f;
        relative_position : Vec2f;
        rect : Vec4f;
    };
}

// for_expansion
Children :: (node : *Node, body : Code, flags : For_Flags) #expand {
    #if flags & .REVERSE {
        `it := node.last_child;
        `it_index := node.num_children - 1;
    } else {
        `it := node.first_child;
        `it_index := 0;
    }

    while it {
        #if flags & .REVERSE {
            next := it.prev_sibling;
        } else {
            next := it.next_sibling;
        }

        defer it = next;

        #insert body;
    }
}

FreeNode :: (node : *Node) {
    for :Children node {
        FreeNode(it);
    }

    free(node);
}

PushChild :: (parent : *Node, node : *Node) {
    after := parent.last_child;
    if after {
        node.next_sibling = after.next_sibling;
        if node.next_sibling {
            node.next_sibling.prev_sibling = node;
        }

        after.next_sibling = node;
        node.prev_sibling = after;
    } else {
        parent.first_child = node;
    }

    parent.last_child = node;

    parent.num_children += 1;
}

PopChild :: (parent : *Node, node : *Node) {
    assert(node.parent == parent);

    if parent.first_child == node {
        parent.first_child = node.next_sibling;
    }

    if parent.last_child == node {
        parent.last_child = node.prev_sibling;
    }

    if node.prev_sibling {
        node.prev_sibling.next_sibling = node.next_sibling;
    }
    if node.next_sibling {
        node.next_sibling.next_sibling = node.prev_sibling;
    }

    node.prev_sibling = null;
    node.next_sibling = null;
}

GetID :: inline (base : ID, id : ID) -> ID {
    return fnv1a_hash(id, base);
}

GetID :: inline (base : ID, str : string) -> ID {
    if !str {
        return 0;
    }

    #import "Hash";

    return fnv1a_hash(str.data, str.count, h=base);
}

GetID :: inline (str : string) -> ID {
    if !str {
        return 0;
    }

    #import "Hash";

    return fnv1a_hash(str.data, str.count);
}

TouchNode :: (node : *Node) {
    if node.last_used_on_frame == context.omg.frame_index {
        return;
    }

    node.last_used_on_frame = context.omg.frame_index;
    node.last_child = null;
    node.num_children = 0;
    node.layout_results = .{};
}

GetNode :: (window : *Window) -> *Node {
    if !window.root_node {
        window.root_node = New(Node);
        window.root_node.local_id = GetID(cast(u64, window), "Root");
        window.root_node.id = window.root_node.local_id;
    }

    TouchNode(window.root_node);

    return window.root_node;
}

GetNode :: (window : *SDL_Window) -> *Node {
    w := GetWindow(window);
    if !w {
        return null;
    }

    return GetNode(w);
}

GetNode :: inline (parent : *Node, str_id : string) -> *Node {
    return GetNode(parent, GetID(str_id));
}

GetNode :: (parent : *Node, id : ID) -> *Node {
    node : *Node;
    if parent {
        for :Children parent {
            if it.local_id == id {
                node = it;
                PopChild(parent, node);
                break;
            }
        }
    }

    if !node {
        node = New(Node);
        node.parent = parent;
        node.local_id = id;
        node.id = GetID(parent.id, id);
    }

    PushChild(parent, node);
    TouchNode(node);

    return node;
}

SetWidth :: inline (node : *Node, size : Size1D) {
    node.desired_size.x = size;
}

SetWidth :: inline (node : *Node, size : Size1D, min : float, max : float) {
    node.desired_size.x = size;
    node.min_size.x = min;
    node.max_size.x = max;
}

SetMinWidth :: inline (node : *Node, size : float) {
    node.min_size.x = size;
}

SetMaxWidth :: inline (node : *Node, size : float) {
    node.max_size.x = size;
}

SetMinMaxWidth :: inline (node : *Node, min : float, max : float) {
    node.min_size.x = min;
    node.max_size.x = max;
}

SetHeight :: inline (node : *Node, size : Size1D) {
    node.desired_size.y = size;
}

SetHeight :: inline (node : *Node, size : Size1D, min : float, max : float) {
    node.desired_size.y = size;
    node.min_size.y = min;
    node.max_size.y = max;
}

SetMinHeight :: inline (node : *Node, size : float) {
    node.min_size.y = size;
}

SetMaxHeight :: inline (node : *Node, size : float) {
    node.max_size.y = size;
}

SetMinMaxHeight :: inline (node : *Node, min : float, max : float) {
    node.min_size.y = min;
    node.max_size.y = max;
}

SetSize :: inline (node : *Node, size : Size2D) {
    node.desired_size = size;
}

SetSize :: inline (node : *Node, x : Size1D, y : Size1D) {
    node.desired_size = .{x, y};
}

SetMinSize :: inline (node : *Node, size : Vec2f) {
    node.min_size = size;
}

SetMinSize :: inline (node : *Node, x : float, y : float) {
    node.min_size = .{x, y};
}

SetMaxSize :: inline (node : *Node, size : Vec2f) {
    node.max_size = size;
}

SetMaxSize :: inline (node : *Node, x : float, y : float) {
    node.max_size = .{x, y};
}

SetLayout :: inline (node : *Node, mode : LayoutMode) {
    node.child_layout_mode = mode;
}
