Enable_Memory_Debugger :: false;

#import "Basic"()(MEMORY_DEBUGGER=Enable_Memory_Debugger);
#import "Math";

OMG :: #import "OhMyGUI";
using,only(.["*"]) OMG;

OMG_SDL :: #import "OhMyGUI/SDL";
OMG_GL :: #import "OhMyGUI/GL";

#import "SDL";
#import "GL";

#if #exists(__Tracy) {
    Tracy :: __Tracy;
}

#load "editor.jai";

g_quit := false;
g_window : *SDL_Window;
g_time : float;
g_delta_time : float;
g_gpu_time : float;
g_user_time : float;
g_slow_down : bool;

g_current_timestamp_query : int;
g_timestamp_queries : [2][2]GLuint;

main :: () {
    #if Enable_Memory_Debugger {
        defer report_memory_leaks();
    }

    #if #exists(Tracy) {
        Tracy.EnableProfiling();
        if Tracy.IsProfiling() {
            print("Profiling is enabled\n");
        }
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

    OMG_GL.Init();
    defer OMG_GL.Terminate();

    glGenQueries(xx (g_timestamp_queries.count * 2), xx g_timestamp_queries.data);
    defer glDeleteQueries(xx (g_timestamp_queries.count * 2), xx g_timestamp_queries.data);

    // Make first query result not cause an error
    for queries, query_backbuffer_index : g_timestamp_queries {
        for queries {
            glQueryCounter(it, GL_TIMESTAMP);

            name := tprint("Query 'Frame Time %, Backbuffer %'", ifx it_index == 0 then "Start" else "End", query_backbuffer_index);
            glObjectLabel(GL_QUERY, it, xx name.count, name.data);
        }
    }

    program_start := current_time_monotonic();
    g_delta_time = 1 / 60.0;
    while !g_quit {
        reset_temporary_storage();

        memory_visualizer_per_frame_update();

        #if #exists(Tracy) {
            Tracy.EmitMessage("Frame Start");
        }

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

        #if #exists(Tracy) {
            Tracy.EmitMessage("OMG.NewFrame");
        }
        OMG.NewFrame(g_delta_time);

        // EditorFrame();

        user_end := current_time_monotonic();
        g_user_time = xx to_float64_seconds(user_end - user_start);

        #if #exists(Tracy) {
            Tracy.EmitMessage("OMG.Render");
        }
        OMG.Render();

        window := OMG.GetWindow(g_window);
        OMG.DrawRect(
            *window.draw_list,
            .{100, 100, 200, 200},
            0xffffffff,
            0xffffffff,
            0xff0000ff,
            0xff0000ff,
            .{10, 20, 15, 0}
        );

        w, h : s32;
        SDL_GetWindowSize(g_window, *w, *h);

        glViewport(0, 0, xx w, xx h);
        glClearColor(0,0,0,1);
        glClear(GL_COLOR_BUFFER_BIT);

        last_query_index := g_current_timestamp_query - (g_timestamp_queries.count - 1);
        if last_query_index < 0 {
            last_query_index += g_timestamp_queries.count;
        }

        start_time, end_time : s64;
        glGetQueryObjecti64v(g_timestamp_queries[last_query_index][0], GL_QUERY_RESULT, *start_time);
        glGetQueryObjecti64v(g_timestamp_queries[last_query_index][1], GL_QUERY_RESULT, *end_time);
        elapsed := end_time - start_time;
        g_gpu_time = cast(float, elapsed / 1_000_000_000.0);

        glQueryCounter(g_timestamp_queries[g_current_timestamp_query][0], GL_TIMESTAMP);

        OMG_GL.Render(xx w, xx h);

        glQueryCounter(g_timestamp_queries[g_current_timestamp_query][1], GL_TIMESTAMP);

        g_current_timestamp_query = (g_current_timestamp_query + 1) % g_timestamp_queries.count;

        SDL_GL_SwapWindow(g_window);

        if g_slow_down {
            sleep_milliseconds(100);
        }
    }
}
