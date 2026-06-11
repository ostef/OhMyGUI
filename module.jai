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
#load "interaction.jai";

#load "Widgets/widgets.jai";

Context :: struct {
    frame_index : u64;
    delta_time : float;
    layout_time_last_frame : float;

    general_purpose_allocator : Allocator;

    #if OS == .LINUX {
        mouse_wheel_multiplier := 10.0;
    } else {
        mouse_wheel_multiplier := 1.0;
    }

    input : InputContext;
    cursor_this_frame : *Cursor;

    windows : *Window;
    fonts : *Font;
    node_pool : Bucket_Array(Node, 1000);

    theme : *Theme;
    id_offset_stack : [..]int;

    mouse_hovered_node : *Node;
    mouse_focused_node : *Node;
    mouse_capturing_node : *Node;
    mouse_captured_this_frame : bool;
    mouse_captured_at : Vec2f = .{FLOAT32_NAN, FLOAT32_NAN};
    mouse_captured_node_value : Vec2f = .{FLOAT32_NAN, FLOAT32_NAN}; // Value that nodes can specify upon capturing the mouse
    scroll_focused_node : *Node;

    // default_effect := Effect.{kind=.SolidColor, solid_color=.{color=0xffffffff}};
}

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

GetWindow :: (window : *SDL_Window, create := true) -> *Window {
    w := context.omg.windows;
    while w {
        if w.sdl_window == window {
            return w;
        }

        w = w.next;
    }

    if !create {
        return null;
    }

    w = New(Window);
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

#add_context omg : *Context;

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

    SetTheme(*g_default_theme_light);
}

Terminate :: () {
    while context.omg.windows {
        DestroyWindow(context.omg.windows);
    }

    while context.omg.fonts {
        DestroyFont(context.omg.fonts);
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

NewFrame :: (delta_time : float) {
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

    window := omg.windows;
    while window {
        defer window = window.next;

        if window.root_node {
            FindMouseFocus(window.root_node);
        }

        if window.popup_root_node {
            FindMouseFocus(window.popup_root_node);
        }
    }

    window = omg.windows;
    while window {
        defer window = window.next;

        if window.root_node {
            TouchNode(window.root_node);
        }
        if window.popup_root_node {
            TouchNode(window.popup_root_node);
        }
    }


    if omg.mouse_focused_node {
        omg.mouse_focused_node.state_flags |= .Focused;
    }
}

Render :: () {
    omg := context.omg;
    omg.layout_time_last_frame = 0;

    if omg.cursor_this_frame {
        SDL_SetCursor(omg.cursor_this_frame);
    } else {
        SDL_SetCursor(GetSystemCursor(.Arrow));
    }

    if omg.id_offset_stack.count > 0 {
        log_error("Mismatching number of push/pop for ID offset stack");
        omg.id_offset_stack.count = 0;
    }

    if !omg.mouse_captured_this_frame {
        omg.mouse_capturing_node = null;
    }
    omg.mouse_captured_this_frame = false;

    window := omg.windows;
    while window {
        defer window = window.next;

        w, h : s32;
        SDL_GetWindowSize(window.sdl_window, *w, *h);

        layout_start := current_time_monotonic();

        if window.root_node {
            SetSize(window.root_node, SizePx(xx w), SizePx(xx h));

            LayoutNodes(window.root_node);
        }

        if window.popup_root_node {
            SetLayout(window.popup_root_node, .None);
            SetChildAlign(window.popup_root_node, 0, 0);
            SetSize(window.popup_root_node, SizePx(xx w), SizePx(xx h));
            window.popup_root_node.flags |= .SortChildren;

            LayoutNodes(window.popup_root_node);
        }

        layout_end := current_time_monotonic();
        omg.layout_time_last_frame = xx to_float64_seconds(layout_end - layout_start);

        if window.root_node {
            DrawNodes(*window.draw_list, window.root_node);
        }
        if window.popup_root_node {
            DrawNodes(*window.draw_list, window.popup_root_node);
        }
    }

    for * context.omg.node_pool {
        if it.last_used_on_frame != context.omg.frame_index {
            FreeNode(it, free_children=false);
        } else {
            it.layout_last_frame = it.layout;
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

#scope_file

DrawNodes :: (draw_list : *DrawList, node : *Node) {
    if node.draw {
        node.draw(draw_list, node);
    }

    if node.clipped_rect.x >= node.clipped_rect.z || node.clipped_rect.y >= node.clipped_rect.w {
        return;
    }

    position := (node.rect.xy + node.rect.zw) * 0.5;
    if node.num_children > 0 {
        if !(node.flags & .NoClip) {
            if node.flags & .NoPaddedClip {
                PushClipBox(*node.window.draw_list, node.rect, node.corner_radiuses);
            } else {
                bounds := node.rect;
                bounds.xy += node.padding.xy;
                bounds.zw -= node.padding.zw;
                PushClipBox(*node.window.draw_list, bounds, node.corner_radiuses);
            }
        }

        for :Children node {
            DrawNodes(draw_list, it);
        }

        if !(node.flags & .NoClip) {
            PopClipBox(*node.window.draw_list);
        }
    }
}
