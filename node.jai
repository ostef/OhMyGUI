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

    align : Vec2f;
    anchor : Vec2f;
    desired_size : Size2D;
    min_size : Size2D;
    max_size : Size2D;

    child_layout_axis : Axis;
    child_layout_direction : LayoutDirection;

    // Computed at the end of the frame before drawing
    size : Vec2f;
    relative_position : Vec2f;
    rect : Vec4f;
    inner_rect : Vec4f;
    content_rect : Vec4f;

    text : string;
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
    assert(parent.last_child != node, "Should not happen");

    if parent.first_child == node {
        parent.first_child = node.next_sibling;
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

Axis :: enum u8 {
    X;
    Y;
}

LayoutDirection :: enum u8 {
    Positive;
    Negative;

    LeftToRight :: Positive;
    RightToLeft :: Negative;

    BottomToTop :: Positive;
    TopToBottom :: Negative;
}

Size1D :: struct {
    Kind :: enum u8 {
        Pixels;
        FillParent;
        FitChildren;
        Text;
    }

    kind : Kind;
    value : float;
}

SizePx :: inline (value : float) -> Size1D {
    return .{.Pixels, value};
}

SizeFillParent :: inline (ratio : float) -> Size1D {
    return .{.FillParent, ratio};
}

SizeFitChildren :: inline (ratio : float) -> Size1D {
    return .{.FillParent, ratio};
}

Size2D :: struct {
    x : Size1D;
    y : Size1D;

    #overlay(x)
    axes : [2]Size1D;
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
    node.last_used_on_frame = context.omg.frame_index;
    node.last_child = null;
    if node.parent {
        node.parent.last_child = node;
    }
}

GetNode :: (window : *Window) -> *Node {
    if !window.root_node {
        window.root_node = New(Node);
        window.root_node.local_id = GetID(cast(u64, window), "Root");
        window.root_node.id = window.root_node.local_id;
    }

    TouchNode(window.root_node);

    w, h : s32;
    SDL_GetWindowSize(window.sdl_window, *w, *h);

    SetSize(window.root_node, SizePx(xx w), SizePx(xx h));

    return window.root_node;
}

GetNode :: (window : *SDL_Window) -> *Node {
    w := GetWindow(window);
    if !w {
        return null;
    }

    return GetNode(w);
}

GetNode :: (parent : *Node, id : ID) -> *Node {
    node : *Node;
    if parent {
        for :Children parent {
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
        PushChild(parent, node);
    }

    TouchNode(node);

    return node;
}

SetWidth :: inline (node : *Node, size : Size1D) {
    node.desired_size.x = size;
}

SetMinWidth :: inline (node : *Node, size : Size1D) {
    node.min_size.x = size;
}

SetMaxWidth :: inline (node : *Node, size : Size1D) {
    node.max_size.x = size;
}

SetHeight :: inline (node : *Node, size : Size1D) {
    node.desired_size.y = size;
}

SetMinHeight :: inline (node : *Node, size : Size1D) {
    node.min_size.y = size;
}

SetMaxHeight :: inline (node : *Node, size : Size1D) {
    node.max_size.y = size;
}

SetSize :: inline (node : *Node, size : Size2D) {
    node.desired_size = size;
}

SetSize :: inline (node : *Node, x : Size1D, y : Size1D) {
    node.desired_size = .{x, y};
}

SetMinSize :: inline (node : *Node, size : Size2D) {
    node.min_size = size;
}

SetMinSize :: inline (node : *Node, x : Size1D, y : Size1D) {
    node.min_size = .{x, y};
}

SetMaxSize :: inline (node : *Node, size : Size2D) {
    node.max_size = size;
}

SetMaxSize :: inline (node : *Node, x : Size1D, y : Size1D) {
    node.max_size = .{x, y};
}

SetAlign :: inline (node : *Node, align : Vec2f) {
    node.align = align;
}

SetAlign :: inline (node : *Node, x : float, y : float) {
    node.align = .{x, y};
}

SetAnchor :: inline (node : *Node, anchor : Vec2f) {
    node.anchor = anchor;
}

SetAnchor :: inline (node : *Node, x : float, y : float) {
    node.anchor = .{x, y};
}

SetLayoutAxis :: inline (node : *Node, axis : Axis) {
    node.child_layout_axis = axis;
}

SetLayoutDirection :: inline (node : *Node, direction : LayoutDirection) {
    node.child_layout_direction = direction;
}

SetLayout :: inline (node : *Node, axis : Axis, direction : LayoutDirection) {
    node.child_layout_axis = axis;
    node.child_layout_direction = direction;
}
