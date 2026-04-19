#import "Hash";

ID :: u64;

NodeFlags :: enum_flags u8 {
    TextNode;
}

Node :: struct {
    id : ID;
    local_id : ID;
    index : Bucket_Locator;

    parent : *Node;

    last_used_on_frame : u64;

    // Computed during the layout phase at the end of the frame
    using layout : struct {
        first_child : *Node;
        last_child : *Node; // Reset when declaring the node
        next_sibling : *Node;
        prev_sibling : *Node;
        num_children : s32;

        size : Vec2f;
        children_size : Vec2f;
        relative_position : Vec2f;
        rect : Vec4f;
    };

    layout_last_frame : type_of(layout);

    // User controlled properties
    using properties : struct {
        font : *Font;
        text : string;
        text_size : float;

        offset : Vec2f; // If parent.child_layout_mode is None
        desired_size := Size2D.{.{kind=.FitChildren}, .{kind=.FitChildren}};
        min_size := Vec2f.{-FLOAT32_INFINITY, -FLOAT32_INFINITY};
        max_size := Vec2f.{ FLOAT32_INFINITY,  FLOAT32_INFINITY};
        padding : Vec2f;
        child_gap : Vec2f; // If child_layout_mode is not None
        child_align : Vec2f; // If child_layout_mode is not None
        child_layout_mode := LayoutMode.LeftToRight;
        flags : NodeFlags;
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
        `it := node.layout_last_frame.last_child;
        `it_index := node.layout_last_frame.num_children - 1;
    } else {
        `it := node.layout_last_frame.first_child;
        `it_index := 0;
    }

    while it {
        #if flags & .REVERSE {
            next := it.layout_last_frame.prev_sibling;
        } else {
            next := it.layout_last_frame.next_sibling;
        }

        defer it = next;

        #insert body;
    }
}

AllocNode :: () -> *Node {
    node, index := find_and_occupy_empty_slot(*context.omg.node_pool);
    node.index = index;

    return node;
}

FreeNode :: (node : *Node) {
    for :PrevFrameChildren node {
        FreeNode(it);
    }

    index := node.index;
    node.index = .{};
    bucket_array_remove(*context.omg.node_pool, index);
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

GetID :: inline (base : ID, id : ID) -> ID {
    return fnv1a_hash(id, base);
}

GetID :: inline (base : ID, str : string) -> ID {
    if !str {
        return 0;
    }

    return fnv1a_hash(str.data, str.count, h=base);
}

GetID :: inline (str : string) -> ID {
    if !str {
        return 0;
    }

    return fnv1a_hash(str.data, str.count);
}

GetID :: inline (loc : Source_Code_Location) -> ID {
    h := fnv1a_hash(loc.fully_pathed_filename.data, loc.fully_pathed_filename.count);
    h = fnv1a_hash(cast,no_check(u64, loc.line_number), h=h);
    h = fnv1a_hash(cast,no_check(u64, loc.character_number), h=h);

    return h;
}

TouchNode :: (node : *Node) {
    if node.last_used_on_frame == context.omg.frame_index {
        return;
    }

    node.last_used_on_frame = context.omg.frame_index;
    node.properties = .{};
    node.layout = .{};
    if node.parent {
        PushChild(node.parent, node);
    }
}

GetNode :: (window : *Window) -> *Node {
    if !window.root_node {
        window.root_node = AllocNode();
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

GetNode :: inline (parent : *Node, location := #caller_location) -> *Node {
    return GetNode(parent, GetID(location));
}

GetNode :: inline (parent : *Node, str_id : string) -> *Node {
    return GetNode(parent, GetID(str_id));
}

GetNode :: (parent : *Node, id : ID) -> *Node {
    assert(id != 0);

    was_added_this_frame := false;
    node : *Node;
    if parent {
        for :PrevFrameChildren parent {
            if it.local_id == id {
                node = it;
                break;
            }
        }

        if !node {
            for :Children parent {
                if it.local_id == id {
                    was_added_this_frame = true;
                    node = it;
                    break;
                }
            }
        }
    }

    if !node {
        node = AllocNode();
        node.parent = parent;
        node.local_id = id;
        node.id = GetID(parent.id, id);
    }

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
