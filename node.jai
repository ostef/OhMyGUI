#import "Hash";

ID :: u64;

NodeFlags :: enum_flags u32 {
    TextNode;     ///> Take the text value of the node into account instead of the children (e.g. for fit sizing).
    WrapText;     ///> Wrap the text when it goes outside the node width.
    Focusable;    ///> Capture mouse focus when hovered if no other foreground node has captured it.
    Scrollable;   ///> Capture scroll focus when hovered if no other foreground node has captured it.
    SortChildren; ///> Before laying out nodes, sort the children based on `Node.z_index`.
    NoClip;       ///> Don't clip nodes when drawing children nodes.
    NoPaddedClip; ///> Don't pad the clip box.
}

TextEffects :: enum_flags u8 {
    Underline;
    Strikethrough;
}

/**
 * @brief Describes the interaction state of a `Node`.
 *
 * @see NodeStateFlags
 */
NodeState :: enum u8 {
    Disabled; ///> Unused for now. Block interactions.
    Active;   ///> Dependent on the interaction type and what the user does with it but usually means a node is selected.
    Hot;      ///> Currently being interacted with (e.g. pressed an holding a button).
    Focused;  ///> Hovered by the mouse and capturing the mouse focus. @see NodeFlags.Focusable
    None;     ///> Not interacting
}

Num_Node_States :: #run type_info(NodeState).values.count;

/**
 * @brief Current and last frame `Node` states
 *
 * Describes the combined interaction states of a `Node` (e.g. a `Node` can be `Active` and `Focused` at the same time).
 * Keeps track of the previous frame's state too.
 *
 * @see NodeState
 */
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

/**
 * @brief Current and last frame mouse interaction
 *
 * Describes the mouse buttons interacting with a `Node`. Usually only one value of this enum is set at a time.
 * Keeps track of the previous frame's state too.
 *
 * @see MouseButton
 * @see MouseButtonFlags
 */
