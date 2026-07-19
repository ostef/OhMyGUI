g_slider_value := 0.5;
g_show_password := true;
g_toggle_value : bool;
g_color := OMG.Vec4f.{0,0,0,1};
g_selected_fruit : enum {
    Apple;
    Strawberry;
    Cherry;
    Banana;
};

g_dummy_viewport_image : struct {
    texture : OMG.TextureHandle;
    width, height : u32;
}

Entity :: struct {
    id : int;
    name : string;
    type : string;
}

g_entities : [..]Entity;

SortEntities :: (params : *OMG.TableSortParams) {
    #import "Sort";
    #import "String";

    for params.column_params {
        if it.str_id == {
        case "id";
            if it.direction == .Ascending {
                quick_sort(g_entities, (a, b) => a.id - b.id);
            } else {
                quick_sort(g_entities, (a, b) => b.id - a.id);
            }
        case "name";
            if it.direction == .Ascending {
                quick_sort(g_entities, (a, b) => compare(a.name, b.name));
            } else {
                quick_sort(g_entities, (a, b) => -compare(a.name, b.name));
            }
        case "type";
            if it.direction == .Ascending {
                quick_sort(g_entities, (a, b) => compare(a.type, b.type));
            } else {
                quick_sort(g_entities, (a, b) => -compare(a.type, b.type));
            }
        }
    }

    if params.column_params.count == 0 {
        quick_sort(g_entities, (a, b) => a.id - b.id);
    }

    params.modified = false;
}

FillEntities :: () {
    Random :: #import "Random";

    RandomName :: () -> string {
        Names :: string.[
            "",
            "Enemy",
            "Wall",
            "Floor",
            "Tree",
            "Rock",
            "Foliage",
            "Light",
        ];

        index := Random.random_get() % Names.count;
        suffix := Random.random_get() % 100;

        return ifx suffix > 0 && index > 0 then sprint("%.%", Names[index], suffix) else Names[index];
    }

    RandomType :: () -> string {
        Types :: string.[
            "Static Mesh",
            "Skinned Mesh",
            "Point Light",
            "Directional Light",
            "Spot Light",
            "Particle Emitter",
        ];

        index := Random.random_get() % Types.count;

        return Types[index];
    }

    for i : 0..100 {
        e := array_add(*g_entities);
        e.id = i + 1;
        e.name = RandomName();
        e.type = RandomType();
    }
}

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

            if content.children_size.y > content.size.y - content.padding.y - content.padding.w {
                OMG.Scrollbar(content_and_scrollbar, content, .Y);
            }

            return content;
        }
    }
}

