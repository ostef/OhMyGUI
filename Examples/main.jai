Memory_Debugger :: false;

#import "Basic"()(MEMORY_DEBUGGER=Memory_Debugger);
#import "Math";

OMG :: #import "OhMyGUI";
using,only(.["*"]) OMG;

OMG_SDL :: #import "OhMyGUI/SDL";
OMG_GL :: #import "OhMyGUI/GL";

#import "SDL";
#import "GL";

#load "editor.jai";

g_quit := false;
g_window : *SDL_Window;
g_frame_in_flight : int;
g_frame_syncs : [2]GLsync;
g_time : float;
g_delta_time : float;
g_user_time : float;
g_slow_down : bool;

main :: () {
    #if Memory_Debugger {
        defer report_memory_leaks();
    }

    window_flags := SDL_WINDOW_OPENGL | SDL_WINDOW_SHOWN | SDL_WINDOW_RESIZABLE;
    g_window = SDL_CreateWindow("Oh My GUI", SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, 1600, 900, window_flags);
    defer SDL_DestroyWindow(g_window);

    SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, xx SDL_GL_CONTEXT_PROFILE_CORE);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 4);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 3);

    gl_context := SDL_GL_CreateContext(g_window);
    defer SDL_GL_DeleteContext(gl_context);

    gl_load(*gl);

    OMG.Init(OMG_SDL.GetPlatformFuncs(), OMG_GL.GetRendererFuncs());
    defer OMG.Terminate();

    if !OMG_GL.Init() {
        exit(1);
    }
    defer OMG_GL.Terminate();

    program_start := current_time_monotonic();
    g_delta_time = 1 / 60.0;
    while !g_quit {
        reset_temporary_storage();

        frame_start := current_time_monotonic();

        g_time = xx to_float64_seconds(frame_start - program_start);

        defer {
            frame_end := current_time_monotonic();
            g_delta_time = xx to_float64_seconds(frame_end - frame_start);
        }

        user_start := current_time_monotonic();

        event : SDL_Event;
        while SDL_PollEvent(*event) {
            if event.type == SDL_QUIT {
                g_quit = true;
            }

            OMG_SDL.HandleEvent(event);
        }

        OMG.NewFrame(g_delta_time);

        EditorFrame();

        user_end := current_time_monotonic();
        g_user_time = xx to_float64_seconds(user_end - user_start);

        OMG.Render();

        if g_frame_syncs[g_frame_in_flight] {
            Second :: 1000 * 1000 * 1000;
            wait := glClientWaitSync(g_frame_syncs[g_frame_in_flight], GL_SYNC_FLUSH_COMMANDS_BIT, 2 * Second);
            assert(wait != GL_TIMEOUT_EXPIRED, "GPU timeout");
            assert(wait != GL_WAIT_FAILED, "glClientWaitSync failed");

            glDeleteSync(g_frame_syncs[g_frame_in_flight]);
        }

        w, h : s32;
        SDL_GetWindowSize(g_window, *w, *h);

        glViewport(0, 0, xx w, xx h);
        glClearColor(0,0,0,1);
        glClear(GL_COLOR_BUFFER_BIT);

        OMG_GL.Render(xx w, xx h);

        g_frame_syncs[g_frame_in_flight] = glFenceSync(GL_SYNC_GPU_COMMANDS_COMPLETE, 0);

        g_frame_in_flight = (g_frame_in_flight + 1) % 2;

        SDL_GL_SwapWindow(g_window);

        if g_slow_down {
            sleep_milliseconds(100);
        }
    }
}
