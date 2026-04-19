#import "Hash";

ID :: u64;

NodeFlags :: enum_flags u32 {
    TextNode;
}

Node :: struct {
    id : ID;
    local_id : ID;

    parent : *Node;

    // Computed during the layout phase at the end of the frame
    using layout : struct {
        first_child : *Node;
        last_child : *Node; // Reset when declaring the node
        next_sibling : *Node;
        prev_sibling : *Node;
        num_children : int;

        size : Vec2f;
        children_size : Vec2f;
        relative_position : Vec2f;
        rect : Vec4f;
    };

    prev_frame_layout : type_of(layout);

    last_used_on_frame : u64;

    // User controlled properties
    using properties : struct {
        flags : NodeFlags;
        offset : Vec2f; // If parent.child_layout_mode is None
        desired_size := Size2D.{.{kind=.FitChildren}, .{kind=.FitChildren}};
        min_size := Vec2f.{-FLOAT32_INFINITY, -FLOAT32_INFINITY};
        max_size := Vec2f.{ FLOAT32_INFINITY,  FLOAT32_INFINITY};
        padding : Vec2f;
        child_layout_mode := LayoutMode.LeftToRight;
        child_gap : Vec2f; // If child_layout_mode is not None
        child_align : Vec2f; // If child_layout_mode is not None

        font : *Font;
        text : string;
        text_size : float;
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

PrevFrameChildren :: (node : *Node, body : Code, flags : For_Flags) #expand {
    #if flags & .REVERSE {
        `it := node.prev_frame_layout.last_child;
        `it_index := node.prev_frame_layout.num_children - 1;
    } else {
        `it := node.prev_frame_layout.first_child;
        `it_index := 0;
    }

    while it {
        #if flags & .REVERSE {
            next := it.prev_frame_layout.prev_sibling;
        } else {
            next := it.prev_frame_layout.next_sibling;
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
    if !id {
        return 0;
    }
    if !base {
        return id;
    }

    return fnv1a_hash(id, base);
}

GetID :: inline (base : ID, str : string) -> ID {
    if !str {
        return 0;
    }

    if !base {
        return GetID(str);
    }

    return fnv1a_hash(str.data, str.count, h=base);
}

GetID :: inline (str : string) -> ID {
    if !str {
        return 0;
    }

    return fnv1a_hash(str.data, str.count);
}

TouchNode :: (node : *Node) {
    if node.last_used_on_frame == context.omg.frame_index {
        return;
    }

    node.last_used_on_frame = context.omg.frame_index;
    node.last_child = null;
    node.num_children = 0;
    node.properties = .{};
    node.layout = .{};
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

GetNode :: inline (parent : *Node) -> *Node {
    return GetNode(parent, 0);
}

GetNode :: inline (parent : *Node, str_id : string) -> *Node {
    return GetNode(parent, GetID(str_id));
}

GetNode :: (parent : *Node, id : ID) -> *Node {
    node : *Node;
    if parent && id != 0 {
        for :PrevFrameChildren parent {
            if it.local_id == id {
                node = it;
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

SetSize :: inline (node : *Node, xy : Size1D) {
    node.desired_size = .{xy, xy};
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

SetPadding :: inline (node : *Node, padding : Vec2f) {
    node.padding = padding;
}

SetPadding :: inline (node : *Node, x : float, y : float) {
    node.padding = .{x, y};
}

SetChildGap :: inline (node : *Node, gap : Vec2f) {
    node.child_gap = gap;
}

SetChildGap :: inline (node : *Node, x : float, y : float) {
    node.child_gap = .{x, y};
}

SetLayout :: inline (node : *Node, mode : LayoutMode) {
    node.child_layout_mode = mode;
}

SetText :: inline (node : *Node, font : *Font, size : float, text : string) {
    node.flags |= .TextNode;
    node.font = font;
    node.text = text;
    node.text_size = size;
}
