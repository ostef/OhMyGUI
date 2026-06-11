#import "Hash";

ID :: u64;

NodeFlags :: enum_flags u32 {
    TextNode;
    Focusable;
    Scrollable;
    SortChildren;
    NoClip;
    NoPaddedClip;
}

TextEffects :: enum_flags u8 {
    Underline;
    Strikethrough;
}

NodeState :: enum u8 {
    Disabled;
    Active;
    Hot;
    Focused;
    None;
}

Num_Node_States :: #run type_info(NodeState).values.count;

NodeStateFlags :: enum_flags u8 {
    Disabled :: 1 << NodeState.Disabled;
    Active   :: 1 << NodeState.Active;
    Hot      :: 1 << NodeState.Hot;
    Focused  :: 1 << NodeState.Focused;
    CurrentFrame :: Focused | Hot | Active | Disabled;

    DisabledLastFrame :: Disabled << (Num_Node_States - 1);
    ActiveLastFrame   :: Active   << (Num_Node_States - 1);
    HotLastFrame      :: Hot      << (Num_Node_States - 1);
    FocusedLastFrame  :: Focused  << (Num_Node_States - 1);
    LastFrame :: FocusedLastFrame | HotLastFrame | ActiveLastFrame | DisabledLastFrame;
}

GetState :: inline (node : *Node) -> NodeState {
    return GetState(node.state_flags);
}

GetState :: inline (state_flags : NodeStateFlags) -> NodeState {
    if state_flags & .Active {
        return .Active;
    }
    if state_flags & .Hot {
        return .Hot;
    }
    if state_flags & .Focused {
        return .Focused;
    }
    if state_flags & .Disabled {
        return .Disabled;
    }

    return .None;
}

GetStateLastFrame :: inline (node : *Node) -> NodeState {
    return GetStateLastFrame(node.state_flags);
}

GetStateLastFrame :: inline (state_flags : NodeStateFlags) -> NodeState {
    if state_flags & .ActiveLastFrame {
        return .Active;
    }
    if state_flags & .HotLastFrame {
        return .Hot;
    }
    if state_flags & .FocusedLastFrame {
        return .Focused;
    }
    if state_flags & .DisabledLastFrame {
        return .Disabled;
    }

    return .None;
}

NodeUserData :: struct {
    next : *NodeUserData;
    destroy : (*Node, *void);
    id : ID;
}

Node :: struct {
    id : ID;
    local_id : ID;
    index : Bucket_Locator;

    last_used_on_frame : u64;
    z_index : s32 = -1; // Used when the parent wants to sort children such as popups

    draw : (*DrawList, *Node) = DrawNodeDefault;
    user_data : *NodeUserData;

    window : *Window;
    parent : *Node;

    using layout : struct {
        first_child : *Node;
        last_child : *Node;
        next_sibling : *Node;
        prev_sibling : *Node;
        num_children : s32;

        // Computed during the layout phase at the end of the frame
        size : Vec2f;
        children_size : Vec2f;
        relative_position : Vec2f;
        rect : Vec4f;
        clipped_rect : Vec4f;
    };

    layout_last_frame : type_of(layout);

    // User controlled properties mostly related to layout, reset each frame except for scroll and offset
    using properties : struct {
        flags : NodeFlags;

        font : *Font;
        text : string;
        text_size : float;

        offset : Vec2f; // NOT reset each frame
        scroll : Vec2f; // NOT reset each frame
        desired_size := Size2D.{.{kind=.FitChildren}, .{kind=.FitChildren}};
        min_size := Vec2f.{-FLOAT32_INFINITY, -FLOAT32_INFINITY};
        max_size := Vec2f.{ FLOAT32_INFINITY,  FLOAT32_INFINITY};
        min_size_fit : [2]bool;
        padding : Vec4f;
        child_gap : Vec2f;
        child_align : Vec2f;
        child_layout_mode := LayoutMode.LeftToRight;
    };

    // Styling properties, NOT reset each frame
    using styling : struct {
        corner_radiuses : Vec4f;
        background_color : RGBA8;
        border_color : RGBA8;
        border_size : float;
        border_inset : float;
        outer_shadow_blur : float;
        outer_shadow_offset : Vec2f;
        outer_shadow_color : RGBA8;
        text_color : RGBA8;
        text_effects : TextEffects;
    };

    state_flags : NodeStateFlags;
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

// for_expansion
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

IsInTree :: (node : *Node, of : *Node) -> bool {
    curr := node;
    while curr {
        if curr == of {
            return true;
        }

        curr = curr.parent;
    }

    return false;
}

IsInTree :: (node : *Node, of : ID) -> bool {
    curr := node;
    while curr {
        if curr.id == of {
            return true;
        }

        curr = curr.parent;
    }

    return false;
}

// for_expansion
UserData :: (node : *Node, body : Code, flags : For_Flags) #expand {
    `it := node.user_data;
    `it_index := 0;

    while it {
        next := it.next;
        defer it = next;

        #insert body;
    }
}

