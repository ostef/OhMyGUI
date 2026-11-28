g_disabled: bool;

ButtonsGallery :: (parent: *OMG.Node) {
    buttons := OMG.GetNode(parent);
    OMG.SetSize(buttons, OMG.SizeFill(), OMG.SizeFit());
    OMG.SetLayout(buttons, .LeftToRight);
    OMG.SetChildGap(buttons, 6);

    OMG.Button(buttons, "Press Me!");
    OMG.Button(buttons, "Accent Button", style=OMG.GetStyle("button_accent", OMG.ButtonStyle));
    OMG.Button(buttons, "Positive Button", style=OMG.GetStyle("button_positive", OMG.ButtonStyle));
    OMG.Button(buttons, "Negative Button", style=OMG.GetStyle("button_negative", OMG.ButtonStyle));
}

g_sliders_data_type: enum {
    Float32;
    Float64;
    Int8;
    Int16;
    Int32;
    Int64;
    UInt8;
    UInt16;
    UInt32;
    UInt64;
} = .Int8;

SliderValues :: struct(T: Type) {
    min := #run OMG.MinValue(T);
    max := #run OMG.MaxValue(T);
    step := #run OMG.DefaultStep(T);
    value: T;
}

g_slider_float32: SliderValues(float32);
g_slider_float64: SliderValues(float64);
g_slider_s8: SliderValues(s8);
g_slider_s16: SliderValues(s16);
g_slider_s32: SliderValues(s32);
g_slider_s64: SliderValues(s64);
g_slider_u8: SliderValues(u8);
g_slider_u16: SliderValues(u16);
g_slider_u32: SliderValues(u32);
g_slider_u64: SliderValues(u64);

TextFlags :: enum_flags u32 {
    WrapText :: OMG.NodeFlags.WrapText;
    JustifyText :: OMG.NodeFlags.JustifyText;
}

g_roboto_extended_font: *OMG.Font;
g_text_font: *OMG.Font;
g_text_effects: OMG.TextEffects;
g_text_flags: TextFlags;
g_text_language: enum {
    English;
    French;
    Spanish;
    Italian;
    German;
    Russian;
    Arabic;
    Greek;
}

Pangrams :: string.[
    // English
    "Pack my box with five dozen liquor jugs.",
    // French
    "Les naïfs ægithales hâtifs d'Aÿ pondant à Noël où il gèle sont sûrs d'être déçus en voyant leurs drôles d'œufs abîmés.",
    // Spanish
    "El veloz murciélago hindú comía feliz cardillo y kiwi. La cigüeña tocaba el saxofón detrás del palenque de paja.",
    // Italian
    "Quel vituperabile xenofobo zelante assaggia il whisky ed esclama: alleluja!",
    // German
    "Victor jagt zwölf Boxkämpfer quer über den großen Sylter Deich.",
    // Russian
    "Съешь ещё этих мягких французских булок, да выпей же чаю", // 0x400 - 0x4ff
    // Arabic
    "نص حكيم له سر قاطع وذو شأن عظيم مكتوب على ثوب أخضر ومغلف بجلد أزرق", // 0x600 - 0x6ff
    // Greek
    "Ξεσκεπάζω την ψυχοφθόρα σας βδελυγμία",
];

Lorem_Ipsum :: "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.";

g_text_input_flags: OMG.TextInputFlags;

SlidersGallery :: (parent: *OMG.Node, values: *SliderValues) {
    SlidersGallery(parent, *values.value, *values.min, *values.max, *values.step);
}

SlidersGallery :: (parent: *OMG.Node, value: *$T, min: *T, max: *T, step: *T) {
    min_max_step_container := OMG.LabelAndContent(parent, "Min, Max, Step");
    OMG.NumberInput(min_max_step_container, min, OMG.MinValue(T), OMG.MaxValue(T), OMG.DefaultStep(T));
    OMG.NumberInput(min_max_step_container, max, OMG.MinValue(T), OMG.MaxValue(T), OMG.DefaultStep(T));
    OMG.NumberInput(min_max_step_container, step, OMG.MinValue(T), OMG.MaxValue(T), OMG.DefaultStep(T));

    OMG.HorizontalSeparatorText(parent, "Normal Style");
    OMG.Slider(parent, value, min.*, max.*, step.*);

    OMG.HorizontalSeparatorText(parent, "Knob Style");
    OMG.KnobSlider(parent, value, min.*, max.*, step.*);

    OMG.HorizontalSeparatorText(parent, "Fill Style");
    OMG.FillSlider(parent, value, min.*, max.*, step.*);
}

