// This file is more of a sandbox than real example code
// @Todo: better demo

g_frame_index : int;
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

g_justify_text : bool;
g_animate_text : bool;
g_text_size := 20.0;

g_content_browser_opened := true;
g_entity_outliner_opened := true;
g_entity_inspector_opened := true;
g_debug_view_opened := true;

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

g_wants_switch_theme : bool;

EditorFrame :: () {
    defer g_frame_index += 1;

    if g_entities.count == 0 {
        FillEntities();
    }

    if g_wants_switch_theme {
        light, dark := OMG.GetDefaultThemes();
        if OMG.GetTheme() == light {
            OMG.SetTheme(dark);
        } else {
            OMG.SetTheme(light);
        }

        g_wants_switch_theme = false;
    }

    if OMG.IsKeyPressed(.Minus) && OMG.GetModState() == .Ctrl {
        theme := OMG.GetTheme();
        text := OMG.GetStyle(theme, "text", OMG.TextStyle);
        OMG.SetGlobalTextSize(theme, max(text.text_size - 2, 5));
    }
    if OMG.IsKeyPressed(.Equals) && OMG.GetModState() == .Ctrl {
        theme := OMG.GetTheme();
        text := OMG.GetStyle(theme, "text", OMG.TextStyle);
        OMG.SetGlobalTextSize(theme, max(text.text_size + 2, 5));
    }

    base_background_color := OMG.GetStyle("base", OMG.BoxStyle).background_colors.top_left;

    window := OMG.GetWindow(g_window);

    root := OMG.GetNode(window);
    {
        OMG.SetLayout(root, .TopToBottom);

        title_bar := OMG.GetNode(root, "title_bar");
        {
            OMG.SetPadding(title_bar, 6, 4, 4, 4);
            OMG.SetChildGap(title_bar, 4);
            OMG.SetChildAlign(title_bar, 0.5, 0.5);
            OMG.SetWidth(title_bar, OMG.SizeFill());
            OMG.SetHeight(title_bar, OMG.SizeFit());

            OMG.SetBackgroundColor(title_bar, base_background_color);
            OMG.SetBorderColor(title_bar, OMG.MakeTone(base_background_color, 0.2));
            OMG.SetBorderSize(title_bar, 1);

            title_bar.flags |= .Focusable;

            if OMG.HasMouseFocus(title_bar) {
                window.hovered_area = .Draggable;
            }

            if window.has_custom_decorations {
                OMG.Text(title_bar, "OMG Engine (% FPS)", cast(int, 1 / g_delta_time));

                OMG.Separator(title_bar);
            }

            title_menu_bar := OMG.MenuBar(title_bar, "title_menu_bar");

            file_menu := OMG.Menu(title_menu_bar, "File");
            if file_menu {
                new_menu := OMG.Menu(file_menu, "New");
                if new_menu {
                    if OMG.MenuItem(new_menu, "World") {
                        print("World\n");
                    }
                    if OMG.MenuItem(new_menu, "Entity") {
                        print("Entity\n");
                    }
                    if OMG.MenuItem(new_menu, "Component") {
                        print("Component\n");
                    }
                }

                if OMG.MenuItem(file_menu, "Open") {
                    print("Open\n");
                }
                if OMG.MenuItem(file_menu, "Save") {
                    print("Save\n");
                }
                if OMG.MenuItem(file_menu, "Save As") {
                    print("Save As\n");
                }
            }

            edit_menu := OMG.Menu(title_menu_bar, "Edit");
            if edit_menu {
                if OMG.MenuItem(edit_menu, "Select All") {
                    print("Select All\n");
                }
                if OMG.MenuItem(edit_menu, "Invert Selection") {
                    print("Invert Selection\n");
                }
            }

            window_menu := OMG.Menu(title_menu_bar, "Window");
            if window_menu {
                if OMG.MenuItem(window_menu, "Debug View") {
                    g_debug_view_opened = true;
                }
                if OMG.MenuItem(window_menu, "New Viewport") {
                    print("New Viewport\n");
                }
                if OMG.MenuItem(window_menu, "Profiler") {
                    print("Profiler\n");
                }
                if OMG.MenuItem(window_menu, "Entity Outliner") {
                    g_entity_outliner_opened = true;
                    print("Entity Outliner\n");
                }
                if OMG.MenuItem(window_menu, "Entity Inspector") {
                    g_entity_inspector_opened = true;
                    print("Entity Inspector\n");
                }
                if OMG.MenuItem(window_menu, "Browser") {
                    g_content_browser_opened = true;
                    print("Browser\n");
                }
            }

            if OMG.MenuItem(title_menu_bar, "Switch Theme") {
                g_wants_switch_theme = true;
            }

            menu_item_style := OMG.GetStyle("menu_item", OMG.MenuItemStyle);
            OMG.Toggle(title_menu_bar, "Slow Mode", *g_slow_down, style=*menu_item_style.button);

            help_menu := OMG.Menu(title_menu_bar, "Help");
            if help_menu {
                if OMG.MenuItem(help_menu, "Documentation") {
                    print("Documentation\n");
                }
                if OMG.MenuItem(help_menu, "About") {
                    print("About\n");
                }
            }

            if window.has_custom_decorations {
                Btn_Size :: 26.0;

                button_style := OMG.GetStyle("button_small", OMG.ButtonStyle).*;
                for * button_style.states {
                    it.background.corner_radiuses = .{2,2,2,2};
                }

                if OMG.CollapseButton(title_bar, Btn_Size, style=*button_style) {
                    SDL_MinimizeWindow(g_window);
                }

                flags := SDL_GetWindowFlags(g_window);
                is_maximized := (flags & SDL_WINDOW_MAXIMIZED) != 0;
                if is_maximized {
                    if OMG.UnmaximizeButton(title_bar, Btn_Size, style=*button_style) {
                        SDL_RestoreWindow(g_window);
                    }
                } else {
                    if OMG.MaximizeButton(title_bar, Btn_Size, style=*button_style) {
                        SDL_MaximizeWindow(g_window);
                    }
                }

                close_button_style := button_style;
                OMG.SetColors(*close_button_style.focused.background.background_colors, 0xc81123ff);
                OMG.SetColors(*close_button_style.hot.background.background_colors, 0xc81123ff);
                OMG.SetAlpha(*close_button_style.hot.background.background_colors, 0.5);
                OMG.SetColors(*close_button_style.active.background.background_colors, 0xc81123ff);

                if OMG.CloseButton(title_bar, Btn_Size, style=*close_button_style) {
                    g_quit = true;
                }
            }
        }

        OMG.DockSpace(root, "dockspace");

        content_browser := OMG.Subwindow(window, "Content Browser", "content_browser", *g_content_browser_opened, initial_size=.{400, 500});
        if content_browser {
            OMG.Text(content_browser, "% nodes", context.omg.node_pool.count);

            aaa := OMG.Text(content_browser, "Some long long text that we should cut but should fit too");
            OMG.SetWidth(aaa, OMG.SizeFill());
            OMG.SetMaxWidthFit(aaa);

            OMG.Text(content_browser, "CPU: % ms", (g_user_time + context.omg.total_time_last_frame) * 1000);
            OMG.Text(content_browser, "\tRender: % ms", context.omg.total_time_last_frame * 1000);
            OMG.Text(content_browser, "\t\tLayout: % ms", context.omg.layout_time_last_frame * 1000);
            OMG.Text(content_browser, "\t\tDraw: % ms", context.omg.draw_time_last_frame * 1000);
            OMG.Text(content_browser, "\t\tRemaining: % ms", (context.omg.total_time_last_frame - context.omg.layout_time_last_frame - context.omg.draw_time_last_frame) * 1000);
            OMG.Text(content_browser, "\tUser: % ms", g_user_time * 1000);
            OMG.Text(content_browser, "GPU: % ms", g_gpu_time * 1000);
            OMG.Text(content_browser, "Num Vertices: %", context.omg.num_vertices_last_frame);
            OMG.Text(content_browser, "Num Indices: %", context.omg.num_indices_last_frame);

            OMG.Separator(content_browser);

            password_field := OMG.GetNode(content_browser, "password_field");
            {
                OMG.SetSize(password_field, OMG.SizeFill(0.3), OMG.SizeFit());
                OMG.SetMinWidth(password_field, 300);
                OMG.SetLayout(password_field, .LeftToRight);
                OMG.SetChildAlign(password_field, 0, 0.5);
                OMG.SetChildGap(password_field, 6);

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
                OMG.SetMinWidth(fields, 300);
                OMG.SetLayout(fields, .TopToBottom);
                OMG.SetChildGap(fields, 10);

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
                    OMG.PushID(OMG.GetID(it));
                    defer OMG.PopID();

                    field := OMG.GetNode(fields);
                    OMG.SetSize(field, OMG.SizeFill(), OMG.SizeFit());
                    OMG.SetChildAlign(field, 0, 0.5);
                    OMG.SetChildGap(field, 8);

                    OMG.RadioButton(field, *g_selected_fruit, xx it);
                    OMG.Text(field, "%", type_info(type_of(g_selected_fruit)).names[it_index]);
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

            justify_field := OMG.LabelAndContent(content_browser, "Justify");
            OMG.Checkbox(justify_field, *g_justify_text);

            animate_field := OMG.LabelAndContent(content_browser, "Animate");
            OMG.Checkbox(animate_field, *g_animate_text);

            _, _, the_quick := OMG.ClickableText(content_browser, Text);
            OMG.SetWidth(the_quick, OMG.SizeFill());
            the_quick.flags |= .WrapText;
            if g_justify_text {
                the_quick.flags |= .JustifyText;
            }
            if g_animate_text {
                g_text_size = 10 + (cos(g_time) + 2) * 0.5 * 30;
            }

            the_quick.text_size = g_text_size;
        }

        entity_outliner := OMG.Subwindow(window, "Entity Outliner", "entity_outliner", *g_entity_outliner_opened, initial_size=.{400, 500});
        if entity_outliner {
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

        entity_inspector := OMG.Subwindow(window, "Entity Inspector", "entity_inspector", *g_entity_inspector_opened, initial_size=.{400, 500});
        if entity_inspector {
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

            InfiniteTreeNode :: (parent : *OMG.Node) {
                tree := OMG.TreeNode(parent, "Infinity Tree");
                if tree {
                    InfiniteTreeNode(tree);
                }
            }

            InfiniteTreeNode(entity_inspector);
        }

        OMG.DebugViewWindow(window, "debugger", *g_debug_view_opened);
    }
}
