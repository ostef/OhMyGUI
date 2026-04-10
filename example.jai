#import "Basic";
#import "Math";
OMG :: #import,file "module.jai";
using,only(.["*"]) OMG;
#import "SDL";
#import "GL";

main :: () {
    window_flags := SDL_WINDOW_OPENGL | SDL_WINDOW_SHOWN | SDL_WINDOW_RESIZABLE;
    window := SDL_CreateWindow("Oh My GUI", SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, 1600, 900, window_flags);
    defer SDL_DestroyWindow(window);

    SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, xx SDL_GL_CONTEXT_PROFILE_CORE);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 4);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 6);

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

        wx, wy : s32;
        SDL_GetWindowPosition(window, *wx, *wy);

        w, h : s32;
        SDL_GetWindowSize(window, *w, *h);

        mx, my : s32;
        SDL_GetGlobalMouseState(*mx, *my);
        mx -= wx;
        my -= wy;

        s := OMG.Circle(100);
        s = OMG.Move(s, cos(time) * 100, 0);
        s = OMG.SmoothUnion(
            s,
            OMG.Box(400, 100),
            20
        );
        s = OMG.Rotate(s, time);
        s = OMG.Move(s, w * 0.5, h * 0.5);
        // s = OMG.Transform(s, OMG.Translate2D(w * 0.5, h * 0.5) * OMG.Rotate2D(time));

        for x : 0..w / 10 - 1 {
            for y : 0..h / 10 - 1 {
                if OMG.IsInside(.{x * 10.0, y * 10.0}, s) {
                    px := OMG.Move(OMG.Circle(3), x * 10.0, y * 10.0);
                    OMG.DrawShape(px);
                }
            }
        }

        color := ifx OMG.IsInside(.{xx mx, xx my}, s)
            then OMG.Vec4f.{0,1,0,1}
            else OMG.Vec4f.{1,1,1,1};
        OMG.DrawShape(s);

        glViewport(0, 0, xx w, xx h);
        glClearColor(0.1, 0.1, 0.1, 1);
        glClear(GL_COLOR_BUFFER_BIT);

        OMG.RenderGL(color);

        SDL_GL_SwapWindow(window);
    }
}
