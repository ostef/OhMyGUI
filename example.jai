#import "Basic";
#import "Math";
OMG :: #import,file "module.jai";
using,only(.["*"]) OMG;
#import "SDL";
#import "GL";

g_window : *SDL_Window;
g_mouse : Vector2;
g_frame_in_flight : int;
g_frame_syncs : [2]GLsync;
g_show_node := true;

DoOneFrame :: (w : float, h : float, time : float, delta_time : float) {
    OMG.NewFrame(delta_time);
    defer OMG.Render();

    root := OMG.GetNode(g_window);

    if OMG.IsKeyPressed(.Space) {
        g_show_node = !g_show_node;
    }

    if g_show_node {
        a := OMG.GetNode(root, "a");
        OMG.SetSize(a, OMG.SizePx(100), OMG.SizePx(100));
    }

    a := OMG.GetNode(root, "b");
    OMG.SetSize(a, OMG.SizeFillParent(0.5), OMG.SizeFillParent(0.5));
    OMG.SetMinMaxWidth(a, 128, 256);

    if !g_show_node {
        a := OMG.GetNode(root, "a");
        OMG.SetSize(a, OMG.SizePx(100), OMG.SizePx(100));
    }

    a = OMG.GetNode(root, "c");
    OMG.SetSize(a, OMG.SizeFillParent(1), OMG.SizeFitChildren());
    OMG.SetLayout(a, .TopToBottom);

    e := OMG.GetNode(root, "AA");
    OMG.SetSize(e, OMG.SizeFillParent(1), OMG.SizePx(100));

    d := OMG.GetNode(a, "d");
    OMG.SetSize(d, OMG.SizePx(25), OMG.SizePx(25));

    d = OMG.GetNode(a, "e");
    OMG.SetSize(d, OMG.SizePx(25), OMG.SizePx(25));

    font := OMG.GetFont("Roboto-Regular");
    OMG.DrawText(font, .{100, 100}, (cos(time) + 2) * 50, "Hello Sailor!\nWhat a lovely day");
}

main :: () {
    window_flags := SDL_WINDOW_OPENGL | SDL_WINDOW_SHOWN | SDL_WINDOW_RESIZABLE;
    g_window = SDL_CreateWindow("Oh My GUI", SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, 1600, 900, window_flags);
    defer SDL_DestroyWindow(g_window);

    SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, xx SDL_GL_CONTEXT_PROFILE_CORE);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 4);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 6);

    gl_context := SDL_GL_CreateContext(g_window);
    defer SDL_GL_DeleteContext(gl_context);

    gl_load(*gl);

    OMG.Init();
    defer OMG.Terminate();

    if !OMG.InitGL() {
        exit(1);
    }
    defer OMG.TerminateGL();

    font_config : OMG.FontConfig;
    font := OMG.LoadFontFromFile("Roboto-Regular.ttf", font_config);

    program_start := current_time_monotonic();
    quit := false;
    delta_time := 1 / 60.0;
    while !quit {
        reset_temporary_storage();

        frame_start := current_time_monotonic();
        time : float = xx to_float64_seconds(frame_start - program_start);

        defer {
            frame_end := current_time_monotonic();
            delta_time = xx to_float64_seconds(frame_end - frame_start);
        }

        event : SDL_Event;
        while SDL_PollEvent(*event) {
            if event.type == SDL_QUIT {
                quit = true;
            }

            OMG.HandleEvent(event);
        }

        wx, wy : s32;
        SDL_GetWindowPosition(g_window, *wx, *wy);

        w, h : s32;
        SDL_GetWindowSize(g_window, *w, *h);

        mx, my : s32;
        SDL_GetGlobalMouseState(*mx, *my);
        mx -= wx;
        my -= wy;

        g_mouse = .{xx mx, xx my};

        DoOneFrame(xx w, xx h, time, delta_time);

        if g_frame_syncs[g_frame_in_flight] {
            Second :: 1000 * 1000 * 1000;
            wait := glClientWaitSync(g_frame_syncs[g_frame_in_flight], GL_SYNC_FLUSH_COMMANDS_BIT, 2 * Second);
            assert(wait != GL_TIMEOUT_EXPIRED, "GPU timeout");
            assert(wait != GL_WAIT_FAILED, "glClientWaitSync failed");

            glDeleteSync(g_frame_syncs[g_frame_in_flight]);
        }

        glViewport(0, 0, xx w, xx h);
        glClearColor(0.5, 0.5, 0.5, 1);
        glClear(GL_COLOR_BUFFER_BIT);

        OMG.RenderGL(xx w, xx h);
        g_frame_syncs[g_frame_in_flight] = glFenceSync(GL_SYNC_GPU_COMMANDS_COMPLETE, 0);

        g_frame_in_flight = (g_frame_in_flight + 1) % 2;

        SDL_GL_SwapWindow(g_window);
    }
}
