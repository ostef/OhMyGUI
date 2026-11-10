g_disabled: bool;

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
};

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

    sliders := OMG.CollapsingHeader(parent, "Sliders");
    if sliders {
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
}

WidgetsGallerySubwindow :: (window: *OMG.Window) {
    subwindow := OMG.Subwindow(window, "Widgets Gallery", "widgets_gallery");
    if subwindow {
        WidgetsGallery(subwindow);
    }
}