AddUserData :: inline (node : *Node, $T : Type, destroy : type_of(NodeUserData.destroy) = null) -> *T, is_new : bool, *NodeUserData {
    ptr, is_new, node := GetUserData(node, T, true);
    node.destroy = destroy;
    return ptr, is_new, node;
}

AddUserData :: inline (node : *Node, str_id : string, $T : Type, destroy : type_of(NodeUserData.destroy) = null) -> *T, is_new : bool, *NodeUserData {
    ptr, is_new, node := GetUserData(node, str_id, T, true);
    node.destroy = destroy;
    return ptr, is_new, node;
}

AddUserData :: inline (node : *Node, id : ID, $T : Type, destroy : type_of(NodeUserData.destroy) = null) -> *T, is_new : bool, *NodeUserData {
    ptr, is_new, node := GetUserData(node, id, T, true);
    node.destroy = destroy;
    return ptr, is_new, node;
}

AddUserData :: (node : *Node, id : ID, size : int, destroy : type_of(NodeUserData.destroy) = null) -> *void, is_new : bool, *NodeUserData {
    ptr, is_new, node := GetUserData(node, id, size, true);
    node.destroy = destroy;
    return ptr, is_new, node;
}

SetUserData :: inline (node : *Node, value : $T, destroy : type_of(NodeUserData.destroy) = null) -> *T, is_new : bool, *NodeUserData {
    ptr, is_new, node := GetUserData(node, T, true);
    ptr.* = value;
    node.destroy = destroy;
    return ptr, is_new, node;
}

SetUserData :: inline (node : *Node, str_id : string, value : $T, destroy : type_of(NodeUserData.destroy) = null) -> *T, is_new : bool, *NodeUserData {
    ptr, is_new, node := GetUserData(node, str_id, T, true);
    ptr.* = value;
    node.destroy = destroy;
    return ptr, is_new, node;
}

SetUserData :: inline (node : *Node, id : ID, value : $T, destroy : type_of(NodeUserData.destroy) = null) -> *T, is_new : bool, *NodeUserData {
    ptr, is_new, node := GetUserData(node, id, T, true);
    ptr.* = value;
    node.destroy = destroy;
    return ptr, is_new, node;
}

GetUserData :: inline (node : *Node, $T : Type, create := false) -> *T, is_new : bool, *NodeUserData {
    ptr, is_new, node := GetUserData(node, cast(ID, type_info(T)), T, create);
    return ptr, is_new, node;
}

GetUserData :: inline (node : *Node, str_id : string, $T : Type, create := false) -> *T, is_new : bool, *NodeUserData {
    ptr, is_new, node := GetUserData(node, GetID(str_id, false), T, create);
    return ptr, is_new, node;
}

GetUserData :: inline (node : *Node, id : ID, $T : Type, create := false) -> *T, is_new : bool, *NodeUserData {
    ptr, is_new, node := GetUserData(node, id, size_of(T), create);
    if is_new {
        cast(*T, ptr).* = .{};
    }

    return xx ptr, is_new, node;
}

GetUserData :: (node : *Node, id : ID, size : int, create := false) -> *void, is_new : bool, *NodeUserData {
    for :UserData node {
        if it.id == id {
            return cast(*void, it + 1), false, it;
        }
    }

    if !create {
        return null, false, null;
    }

    ptr := alloc(size + size_of(NodeUserData) ,, context.omg.general_purpose_allocator);

    list_node := cast(*NodeUserData, ptr);
    list_node.id = id;

    list_node.next = node.user_data;
    node.user_data = list_node;

    return cast(*void, list_node + 1), true, list_node;
}

AllocNode :: () -> *Node {
    node, index := find_and_occupy_empty_slot(*context.omg.node_pool);
    node.index = index;

    return node;
}

