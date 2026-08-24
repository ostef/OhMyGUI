#import "Basic";
#import "Math";
#import "Bucket_Array";
#import "Print_Vars";
HT :: #import "Hash_Table";
using,only(.["for_expansion"]) HT;
#import "String";

#load "math.jai";
#load "color.jai";
#load "unicode.jai";
#load "input.jai";
#load "sdf.jai";
#load "draw.jai";
#load "text.jai";
#load "node.jai";
#load "style.jai";
#load "layout.jai";

#load "Widgets/widgets.jai";

Context :: struct {
    frame_index : u64;
    delta_time : float;
    layout_time_last_frame : float;
    draw_time_last_frame : float;
    total_time_last_frame : float;

    platform_funcs : PlatformFunctions;
    renderer_funcs : RendererFunctions;

    debug_mode := false;

    general_purpose_allocator : Allocator;

    mouse_wheel_multiplier := 10.0;

    input : InputContext;
    cursor_this_frame : PlatformCursorHandle;

    windows : *Window;
    fonts : *Font;
    node_pool : Bucket_Array(Node, 300);
    nodes_by_id : HT.Table(ID, *Node);
    user_data : *NodeUserData;

    theme : *Theme;
    id_offset_stack : [..]int;

    mouse_hovered_node : *Node;
    mouse_focused_node : *Node;
    mouse_capturing_node : *Node;
    mouse_captured_this_frame : bool;
    mouse_captured_at : Vec2f = .{FLOAT32_NAN, FLOAT32_NAN};
    mouse_captured_node_value : Vec4f = .{FLOAT32_NAN, FLOAT32_NAN, FLOAT32_NAN, FLOAT32_NAN}; // Value that nodes can specify upon capturing the mouse
    scroll_focused_node : *Node;
}

#add_context omg : *Context;

PlatformWindowHandle :: *void;
PlatformCursorHandle :: *void;

PlatformWindowFlags :: enum_flags {
    HasInputFocus;
    HasMouseFocus;
    Minimized;
    Maximized;
}

PlatformFunctions :: struct {
    GetWindowPosition : (handle : PlatformWindowHandle) -> int, int;
    SetWindowPosition : (handle : PlatformWindowHandle, x : int, y : int);
    GetWindowSize : (handle : PlatformWindowHandle) -> int, int;
    SetWindowSize : (handle : PlatformWindowHandle, width : int, height : int);
    GetWindowFlags : (handle : PlatformWindowHandle) -> PlatformWindowFlags;
    GetMousePosition : () -> int, int;
    CaptureMouse : (capture : bool);
    SetCursor : (handle : PlatformCursorHandle);
    CreateRGBA8Cursor : (pixels : *void, width : u32, height : u32, hot_x_01 : float, hot_y_01 : float) -> PlatformCursorHandle;
    CreateSystemCursor : (system_cursor : SystemCursor) -> PlatformCursorHandle;
    DestroyCursor : (cursor : PlatformCursorHandle);
    GetClipboardText : () -> string;
    SetClipboardText : (text : string);
    HasClipboardText : () -> bool;
}

PlatformGetWindowPosition :: inline (handle : PlatformWindowHandle) -> int, int {
    if context.omg.platform_funcs.GetWindowPosition {
        x, y := context.omg.platform_funcs.GetWindowPosition(handle);
        return x, y;
    }

    return 0, 0;
}

PlatformSetWindowPosition :: inline (handle : PlatformWindowHandle, x : int, y : int) {
    if context.omg.platform_funcs.SetWindowPosition {
        context.omg.platform_funcs.SetWindowPosition(handle, x, y);
    }
}

PlatformGetWindowSize :: inline (handle : PlatformWindowHandle) -> int, int {
    if context.omg.platform_funcs.GetWindowSize {
        w, h := context.omg.platform_funcs.GetWindowSize(handle);
        return w, h;
    }

    return 0, 0;
}

PlatformSetWindowSize :: inline (handle : PlatformWindowHandle, width : int, height : int) {
    if context.omg.platform_funcs.SetWindowSize {
        context.omg.platform_funcs.SetWindowSize(handle, width, height);
    }
}