WidgetsGallery :: (parent: *OMG.Node) {
    OMG.SetLayout(parent, .TopToBottom);
    OMG.SetChildGap(parent, 6);

    disable_container := OMG.LabelAndContent(parent, "Disable All");
    OMG.Checkbox(disable_container, *g_disabled);

    OMG.PushDisabled(g_disabled);
    defer OMG.PopDisabled();

    scroll_view := OMG.ScrollView(parent, .NoScrollbarX);

    buttons := OMG.CollapsingHeader(scroll_view, "Buttons");
    if buttons {
        buttons.padding.x += 4;
        buttons.padding.z += 4;

        ButtonsGallery(buttons);
    }

    if !g_roboto_extended_font {
        config: OMG.FontConfig;
        config.glyph_ranges = .[
            .{0x20, 0x7f}, // ASCII
            .{0xa0, 0x24f}, // Latin
            .{0x20A0, 0x20CF}, // Currency symbols
            .{0x400, 0x4ff}, // Russian
            .{0x600, 0x6ff}, // Arabic
            .{0x370, 0x3ff}, // Greek
            .{0x1f00, 0x1fff}, // Greek extended
        ];
        config.atlas_width = 2048;
        config.atlas_height = 2048;

        g_roboto_extended_font = OMG.LoadFontFromMemory("Roboto-Regular", OMG.Roboto_Regular, config);
        g_text_font = g_roboto_extended_font;
    }

    text := OMG.CollapsingHeader(scroll_view, "Text");
    if text {
        language := OMG.LabelAndContent(text, "Language");
        OMG.EnumCombo(language, *g_text_language);

        if !g_text_font {
            g_text_font = OMG.GetStyle("text", OMG.TextStyle).font;
        }

        font := OMG.LabelAndContent(text, "Font");
        fonts_menu := OMG.ComboMenu(font, ifx g_text_font then g_text_font.name else "None");
        if fonts_menu {
            menu_style := OMG.GetStyle("combo", OMG.ComboStyle);
            selected: *OMG.Font;
            for :OMG.Fonts context.omg {
                OMG.PushID(OMG.GetID(it_index));
                defer OMG.PopID();

                if OMG.MenuItem(fonts_menu, it.name, selected=it == g_text_font, style=*menu_style.item) {
                    selected = it;
                }
            }

            if selected {
                g_text_font = selected;
            }
        }

        flags := OMG.LabelAndContent(text, "Flags & Effects");
        OMG.EnumCombo(flags, *g_text_flags);
        OMG.EnumCombo(flags, *g_text_effects);

        OMG.Spacing(text, 10);

        text_node := OMG.Text(text, "%", Pangrams[g_text_language]);
        OMG.SetSize(text_node, OMG.SizeFill(), OMG.SizeFit());

        text_node.font = g_text_font;
        text_node.flags |= xx g_text_flags;
        text_node.text_effects = g_text_effects;

        text_node = OMG.Text(text, "%", Lorem_Ipsum);
        OMG.SetSize(text_node, OMG.SizeFill(), OMG.SizeFit());

        text_node.font = g_text_font;
        text_node.flags |= xx g_text_flags;
        text_node.text_effects = g_text_effects;
    }

    text_inputs := OMG.CollapsingHeader(scroll_view, "Text Inputs");
    if text_inputs {
        OMG.SetLayout(text_inputs, .LeftToRight);
        OMG.TextInput(text_inputs, g_text_input_flags);

        flags := OMG.LabelAndContent(text_inputs, "Flags");
        OMG.EnumCombo(flags, *g_text_input_flags);
    }

    sliders := OMG.CollapsingHeader(scroll_view, "Sliders");
    if sliders {
        sliders.padding.x += 4;
        sliders.padding.z += 4;

        data_type_container := OMG.LabelAndContent(sliders, "Type");
        OMG.EnumCombo(data_type_container, *g_sliders_data_type);

        if #complete g_sliders_data_type == {
        case .Float32;
            SlidersGallery(sliders, *g_slider_float32);
        case .Float64;
            SlidersGallery(sliders, *g_slider_float64);
        case .Int8;
            SlidersGallery(sliders, *g_slider_s8);
        case .Int16;
            SlidersGallery(sliders, *g_slider_s16);
        case .Int32;
            SlidersGallery(sliders, *g_slider_s32);
        case .Int64;
            SlidersGallery(sliders, *g_slider_s64);
        case .UInt8;
            SlidersGallery(sliders, *g_slider_u8);
        case .UInt16;
            SlidersGallery(sliders, *g_slider_u16);
        case .UInt32;
            SlidersGallery(sliders, *g_slider_u32);
        case .UInt64;
            SlidersGallery(sliders, *g_slider_u64);
        }
    }

    trees := OMG.CollapsingHeader(scroll_view, "Trees");
    tables := OMG.CollapsingHeader(scroll_view, "Tables");
    grids := OMG.CollapsingHeader(scroll_view, "Grids");
    tabs := OMG.CollapsingHeader(scroll_view, "Tabs");
}

WidgetsGallerySubwindow :: (window: *OMG.Window) {
    subwindow := OMG.Subwindow(window, "Widgets Gallery", "widgets_gallery");
    if subwindow {
        menu_bar := OMG.MenuBar(subwindow, "menu_bar");
        file := OMG.Menu(menu_bar, "File");
        if file {
            new := OMG.Menu(file, "New");
            if new {
                OMG.MenuItem(new, "Document");
                OMG.MenuItem(new, "Folder");
            }

            OMG.MenuItem(file, "Open");
            OMG.MenuItem(file, "Save");
            OMG.MenuItem(file, "Save As");
            OMG.MenuItem(file, "Save All");

            InfiniteMenu :: (parent: *OMG.Node) {
                menu := OMG.Menu(parent, "Infinite");
                if menu {
                    InfiniteMenu(menu);
                }
            }

            InfiniteMenu(file);
        }

        OMG.PushDisabled(true);
        OMG.MenuItem(menu_bar, "Disabled");
        OMG.PopDisabled();

        WidgetsGallery(subwindow);
    }
}