FreeNode :: (node : *Node, free_children := true) {
    window := node.window;

    if free_children {
        for :PrevFrameChildren node {
            FreeNode(it);
        }
    }

    for :UserData node {
        if it.destroy {
            it.destroy(node, cast(*void, it + 1));
        }

        free(it ,, context.omg.general_purpose_allocator);
    }

    bucket_array_remove(*context.omg.node_pool, node.index);

    if window.root_node == node {
        window.root_node = null;
    }
    if window.popup_root_node == node {
        window.popup_root_node = null;
    }
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

PushIDOffset :: inline (offset : int) {
    array_add(*context.omg.id_offset_stack, offset);
}

PopIDOffset :: inline () {
    pop(*context.omg.id_offset_stack);
}

GetIDOffset :: inline () -> int {
    if context.omg.id_offset_stack.count <= 0 {
        return 0;
    }

    return context.omg.id_offset_stack[context.omg.id_offset_stack.count - 1];
}

GetID :: inline (id : ID, base : ID) -> ID {
    return fnv1a_hash(id, h=base);
}

GetID :: inline (str : string, apply_offset := true) -> ID {
    if !str {
        return 0;
    }

    id := fnv1a_hash(str.data, str.count);

    if apply_offset {
        id += xx,no_check GetIDOffset();
    }

    return id;
}

GetID :: inline (loc : Source_Code_Location, apply_offset := true) -> ID {
    id := fnv1a_hash(loc.fully_pathed_filename.data, loc.fully_pathed_filename.count);
    id = fnv1a_hash(cast,no_check(u64, loc.line_number), h=id);
    id = fnv1a_hash(cast,no_check(u64, loc.character_number), h=id);

    if apply_offset {
        id += xx,no_check GetIDOffset();
    }

    return id;
}

TouchNode :: (node : *Node) {
    if node.last_used_on_frame == context.omg.frame_index {
        return;
    }

    node.last_used_on_frame = context.omg.frame_index;

    scroll := node.scroll;
    offset := node.offset;
    node.properties = .{};
    node.scroll = scroll;
    node.offset = offset;

    node.layout = .{};

    if node.parent {
        PushChild(node.parent, node);
    }
}

GetPopupRoot :: (window : *Window) -> *Node, is_new : bool {
    is_new : bool;

    if !window.popup_root_node {
        window.popup_root_node = AllocNode();
        window.popup_root_node.window = window;
        window.popup_root_node.local_id = GetID("PopupRoot");
        window.popup_root_node.id = GetID(window.popup_root_node.local_id, cast(u64, window));

        is_new = true;
    }

    TouchNode(window.popup_root_node);

    return window.popup_root_node, is_new;
}

GetNode :: (window : *Window) -> *Node, is_new : bool {
    is_new : bool;

    if !window.root_node {
        window.root_node = AllocNode();
        window.root_node.window = window;
        window.root_node.local_id = GetID("Root");
        window.root_node.id = GetID(window.root_node.local_id, cast(u64, window));

        is_new = true;
    }

    TouchNode(window.root_node);

    return window.root_node, is_new;
}

GetNode :: inline (parent : *Node, location := #caller_location) -> *Node, is_new : bool {
    node, is_new := GetNode(parent, GetID(location));
    return node, is_new;
}

GetNode :: inline (parent : *Node, str_id : string) -> *Node, is_new : bool {
    node, is_new := GetNode(parent, GetID(str_id));
    return node, is_new;
}

GetNode :: (parent : *Node, id : ID) -> *Node, is_new : bool {
    assert(id != 0);
    assert(parent == null || parent.last_used_on_frame == context.omg.frame_index);

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
                    node = it;
                    break;
                }
            }
        }
    }

    is_new : bool;

    if !node {
        node = AllocNode();
        node.window = parent.window;
        node.parent = parent;
        node.local_id = id;
        node.id = GetID(id, base=parent.id);

        is_new = true;
    }

    TouchNode(node);

    return node, is_new;
}

GetPopupNode :: inline (window : *Window, location := #caller_location) -> *Node, is_new : bool {
    node, is_new := GetNode(GetPopupRoot(window), location);
    return node, is_new;
}

GetPopupNode :: inline (window : *Window, str_id : string) -> *Node, is_new : bool {
    node, is_new := GetNode(GetPopupRoot(window), str_id);
    return node, is_new;
}

GetPopupNode :: inline (window : *Window, id : ID) -> *Node, is_new : bool {
    node, is_new := GetNode(GetPopupRoot(window), id);
    return node, is_new;
}

BringForward :: (node : *Node) {
    node.z_index = 0x7fffffff;
}