PlatformGetWindowFlags :: inline (handle : PlatformWindowHandle) -> PlatformWindowFlags {
    if context.omg.platform_funcs.GetWindowFlags {
        return context.omg.platform_funcs.GetWindowFlags(handle);
    }

    return 0;
}

PlatformGetMousePosition :: inline () -> int, int {
    if context.omg.platform_funcs.GetMousePosition {
        x, y := context.omg.platform_funcs.GetMousePosition();
        return x, y;
    }

    return 0, 0;
}

PlatformCaptureMouse :: inline (capture : bool) {
    if context.omg.platform_funcs.CaptureMouse {
        context.omg.platform_funcs.CaptureMouse(capture);
    }
}

PlatformSetCursor :: inline (handle : PlatformCursorHandle) {
    if context.omg.platform_funcs.SetCursor {
        context.omg.platform_funcs.SetCursor(handle);
    }
}

PlatformCreateSystemCursor :: inline (system_cursor : SystemCursor) -> PlatformCursorHandle {
    if context.omg.platform_funcs.CreateSystemCursor {
        return context.omg.platform_funcs.CreateSystemCursor(system_cursor);
    }
    return null;
}

PlatformCreateRGBA8Cursor :: inline (pixels : *void, width : u32, height : u32, hot_x_01 : float, hot_y_01 : float) -> PlatformCursorHandle {
    if context.omg.platform_funcs.CreateRGBA8Cursor {
        return context.omg.platform_funcs.CreateRGBA8Cursor(pixels, width, height, hot_x_01, hot_y_01);
    }
    return null;
}

PlatformDestroyCursor :: inline (cursor : PlatformCursorHandle) {
    if context.omg.platform_funcs.DestroyCursor {
        context.omg.platform_funcs.DestroyCursor(cursor);
    }
}

PlatformGetClipboardText :: inline () -> string {
    if context.omg.platform_funcs.GetClipboardText {
        return context.omg.platform_funcs.GetClipboardText();
    }
    return "";
}

PlatformSetClipboardText :: inline (text : string) {
    if context.omg.platform_funcs.SetClipboardText {
        context.omg.platform_funcs.SetClipboardText(text);
    }
}

PlatformHasClipboardText :: inline () -> bool {
    if context.omg.platform_funcs.HasClipboardText {
        return context.omg.platform_funcs.HasClipboardText();
    }
    return false;
}

RendererFunctions :: struct {
    CreateR8Texture : (name : string, data : *void, width : u32, height : u32) -> TextureHandle;
    CreateRGBA8Texture : (name : string, data : *void, width : u32, height : u32) -> TextureHandle;
    DestroyTexture : (texture : TextureHandle);
}

RendererCreateR8Texture :: inline (name : string, data : *void, width : u32, height : u32) -> TextureHandle {
    if context.omg.renderer_funcs.CreateR8Texture {
        return context.omg.renderer_funcs.CreateR8Texture(name, data, width, height);
    }
    return 0;
}

RendererCreateRGBA8Texture :: inline (name : string, data : *void, width : u32, height : u32) -> TextureHandle {
    if context.omg.renderer_funcs.CreateRGBA8Texture {
        return context.omg.renderer_funcs.CreateRGBA8Texture(name, data, width, height);
    }
    return 0;
}

RendererDestroyTexture :: inline (texture : TextureHandle) {
    if context.omg.renderer_funcs.DestroyTexture {
        context.omg.renderer_funcs.DestroyTexture(texture);
    }
}

GetTheme :: inline () -> *Theme {
    return context.omg.theme;
}

SetTheme :: inline (theme : *Theme) {
    context.omg.theme = theme;
}

Window :: struct {
    platform_handle : PlatformWindowHandle;
    prev : *Window;
    next : *Window;

    root_node : *Node;
    popup_root_node : *Node;
    draw_list : DrawList;
}

// for_expansion
Windows :: (ctx : *Context, body : Code, flags : For_Flags) #expand {
    `it := ctx.windows;
    `it_index := 0;
    while it {
        next := it.next;
        defer {
            it = next;
            it_index += 1;
        }

        #insert body;
    }
}

GetMouseHoveredWindow :: () -> *Window {
    for :Windows context.omg {
        if PlatformGetWindowFlags(it.platform_handle) & .HasMouseFocus {
            return it;
        }
    }

    return null;
}

