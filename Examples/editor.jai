g_slider_value : float;
g_show_password : bool;

EditorFrame :: () {
    base_background_color := OMG.GetStyle("base", OMG.BoxStyle).background_color;

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

            OMG.SetBackgroundColor(title_bar, base_background_color);
            OMG.SetBorderColor(title_bar, OMG.MakeTone(base_background_color, 0.2));
            OMG.SetBorderSize(title_bar, 1);

            OMG.Text(title_bar, "OMG Engine (% FPS)", cast(int, 1 / g_delta_time));

            OMG.VerticalSeparator(title_bar);

            title_menu_bar := OMG.MenuBar(title_bar, "title_menu_bar");

            file_menu := OMG.Menu(title_menu_bar, "File");
            if file_menu {
                OMG.MenuItem(file_menu, "New");
                OMG.MenuItem(file_menu, "Open");
                OMG.MenuItem(file_menu, "Save");
                OMG.MenuItem(file_menu, "Save As");
            }

            edit_menu := OMG.Menu(title_menu_bar, "Edit");
            if edit_menu {
                OMG.MenuItem(edit_menu, "Select All");
                OMG.MenuItem(edit_menu, "Invert Selection");
            }

            window_menu := OMG.Menu(title_menu_bar, "Window");
            if window_menu {
                OMG.MenuItem(window_menu, "New Viewport");
                OMG.MenuItem(window_menu, "Profiler");
                OMG.MenuItem(window_menu, "Entity Outliner");
                OMG.MenuItem(window_menu, "Entity Inspector");
                OMG.MenuItem(window_menu, "Browser");
            }

            help_menu := OMG.Menu(title_menu_bar, "Help");
            if help_menu {
                OMG.MenuItem(help_menu, "Documentation");
                OMG.MenuItem(help_menu, "About");
            }

            if OMG.Button(title_bar, OMG.SizePx(25), OMG.SizePx(25)) {
                SDL_MinimizeWindow(g_window);
            }

            if OMG.Button(title_bar, OMG.SizePx(25), OMG.SizePx(25)) {
                SDL_MaximizeWindow(g_window);
            }

            if OMG.Button(title_bar, OMG.SizePx(25), OMG.SizePx(25)) {
                SDL_Quit();
            }
        }

        content := OMG.GetNode(root, "content");
        {
            OMG.SetSize(content, OMG.SizeFill());

            Panel :: (parent : *OMG.Node, str_id : string, title : string) -> *OMG.Node {
                base_background_color := OMG.GetStyle("base", OMG.BoxStyle).background_color;

                panel := OMG.GetNode(parent, str_id);
                {
                    OMG.SetLayout(panel, .TopToBottom);
                    OMG.SetSize(panel, OMG.SizeFill());

                    OMG.SetBackgroundColor(panel, base_background_color);
                    OMG.SetBorderColor(panel, OMG.MakeTone(base_background_color, 0.2));
                    OMG.SetBorderSize(panel, 1);

                    title_bar := OMG.GetNode(panel, "title_bar");
                    {
                        OMG.SetSize(title_bar, OMG.SizeFill(), OMG.SizePx(32));
                        OMG.SetPadding(title_bar, 10, 4);
                        OMG.SetChildAlign(title_bar, 0, 0.5);

                        OMG.SetBackgroundColor(title_bar, base_background_color);
                        OMG.SetBorderColor(title_bar, OMG.MakeTone(base_background_color, 0.2));
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
                            OMG.SetPadding(content, 10, 10);

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

                OMG.Text(main_viewport, "Mouse hover: % %", context.omg.mouse_hovered_node, ifx context.omg.mouse_hovered_node then context.omg.mouse_hovered_node.id);
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

                OMG.HorizontalSeparator(main_viewport);

Text :: #string END
The quick brown fox jumps over the lazy dog?
THE QUICK BROWN FOX JUMPS OVER THE LAZY DOG!
0123456789
END

                the_quick := OMG.Text(main_viewport, Text);
                the_quick.text_size = (cos(g_time) + 2) * 10;

                content_browser := Panel(left_side, "content_browser", "Content Browser");
                {
                    OMG.SetHeight(content_browser, OMG.SizeFill(0.9));

                }
            }

            if content.layout_last_frame.size.x > 500 {
                right_side := OMG.GetNode(content, "right_side");
                {
                    OMG.SetSize(right_side, OMG.SizePx(400), OMG.SizeFill());
                    OMG.SetLayout(right_side, .TopToBottom);

                    entity_outliner := Panel(right_side, "entity_outliner", "Entity Outliner");
                    {
                        for i : 0..25 {
                            OMG.PushIDOffset(i);
                            defer OMG.PopIDOffset();

                            entry := OMG.GetNode(entity_outliner);
                            OMG.SetPadding(entry, 2, 2);
                            OMG.SetSize(entry, OMG.SizeFill(), OMG.SizeFit());
                            OMG.ButtonBehavior(entry);

                            OMG.Text(entry, "Entry %", i);
                        }
                    }

                    entity_inspector := Panel(right_side, "entity_inspector", "Entity Inspector");
                    {
                        add_component, add_component_node := OMG.Button(entity_inspector, "Add Component", style=OMG.GetStyle("button_accent", OMG.ButtonStyle));
                        OMG.SetWidth(add_component_node, OMG.SizeFill());

                        text := OMG.GetNode(add_component_node, "text");
                        text.text_size *= 1.1;
                    }
                }
            }
        }
    }
}
