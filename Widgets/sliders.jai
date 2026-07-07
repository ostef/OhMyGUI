SliderStateStyle :: struct {
    background : BoxStyle;
    fill : BoxStyle;
    handle : BoxStyle;
    text : TextStyle;
}

SliderStyle :: struct {
    using _ : StateStyle(SliderStateStyle);
    background_size : float;
    handle_outside_background : bool;
    handle_size : Vec2f;
    text_align := Vec2f.{0.5,0.5};
}

SetColors :: (using style : *SliderStyle, base_background_color : RGBA8, base_fill_color : RGBA8, base_handle_color : RGBA8) {
    normal.background.background_color = base_background_color;
    focused.background.background_color = base_background_color;
    hot.background.background_color = base_background_color;
    active.background.background_color = base_background_color;

    normal.fill.background_color = base_fill_color;
    focused.fill.background_color = base_fill_color;
    hot.fill.background_color = base_fill_color;
    active.fill.background_color = base_fill_color;

    normal.handle.background_color = base_handle_color;
    focused.handle.background_color = Whiten(base_handle_color, 0.05);
    hot.handle.background_color = Darken(base_handle_color, 0.05);
    active.handle.background_color = Whiten(base_handle_color, 0.1);
}

KnobSlider :: (
    parent : *Node,
    value : *$T,
    min : T, max : T, step : T,
    axis := Axis.X,
    to_string : (T) -> string = null,
    style : *SliderStyle = null,
    location := #caller_location
) -> bool, slider : *Node, background : *Node, handle : *Node {
    EnsureStyle(*style, "knob_slider");
    ok, slider, background, handle := Slider(parent, value, min, max, step, axis, to_string, style, location);

    return ok, slider, background, handle;
}

FillSlider :: (
    parent : *Node,
    value : *$T,
    min : T, max : T, step : T,
    axis := Axis.X,
    to_string : (T) -> string = null,
    style : *SliderStyle = null,
    location := #caller_location
) -> bool, slider : *Node, background : *Node, handle : *Node {
    EnsureStyle(*style, "fill_slider");
    ok, slider, background, handle := Slider(parent, value, min, max, step, axis, to_string, style, location);

    return ok, slider, background, handle;
}

Slider :: (
    parent : *Node,
    value : *$T,
    min : T, max : T, step : T,
    axis := Axis.X,
    to_string : (T) -> string = null,
    style : *SliderStyle = null,
    location := #caller_location
) -> bool, slider : *Node, background : *Node, handle : *Node {
    EnsureStyle(*style, "slider");

    cross := GetCrossAxis(axis);

    fvalue_original := ifx value then cast(float, value.*);
    fvalue := ifx value then cast(float, value.*);
    fmin := cast(float, min);
    fmax := cast(float, max);
    fstep := ifx GetModState() == .Shift then 0.0 else cast(float, step);

    real_min := Min(fmin, fmax);
    real_max := Max(fmin, fmax);

    defer if value && fvalue_original != fvalue {
        value.* = xx fvalue;
    }

    slider, background, fill, handle, text : *Node;
    interacting := false;

    slider = GetNode(parent, location=location);
    {
        SetLayout(slider, .None);
        SetDraw(slider, null);

        slider.child_align[cross] = 0.5;
        slider.desired_size[axis] = SizeFill();
        slider.desired_size[cross] = SizeFit();
        if style.handle_outside_background {
            slider.padding.xy[axis] = xx (style.handle_size.x * 0.5);
            slider.padding.zw[axis] = xx (style.handle_size.x * 0.5);
        }
        slider.flags |= .NoPaddedClip;

        scroll := ScrollBehavior(slider);
        if scroll.y != 0 {
            fvalue = clamp(fvalue - sign(fmax - fmin) * sign(scroll.y) * cast(float, step), real_min, real_max);
            fvalue = Snap(fvalue, fstep);

            interacting = true;
        } else if scroll.x != 0 {
            fvalue = clamp(fvalue - sign(fmax - fmin) * sign(scroll.x) * cast(float, step), real_min, real_max);
            fvalue = Snap(fvalue, fstep);

            interacting = true;
        }

        background = GetNode(slider, "background");
        {
            background.flags |= .NoClip;

            SetLayout(background, .None);

            background.desired_size[axis] = SizeFill();
            background.desired_size[cross] = SizePx(style.background_size);
        }

        using _ := ButtonBehavior(slider);

        base_background_padding := Vec2f.{xx style.normal.background.padding.xy[axis], xx style.normal.background.padding.zw[axis]};

        offset_max := background.layout_last_frame.size[axis] - base_background_padding.x - base_background_padding.y;
        if !style.handle_outside_background {
            offset_max -= style.handle_size.x;
        }

        if slider.state_flags & .Focused && IsMouseButtonPressed(.Left) {
            SetMouseCapture(slider);
            SetMouseFocus(slider);
            pressed = true;
            held = true;

            mouse := GetMousePosition(slider.window)[axis];
            new_offset := mouse - (background.layout_last_frame.rect.xy[axis] + base_background_padding.x);
            new_value := lerp(fmin, fmax, clamp(new_offset / offset_max, 0, 1));

            fvalue = Snap(new_value, fstep);

            interacting = true;
        }

        if pressed {
            context.omg.mouse_captured_node_value = .{};
            context.omg.mouse_captured_node_value.xy[axis] = InverseLerp(fmin, fmax, fvalue) * offset_max;

            interacting = true;
        }

        if held {
            slider.state_flags |= .Active;

            new_offset := GetMousePosition()[axis] - context.omg.mouse_captured_at[axis];
            new_offset += context.omg.mouse_captured_node_value.xy[axis];
            new_value := lerp(fmin, fmax, clamp(new_offset / offset_max, 0, 1));

            fvalue = Snap(new_value, fstep);

            interacting = true;
        }

        fill = GetNode(background, "fill");
        {
            SetSize(fill, SizePercent(fvalue / (fmax - fmin)), SizeFill());
        }

        handle_parent := ifx style.handle_outside_background then slider else background;
        handle = GetNode(handle_parent, "handle");
        {
            SetSize(handle, SizePx(style.handle_size[axis]), SizePx(style.handle_size[cross]));

            handle.offset[axis] = InverseLerp(fmin, fmax, fvalue) * offset_max;
            if style.handle_outside_background {
                handle.offset[axis] -= style.handle_size.x * 0.5;
            }
        }

        text_area := GetNode(slider, "text_area");
        {
            SetSize(text_area, SizeFill(), SizeFill());
            text_area.child_align[axis] = style.text_align.x;
            text_area.child_align[cross] = style.text_align.y;

            text = GetNode(text_area, "text");
            {
                SetSize(text, SizeFit(), SizeFit());

                if to_string {
                    SetText(text, to_string(value.*));
                } else {
                    SetText(text, tprint("%", value.*));
                }
            }
        }
    }

    state := GetState(slider);
    Apply(background, style.states[state].background);
    Apply(fill, style.states[state].fill);
    Apply(handle, style.states[state].handle);
    Apply(text, style.states[state].text);

    return interacting, slider, background, handle;
}