GetWindow :: (handle : PlatformWindowHandle, create := true) -> *Window {
    for :Windows context.omg {
        if it.platform_handle == handle {
            return it;
        }
    }

    if !create {
        return null;
    }

    w := New(Window);
    InitDrawList(*w.draw_list);
    w.platform_handle = handle;
    w.next = context.omg.windows;
    if w.next {
        w.next.prev = w;
    }
    context.omg.windows = w;

    return w;
}

DestroyWindow :: (window : *Window) {
    if window.prev {
        window.prev.next = window.next;
    }
    if window.next {
        window.next.prev = window.prev;
    }

    if context.omg.windows == window {
        context.omg.windows = window.next;
    }

    DestroyDrawList(*window.draw_list);

    if window.popup_root_node {
        FreeNode(window.popup_root_node);
    }

    if window.root_node {
        FreeNode(window.root_node);
    }

    free(window);
}

ScreenToWindow :: (window : *Window, point : Vec2f) -> Vec2f {
    wx, wy := PlatformGetWindowPosition(window.platform_handle);

    return point - Vec2f.{xx wx, xx wy};
}

ScreenToWindow :: (window : *Window, rect : Vec4f) -> Vec4f {
    wx, wy := PlatformGetWindowPosition(window.platform_handle);

    return .{
        xy=rect.xy - Vec2f.{xx wx, xx wy},
        zw=rect.zw - Vec2f.{xx wx, xx wy},
    };
}

WindowToScreen :: (window : *Window, point : Vec2f) -> Vec2f {
    wx, wy := PlatformGetWindowPosition(window.platform_handle);

    return point + Vec2f.{xx wx, xx wy};
}

WindowToScreen :: (window : *Window, rect : Vec4f) -> Vec4f {
    wx, wy := PlatformGetWindowPosition(window.platform_handle);

    return .{
        xy=rect.xy + Vec2f.{xx wx, xx wy},
        zw=rect.zw + Vec2f.{xx wx, xx wy},
    };
}

// for_expansion
UserData :: (ctx : *Context, body : Code, flags : For_Flags) #expand {
    `it := ctx.user_data;
    `it_index := 0;

    while it {
        next := it.next;
        defer it = next;

        #insert body;
    }
}

AddGlobalUserData :: inline ($T : Type, destroy : type_of(NodeUserData.destroy) = null) -> *T, is_new : bool, *NodeUserData {
    ptr, is_new, data := GetGlobalUserData(T, true);
    data.destroy = destroy;
    return ptr, is_new, data;
}

AddGlobalUserData :: inline (str_id : string, $T : Type, destroy : type_of(NodeUserData.destroy) = null) -> *T, is_new : bool, *NodeUserData {
    ptr, is_new, data := GetGlobalUserData(str_id, T, true);
    data.destroy = destroy;
    return ptr, is_new, data;
}

AddGlobalUserData :: inline (id : ID, $T : Type, destroy : type_of(NodeUserData.destroy) = null) -> *T, is_new : bool, *NodeUserData {
    ptr, is_new, data := GetGlobalUserData(id, T, true);
    data.destroy = destroy;
    return ptr, is_new, data;
}

AddGlobalUserData :: (id : ID, size : int, destroy : type_of(NodeUserData.destroy) = null) -> *void, is_new : bool, *NodeUserData {
    ptr, is_new, data := GetGlobalUserData(id, size, true);
    data.destroy = destroy;
    return ptr, is_new, data;
}

GetGlobalUserData :: inline ($T : Type, create := false) -> *T, is_new : bool, *NodeUserData {
    ptr, is_new, data := GetGlobalUserData(cast(ID, type_info(T)), T, create);
    return ptr, is_new, data;
}

GetGlobalUserData :: inline (str_id : string, $T : Type, create := false) -> *T, is_new : bool, *NodeUserData {
    ptr, is_new, data := GetGlobalUserData(GetID(str_id, false), T, create);
    return ptr, is_new, data;
}

GetGlobalUserData :: inline (id : ID, $T : Type, create := false) -> *T, is_new : bool, *NodeUserData {
    ptr, is_new, data := GetGlobalUserData(id, size_of(T), create);
    if is_new {
        Initialize(cast(*T, ptr));
    }

    return xx ptr, is_new, data;
}

