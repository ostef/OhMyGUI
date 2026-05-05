Memory_Debugger :: false;

#import "Basic"()(MEMORY_DEBUGGER=Memory_Debugger);
#import "Math";
OMG :: #import,file "module.jai";
using,only(.["*"]) OMG;
#import "SDL";
#import "GL";

g_window : *SDL_Window;
g_mouse : Vector2;
g_frame_in_flight : int;
g_frame_syncs : [2]GLsync;

DoOneFrame :: (w : float, h : float, time : float, delta_time : float) {
    OMG.NewFrame(delta_time);
    defer OMG.Render();

    Text :: (parent : *OMG.Node, font : *OMG.Font, size : float, text : string, location := #caller_location) {
        node := OMG.GetNode(parent, location);
        OMG.SetText(node, font, size, text);
    }

    font := OMG.GetFont("Roboto-Regular");

    root := OMG.GetNode(g_window);
    {
        OMG.SetLayout(root, .TopToBottom);

        title_bar := OMG.GetNode(root, "title_bar");
        {
            OMG.SetPadding(title_bar, 4, 4);
            OMG.SetChildGap(title_bar, 4, 4);
            OMG.SetChildAlign(title_bar, 0.5, 0.5);
            OMG.SetWidth(title_bar, OMG.SizeFill());
            OMG.SetHeight(title_bar, OMG.SizeFit());

            Text(title_bar, font, 14, tprint("OMG Engine (% FPS)", cast(int, 1 / delta_time)));

            MenuButton :: (menu : *OMG.Node, str_id : string, font : *OMG.Font, text : string) -> *OMG.Node {
                button := OMG.GetNode(menu, str_id);
                {
                    button.flags |= .Focusable;
                    OMG.SetPadding(button, 4, 4);
                    OMG.SetSize(button, OMG.SizeFit(), OMG.SizeFit());
                    OMG.SetChildAlign(button, 0.5, 0.5);

                    clicked := OMG.ButtonBehavior(button);
                    if clicked {
                        print("Clicked %!\n", text);
                    }

                    if button.state_flags & .Active {
                        button.color = .{1,0,0,1};
                    } else if button.state_flags & .Focused {
                        button.color = .{0,1,0,1};
                    }

                    Text(button, font, 14, text);
                }

                return button;
            }

            title_menu := OMG.GetNode(title_bar);
            OMG.SetSize(title_menu, OMG.SizeFill(), OMG.SizeFit());

            file_menu := MenuButton(title_menu, "file_menu", font, "File");
            edit_menu := MenuButton(title_menu, "edit_menu", font, "Edit");
            entities_menu := MenuButton(title_menu, "entities_menu", font, "Entities");
            window_menu := MenuButton(title_menu, "window_menu", font, "Window");
            help_menu := MenuButton(title_menu, "help_menu", font, "Help");

            title_mini := OMG.GetNode(title_bar, "minimize");
            OMG.SetSize(title_mini, OMG.SizePx(25));

            title_maxi := OMG.GetNode(title_bar, "maximize");
            OMG.SetSize(title_maxi, OMG.SizePx(25));

            title_close := OMG.GetNode(title_bar, "close");
            OMG.SetSize(title_close, OMG.SizePx(25));
        }

        content := OMG.GetNode(root, "content");
        {
            OMG.SetSize(content, OMG.SizeFill());

            Panel :: (parent : *OMG.Node, str_id : string, title : string) -> *OMG.Node {
                panel := OMG.GetNode(parent, str_id);
                {
                    OMG.SetLayout(panel, .TopToBottom);
                    OMG.SetSize(panel, OMG.SizeFill());

                    title_bar := OMG.GetNode(panel, "title_bar");
                    {
                        OMG.SetSize(title_bar, OMG.SizeFill(), OMG.SizePx(32));
                        OMG.SetPadding(title_bar, 4, 4);
                        OMG.SetChildAlign(title_bar, 0, 0.5);

                        Text(title_bar, OMG.GetFont("Roboto-Regular"), 14, title);
                    }
                }

                return panel;
            }

            left_side := OMG.GetNode(content, "left_side");
            {
                OMG.SetSize(left_side, OMG.SizeFill());
                OMG.SetLayout(left_side, .TopToBottom);

                main_viewport := Panel(left_side, "main_viewport", "Main Viewport");

                Text(main_viewport, font, 16, tprint("Mouse focus: %", context.omg.mouse_focused_node));
                Text(main_viewport, font, 16, tprint("Mouse capture: %", context.omg.mouse_capturing_node));

                Text(main_viewport, font, 16, tprint("Layout: % us", cast(int, context.omg.layout_time_last_frame * 1000 * 1000)));
                Text(main_viewport, OMG.GetFont("JetBrainsMono-Regular"), 14, "Some text with another font");
                Text(main_viewport, font, (cos(time) + 2) * 10, "The quick brown fox jumps over the lazy dog!");

                content_browser := Panel(left_side, "content_browser", "Content Browser");
                OMG.SetHeight(content_browser, OMG.SizeFill(0.9));
            }

            if content.layout_last_frame.size.x > 500 {
                right_side := OMG.GetNode(content, "right_side");
                {
                    OMG.SetSize(right_side, OMG.SizePx(400), OMG.SizeFill());
                    OMG.SetLayout(right_side, .TopToBottom);

                    entity_outliner := Panel(right_side, "entity_outliner", "Entity Outliner");
                    entity_inspector := Panel(right_side, "entity_inspector", "Entity Inspector");
                }
            }
        }
    }
}

main :: () {
    #if Memory_Debugger {
        defer report_memory_leaks();
    }

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
    OMG.LoadFontFromFile("Roboto-Regular.ttf", font_config);
    OMG.LoadFontFromFile("JetBrainsMono-Regular.ttf", font_config);

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
        glClearColor(1,1,1, 1);
        glClear(GL_COLOR_BUFFER_BIT);

        OMG.RenderGL(xx w, xx h);
        g_frame_syncs[g_frame_in_flight] = glFenceSync(GL_SYNC_GPU_COMMANDS_COMPLETE, 0);

        g_frame_in_flight = (g_frame_in_flight + 1) % 2;

        SDL_GL_SwapWindow(g_window);
    }
}