NodeInteractingMouseButtons :: enum_flags u8 {
    Left   :: 1 << MouseButton.Left;
    Middle :: 1 << MouseButton.Middle;
    Right  :: 1 << MouseButton.Right;
    CurrentFrame :: Left | Middle | Right;

    LeftLastFrame   :: Left   << 3;
    MiddleLastFrame :: Middle << 3;
    RightLastFrame  :: Right  << 3;
    LastFrame :: LeftLastFrame | MiddleLastFrame | RightLastFrame;
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

/**
 * @brief Base struct for a `Node` user data
 *
 * Base struct used for a `Node`'s user data. User data can be added to a `Node` in a linked list. It is destroyed when the `Node` is freed.
 * User data can also be added to the `Context` (i.e. global user data), in which case the `Node` is null.
 *
 * @see AddUserData
 * @see GetUserData
 * @see SetUserData
 * @see AddGlobalUserData
 * @see GetGlobalUserData
 */
NodeUserData :: struct {
    next : *NodeUserData;     ///> Linked list next element.
    destroy : (*Node, *void); ///> Destroy callback.
    id : ID;                  ///> Unique id within the node.
}

/**
 * @brief UI element tree node
 *
 * Nodes are the core building block of a UI. They contain all the information required to perform
 * the layout calculations, as well as styling information and attached user data.
 * Nodes form a tree structure, with each children enclosed and clipped by its parent.
 */
Node :: struct {
    id : ID;                ///> Global ID (local ID combined with the parent's global ID).
    local_id : ID;          ///> Local ID within the parent, unique within the node's siblings.
    index : Bucket_Locator; ///> Index in the node_pool Bucket_Array.

    last_used_on_frame : u64; ///> Keep tracks of when the node was last declared. If a node was not declared during the current frame it is freed.
    z_index : s32 = -1;       ///> Used when the parent wants to sort children. After sorting this is set to the actual index in the list of children.

    draw : (*DrawList, *Node) -> draw_children : bool;          ///> Drawing function for the node. Initialized to the context's default drawing function.
    hit_test : (*Node, point : Vec2f) -> bool = DefaultHitTest; ///> Hit test function. Change this to perform custom hit test logic. Clipping test must be performed inside this function manually.
    user_data : *NodeUserData;                                  ///> Attached user data.

    window : *Window; ///> UI window the node was declared in.
    parent : *Node;

    using tree : struct {
        first_child : *Node;
        last_child : *Node;
        next_sibling : *Node;
        prev_sibling : *Node;
        num_children : s32;
    };

    tree_last_frame : type_of(tree);

    /**
     * @brief Layout data.
     *
     * Computed during the layout phase at the end of the frame.
     * Before then it refers to the layout results of the previous frame.
     */
    using layout : struct {
        size : Vec2f;
        children_size : Vec2f;
        relative_position : Vec2f;
        rect : Vec4f;
        clipped_rect : Vec4f;
    };

    /**
     * @brief Layout properties.
     *
     * User controlled properties that affect the layout, reset each frame except for scroll and offset
     */
    using properties : struct {
        font : *Font;
        text : string;
        text_size : float;

        flags : NodeFlags;

        offset : Vec2f;                                           ///> Offset relative to the parent, after scroll is applied. Not reset each frame.
        scroll : Vec2f;                                           ///> Scroll, additional offset applied to children. Not reset each frame.
        child_align : Vec2f;                                      ///> Child alignment on each axis; 0 means the start of the axis, 1 means the end (depends on the layout direction).
        desired_size := Size2D.{.{kind=.FitChildren}, .{kind=.FitChildren}};
        min_size := Vec2f.{-FLOAT32_INFINITY, -FLOAT32_INFINITY}; ///> Min size in pixels.
        max_size := Vec2f.{ FLOAT32_INFINITY,  FLOAT32_INFINITY}; ///> Max size in pixels.
        min_size_fit : enum_flags u8 {
            Width;  ///> Fit children on the X axis
            Height; ///> Fit children on the Y axis
        }; ///> Flags describing whether the node should at least fit its child contents.
        child_gap : Vec2b; ///> Gap between children (at most 127). Currently the value on the cross layout axis is unused, until we have element wrapping.
        padding : Vec4b;   ///> Inner padding applied on the left, top, right and bottom of the node (at most 127).
        child_layout_mode := LayoutMode.LeftToRight;
    };

    /**
     * @brief Styling properties.
     *
     * Styling properties, reset each frame. These do not affect the hit-test or layout results and are purely visual.
     */
    using styling : struct {
        image : TextureHandle;
        image_uv_bounds : Vec4f;
        corner_radiuses : Vec4f;       ///> Radius for the top-left, top-right, bottom-left and bottom-right corners.
        background_colors : BoxColors; ///> Colors for each corner of the background.
        border_colors : BoxColors;     ///> Colors for each corner of the border.
        border_size : float;           ///> Thickness of the border. Border is applied *within* the node.
        border_inset : float;          ///> Amount of inset applied to the border, positive means the border will be smaller than the background, negative means it will go outside.
        outer_shadow_size : float;
        outer_shadow_offset : Vec2f;
        outer_shadow_color : RGBA8;
        inner_shadow_size : float;     ///> Size of the inner shadow. Warning: Currently a size greater than the smallest corner radius will produce visual artifacts (except for a size or min corner radius of 0).
        inner_shadow_color : RGBA8;
        text_color : RGBA8;
        text_effects : TextEffects;
    };

    state_flags : NodeStateFlags; ///> The state combination of the node in the current and last frames.
    interacting_mouse_buttons : NodeInteractingMouseButtons; ///> The mouse button(s) that are interacting with the node in the current and last frames.
}

/**
 * @brief Iterate over a node's children.
 */
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

/**
 * @brief Iterate over a node's previous frame children.
 */
PrevFrameChildren :: (node : *Node, body : Code, flags : For_Flags) #expand {
    #if flags & .REVERSE {
        `it := node.tree_last_frame.last_child;
        `it_index := node.tree_last_frame.num_children - 1;
    } else {
        `it := node.tree_last_frame.first_child;
        `it_index := 0;
    }

    while it {
        #if flags & .REVERSE {
            next := it.tree_last_frame.prev_sibling;
        } else {
            next := it.tree_last_frame.next_sibling;
        }

        defer it = next;

        #insert body;
    }
}

DefaultHitTest :: (node : *Node, point : Vec2f) -> bool {
    return IsInsideRect(point, node.clipped_rect);
}

IsHovered :: (node : *Node) -> bool {
    if !node.hit_test {
        return false;
    }

    mouse := GetMousePosition(node.window);

    return node.hit_test(node, mouse);
}

/**
 * @brief Check if a Node is a descendant of another.
 *
 * @returns true if `node` is a descendant of `of`, false otherwise.
 */
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

/**
 * @brief Check if a Node is a descendant of another.
 *
 * @returns true if `node` is a descendant of `of`, false otherwise.
 */
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

/**
 * @brief Iterate over a node's attached user data.
 */
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
    ptr, is_new, data := GetUserData(node, T, true);
    data.destroy = destroy;
    return ptr, is_new, data;
}