ScrollbarStateStyle :: struct {
    background : BoxStyle;
    handle : BoxStyle;
}

ScrollbarStyle :: struct {
    using _ : StateStyle(ScrollbarStateStyle);
    background_size : float;
    handle_size : Vec2f;
}

SetColors :: (using style : *ScrollbarStyle, base_background_color : RGBA8, base_handle_color : RGBA8) {
    normal.background.background_color = base_background_color;
    focused.background.background_color = base_background_color;
    hot.background.background_color = base_background_color;
    active.background.background_color = base_background_color;

    normal.handle.background_color = base_handle_color;
    focused.handle.background_color = Whiten(base_handle_color, 0.05);
    hot.handle.background_color = Darken(base_handle_color, 0.05);
    active.handle.background_color = Whiten(base_handle_color, 0.1);
}

Scrollbar :: (parent : *Node, target : *Node, axis : Axis, style : *ScrollbarStyle = null, location := #caller_location) -> background : *Node, handle : *Node {
    EnsureStyle(*style, "scrollbar");

    background, handle : *Node;

    size := target.layout_last_frame.size[axis];
    children_size := target.layout_last_frame.children_size[axis] + target.padding.xy[axis] + target.padding.zw[axis];

    background = GetNode(parent, location);
    {
        background.desired_size[axis] = SizeFill();
        background.desired_size[GetCrossAxis(axis)] = SizeFit();

        SetLayout(background, .None);

        ScrollViewBehavior(background, target, xx (1 << axis));

        handle = GetNode(background, "handle");
        {
            ratio := size / children_size;

            handle.desired_size[axis] = SizeFill(ratio);
            handle.desired_size[GetCrossAxis(axis)] = SizePx(style.handle_size.y);
            handle.min_size[axis] = style.handle_size.x;

            // offset = (scroll / scrollable) * offset_max
            // offset / offset_max = scroll / scrollable
            // => scroll = (offset / offset_max) * scrollable

            scrollable := size - children_size;
            offset_max := background.layout_last_frame.size[axis] - handle.layout_last_frame.size[axis];

            // Allow the user to click on the background to interact with the scrollbar
            background.flags |= .Focusable;

            handle_result := ButtonBehavior(handle);

            if background.state_flags & .Focused && IsMouseButtonPressed(.Left) {
                SetMouseCapture(handle);
                SetMouseFocus(handle);
                handle_result.pressed = true;
                handle_result.held = true;

                mouse := GetMousePosition(background.window)[axis];
                new_offset := mouse - background.layout_last_frame.rect.xy[axis] - handle.layout_last_frame.size[axis] * 0.5;
                new_scroll := (new_offset / offset_max) * scrollable;

                SetContentScroll(target, axis, new_scroll);
            }

            if handle_result.pressed {
                context.omg.mouse_captured_node_value = .{};
                context.omg.mouse_captured_node_value.xy[axis] = (target.scroll[axis] / scrollable) * offset_max;
            }

            if handle_result.held {
                handle.state_flags |= .Active;

                new_offset := GetMousePosition()[axis] - context.omg.mouse_captured_at[axis];
                new_offset += context.omg.mouse_captured_node_value.xy[axis];
                new_scroll := (new_offset / offset_max) * scrollable;

                SetContentScroll(target, axis, new_scroll);
            }

            handle.offset[axis] = (target.scroll[axis] / scrollable) * offset_max;
        }
    }

    state := GetState(background.state_flags | handle.state_flags);
    Apply(background, style.states[state].background);

    state = GetState(handle.state_flags);
    Apply(handle, style.states[state].handle);

    return background, handle;
}
