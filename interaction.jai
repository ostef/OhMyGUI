IsHovered :: (node : *Node) -> bool {
    mouse := GetMousePosition(node.window);

    return IsInsideRect(mouse, node.layout_last_frame.clipped_rect);
}

ButtonResult :: struct {
    pressed : bool;
    held : bool;
    released : bool;
}

ButtonBehavior :: (node : *Node) -> ButtonResult {
    omg := context.omg;

    node.flags |= .Focusable;

    if (IsMouseButtonReleased(.Left) || IsMouseButtonDown(.Left)) && omg.mouse_capturing_node == node {
        SetMouseCapture(node);
        SetMouseFocus(node);
    } else if node.state_flags & .Focused && IsMouseButtonPressed(.Left) {
        SetMouseCapture(node);
    }

    if omg.mouse_capturing_node == node {
        node.state_flags |= .Hot;
    }

    result : ButtonResult;
    if node.state_flags & .Hot {
        result.held = true;
        result.pressed = IsHovered(node) && IsMouseButtonPressed(.Left);
        result.released = IsHovered(node) && IsMouseButtonReleased(.Left);
    }

    return result;
}

TextInputData :: struct {
    buffer : [..]u32;
    selection : s32;
    cursor : s32;
    cursor_blink_time : float;
}

DestroyTextInputData :: (node : *Node, data : *void) {
    using _ := cast(*TextInputData, data);
    array_free(buffer);
}

GetTextInputResultUtf32 :: (node : *Node) -> []u32 {
    data := GetUserData(node, TextInputData);
    if !data {
        return .[];
    }

    return array_copy(data.buffer);
}

GetTextInputResult :: (node : *Node) -> string {
    data := GetUserData(node, TextInputData);
    if !data {
        return "";
    }

    return EncodeStringAsUtf8(data.buffer);
}

Activate :: (input : *TextInputData) {
    input.cursor_blink_time = 0;
    input.cursor = xx input.buffer.count;
    input.selection = 0;
}

SelectAll :: (input : *TextInputData) {
    input.cursor_blink_time = 0;
    input.cursor = xx input.buffer.count;
    input.selection = -input.cursor;
}

Insert :: (input : *TextInputData, str : $T) {
    input.cursor_blink_time = 0;

    if input.selection != 0 {
        Delete(input);
    }

    for str {
        array_insert_at(*input.buffer, it, input.cursor);
        input.cursor += 1;
    }
}

BackspaceWord :: (input : *TextInputData) -> bool {
    input.cursor_blink_time = 0;

    if input.selection != 0 {
        return Delete(input);
    }

    if !MoveCursorLeftByWord(input, true) {
        return false;
    }

    return Delete(input);
}

Backspace :: (input : *TextInputData) -> bool {
    if input.selection != 0 {
        return Delete(input);
    }

    if !MoveCursorLeft(input) {
        return false;
    }

    return Delete(input);
}

Delete :: (input : *TextInputData) -> bool {
    if input.selection != 0 {
        while input.selection > 0 {
            input.selection -= 1;
            array_ordered_remove_by_index(*input.buffer, input.cursor);
        }
        while input.selection < 0 {
            input.selection += 1;
            input.cursor -= 1;
            array_ordered_remove_by_index(*input.buffer, input.cursor);
        }

        return true;
    }

    if input.cursor == input.buffer.count {
        return false;
    }

    array_ordered_remove_by_index(*input.buffer, input.cursor);
    return true;
}

DeleteWord :: (input : *TextInputData) -> bool {
    input.cursor_blink_time = 0;

    if input.selection != 0 {
        return Delete(input);
    }

    if !MoveCursorRightByWord(input, true) {
        return false;
    }

    return Delete(input);
}

MoveCursorLeftByWord :: (input : *TextInputData, select := false) -> bool {
    input.cursor_blink_time = 0;

    if !MoveCursorLeft(input, select) {
        return false;
    }

    start_char := input.buffer[input.cursor];
    while input.cursor > 0 && IsAlpha(start_char) == IsAlpha(input.buffer[input.cursor - 1]) {
        MoveCursorLeft(input, select);
    }

    return true;
}