AddUserData :: inline (node : *Node, str_id : string, $T : Type, destroy : type_of(NodeUserData.destroy) = null) -> *T, is_new : bool, *NodeUserData {
    ptr, is_new, data := GetUserData(node, str_id, T, true);
    data.destroy = destroy;
    return ptr, is_new, data;
}

AddUserData :: inline (node : *Node, id : ID, $T : Type, destroy : type_of(NodeUserData.destroy) = null) -> *T, is_new : bool, *NodeUserData {
    ptr, is_new, data := GetUserData(node, id, T, true);
    data.destroy = destroy;
    return ptr, is_new, data;
}

AddUserData :: (node : *Node, id : ID, size : int, destroy : type_of(NodeUserData.destroy) = null) -> *void, is_new : bool, *NodeUserData {
    ptr, is_new, data := GetUserData(node, id, size, true);
    data.destroy = destroy;
    return ptr, is_new, data;
}

SetUserData :: inline (node : *Node, value : $T, destroy : type_of(NodeUserData.destroy) = null) -> *T, is_new : bool, *NodeUserData {
    ptr, is_new, data := GetUserData(node, T, true);
    ptr.* = value;
    data.destroy = destroy;
    return ptr, is_new, data;
}

SetUserData :: inline (node : *Node, str_id : string, value : $T, destroy : type_of(NodeUserData.destroy) = null) -> *T, is_new : bool, *NodeUserData {
    ptr, is_new, data := GetUserData(node, str_id, T, true);
    ptr.* = value;
    data.destroy = destroy;
    return ptr, is_new, data;
}

SetUserData :: inline (node : *Node, id : ID, value : $T, destroy : type_of(NodeUserData.destroy) = null) -> *T, is_new : bool, *NodeUserData {
    ptr, is_new, data := GetUserData(node, id, T, true);
    ptr.* = value;
    data.destroy = destroy;
    return ptr, is_new, data;
}

GetUserData :: inline (node : *Node, $T : Type, create := false) -> *T, is_new : bool, *NodeUserData {
    ptr, is_new, data := GetUserData(node, cast(ID, type_info(T)), T, create);
    return ptr, is_new, data;
}

GetUserData :: inline (node : *Node, str_id : string, $T : Type, create := false) -> *T, is_new : bool, *NodeUserData {
    ptr, is_new, data := GetUserData(node, GetID(str_id, false), T, create);
    return ptr, is_new, data;
}

GetUserData :: inline (node : *Node, id : ID, $T : Type, create := false) -> *T, is_new : bool, *NodeUserData {
    ptr, is_new, data := GetUserData(node, id, size_of(T), create);
    if is_new {
        Initialize(cast(*T, ptr));
    }

    return xx ptr, is_new, data;
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
    node.draw = context.omg.default_draw_node;

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

    HT.table_remove(*context.omg.nodes_by_id, node.id);
    bucket_array_remove(*context.omg.node_pool, node.index);

    if window.root_node == node {
        window.root_node = null;
    }
    if window.popup_root_node == node {
        window.popup_root_node = null;
    }
} @Profile

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

/**
 * @brief Get a node by its global ID.
 */
GetNodeByGlobalID :: inline (id : ID) -> *Node {
    _, node := HT.table_find(*context.omg.nodes_by_id, id);
    return node;
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

    node.tree = .{};
    node.styling = .{};

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

        table_entry := HT.find_or_add(*context.omg.nodes_by_id, window.popup_root_node.id);
        table_entry.* = window.popup_root_node;

        is_new = true;
    }

    TouchNode(window.popup_root_node);

    return window.popup_root_node, is_new;
}

FindNode :: inline (parent : *Node, str_id : string) -> *Node {
    return FindNode(parent, GetID(str_id));
}

FindNode :: (parent : *Node, id : ID) -> *Node {
    for :Children parent {
        if it.local_id == id {
            return it;
        }
    }

    return null;
}

FindPrevFrameNode :: inline (parent : *Node, str_id : string) -> *Node {
    return FindPrevFrameNode(parent, GetID(str_id));
}

FindPrevFrameNode :: (parent : *Node, id : ID) -> *Node {
    for :PrevFrameChildren parent {
        if it.local_id == id {
            return it;
        }
    }

    return null;
}

/**
 * @brief Get a Window's root Node.
 *
 * Get the root Node of a Window. The root always sets its size to the window's size in pixels.
 */
