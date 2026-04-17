#import "Basic";
#import "Math";
#import "SDL";

#load "math.jai";
#load "input.jai";
#load "sd_shape.jai";
#load "text.jai";
#load "draw.jai";
#load "gl.jai";
#load "node.jai";
#load "layout.jai";

Context :: struct {
    frame_index : u64;
    delta_time : float;

    input : InputContext;
    input_last_frame : InputContext;

    windows : *Window;

    fonts : [..]*Font;
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

    free(window);
}

#add_context omg : *Context;

Init :: () {
    context.omg = New(Context);
}

Terminate :: () {
    free(context.omg);
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
}

Render :: () {
    omg := context.omg;

    window := omg.windows;
    while window {
        defer window = window.next;
        if !window.root_node {
            continue;
        }

        w, h : s32;
        SDL_GetWindowSize(window.sdl_window, *w, *h);

        SetSize(window.root_node, SizePx(xx w), SizePx(xx h));

        RemoveUndeclaredNodes(window.root_node);
        LayoutNodes(window.root_node);
        DrawNodes(window.root_node);
    }

    omg.input_last_frame = omg.input;
}

#scope_file

RemoveUndeclaredNodes :: (node : *Node) {
    frame_index := context.omg.frame_index;

    for :Children node {
        if it.last_used_on_frame != frame_index {
            PopChild(node, it);
            FreeNode(it);
        }
    }

    for :Children node {
        RemoveUndeclaredNodes(it);
    }
}

DrawNodes :: (node : *Node) {
    position := (node.rect.xy + node.rect.zw) * 0.5;
    size     :=  node.rect.zw - node.rect.xy;

    d := DrawShape(Box(size, 6), position);
    SolidColor(d, .{1,1,1,1});
    StrokeColor(d, .{0,0,0,1}, 1);

    for :Children node {
        DrawNodes(it);
    }
}
