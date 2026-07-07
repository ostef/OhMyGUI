#import "Basic";
#import "Math";
#import "SDL";
#import "Bucket_Array";
#import "Print_Vars";

#load "math.jai";
#load "color.jai";
#load "unicode.jai";
#load "input.jai";
#load "sdf.jai";
#load "draw.jai";
#load "text.jai";
#load "gl.jai";
#load "node.jai";
#load "style.jai";
#load "layout.jai";

#load "Widgets/widgets.jai";

Context :: struct {
    frame_index : u64;
    delta_time : float;
    layout_time_last_frame : float;

    debug_mode := false;

    general_purpose_allocator : Allocator;

    mouse_wheel_multiplier := 10.0;

    input : InputContext;
    cursor_this_frame : *Cursor;

    windows : *Window;
    fonts : *Font;
    node_pool : Bucket_Array(Node, 300);
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

GetTheme :: inline () -> *Theme {
    return context.omg.theme;
}

SetTheme :: inline (theme : *Theme) {
    context.omg.theme = theme;
}

Window :: struct {
    sdl_window : *SDL_Window;
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
        if SDL_GetWindowFlags(it.sdl_window) & SDL_WINDOW_MOUSE_FOCUS {
            return it;
        }
    }

    return null;
}

GetWindow :: (window : *SDL_Window, create := true) -> *Window {
    for :Windows context.omg {
        if it.sdl_window == window {
            return it;
        }
    }

    if !create {
        return null;
    }

    w := New(Window);
    InitDrawList(*w.draw_list);
    w.sdl_window = window;
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
    wx, wy : s32;
    SDL_GetWindowPosition(window.sdl_window, *wx, *wy);

    return point - Vec2f.{xx wx, xx wy};
}

ScreenToWindow :: (window : *Window, rect : Vec4f) -> Vec4f {
    wx, wy : s32;
    SDL_GetWindowPosition(window.sdl_window, *wx, *wy);

    return .{
        xy=rect.xy - Vec2f.{xx wx, xx wy},
        zw=rect.zw - Vec2f.{xx wx, xx wy},
    };
}

WindowToScreen :: (window : *Window, point : Vec2f) -> Vec2f {
    wx, wy : s32;
    SDL_GetWindowPosition(window.sdl_window, *wx, *wy);

    return point + Vec2f.{xx wx, xx wy};
}

WindowToScreen :: (window : *Window, rect : Vec4f) -> Vec4f {
    wx, wy : s32;
    SDL_GetWindowPosition(window.sdl_window, *wx, *wy);

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

Init :: () {
    context.omg = New(Context);
    context.omg.general_purpose_allocator = context.allocator;
    context.omg.node_pool.allocator = context.allocator;

    InitInput(*context.omg.input);
    InitSystemCursors();

    default_font := LoadDefaultFont();
    assert(default_font != null, "Could not load default font");

    SetupDefaultTheme(
        *g_default_theme_light,
        base_background_color=ColorU32(0.95, 0.95, 0.95, 1),
        base_accent_color=ColorU32(0.3, 0.5, 0.8, 1),
    );
    SetupDefaultTheme(
        *g_default_theme_dark,
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

    array_free(context.omg.id_offset_stack);

    DestroyInput(*context.omg.input);
    DestroySystemCursors();

    bucket_array_reset(*context.omg.node_pool);

    free(context.omg);
    context.omg = null;
}

HandleEvent :: (event : SDL_Event) {
    if event.type == SDL_WINDOWEVENT {
        if event.window.event == SDL_WINDOWEVENT_CLOSE {
            sdl_window := SDL_GetWindowFromID(event.window.windowID);
            window := GetWindow(sdl_window, create=false);
            if window {
                DestroyWindow(window);
            }
        }
    }

    HandleInputEvent(event);
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

    if omg.id_offset_stack.count > 0 {
        log_error("Mismatching number of push/pop for ID offset stack");
        omg.id_offset_stack.count = 0;
    }

    if !omg.mouse_captured_this_frame {
        omg.mouse_capturing_node = null;
        SDL_CaptureMouse(0);
    } else {
        SDL_CaptureMouse(1);
    }
    omg.mouse_captured_this_frame = false;

    if omg.cursor_this_frame {
        SDL_SetCursor(omg.cursor_this_frame);
    } else {
        SDL_SetCursor(GetSystemCursor(.Arrow));
    }

    for :Windows omg {
        w, h : s32;
        SDL_GetWindowSize(it.sdl_window, *w, *h);

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
        omg.layout_time_last_frame = xx to_float64_seconds(layout_end - layout_start);

        if it.root_node {
            DrawNodes(*it.draw_list, it.root_node);
        }
        if it.popup_root_node {
            DrawNodes(*it.draw_list, it.popup_root_node);
        }
    }

    for * context.omg.node_pool {
        if it.last_used_on_frame != context.omg.frame_index {
            FreeNode(it, free_children=false);
        } else {
            it.layout_last_frame = it.layout;
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
}

#scope_module

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