GetNode :: (window : *Window) -> *Node, is_new : bool {
    is_new : bool;

    if !window.root_node {
        window.root_node = AllocNode();
        window.root_node.window = window;
        window.root_node.local_id = GetID("Root");
        window.root_node.id = GetID(window.root_node.local_id, cast(u64, window));

        table_entry := HT.find_or_add(*context.omg.nodes_by_id, window.root_node.id);
        table_entry.* = window.root_node;

        is_new = true;
    }

    TouchNode(window.root_node);

    return window.root_node, is_new;
} @Profile

/**
 * @brief Get or declare a new Node.
 *
 * Get a children Node of `parent` that was declared prior in the frame, or create it if it does not exist.
 *
 * @param is_global_id If false, the id is hashed against the parent's, otherwise id and local_id are the same.
 */
GetNode :: inline (parent : *Node, location := #caller_location, is_global_id := false) -> *Node, is_new : bool {
    node, is_new := GetNode(parent, GetID(location), is_global_id);
    return node, is_new;
}

/**
 * @brief Get or declare a new Node.
 *
 * Get a children Node of `parent` that was declared prior in the frame, or create it if it does not exist.
 *
 * @param is_global_id If false, the id is hashed against the parent's, otherwise id and local_id are the same.
 */
GetNode :: inline (parent : *Node, str_id : string, is_global_id := false) -> *Node, is_new : bool {
    node, is_new := GetNode(parent, GetID(str_id), is_global_id);
    return node, is_new;
}

/**
 * @brief Get or declare a new Node.
 *
 * Get a children Node of `parent` that was declared prior in the frame, or create it if it does not exist.
 *
 * @param is_global_id If false, the id is hashed against the parent's, otherwise id and local_id are the same.
 */
GetNode :: (parent : *Node, id : ID, is_global_id := false) -> *Node, is_new : bool {
    assert(id != 0);
    assert(parent != null && parent.last_used_on_frame == context.omg.frame_index);
    assert(parent.window != null);

    node := FindPrevFrameNode(parent, id);

    if !node {
        node = FindNode(parent, id);
    }

    is_new : bool;

    if !node {
        node = AllocNode();
        node.window = parent.window;
        node.parent = parent;
        node.local_id = id;
        node.id = ifx is_global_id then id else GetID(id, base=parent.id);

        table_entry := HT.find_or_add(*context.omg.nodes_by_id, node.id);
        table_entry.* = node;

        is_new = true;
    }

    TouchNode(node);

    return node, is_new;
} @Profile

/**
 * @brief Get or declare a new popup Node in a Window.
 *
 * Get or declare a new popup Node in a Window. A Window contains a root Node and a root popup Node for floating nodes.
 *
 * @param is_global_id If false, the id is hashed against the parent's, otherwise id and local_id are the same.
 */
GetPopupNode :: inline (window : *Window, location := #caller_location, is_global_id := true) -> *Node, is_new : bool {
    node, is_new := GetNode(GetPopupRoot(window), location, is_global_id);
    return node, is_new;
}

/**
 * @brief Get or declare a new popup Node in a Window.
 *
 * Get or declare a new popup Node in a Window. A Window contains a root Node and a root popup Node for floating nodes.
 *
 * @param is_global_id If false, the id is hashed against the parent's, otherwise id and local_id are the same.
 */
GetPopupNode :: inline (window : *Window, str_id : string, is_global_id := true) -> *Node, is_new : bool {
    node, is_new := GetNode(GetPopupRoot(window), str_id, is_global_id);
    return node, is_new;
}

/**
 * @brief Get or declare a new popup Node in a Window.
 *
 * Get or declare a new popup Node in a Window. A Window contains a root Node and a root popup Node for floating nodes.
 *
 * @param is_global_id If false, the id is hashed against the parent's, otherwise id and local_id are the same.
 */
GetPopupNode :: inline (window : *Window, id : ID, is_global_id := true) -> *Node, is_new : bool {
    node, is_new := GetNode(GetPopupRoot(window), id, is_global_id);
    return node, is_new;
}

/**
 * @brief Bing a Node on top of its siblings.
 *
 * Bring a Node on top of its siblings, only effective if the parent has the SortChildren flag.
 *
 * @see NodeFlags.SortChildren
 */
BringForward :: (node : *Node) {
    node.z_index = S32_MAX;
}

