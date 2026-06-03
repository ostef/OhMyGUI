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

g_slider_value : float;
g_checkbox_value : bool;
g_show_password : bool;

g_theme : OMG.Theme;

DoOneFrame :: (w : float, h : float, time : float, delta_time : float) {
    OMG.NewFrame(delta_time);
    defer OMG.Render();

    window := OMG.GetWindow(g_window);
    root := OMG.GetNode(window);
    {
        OMG.SetLayout(root, .TopToBottom);

        title_bar := OMG.GetNode(root, "title_bar");
        {
            OMG.SetPadding(title_bar, 4, 4);
            OMG.SetChildGap(title_bar, 4, 4);
            OMG.SetChildAlign(title_bar, 0.5, 0.5);
            OMG.SetWidth(title_bar, OMG.SizeFill());
            OMG.SetHeight(title_bar, OMG.SizeFit());

            OMG.SetBackgroundColor(title_bar, 1, 1, 1, 1);
            OMG.SetBorderColor(title_bar, 0, 0, 0, 1);
            OMG.SetBorderSize(title_bar, 1);

            OMG.Text(title_bar, "OMG Engine (% FPS)", cast(int, 1 / delta_time));

            title_menu := OMG.GetNode(title_bar);
            OMG.SetSize(title_menu, OMG.SizeFill(), OMG.SizeFit());

            OMG.Button(title_menu, "File");
            OMG.Button(title_menu, "Edit");
            OMG.Button(title_menu, "Entities");
            OMG.Button(title_menu, "Window");
            OMG.Button(title_menu, "Help");

            title_mini := OMG.GetNode(title_bar, "minimize");
            OMG.SetSize(title_mini, OMG.SizePx(25));

            if OMG.ButtonBehavior(title_mini).released {
                SDL_MinimizeWindow(g_window);
            }

            title_maxi := OMG.GetNode(title_bar, "maximize");
            OMG.SetSize(title_maxi, OMG.SizePx(25));

            if OMG.ButtonBehavior(title_maxi).released {
                SDL_MaximizeWindow(g_window);
            }

            title_close := OMG.GetNode(title_bar, "close");
            OMG.SetSize(title_close, OMG.SizePx(25));

            if OMG.ButtonBehavior(title_close).released {
                SDL_Quit();
            }
        }

        content := OMG.GetNode(root, "content");
        {
            OMG.SetSize(content, OMG.SizeFill());

            Panel :: (parent : *OMG.Node, str_id : string, title : string) -> *OMG.Node {
                panel := OMG.GetNode(parent, str_id);
                {
                    OMG.SetLayout(panel, .TopToBottom);
                    OMG.SetSize(panel, OMG.SizeFill());

                    OMG.SetBackgroundColor(panel, 1, 1, 1, 1);
                    OMG.SetBorderColor(panel, 0, 0, 0, 1);
                    OMG.SetBorderSize(panel, 1);

                    title_bar := OMG.GetNode(panel, "title_bar");
                    {
                        OMG.SetSize(title_bar, OMG.SizeFill(), OMG.SizePx(32));
                        OMG.SetPadding(title_bar, 4, 4);
                        OMG.SetChildAlign(title_bar, 0, 0.5);

                        OMG.SetBackgroundColor(title_bar, 1, 1, 1, 1);
                        OMG.SetBorderColor(title_bar, 0, 0, 0, 1);
                        OMG.SetBorderSize(title_bar, 1);

                        OMG.Text(title_bar, title);
                    }

                    content_and_scrollbar := OMG.GetNode(panel, "content_and_scrollbar");
                    {
                        OMG.SetLayout(content_and_scrollbar, .LeftToRight);
                        OMG.SetSize(content_and_scrollbar, OMG.SizeFill());

                        content := OMG.GetNode(content_and_scrollbar, "content");
                        {
                            OMG.SetLayout(content, .TopToBottom);
                            OMG.SetSize(content, OMG.SizeFill());

                            OMG.ScrollViewBehavior(content, .Y);
                        }

                        if content.layout_last_frame.children_size.y > content.layout_last_frame.size.y {
                            OMG.Scrollbar(content_and_scrollbar, content, .Y);
                        }

                        return content;
                    }
                }
            }

            left_side := OMG.GetNode(content, "left_side");
            {
                OMG.SetSize(left_side, OMG.SizeFill());
                OMG.SetLayout(left_side, .TopToBottom);

                main_viewport := Panel(left_side, "main_viewport", "Main Viewport");
                OMG.SetPadding(main_viewport, 12, 12);
                OMG.SetChildGap(main_viewport, 4, 4);

                OMG.Text(main_viewport, "Mouse focus: % %", context.omg.mouse_focused_node, ifx context.omg.mouse_focused_node then context.omg.mouse_focused_node.id);
                OMG.Text(main_viewport, "Mouse capture: % %", context.omg.mouse_capturing_node, ifx context.omg.mouse_capturing_node then context.omg.mouse_capturing_node.id);
                OMG.Text(main_viewport, "Scroll focus: %", context.omg.scroll_focused_node);

                OMG.Text(main_viewport, "Layout: % us", cast(int, context.omg.layout_time_last_frame * 1000 * 1000));
                OMG.Text(main_viewport, "Render: % ms", OMG.GetLastFrameGPUTime() * 1000);

                password_field := OMG.GetNode(main_viewport, "password_field");
                {
                    OMG.SetSize(password_field, OMG.SizeFit(), OMG.SizeFit());
                    OMG.SetLayout(password_field, .LeftToRight);
                    OMG.SetChildAlign(password_field, 0, 0.5);
                    OMG.SetChildGap(password_field, 6, 6);

                    text_input_submitted, text_input := OMG.TextInput(password_field, ifx !g_show_password then .Password);
                    OMG.SetWidth(text_input, OMG.SizePx(300));

                    if text_input_submitted {
                        text := OMG.GetTextInputResult(text_input ,, temp);
                        print("%\n", text);
                    }

                    OMG.Text(password_field, "Show Password:");
                    OMG.Checkbox(password_field, *g_show_password);
                }

                label_and_slider := OMG.GetNode(main_viewport);
                {
                    OMG.SetDraw(label_and_slider, null);
                    OMG.SetSize(label_and_slider, OMG.SizeFill(0.3), OMG.SizeFit());
                    OMG.SetLayout(label_and_slider, .LeftToRight);
                    OMG.SetChildAlign(label_and_slider, 0, 0.5);
                    OMG.SetChildGap(label_and_slider, 10, 0);

                    label := OMG.Text(label_and_slider, "Value: %", g_slider_value);
                    OMG.SetWidth(label, OMG.SizeFill(0.5));

                    OMG.Slider(label_and_slider, *g_slider_value, 0, 1, 0.1);
                }

                for i : 0..3 {
                    OMG.PushIDOffset(i);
                    defer OMG.PopIDOffset();

                    popup := OMG.GetPopupNode(window);
                    OMG.SetSize(popup, OMG.SizePx(50), OMG.SizePx(100));
                    OMG.SetBackgroundColor(popup, 1,1,1,1);
                    OMG.SetCornerRadius(popup, 3);
                    popup.outer_shadow_color = OMG.ColorU32(0,0,0,0.5);
                    popup.outer_shadow_blur = 5;
                    popup.outer_shadow_offset = .{1,1};

                    popup_result := OMG.ButtonBehavior(popup);
                    if popup_result.held {
                        OMG.BringForward(popup);
                        popup.offset = OMG.GetMousePosition(window);
                    }

                    OMG.Text(popup, "%", popup.z_index);
                }

                OMG.Checkbox(main_viewport, *g_checkbox_value);

Text :: #string END
The quick brown fox jumps over the lazy dog?
THE QUICK BROWN FOX JUMPS OVER THE LAZY DOG!
0123456789
END

                the_quick := OMG.Text(main_viewport, Text);
                the_quick.text_size = (cos(time) + 2) * 10;

                content_browser := Panel(left_side, "content_browser", "Content Browser");
                OMG.SetHeight(content_browser, OMG.SizeFill(0.9));
            }

            if content.layout_last_frame.size.x > 500 {
                right_side := OMG.GetNode(content, "right_side");
                {
                    OMG.SetSize(right_side, OMG.SizePx(400), OMG.SizeFill());
                    OMG.SetLayout(right_side, .TopToBottom);

                    entity_outliner := Panel(right_side, "entity_outliner", "Entity Outliner");
                    for i : 0..25 {
                        OMG.PushIDOffset(i);
                        defer OMG.PopIDOffset();

                        entry := OMG.GetNode(entity_outliner);
                        OMG.SetPadding(entry, 2, 2);
                        OMG.SetSize(entry, OMG.SizeFill(), OMG.SizeFit());
                        OMG.ButtonBehavior(entry);

                        OMG.Text(entry, "Entry %", i);
                    }

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
        glClearColor(0,0,0,1);
        glClear(GL_COLOR_BUFFER_BIT);

        OMG.RenderGL(xx w, xx h);
        g_frame_syncs[g_frame_in_flight] = glFenceSync(GL_SYNC_GPU_COMMANDS_COMPLETE, 0);

        g_frame_in_flight = (g_frame_in_flight + 1) % 2;

        SDL_GL_SwapWindow(g_window);
    }
}