GetGlobalUserData :: (id : ID, size : int, create := false) -> *void, is_new : bool, *NodeUserData {
    for :UserData context.omg {
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

    list_node.next = context.omg.user_data;
    context.omg.user_data = list_node;

    return cast(*void, list_node + 1), true, list_node;
}

Init :: (platform_funcs : PlatformFunctions, renderer_funcs : RendererFunctions) {
    context.omg = New(Context);
    context.omg.general_purpose_allocator = context.allocator;
    context.omg.node_pool.allocator = context.allocator;
    context.omg.platform_funcs = platform_funcs;
    context.omg.renderer_funcs = renderer_funcs;

    InitInput(*context.omg.input);

    InitSystemCursors();

    LoadDefaultFonts();

    SetupDefaultTheme(
        *g_default_theme_light,
        base_text_size=14,
        base_background_color=ColorU32(0.95, 0.95, 0.95, 1),
        base_accent_color=ColorU32(0.3, 0.5, 0.8, 1),
    );
    SetupDefaultTheme(
        *g_default_theme_dark,
        base_text_size=14,
        base_background_color=ColorU32(0.05, 0.05, 0.05, 1),
        base_accent_color=ColorU32(0.3, 0.5, 0.8, 1),
    );

    SetTheme(*g_default_theme_dark);
}

Terminate :: () {
    while context.omg.windows {
        DestroyWindow(context.omg.windows);
    }

    while context.omg.fonts {
        DestroyFont(context.omg.fonts);
    }

    for :UserData context.omg {
        if it.destroy {
            it.destroy(null, cast(*void, it + 1));
        }

        free(it ,, context.omg.general_purpose_allocator);
    }

    array_reset(*context.omg.id_offset_stack);

    DestroyInput(*context.omg.input);
    DestroySystemCursors();

    bucket_array_reset(*context.omg.node_pool);

    free(context.omg);
    context.omg = null;
}

SetMouseFocus :: inline (node : *Node) {
    if context.omg.mouse_focused_node {
        context.omg.mouse_focused_node.state_flags &= ~.Focused;
    }

    context.omg.mouse_focused_node = node;

    if node {
        node.state_flags |= .Focused;
    }
}

SetScrollFocus :: inline (node : *Node) {
    context.omg.scroll_focused_node = node;
}

SetMouseCapture :: inline (node : *Node) {
    SetMouseCapture(node, .{});
}

SetMouseCapture :: inline (node : *Node, node_value : Vec4f) {
    if context.omg.mouse_capturing_node != node {
        context.omg.mouse_captured_at = GetMousePosition();
        context.omg.mouse_captured_node_value = node_value;
    }

    context.omg.mouse_capturing_node = node;
    context.omg.mouse_captured_this_frame = true;
}

NewFrame :: (delta_time : float) {
    FindMouseFocus :: (node : *Node) {
        omg := context.omg;

        if node.parent && IsHovered(node) {
            omg.mouse_hovered_node = node;

            if !omg.mouse_capturing_node || omg.mouse_capturing_node == node {
                if node.flags & .Focusable {
                    omg.mouse_focused_node = node;
                }
                if node.flags & .Scrollable {
                    omg.scroll_focused_node = node;
                }
            }
        }

        for :Children node {
            FindMouseFocus(it);
        }
    }

    omg := context.omg;

    omg.frame_index += 1;
    omg.delta_time = delta_time;

    InputNewFrame(*context.omg.input);

    ProcessDockNodeSplitRequests();
    RemoveEmptyDockNodes();

    SetCursor(null);

    omg.mouse_hovered_node = null;
    omg.mouse_focused_node = null;
    omg.scroll_focused_node = null;

    for * omg.node_pool {
        it.state_flags = (it.state_flags & .CurrentFrame) << (Num_Node_States - 1);
    }

    for :Windows omg {
        if it.root_node {
            FindMouseFocus(it.root_node);
        }

        if it.popup_root_node {
            FindMouseFocus(it.popup_root_node);
        }
    }

    for :Windows omg {
        if it.root_node {
            TouchNode(it.root_node);
        }
        if it.popup_root_node {
            TouchNode(it.popup_root_node);
        }
    }

    if omg.mouse_focused_node {
        omg.mouse_focused_node.state_flags |= .Focused;
    }
}

Render :: () {
    // @Todo: find a way to not hardcode this
    ColorPickerSubwindow();

    omg := context.omg;
    omg.layout_time_last_frame = 0;
    omg.draw_time_last_frame = 0;
    omg.total_time_last_frame = 0;

    total_start := current_time_monotonic();

    if omg.id_offset_stack.count > 0 {
        log_error("Mismatching number of push/pop for ID offset stack");
        omg.id_offset_stack.count = 0;
    }

    if !omg.mouse_captured_this_frame {
        omg.mouse_capturing_node = null;
        PlatformCaptureMouse(false);
    } else {
        PlatformCaptureMouse(true);
    }
    omg.mouse_captured_this_frame = false;

    if omg.cursor_this_frame {
        PlatformSetCursor(omg.cursor_this_frame);
    } else {
        PlatformSetCursor(GetSystemCursor(.Arrow));
    }

    for * omg.node_pool {
        it.layout = .{};
    }

    for :Windows omg {
        w, h := PlatformGetWindowSize(it.platform_handle);

        layout_start := current_time_monotonic();

        if it.root_node {
            SetSize(it.root_node, SizePx(xx w), SizePx(xx h));

            LayoutNodes(it.root_node);
        }

        if it.popup_root_node {
            SetLayout(it.popup_root_node, .None);
            SetChildAlign(it.popup_root_node, 0, 0);
            SetSize(it.popup_root_node, SizePx(xx w), SizePx(xx h));
            it.popup_root_node.flags |= .SortChildren;

            LayoutNodes(it.popup_root_node);
        }

        layout_end := current_time_monotonic();
        omg.layout_time_last_frame += xx to_float64_seconds(layout_end - layout_start);

        draw_start := current_time_monotonic();

        if it.root_node {
            DrawNodes(*it.draw_list, it.root_node);
        }
        if it.popup_root_node {
            DrawNodes(*it.draw_list, it.popup_root_node);
        }

        draw_end := current_time_monotonic();
        omg.draw_time_last_frame += xx to_float64_seconds(draw_end - draw_start);
    }

    for * omg.node_pool {
        if it.last_used_on_frame != omg.frame_index {
            FreeNode(it, free_children=false);
        } else {
            it.tree_last_frame = it.tree;
        }
    }

    if omg.debug_mode {
        if omg.mouse_hovered_node {
            node := omg.mouse_hovered_node;
            DrawBox(*node.window.draw_list, .{
                size=node.size,
                position=(node.rect.xy + node.rect.zw) * 0.5,
                border_color=ColorU32(1, 0, 0, 1),
                border_size=2,
                border_inset=-4
            });
        }

        if omg.mouse_focused_node {
            node := omg.mouse_focused_node;
            DrawBox(*node.window.draw_list, .{
                size=node.size,
                position=(node.rect.xy + node.rect.zw) * 0.5,
                border_color=ColorU32(0, 1, 0, 1),
                border_size=2,
                border_inset=-2
            });
        }
    }

    ResetInput(*omg.input);

    total_end := current_time_monotonic();
    omg.total_time_last_frame += xx to_float64_seconds(total_end - total_start);
}

LoadImage :: (filename : string) -> TextureHandle, width : u32, height : u32 {
    contents, ok := read_entire_file(filename);
    if !ok {
        return 0, 0, 0;
    }

    w, h : s32;
    stbi_set_flip_vertically_on_load(0);
    data := stbi_load_from_memory(contents.data, xx contents.count, *w, *h, null, 4);
    if !data {
        log_error("Could not create cursor image");
        return 0, 0, 0;
    }

    defer stbi_image_free(data);

    handle := RendererCreateRGBA8Texture(tprint("Texture '%'", filename), data, xx w, xx h);

    return handle, xx w, xx h;
}

ReadCompileTimeFile :: (filename : string, location := #caller_location) -> string {
    #import "File";
    absolute_filename := sprint("%/%", #filepath, filename);
    contents, ok := read_entire_file(absolute_filename);

    if !ok {
        #import "Compiler";
        compiler_report(sprint("Could not read file '%'", absolute_filename), loc=location);
    }

    return contents;
}
