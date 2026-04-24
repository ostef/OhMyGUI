#import "Basic";
#import "Math";
#import "SDL";
#import "Bucket_Array";

#load "math.jai";
#load "input.jai";
#load "sd_shape.jai";
#load "text.jai";
#load "draw.jai";
#load "gl.jai";
#load "node.jai";
#load "layout.jai";
#load "interaction.jai";

Context :: struct {
    frame_index : u64;
    delta_time : float;
    layout_time_last_frame : float;

    input : InputContext;
    input_last_frame : InputContext;

    windows : *Window;
    fonts : *Font;
    node_pool : Bucket_Array(Node, 1000);

    id_offset_stack : [..]int;

    mouse_is_over_node : bool;
    mouse_hovered_node : *Node;
    mouse_focused_node : *Node;
    mouse_interacting_node : *Node;
    scroll_focused_node : *Node;
    interacted_this_frame : bool;

    shapes_to_draw : [..]Drawing;
    default_effect := Effect.{kind=.SolidColor, solid_color=.{color=.{1,1,1,1}}};
}

Window :: struct {
    sdl_window : *SDL_Window;
    prev : *Window;
    next : *Window;

    root_node : *Node;
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

    FreeNode(window.root_node);
    free(window);
}

#add_context omg : *Context;

Init :: () {
    context.omg = New(Context);
}

Terminate :: () {
    while context.omg.windows {
        DestroyWindow(context.omg.windows);
    }

    while context.omg.fonts {
        DestroyFont(context.omg.fonts);
    }

    bucket_array_reset(*context.omg.node_pool);
    array_free(context.omg.shapes_to_draw);

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

    mx, my : s32;
    SDL_GetGlobalMouseState(*mx, *my);
    omg.input.mouse_position = .{xx mx, xx my};

    omg.mouse_hovered_node = null;
    omg.mouse_is_over_node = false;
    SetMouseFocus(null);
    SetScrollFocus(null);

    window := omg.windows;
    while window {
        defer window = window.next;
        if !window.root_node {
            continue;
        }

        FindMouseFocus(window.root_node, window);
    }
}

Render :: () {
    omg := context.omg;
    omg.layout_time_last_frame = 0;

    if omg.id_offset_stack.count > 0 {
        log_error("Mismatching number of push/pop for ID offset stack");
        omg.id_offset_stack.count = 0;
    }

    if !omg.interacted_this_frame {
        omg.mouse_interacting_node = null;
    }
    omg.interacted_this_frame = false;

    window := omg.windows;
    while window {
        defer window = window.next;
        if !window.root_node {
            continue;
        }

        w, h : s32;
        SDL_GetWindowSize(window.sdl_window, *w, *h);

        SetSize(window.root_node, SizePx(xx w), SizePx(xx h));

        layout_start := current_time_monotonic();
        LayoutNodes(window.root_node);
        PostLayout(window.root_node);
        layout_end := current_time_monotonic();
        omg.layout_time_last_frame = xx to_float64_seconds(layout_end - layout_start);

        DrawNodes(window.root_node);
    }

    omg.input_last_frame = omg.input;

    omg.input.mouse_wheel = .{};
}

#scope_file

PostLayout :: (node : *Node) {
    frame_index := context.omg.frame_index;

    for :PrevFrameChildren node {
        if it.last_used_on_frame != frame_index {
            FreeNode(it);
        } else {
            PostLayout(it);
        }
    }

    node.layout_last_frame = node.layout;
}

DrawNodes :: (node : *Node, clip_shape : *SDShape = null) {
    Border :: Vec4f.{0,0,0,1};
    Fill :: Vec4f.{1,1,1,1};

    position := (node.rect.xy + node.rect.zw) * 0.5;

    if !(node.flags & .TextNode) {
        d := DrawShape(Box(node.size, 6), position);
        if context.omg.mouse_focused_node == node {
            SolidColor(d, .{1,0,0,1});
        } else {
            SolidColor(d, Fill);
        }
        StrokeColor(d, Border, 1);
        Clip(d, clip_shape);
    }

    if node.num_children > 0 {
        my_clip := Move(Box(node.size - node.padding * 2), position);
        clip_shape = ifx clip_shape then Inter(clip_shape, my_clip) else my_clip;

        for :Children node {
            DrawNodes(it, clip_shape);
        }
    }

    if node.flags & .TextNode && node.text {
        DrawText(node.font, node.rect.xy, node.text_size, node.text, Border, clip_shape);
    }
}