SetDraw :: inline (node : *Node, draw : type_of(Node.draw)) {
    node.draw = draw;
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

SetMinWidthFit :: inline (node : *Node, fit : bool) {
    node.min_size_fit[0] = fit;
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

SetMinHeightFit :: inline (node : *Node, fit : bool) {
    node.min_size_fit[1] = fit;
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

SetMinSizeFit :: inline (node : *Node, x : bool, y : bool) {
    node.min_size_fit[0] = x;
    node.min_size_fit[1] = y;
}

SetMaxSize :: inline (node : *Node, size : Vec2f) {
    node.max_size = size;
}

SetMaxSize :: inline (node : *Node, x : float, y : float) {
    node.max_size = .{x, y};
}

SetPadding :: inline (node : *Node, padding : Vec4f) {
    node.padding = padding;
}

SetPadding :: inline (node : *Node, x : float, y : float) {
    node.padding = .{x, y, x, y};
}

SetPadding :: inline (node : *Node, left : float, top : float, right : float, bottom : float) {
    node.padding = .{left, top, right, bottom};
}

SetChildGap :: inline (node : *Node, gap : Vec2f) {
    node.child_gap = gap;
}

SetChildGap :: inline (node : *Node, x : float, y : float) {
    node.child_gap = .{x, y};
}

SetChildAlign :: inline (node : *Node, align : Vec2f) {
    node.child_align = align;
}

SetChildAlign :: inline (node : *Node, x : float, y : float) {
    node.child_align = .{x, y};
}

SetLayout :: inline (node : *Node, mode : LayoutMode) {
    node.child_layout_mode = mode;
}

SetText :: inline (node : *Node, text : string) {
    node.flags |= .TextNode;
    node.text = text;
}

SetText :: inline (node : *Node, font : *Font, size : float, text : string) {
    node.flags |= .TextNode;
    node.font = font;
    node.text = text;
    node.text_size = size;
}

SetCornerRadius :: inline (node : *Node, radius : float) {
    node.corner_radiuses = .{radius, radius, radius, radius};
}

SetCornerRadiuses :: inline (node : *Node, top_left : float, top_right : float, bottom_left : float, bottom_right : float) {
    node.corner_radiuses = .{top_left, top_right, bottom_left, bottom_right};
}

SetCornerRadiuses :: inline (node : *Node, radiuses : Vec4f) {
    node.corner_radiuses = radiuses;
}

SetBackgroundColor :: inline (node : *Node, r : float, g : float, b : float, a : float) {
    node.background_color = ColorU32(r, g, b, a);
}

SetBackgroundColor :: inline (node : *Node, color : Vec4f) {
    node.background_color = ColorU32(color);
}

SetBackgroundColor :: inline (node : *Node, color : RGBA8) {
    node.background_color = color;
}

SetTextColor :: inline (node : *Node, r : float, g : float, b : float, a : float) {
    node.text_color = ColorU32(r, g, b, a);
}

SetTextColor :: inline (node : *Node, color : Vec4f) {
    node.text_color = ColorU32(color);
}

SetTextColor :: inline (node : *Node, color : RGBA8) {
    node.text_color = color;
}

SetBorderColor :: inline (node : *Node, r : float, g : float, b : float, a : float) {
    node.border_color = ColorU32(r, g, b, a);
}

SetBorderColor :: inline (node : *Node, color : Vec4f) {
    node.border_color = ColorU32(color);
}

SetBorderColor :: inline (node : *Node, color : RGBA8) {
    node.border_color = color;
}

SetBorderSize :: inline (node : *Node, size : float) {
    node.border_size = size;
}

SetBorderInset :: inline (node : *Node, inset : float) {
    node.border_inset = inset;
}

SetOuterShadowOffset :: inline (node : *Node, x : float, y : float) {
    node.outer_shadow_offset = .{x,y};
}

SetOuterShadowOffset :: inline (node : *Node, offset : Vec2f) {
    node.outer_shadow_offset = offset;
}

SetOuterShadowColor :: inline (node : *Node, r : float, g : float, b : float, a : float) {
    node.outer_shadow_color = ColorU32(r, g, b, a);
}

SetOuterShadowColor :: inline (node : *Node, color : Vec4f) {
    node.outer_shadow_color = ColorU32(color);
}

SetOuterShadowOpacity :: inline (node : *Node, alpha : float) {
    SetAlpha(*node.outer_shadow_color, alpha);
}

SetOuterShadowBlur :: inline (node : *Node, blur : float) {
    node.outer_shadow_blur = blur;
}
