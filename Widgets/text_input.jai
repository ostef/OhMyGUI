TextInputEdit :: struct {
    Kind :: enum u8 {
        Insert;
        Delete;
        BatchBegin;
        BatchEnd;
    }

    cursor : s32;
    edit_buffer_offset : s32;
    length : s32;
    kind : Kind;
}

TextInputData :: struct {
    buffer : [..]u32;
    selection : s32;
    cursor : s32;
    cursor_blink_time : float;

    edit_history : [..]TextInputEdit;
    edit_buffer : [..]u32;
    edit_history_cursor := -1;
}

DestroyTextInputData :: (node : *Node, data : *void) {
    using _ := cast(*TextInputData, data);
    array_free(buffer);
    array_free(edit_buffer);
    array_free(edit_history);
}

ClearTextInputData :: (data : *TextInputData) {
    data.selection = 0;
    data.cursor = 0;
    array_reset_keeping_memory(*data.edit_history);
    array_reset_keeping_memory(*data.edit_buffer);
    data.edit_history_cursor = -1;

    array_reset_keeping_memory(*data.buffer);
}

SetTextInputResult :: (node : *Node, str : string) {
    data := GetUserData(node, TextInputData);
    if !data {
        return;
    }

    ClearTextInputData(data);

    for MakeUtf8String(str) {
        array_add(*data.buffer, it);
    }
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

PushEdit :: (input : *TextInputData, kind : TextInputEdit.Kind, cursor : s32, length : s32) -> *TextInputEdit {
    while input.edit_history.count > 0 && input.edit_history.count > input.edit_history_cursor {
        PopEdit(input);
    }

    edit := array_add(*input.edit_history);
    edit.kind = kind;
    edit.edit_buffer_offset = xx input.edit_buffer.count;
    edit.length = length;
    edit.cursor = cursor;

    input.edit_history_cursor = input.edit_history.count;

    return edit;
}

PushEdit :: (input : *TextInputData, kind : TextInputEdit.Kind) -> *TextInputEdit {
    return PushEdit(input, kind, 0, 0);
}

PushEdit :: (input : *TextInputData, kind : TextInputEdit.Kind, cursor : s32, text : $T) -> *TextInputEdit {
    edit := PushEdit(input, kind, cursor, xx text.count);
    for text {
        array_add(*input.edit_buffer, it);
    }

    // #if T == Utf8String {
    //     print("Edit % at %: '%'\n", kind, cursor, text.as_string);
    // } else #if T == []u32 || T == [..]u32 {
    //     print("Edit % at %: '%'\n", kind, cursor, EncodeStringAsUtf8(text ,, temp));
    // }

    return edit;
}

PopEdit :: (input : *TextInputData) {
    edit := *input.edit_history[input.edit_history.count - 1];
    input.edit_buffer.count = max(edit.edit_buffer_offset, 0);

    pop(*input.edit_history);

    input.edit_history_cursor = min(input.edit_history_cursor, input.edit_history.count);
}

GetEditText :: (input : *TextInputData, edit : TextInputEdit) -> []u32 {
    text : []u32;
    text.data = input.edit_buffer.data + clamp(edit.edit_buffer_offset, 0, xx input.edit_buffer.count);
    text.count = min(input.edit_buffer.count - edit.edit_buffer_offset, xx edit.length);

    return text;
}

Undo :: (input : *TextInputData) -> bool {
    if input.edit_history_cursor <= 0 || input.edit_history_cursor > input.edit_history.count {
        return false;
    }

    input.edit_history_cursor -= 1;
    edit := input.edit_history[input.edit_history_cursor];

    if #complete edit.kind == {
    case .Insert;
        SetCursor(input, edit.cursor);

        for i : 0..edit.length - 1 {
            if !Delete(input, push_edit=false) {
                break;
            }
        }

    case .Delete;
        SetCursor(input, edit.cursor);
        Insert(input, GetEditText(input, edit), push_edit=false);

    case .BatchEnd;
        while input.edit_history_cursor > 0 {
            edit := input.edit_history[input.edit_history_cursor - 1];

            Undo(input);

            if edit.kind == .BatchBegin {
                break;
            }
        }

    case .BatchBegin;
    }

    return true;
}

Redo :: (input : *TextInputData) -> bool {
    if input.edit_history_cursor < 0 || input.edit_history_cursor >= input.edit_history.count {
        return false;
    }

    edit := input.edit_history[input.edit_history_cursor];
    input.edit_history_cursor += 1;

    if #complete edit.kind == {
    case .Insert;
        SetCursor(input, edit.cursor);
        Insert(input, GetEditText(input, edit), push_edit=false);

    case .Delete;
        SetCursor(input, edit.cursor);

        for i : 0..edit.length - 1 {
            if !Delete(input, push_edit=false) {
                break;
            }
        }

    case .BatchBegin;
        while input.edit_history_cursor < input.edit_history.count {
            edit := input.edit_history[input.edit_history_cursor];

            Redo(input);

            if edit.kind == .BatchEnd {
                break;
            }
        }

    case .BatchEnd;
    }

    return true;
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

