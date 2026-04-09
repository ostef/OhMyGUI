#import "Basic";
#import "Math";
OMG :: #import,file "module.jai";
#import "SDL";
#import "GL";

main :: () {
    window_flags := SDL_WINDOW_OPENGL | SDL_WINDOW_SHOWN | SDL_WINDOW_RESIZABLE;
    window := SDL_CreateWindow("Oh My GUI", SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, 1600, 900, window_flags);
    defer SDL_DestroyWindow(window);

    SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, xx SDL_GL_CONTEXT_PROFILE_CORE);

    gl_context := SDL_GL_CreateContext(window);
    defer SDL_GL_DeleteContext(gl_context);

    gl_load(*gl);

    OMG.Init();
    defer OMG.Terminate();

    if !OMG.InitGL() {
        exit(1);
    }
    defer OMG.TerminateGL();

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
        }

        a := OMG.Circle(100);
        b := OMG.Box(.{400, 100});
        c := OMG.Inter(a, b);
        c = OMG.Rotate(c, time);
        c = OMG.Move(c, .{200, 200});
        OMG.DrawShape(c);

        glClearColor(0.1, 0.1, 0.1, 1);
        glClear(GL_COLOR_BUFFER_BIT);

        OMG.RenderGL();

        SDL_GL_SwapWindow(window);
    }
}