SetHitTest :: inline (node : *Node, hit_test : type_of(Node.hit_test)) {
    node.hit_test = hit_test;
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

SetMinWidthFit :: inline (node : *Node, fit := true) {
    if fit {
        node.min_size_fit |= .Width;
    } else {
        node.min_size_fit &= ~.Width;
    }
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

SetMinHeightFit :: inline (node : *Node, fit := true) {
    if fit {
        node.min_size_fit |= .Height;
    } else {
        node.min_size_fit &= ~.Height;
    }
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

SetMinSizeFit :: inline (node : *Node, x := true, y := true) {
    SetMinWidthFit(node, x);
    SetMinHeightFit(node, y);
}

SetMaxSize :: inline (node : *Node, size : Vec2f) {
    node.max_size = size;
}

SetMaxSize :: inline (node : *Node, x : float, y : float) {
    node.max_size = .{x, y};
}

SetPadding :: inline (node : *Node, padding : Vec4b) {
    node.padding = padding;
}

SetPadding :: inline (node : *Node, x : s8, y : s8) {
    node.padding = .{x, y, x, y};
}

SetPadding :: inline (node : *Node, left : s8, top : s8, right : s8, bottom : s8) {
    node.padding = .{left, top, right, bottom};
}

SetChildGap :: inline (node : *Node, gap : Vec2b) {
    node.child_gap = gap;
}

SetChildGap :: inline (node : *Node, x : s8, y : s8) {
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

SetImage :: inline (node : *Node, image : TextureHandle, uv_bounds := Vec4f.{0,0,1,1}) {
    node.image = image;
    node.image_uv_bounds = uv_bounds;
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
    for * node.background_colors.corners {
        it.* = ColorU32(r, g, b, a);
    }
}

SetBackgroundColor :: inline (node : *Node, color : Vec4f) {
    for * node.background_colors.corners {
        it.* = ColorU32(color);
    }
}

SetBackgroundColor :: inline (node : *Node, color : RGBA8) {
    for * node.background_colors.corners {
        it.* = color;
    }
}

SetBackgroundColors :: inline (node : *Node, top_left : RGBA8, top_right : RGBA8, bottom_left : RGBA8, bottom_right : RGBA8) {
    node.background_colors.top_left = top_left;
    node.background_colors.top_right = top_right;
    node.background_colors.bottom_left = bottom_left;
    node.background_colors.bottom_right = bottom_right;
}

SetBackgroundColors :: inline (node : *Node, colors : BoxColors) {
    node.background_colors = colors;
}

SetBorderColor :: inline (node : *Node, r : float, g : float, b : float, a : float) {
    for * node.border_colors.corners {
        it.* = ColorU32(r, g, b, a);
    }
}

SetBorderColor :: inline (node : *Node, color : Vec4f) {
    for * node.border_colors.corners {
        it.* = ColorU32(color);
    }
}

SetBorderColor :: inline (node : *Node, color : RGBA8) {
    for * node.border_colors.corners {
        it.* = color;
    }
}

SetBorderColors :: inline (node : *Node, top_left : RGBA8, top_right : RGBA8, bottom_left : RGBA8, bottom_right : RGBA8) {
    node.border_colors.top_left = top_left;
    node.border_colors.top_right = top_right;
    node.border_colors.bottom_left = bottom_left;
    node.border_colors.bottom_right = bottom_right;
}

SetBorderColors :: inline (node : *Node, colors : BoxColors) {
    node.border_colors = colors;
}

SetBorderSize :: inline (node : *Node, size : float) {
    node.border_size = size;
}

SetBorderInset :: inline (node : *Node, inset : float) {
    node.border_inset = inset;
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

SetOuterShadowColor :: inline (node : *Node, color : RGBA8) {
    node.outer_shadow_color = color;
}

SetOuterShadowOpacity :: inline (node : *Node, alpha : float) {
    SetAlpha(*node.outer_shadow_color, alpha);
}

SetOuterShadowSize :: inline (node : *Node, blur : float) {
    node.outer_shadow_size = blur;
}

SetInnerShadowColor :: inline (node : *Node, r : float, g : float, b : float, a : float) {
    node.inner_shadow_color = ColorU32(r, g, b, a);
}

SetInnerShadowColor :: inline (node : *Node, color : Vec4f) {
    node.inner_shadow_color = ColorU32(color);
}

SetInnerShadowColor :: inline (node : *Node, color : RGBA8) {
    node.inner_shadow_color = color;
}

SetInnerShadowOpacity :: inline (node : *Node, alpha : float) {
    SetAlpha(*node.inner_shadow_color, alpha);
}

SetInnerShadowSize :: inline (node : *Node, blur : float) {
    node.inner_shadow_size = blur;
}