MoveCursorRightByWord :: (input : *TextInputData, select := false) -> bool {
    input.cursor_blink_time = 0;

    start_char := ifx input.cursor < input.buffer.count then input.buffer[input.cursor];
    if !MoveCursorRight(input, select) {
        return false;
    }

    while input.cursor < input.buffer.count && IsAlpha(start_char) == IsAlpha(input.buffer[input.cursor]) {
        MoveCursorRight(input, select);
    }

    return true;
}

MoveCursorLeft :: (input : *TextInputData, select := false) -> bool {
    input.cursor_blink_time = 0;

    if !select {
        defer input.selection = 0;

        if input.selection != 0 {
            return false;
        }
    }

    if input.cursor == 0 {
        return false;
    }

    if select {
        input.selection += 1;
    }

    input.cursor -= 1;
    return true;
}

MoveCursorRight :: (input : *TextInputData, select := false) -> bool {
    input.cursor_blink_time = 0;

    if !select {
        defer input.selection = 0;

        if input.selection != 0 {
            return false;
        }
    }

    if input.cursor == input.buffer.count {
        return false;
    }

    if select {
        input.selection -= 1;
    }

    input.cursor += 1;
    return true;
}

SetCursor :: (input : *TextInputData, cursor : s32, select := false) {
    input.cursor_blink_time = 0;

    selection_end := input.cursor + input.selection;

    input.cursor = clamp(cursor, 0, xx input.buffer.count);

    if select {
        input.selection = selection_end - input.cursor;
    } else {
        input.selection = 0;
    }
}

TextInputBehavior :: (node : *Node) -> *TextInputData, submitted : bool, ButtonResult {
    input, is_new := AddUserData(node, TextInputData, DestroyTextInputData);
    if is_new {
        input.buffer.allocator = context.omg.general_purpose_allocator;
    }

    submitted := node.state_flags & .ActiveLastFrame && IsKeyPressed(.Return);
    should_deactivate := !(node.state_flags & .Focused) && IsMouseButtonPressed(.Left);
    should_deactivate |= IsKeyPressed(.Escape);
    should_deactivate |= submitted;

    button_result := ButtonBehavior(node);
    if !should_deactivate && (button_result.pressed || node.state_flags & .ActiveLastFrame) {
        node.state_flags |= .Active;
    }

    if node.state_flags & .Active {
        if node.state_flags & .ActiveLastFrame {
            input.cursor_blink_time += context.omg.delta_time;
        } else {
            Activate(input);
        }

        if context.omg.input.text.count > 0 {
            Insert(input, context.omg.input.text);
        }

        if IsKeyPressed(.Backspace) {
            if GetModState() & .Ctrl {
                BackspaceWord(input);
            } else {
                Backspace(input);
            }
        }

        if IsKeyPressed(.Delete) {
            if GetModState() & .Ctrl {
                DeleteWord(input);
            } else {
                Delete(input);
            }
        }

        if IsKeyPressed(.Left) && !(GetModState() & .Alt) {
            select := GetModState() & .Shift != 0;
            if GetModState() & .Ctrl {
                MoveCursorLeftByWord(input, select);
            } else {
                MoveCursorLeft(input, select);
            }
        }

        if IsKeyPressed(.Right) && !(GetModState() & .Alt) {
            select := GetModState() & .Shift != 0;
            if GetModState() & .Ctrl {
                MoveCursorRightByWord(input, select);
            } else {
                MoveCursorRight(input, select);
            }
        }

        if IsKeyPressed(.A) && GetModState() == .Ctrl {
            SelectAll(input);
        }

        if IsKeyPressed(.Home) && !(GetModState() & (.Ctrl | .Alt)) {
            SetCursor(input, 0, GetModState() & .Shift != 0);
        }

        if IsKeyPressed(.End) && !(GetModState() & (.Ctrl | .Alt)) {
            SetCursor(input, xx input.buffer.count, GetModState() & .Shift != 0);
        }

        if input.selection != 0 && (IsKeyPressed(.C) || IsKeyPressed(.X)) && GetModState() == .Ctrl {
            cut := IsKeyPressed(.X);

            start := min(input.cursor, input.cursor + input.selection);
            end   := max(input.cursor, input.cursor + input.selection);

            utf32 : []u32;
            utf32.data = input.buffer.data + start;
            utf32.count = end - start;

            text := EncodeStringAsUtf8(utf32 ,, temp);
            ctext := to_c_string(text ,, temp);
            SDL_SetClipboardText(ctext);

            if cut {
                Delete(input);
            }
        }

        if IsKeyPressed(.V) && GetModState() == .Ctrl && SDL_HasClipboardText() {
            SDL_free :: (ptr : *void) #foreign SDL2;

            ctext := SDL_GetClipboardText();
            defer SDL_free(ctext);
            text := to_string(ctext);

            Insert(input, MakeUtf8String(text));
        }
    }

    return input, submitted, button_result;
}

