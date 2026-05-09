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
    mouse_capturing_node : *Node;
    mouse_captured_this_frame : bool;
    mouse_captured_at : Vec2f = .{FLOAT32_NAN, FLOAT32_NAN};
    mouse_captured_node_value : Vec2f = .{FLOAT32_NAN, FLOAT32_NAN}; // Value that nodes can specify upon capturing the mouse
    scroll_focused_node : *Node;

    shapes_to_draw : [..]Drawing;
    default_effect := Effect.{kind=.SolidColor, solid_color=.{color=0xffffffff}};
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
    omg.mouse_focused_node = null;
    omg.scroll_focused_node = null;

    for * omg.node_pool {
        it.state_flags = (it.state_flags & .CurrentFrame) << Num_Node_States;
    }

    window := omg.windows;
    while window {
        defer window = window.next;
        if !window.root_node {
            continue;
        }

        FindMouseFocus(window.root_node);
    }

    if omg.mouse_focused_node {
        omg.mouse_focused_node.state_flags |= .Focused;
    }
}

Render :: () {
    omg := context.omg;
    omg.layout_time_last_frame = 0;

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
    DrawBox :: inline (node : *Node, clip_shape : *SDShape) {
        has_background := (node.background_color & 0xff) > 0;
        has_border := (node.border_color & 0xff) > 0 && node.border_size > 0;
        has_shadow := (node.outer_shadow_color & 0xff) > 0;

        if !has_background && !has_border && !has_shadow {
            return;
        }

        position := (node.rect.xy + node.rect.zw) * 0.5;

        d := DrawShape(Box(node.size, node.corner_radiuses), position);

        if has_shadow {
            OuterShadow(d, node.outer_shadow_offset, node.outer_shadow_blur, node.outer_shadow_color);
        }
        if has_background {
            SolidColor(d, node.background_color);
        }
        if has_border {
            StrokeColor(d, node.border_color, node.border_size, node.border_inset);
        }

        Clip(d, clip_shape);
    }

    DrawText :: (node : *Node, clip_shape : *SDShape) {
        if !node.font || node.text_size <= 0 || !node.text || (node.text_color & 0xff) == 0 {
            return;
        }

        DrawText(node.font, node.rect.xy, node.text_size, node.text, node.text_color, clip_shape);
    }

    position := (node.rect.xy + node.rect.zw) * 0.5;

    if !(node.flags & .TextNode) {
        DrawBox(node, clip_shape);
    }

    if node.num_children > 0 {
        my_clip := Move(Box(node.size - node.padding * 2), position);
        clip_shape = ifx clip_shape then Inter(clip_shape, my_clip) else my_clip;

        for :Children node {
            DrawNodes(it, clip_shape);
        }
    }

    if node.flags & .TextNode {
        DrawText(node, clip_shape);
    }
}