EditorFrame :: () {
    if !g_dummy_viewport_image.texture {
        using g_dummy_viewport_image;

        texture, width, height = OMG.LoadImage("dummy_viewport.png");
        assert(texture != 0);
    }

    if g_entities.count == 0 {
        FillEntities();
    }

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
                new_menu := OMG.SubMenu(file_menu, "New");
                if new_menu {
                    OMG.MenuItem(new_menu, "World");
                    OMG.MenuItem(new_menu, "Entity");
                    OMG.MenuItem(new_menu, "Component");
                }

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

            if OMG.MenuItem(title_menu_bar, "Switch Theme") {
                light, dark := OMG.GetDefaultThemes();
                if OMG.GetTheme() == light {
                    OMG.SetTheme(dark);
                } else {
                    OMG.SetTheme(light);
                }
            }

            OMG.Toggle(title_menu_bar, "Debug Mode", *context.omg.debug_mode, style=OMG.GetStyle("menu_item", OMG.ButtonStyle));

            help_menu := OMG.Menu(title_menu_bar, "Help");
            if help_menu {
                OMG.MenuItem(help_menu, "Documentation");
                OMG.MenuItem(help_menu, "About");
            }

            Btn_Size :: 20.0;

            minimize, minimize_node := OMG.Button(title_bar, OMG.SizePx(Btn_Size), OMG.SizePx(Btn_Size));
            minimize_node.flags |= .NoPaddedClip;
            OMG.SetCornerRadius(minimize_node, Btn_Size * 0.5);
            OMG.SetPadding(minimize_node, 5, 5);
            if minimize {
                SDL_MinimizeWindow(g_window);
            }

            maximize, maximize_node := OMG.Button(title_bar, OMG.SizePx(Btn_Size), OMG.SizePx(Btn_Size));
            maximize_node.flags |= .NoPaddedClip;
            OMG.SetCornerRadius(maximize_node, Btn_Size * 0.5);
            OMG.SetPadding(maximize_node, 5, 5);
            if maximize {
                flags := SDL_GetWindowFlags(g_window);
                if flags & SDL_WINDOW_MAXIMIZED {
                    SDL_RestoreWindow(g_window);
                } else {
                    SDL_MaximizeWindow(g_window);
                }
            }

            close, close_node := OMG.Button(title_bar, OMG.SizePx(Btn_Size), OMG.SizePx(Btn_Size));
            close_node.flags |= .NoPaddedClip;
            OMG.SetCornerRadius(close_node, Btn_Size * 0.5);
            OMG.SetPadding(close_node, 5, 5);
            if close {
                g_quit = true;
            }

            minimize_icon := OMG.GetNode(minimize_node);
            OMG.SetSize(minimize_icon, OMG.SizeFill(), OMG.SizeFill());
            OMG.SetBackgroundColor(minimize_icon, OMG.ChooseTextColor(base_background_color));
            OMG.SetDraw(minimize_icon, (draw_list : *OMG.DrawList, node : *OMG.Node) {
                center := (node.rect.xy + node.rect.zw) * 0.5;
                length := node.size.x * 0.7;

                OMG.DrawBox(draw_list, .{
                    position=center,
                    size=.{length, 1},
                    border_color=node.background_color,
                    border_size=1,
                });
            });

            maximize_icon := OMG.GetNode(maximize_node);
            OMG.SetSize(maximize_icon, OMG.SizeFill(), OMG.SizeFill());
            OMG.SetBackgroundColor(maximize_icon, OMG.ChooseTextColor(base_background_color));

            if SDL_GetWindowFlags(g_window) & SDL_WINDOW_MAXIMIZED {
                OMG.SetDraw(maximize_icon, (draw_list : *OMG.DrawList, node : *OMG.Node) {
                    size := OMG.Vec2f.{1,1} * sqrt(0.5 * node.size.x * node.size.x);
                    center := (node.rect.xy + node.rect.zw) * 0.5;
                    rect := OMG.Vec4f.{xy=center - size * 0.5, zw=center + size * 0.5};

                    p0 := OMG.Vec2f.{size.x * 0.3, 0};
                    p1 := OMG.Vec2f.{size.x, 0};
                    p2 := OMG.Vec2f.{size.x, size.y - size.y * 0.3};

                    tri_center := (p0 + p1 + p2) / 3;
                    p0 = tri_center + OMG.Rotate(p0 - tri_center, PI);
                    p1 = tri_center + OMG.Rotate(p1 - tri_center, PI);
                    p2 = tri_center + OMG.Rotate(p2 - tri_center, PI);

                    OMG.DrawTriangle(draw_list, rect.xy + p0, rect.xy + p1, rect.xy + p2, node.background_color);

                    p0 = OMG.Vec2f.{0, size.y * 0.3};
                    p1 = OMG.Vec2f.{0, size.y};
                    p2 = OMG.Vec2f.{size.x - size.x * 0.3, size.y};

                    tri_center = (p0 + p1 + p2) / 3;
                    p0 = tri_center + OMG.Rotate(p0 - tri_center, PI);
                    p1 = tri_center + OMG.Rotate(p1 - tri_center, PI);
                    p2 = tri_center + OMG.Rotate(p2 - tri_center, PI);

                    OMG.DrawTriangle(draw_list, rect.xy + p0, rect.xy + p1, rect.xy + p2, node.background_color);
                });
            } else {
                OMG.SetDraw(maximize_icon, (draw_list : *OMG.DrawList, node : *OMG.Node) {
                    size := OMG.Vec2f.{1,1} * sqrt(0.5 * node.size.x * node.size.x);
                    center := (node.rect.xy + node.rect.zw) * 0.5;
                    rect := OMG.Vec4f.{xy=center - size * 0.5, zw=center + size * 0.5};

                    p0 := OMG.Vec2f.{size.x * 0.3, 0};
                    p1 := OMG.Vec2f.{size.x, 0};
                    p2 := OMG.Vec2f.{size.x, size.y - size.y * 0.3};

                    OMG.DrawTriangle(draw_list, rect.xy + p0, rect.xy + p1, rect.xy + p2, node.background_color);

                    p0 = OMG.Vec2f.{0, size.y * 0.3};
                    p1 = OMG.Vec2f.{0, size.y};
                    p2 = OMG.Vec2f.{size.x - size.x * 0.3, size.y};

                    OMG.DrawTriangle(draw_list, rect.xy + p0, rect.xy + p1, rect.xy + p2, node.background_color);
                });
            }

            close_icon := OMG.GetNode(close_node);
            OMG.SetSize(close_icon, OMG.SizeFill(), OMG.SizeFill());
            OMG.SetBackgroundColor(close_icon, OMG.ChooseTextColor(base_background_color));
            OMG.SetDraw(close_icon, (draw_list : *OMG.DrawList, node : *OMG.Node) {
                center := (node.rect.xy + node.rect.zw) * 0.5;
                length := node.size.x;

                a := OMG.Rotate(OMG.Box(1, length), PI * 0.25);
                b := OMG.Rotate(OMG.Box(1, length), -PI * 0.25);
                shape := OMG.Union(a, b);
                OMG.DrawShape(draw_list, shape, center, node.background_color);
            });
        }

        content := OMG.GetNode(root, "content");
        {
            OMG.SetSize(content, OMG.SizeFill());

            left_side := OMG.GetNode(content, "left_side");
            {
                OMG.SetSize(left_side, OMG.SizeFill());
                OMG.SetLayout(left_side, .TopToBottom);

                dock := OMG.DockSpace(left_side, "dockspace");
                docked := OMG.DockSubwindow(dock, "color_picker");

                content_browser := Panel(left_side, "content_browser", "Content Browser");
                {
                    OMG.SetHeight(content_browser, OMG.SizeFill(0.9));

                    OMG.SetPadding(content_browser, 12, 12);
                    OMG.SetChildGap(content_browser, 4, 4);

                    OMG.Text(content_browser, "% nodes", context.omg.node_pool.count);

                    OMG.Text(content_browser, "CPU: % ms", (g_user_time + context.omg.total_time_last_frame) * 1000);
                    OMG.Text(content_browser, "\tRender: % ms", context.omg.total_time_last_frame * 1000);
                    OMG.Text(content_browser, "\t\tLayout: % ms", context.omg.layout_time_last_frame * 1000);
                    OMG.Text(content_browser, "\t\tDraw: % ms", context.omg.draw_time_last_frame * 1000);
                    OMG.Text(content_browser, "\tUser: % ms", g_user_time * 1000);
                    OMG.Text(content_browser, "GPU: % ms", OMG_GL.GetLastFrameGPUTime() * 1000);
                    OMG.Text(content_browser, "GPU buffers: % MiB", OMG_GL.GetLastFrameMemoryUsage() / (1024.0 * 1024.0));

                    password_field := OMG.GetNode(content_browser, "password_field");
                    {
                        OMG.SetSize(password_field, OMG.SizeFill(0.3), OMG.SizeFit());
                        OMG.SetLayout(password_field, .LeftToRight);
                        OMG.SetChildAlign(password_field, 0, 0.5);
                        OMG.SetChildGap(password_field, 6, 6);

                        text_input_submitted, text_input := OMG.TextInput(password_field, ifx !g_show_password then .Password);

                        if text_input_submitted {
                            text := OMG.GetTextInputResult(text_input ,, temp);
                            print("%\n", text);
                        }

                        OMG.Text(password_field, "Show Password:");
                        OMG.Checkbox(password_field, *g_show_password);
                    }

                    fields := OMG.GetNode(content_browser);
                    {
                        OMG.SetSize(fields, OMG.SizeFill(0.3), OMG.SizeFit());
                        OMG.SetLayout(fields, .TopToBottom);
                        OMG.SetChildGap(fields, 0, 10);

                        OMG.Slider(fields, *g_slider_value, 0, 1, 0.1);
                        OMG.FillSlider(fields, *g_slider_value, 0, 1, 0.1);
                        OMG.KnobSlider(fields, *g_slider_value, 0, 1, 0.1);

                        OMG.Separator(fields);

                        if OMG.EnumCombo(fields, *g_selected_fruit) {
                            print("Selected: %\n", g_selected_fruit);
                        }

                        OMG.ColorInput(fields, *g_color);

                        OMG.Separator(fields);

                        for type_info(type_of(g_selected_fruit)).values {
                            OMG.PushIDOffset(xx it);
                            defer OMG.PopIDOffset();

                            content := OMG.LabelAndContent(fields, type_info(type_of(g_selected_fruit)).names[it_index]);
                            OMG.RadioButton(content, *g_selected_fruit, xx it);
                        }

                        OMG.Separator(fields);

                        OMG.ProgressBar(fields, (cos(g_time) + 1) * 0.5);
                    }

                    OMG.Separator(content_browser);

Text :: #string END
The quick brown fox jumps over the lazy dog?
THE QUICK BROWN FOX JUMPS OVER THE LAZY DOG!
0123456789

Voix ambiguë d'un cœur qui, au zéphyr, préfère les jattes de kiwis.
END

                    _, _, the_quick := OMG.ClickableText(content_browser, Text);
                    OMG.SetWidth(the_quick, OMG.SizeFill());
                    the_quick.flags |= .WrapText;
                    the_quick.text_size = 10 + (cos(g_time) + 2) * 0.5 * 30;
                }
            }

            if content.size.x > 500 {
                right_side := OMG.GetNode(content, "right_side");
                {
                    OMG.SetSize(right_side, OMG.SizePx(400), OMG.SizeFill());
                    OMG.SetLayout(right_side, .TopToBottom);

                    entity_outliner := Panel(right_side, "entity_outliner", "Entity Outliner");
                    {
                        table := OMG.Table(entity_outliner);
                        OMG.TableAddColumn(table, "ID", "id", OMG.SizeFill(0.2), flags=.Sortable);
                        OMG.TableAddColumn(table, "Name", "name", OMG.SizeFill(0.4), flags=.Sortable);
                        OMG.TableAddColumn(table, "Type", "type", OMG.SizeFill(0.4), flags=.Sortable);
                        OMG.TableHeadersRow(table);

                        sort_params := OMG.GetTableSortParams(table);
                        if sort_params && sort_params.modified {
                            SortEntities(sort_params);
                        }

                        for g_entities {
                            cell := OMG.TableNextRow(table);

                            OMG.Text(cell, "%", it.id);

                            cell = OMG.TableNextColumn(table);

                            if it.name {
                                OMG.Text(cell, "%", it.name);
                            } else {
                                text := OMG.Text(cell, "Unnamed");
                                OMG.SetAlpha(*text.text_color, 0.5);
                            }

                            cell = OMG.TableNextColumn(table);

                            OMG.Text(cell, "%", it.type);
                        }
                    }

                    entity_inspector := Panel(right_side, "entity_inspector", "Entity Inspector");
                    {
                        tree1 := OMG.TreeNode(entity_inspector, "1", flags=.OpenByDefault);
                        if tree1 {
                            tree1_1 := OMG.TreeNode(tree1, "1.1");
                            if tree1_1 {
                                OMG.TreeNode(tree1_1, "1.1.1", .Leaf);
                            }

                            OMG.TreeNode(tree1, "1.2", .Leaf);
                        }

                        tree2 := OMG.TreeNode(entity_inspector, "2");
                        if tree2 {
                            tree2_1 := OMG.TreeNode(tree2, "2.1");
                            if tree2_1 {
                                OMG.TreeNode(tree2_1, "2.1.1", .Leaf);
                            }

                            OMG.TreeNode(tree2, "2.2", .Leaf);
                        }

                        InfiniteTreeNode :: (parent : *OMG.Node, location := #caller_location) {
                            tree := OMG.TreeNode(parent, "Infinity Tree");
                            if tree {
                                InfiniteTreeNode(tree);
                            }
                        }

                        InfiniteTreeNode(entity_inspector);
                    }
                }
            }
        }
    }
}