SetContentScroll :: inline (node : *Node, axis : Axis, value : float) {
    if axis == .X {
        SetContentScrollX(node, value);
    } else {
        SetContentScrollY(node, value);
    }
}

SetContentScrollX :: inline (node : *Node, value : float) {
    avail_scroll := node.layout_last_frame.size.x - node.layout_last_frame.children_size.x;
    node.scroll.x = clamp(value, avail_scroll, 0);
}

SetContentScrollY :: inline (node : *Node, value : float) {
    avail_scroll := node.layout_last_frame.size.y - node.layout_last_frame.children_size.y;
    node.scroll.y = clamp(value, avail_scroll, 0);
}

ScrollBehavior :: (node : *Node) -> Vec2f {
    node.flags |= .Scrollable;

    if context.omg.scroll_focused_node == node {
        return GetMouseWheel();
    }

    return .{};
}

ScrollViewBehavior :: (node : *Node, axis : AxisFlags) {
    ScrollViewBehavior(node, node, axis);
}

ScrollViewBehavior :: (node : *Node, target : *Node, axis : AxisFlags) {
    scroll := ScrollBehavior(node);
    if axis & .X {
        SetContentScrollX(target, target.scroll.x + scroll.x);
    }

    if axis & .Y {
        SetContentScrollY(target, target.scroll.y + scroll.y);
    }
}

SetMouseFocus :: inline (node : *Node) {
    if context.omg.mouse_focused_node {
        context.omg.mouse_focused_node.state_flags &= ~.Focused;
    }

    context.omg.mouse_focused_node = node;

    if node {
        node.state_flags |= .Focused;
    }
}

SetScrollFocus :: inline (node : *Node) {
    context.omg.scroll_focused_node = node;
}

SetMouseCapture :: inline (node : *Node) {
    SetMouseCapture(node, .{});
}

SetMouseCapture :: inline (node : *Node, node_value : Vec2f) {
    if context.omg.mouse_capturing_node != node {
        context.omg.mouse_captured_at = GetMousePosition();
        context.omg.mouse_captured_node_value = node_value;
    }

    context.omg.mouse_capturing_node = node;
    context.omg.mouse_captured_this_frame = true;
}

ScreenToWindow :: (window : *Window, point : Vec2f) -> Vec2f {
    wx, wy : s32;
    SDL_GetWindowPosition(window.sdl_window, *wx, *wy);

    return point - Vec2f.{xx wx, xx wy};
}

WindowToScreen :: (window : *Window, point : Vec2f) -> Vec2f {
    wx, wy : s32;
    SDL_GetWindowPosition(window.sdl_window, *wx, *wy);

    return point + Vec2f.{xx wx, xx wy};
}

FindMouseFocus :: (node : *Node) {
    omg := context.omg;
    mouse := GetMousePosition(node.window);

    if node.parent && IsInsideRect(mouse, node.clipped_rect) {
        omg.mouse_is_over_node = true;
    }

    if IsInsideRect(mouse, node.clipped_rect) {
        omg.mouse_hovered_node = node;

        if !omg.mouse_capturing_node || omg.mouse_capturing_node == node {
            if node.flags & .Focusable {
                omg.mouse_focused_node = node;
            }
            if node.flags & .Scrollable {
                omg.scroll_focused_node = node;
            }
        }
    }

    for :Children node {
        FindMouseFocus(it);
    }
}
