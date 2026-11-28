g_disabled: bool;

ButtonsGallery :: (parent: *OMG.Node) {
    OMG.Button(parent, "Press Me!");
    OMG.Button(parent, "Accent Button", style=OMG.GetStyle("button_accent", OMG.ButtonStyle));
    OMG.Button(parent, "Positive Button", style=OMG.GetStyle("button_positive", OMG.ButtonStyle));
    OMG.Button(parent, "Negative Button", style=OMG.GetStyle("button_negative", OMG.ButtonStyle));
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

g_text_input_flags: OMG.TextInputFlags;

SlidersGallery :: (parent: *OMG.Node, values: *SliderValues) {
    SlidersGallery(parent, *values.value, *values.min, *values.max, *values.step);
}

SlidersGallery :: (parent: *OMG.Node, value: *$T, min: *T, max: *T, step: *T) {
    min_container := OMG.LabelAndContent(parent, "Min");
    OMG.NumberInput(min_container, min, OMG.MinValue(T), OMG.MaxValue(T), OMG.DefaultStep(T));

    max_container := OMG.LabelAndContent(parent, "Max");
    OMG.NumberInput(max_container, max, OMG.MinValue(T), OMG.MaxValue(T), OMG.DefaultStep(T));

    step_container := OMG.LabelAndContent(parent, "Step");
    OMG.NumberInput(step_container, step, OMG.MinValue(T), OMG.MaxValue(T), OMG.DefaultStep(T));

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