Insert :: (input : *TextInputData, str : $T, push_edit := true) {
    input.cursor_blink_time = 0;

    pushed_batch := false;
    if input.selection != 0 {
        if push_edit {
            PushEdit(input, .BatchBegin);
            pushed_batch = true;
        }

        Delete(input, push_edit);
    }

    cursor := input.cursor;

    for str {
        if it == #char "\n" {
            array_insert_at(*input.buffer, #char " ", input.cursor);
        } else {
            array_insert_at(*input.buffer, it, input.cursor);
        }
        input.cursor += 1;
    }

    if push_edit {
        PushEdit(input, .Insert, cursor, str);

        if pushed_batch {
            PushEdit(input, .BatchEnd);
        }
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

Delete :: (input : *TextInputData, push_edit := true) -> bool {
    if input.selection != 0 {
        if push_edit {
            start := min(input.cursor, input.cursor + input.selection);
            end := max(input.cursor, input.cursor + input.selection);
            text : []u32 = .{data=input.buffer.data + start, count=end - start};
            PushEdit(input, .Delete, start, text);
        }

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

    if push_edit {
        PushEdit(input, .Delete, input.cursor, ([]u32).{count=1, data=input.buffer.data + input.cursor});
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

        if IsKeyPressed(.Z) && GetModState() == .Ctrl {
            Undo(input);
        }
        if IsKeyPressed(.Z) && GetModState() == (.Shift | .Ctrl) {
            Redo(input);
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

TextInputStateStyle :: struct {
    background : BoxStyle;
    text : TextStyle;
    cursor : *Cursor;
}

TextInputStyle :: struct {
    using _ : StateStyle(TextInputStateStyle);
    cursor : BoxStyle;
    selection : BoxStyle;
    password_codepoint : u32 = #char "*";
}

SetColors :: (using style : *TextInputStyle, base_background_color : RGBA8, accent_color : RGBA8) {
    text_color := ChooseTextColor(base_background_color);
    normal.text.text_color = text_color;
    focused.text.text_color = text_color;
    hot.text.text_color = text_color;
    active.text.text_color = text_color;

    cursor.background_color = text_color;
    selection.background_color = accent_color;

    normal.background.background_color = base_background_color;
    focused.background.background_color = Whiten(base_background_color, 0.05);
    hot.background.background_color = Darken(base_background_color, 0.05);
    active.background.background_color = Whiten(base_background_color, 0.1);

    active.background.border_size = 2;
    active.background.border_color = accent_color;
}

DrawTextInputText :: (draw_list : *DrawList, node : *Node) {
    if !node.font || (node.text_color & 0xff) == 0 {
        return;
    }

    input := GetUserData(node.parent, TextInputData);
    if !input {
        DrawText(
            draw_list,
            node.font,
            node.rect.xy,
            node.text_size,
            node.text,
            node.text_color,
            node.outer_shadow_color,
            node.outer_shadow_offset,
            node.outer_shadow_blur
        );

        return;
    }

    sdf_range := node.font.sdf_range * node.text_size;

    selection_box_index := ifx node.parent.state_flags & .Active && input.selection != 0
        then DrawBox(draw_list, .{size=.{FLOAT32_INFINITY, FLOAT32_INFINITY}, background_color=0xffffffff})
        else -1;

    selection_position := node.rect.xy;
    cursor_position := node.rect.xy;
    iter := IterText(node);
    for iter {
        glyph_position := node.rect.xy + iter.pen + it.hori_bearing * iter.font_size;
        glyph_position += it.size * iter.font_size * 0.5;

        bounds := Vec4f.{
            xy=glyph_position - it.texture_size * iter.font_size * 0.5,
            zw=glyph_position + it.texture_size * iter.font_size * 0.5,
        };

        DrawGlyph(draw_list, .{
                bounds=bounds,
                uv_bounds=it.uv_rect,
                sdf_range=.{sdf_range, -sdf_range},
                color=node.text_color,
                outer_shadow_color=node.outer_shadow_color,
                outer_shadow_offset=node.outer_shadow_offset,
                outer_shadow_blur=node.outer_shadow_blur,
            },
            node.font.texture
        );

        if it_index == input.cursor {
            cursor_position += Vec2f.{iter.pen.x, iter.pen.y - iter.font.ascent * iter.font_size};
        }
        if it_index == input.cursor + input.selection {
            selection_position += Vec2f.{iter.pen.x, iter.pen.y - iter.font.ascent * iter.font_size};
        }
    }

    if input.cursor == input.buffer.count {
        cursor_position += Vec2f.{iter.pen.x, iter.pen.y - iter.font.ascent * iter.font_size};
    }
    if input.cursor + input.selection == input.buffer.count {
        selection_position += Vec2f.{iter.pen.x, iter.pen.y - iter.font.ascent * iter.font_size};
    }

    cursor_position.x = ceil(cursor_position.x);
    cursor_position.y = ceil(cursor_position.y);

    // Draw cursor
    if node.parent.state_flags & .Active && (fmod_cycling(input.cursor_blink_time, 1) < 0.5 || input.cursor_blink_time > 5) {
        cursor_size := Vec2f.{1, node.rect.w - node.rect.y};

        DrawBox(draw_list, .{
            size=cursor_size,
            position=cursor_position + cursor_size * 0.5,
            background_color=node.text_color,
        });
    }

    // Draw selection
    if selection_box_index >= 0 {
        selection_size := Vec2f.{abs(cursor_position.x - selection_position.x), node.rect.w - node.rect.y};
        selection_size.x = ceil(selection_size.x);
        selection_size.y = ceil(selection_size.y);

        selection_position = min(cursor_position, selection_position);
        selection_position.x = floor(selection_position.x);
        selection_position.y = floor(selection_position.y);

        box := *draw_list.boxes[selection_box_index];
        box.size = selection_size;
        box.position = selection_position + selection_size * 0.5;
        box.background_color = ColorU32(0.1, 0.2, 0.6, 0.5);
    }
}

TextInputFlags :: enum_flags {
    Password;
}

ParseIntInput :: (str : string, $T : Type) -> bool, T {
    _s := str;
    base := 10;
    if begins_with(_s, "0x") {
        advance(*_s, 2);
        base = 16;
    }

    value, ok, remainder := string_to_int(_s, base, T);

    return ok && remainder.count == 0, value;
}

FloatInput :: (
    parent : *Node,
    value : *$T/.[float32, float64],
    min : T, max : T,
    trailing_digits := 3,
    style : *TextInputStyle = null,
    location := #caller_location
) -> submitted : bool, *Node {
    user : struct {
        trailing_digits : int;
    } = .{trailing_digits};

    FromString :: (str : string, user_data : *void) -> bool, T {
        using _ := cast(*type_of(user), user_data);

        v, ok, remainder := string_to_float64(str);
        return ok && remainder.count == 0, xx v;
    }

    ToString :: (value : T, user_data : *void) -> string {
        using _ := cast(*type_of(user), user_data);
        return trim(tprint("%", FormatFloat.{value=value, trailing_width=trailing_digits}));
    }

    submitted, node := NumberInput(parent, value, min, max, *user, FromString, ToString, style=style, location=location);

    return submitted, node;
}

IntInput :: (
    parent : *Node,
    value : *$T/.[u8,s8,u16,s16,u32,s32,u64,s64],
    min : T, max : T,
    base := 10,
    min_digits := 1,
    style : *TextInputStyle = null,
    location := #caller_location
) -> submitted : bool, *Node {
    user : struct {
        base : int;
        min_digits : int;
    } = .{base, min_digits};

    FromString :: (str : string, user_data : *void) -> bool, T {
        using _ := cast(*type_of(user), user_data);

        v, ok, remainder := string_to_int(str, base=base, T=T);
        return ok && remainder.count == 0, v;
    }

    ToString :: (value : T, user_data : *void) -> string {
        using _ := cast(*type_of(user), user_data);
        return tprint("%", FormatInt.{value=value, base=base, minimum_digits=min_digits});
    }

    submitted, node := NumberInput(parent, value, min, max, *user, FromString, ToString, style=style, location=location);

    return submitted, node;
}

NumberInput :: (
    parent : *Node,
    value : *$T/.[u8,s8,u16,s16,u32,s32,u64,s64,float32,float64],
    min : T, max : T,
    user_data := null,
    from_string : (str : string, user_data := null) -> (bool, T) = null,
    to_string : (value : T, user_data := null) -> string = null,
    flags : TextInputFlags = 0,
    style : *TextInputStyle = null,
    location := #caller_location
) -> submitted : bool, *Node {
    submitted, node := TextInput(parent, flags, style, location);

    if submitted {
        str := GetTextInputResult(node);

        #if T == float32 {
            f := ifx from_string then from_string else (str : string, user_data := null) -> (bool, T) { v, ok, remainder := string_to_float(str); return ok && remainder.count == 0, v; };
            ok, result := f(str, user_data);
            if ok {
                value.* = result;
            }
        } else #if T == float64 {
            f := ifx from_string then from_string else (str : string, user_data := null) -> (bool, T) { v, ok, remainder := string_to_float64(str); return ok && remainder.count == 0, v; };
            ok, result := f(str, user_data);
            if ok {
                value.* = result;
            }
        } else {
            f := ifx from_string then from_string else (str : string, user_data := null) -> (bool, T) { v, ok, remainder := string_to_int(str, T=T); return ok && remainder.count == 0, v; };
            ok, result := f(str, user_data);
            if ok {
                value.* = result;
            }
        }
    } else if !(node.state_flags & .Active) {
        str := ifx to_string then to_string(value.*, user_data) else trim(tprint("%", value.*));
        SetTextInputResult(node, str);
    }

    if submitted {
        value.* = clamp(value.*, min, max);
    }

    return submitted, node;
}

TextInput :: (parent : *Node, flags : TextInputFlags = 0, style : *TextInputStyle = null, location := #caller_location) -> submitted : bool, *Node {
    EnsureStyle(*style, "text_input");

    input_field := GetNode(parent, location=location);
    {
        input_field.flags |= .NoPaddedClip;

        SetSize(input_field, SizeFill(), SizeFit());
        SetChildAlign(input_field, 0, 0.5);

        input, submitted, input_button := TextInputBehavior(input_field);

        text_node := GetNode(input_field, "text");
        {
            SetDraw(text_node, DrawTextInputText);

            state := GetState(input_field);
            Apply(input_field, style.states[state].background);
            Apply(text_node, style.states[state].text);

            if HasCursorControl(input_field) {
                SetCursor(style.states[state].cursor);
            }

            if flags & .Password {
                password_codepoint : u32 = style.password_codepoint;
                password_glyph := GetGlyph(text_node.font, password_codepoint);
                if !password_glyph {
                    password_codepoint = #char "*";
                }

                encoding_size := GetUtf8EncodingSize(password_codepoint);
                text := alloc_string(input.buffer.count * encoding_size ,, temp);
                byte_offset := 0;
                for i : 0..input.buffer.count - 1 {
                    size := EncodeCharacterAsUtf8(password_codepoint, xx text, byte_offset);
                    byte_offset += size;
                }

                SetText(text_node, text);
            } else {
                text := EncodeStringAsUtf8(input.buffer ,, temp);
                SetText(text_node, text);
            }

            if input_field.state_flags & .Active {
                cursor_position : Vec2f;

                is_selecting := context.omg.mouse_capturing_node == input_field;
                mouse := GetMousePosition(input_field.window);

                if is_selecting && mouse.x < text_node.layout_last_frame.rect.x {
                    SetCursor(input, 0, !input_button.pressed);
                }

                iter := IterText(text_node);
                for iter {
                    glyph_rect : Vec4f;
                    glyph_rect.xy = text_node.layout_last_frame.rect.xy + iter.pen - Vec2f.{0, iter.font.ascent * iter.font_size};
                    glyph_rect.zw = glyph_rect.xy + Vec2f.{it.hori_advance, iter.font.ascent + iter.font.descent} * iter.font_size;

                    if is_selecting {
                        if mouse.x >= glyph_rect.x && mouse.x < (glyph_rect.x + glyph_rect.z) * 0.5 {
                            SetCursor(input, xx it_index, !input_button.pressed);
                        } else if mouse.x >= (glyph_rect.x + glyph_rect.z) * 0.5 && mouse.x < glyph_rect.z {
                            SetCursor(input, xx (it_index + 1), !input_button.pressed);
                        }
                    }

                    if it_index == input.cursor {
                        cursor_position = .{iter.pen.x, iter.pen.y - iter.font.ascent * iter.font_size};
                    }
                }

                if is_selecting && mouse.x >= text_node.layout_last_frame.rect.x + iter.pen.x {
                    SetCursor(input, xx input.buffer.count, !input_button.pressed);
                }

                if input.cursor == input.buffer.count {
                    cursor_position = .{iter.pen.x, iter.pen.y - iter.font.ascent * iter.font_size};
                }

                if text_node.layout_last_frame.rect.x + cursor_position.x < input_field.layout_last_frame.rect.x + input_field.padding.x {
                    input_field.scroll.x = ceil(-cursor_position.x);
                }

                if text_node.layout_last_frame.rect.x + cursor_position.x >= input_field.layout_last_frame.rect.z - input_field.padding.z {
                    input_field.scroll.x = floor(-cursor_position.x + input_field.layout_last_frame.size.x - input_field.padding.x - input_field.padding.z - 1);
                }

                input_field.scroll.x = clamp(input_field.scroll.x, -text_node.layout_last_frame.size.x, 0);
            } else if input_field.state_flags & .ActiveLastFrame {
                input_field.scroll.x = 0;
            }
        }

        return submitted, input_field;
    }
}
