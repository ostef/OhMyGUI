InputContext :: struct {
    mouse_position : Vec2f;
    mouse_delta : Vec2f;
    mouse_wheel : Vec2f;

    mouse_button_states : [3]KeyState;
    key_states : []KeyState;

    text : [..]u32;
}

KeyState :: enum_flags u8 {
    Pressed;
    Repeated;
    Down;
    Released;
}

MouseButton :: enum u8 {
    Left;
    Middle;
    Right;
}

MouseButtonFlags :: enum_flags u8 {
    Left;
    Middle;
    Right;
}

InitInput :: (using input : *InputContext) {
    text.allocator = context.allocator;
    key_states = NewArray(xx KeyCode.Count, KeyState);
}

DestroyInput :: (using input : *InputContext) {
    array_free(text);
    free(*key_states.data);
    input.* = .{};
}

ResetInput :: (using input : *InputContext) {
    array_reset_keeping_memory(*text);

    mouse_wheel = .{};
    mouse_delta = .{};

    for * mouse_button_states {
        it.* &= ~(KeyState.Pressed | .Repeated | .Released);
    }

    for * key_states {
        it.* &= ~(KeyState.Pressed | .Repeated | .Released);
    }
}

InputNewFrame :: (using input : *InputContext) {
    old_mouse_pos := mouse_position;

    mx, my := PlatformGetMousePosition();
    mouse_position = .{xx mx, xx my};

    mouse_delta = mouse_position - old_mouse_pos;
}

GetMousePosition :: inline () -> Vec2f {
    return context.omg.input.mouse_position;
}

GetMousePosition :: inline (window : *Window) -> Vec2f {
    wx, wy := PlatformGetWindowPosition(window.platform_handle);

    return context.omg.input.mouse_position - Vec2f.{xx wx, xx wy};
}

GetMouseDelta :: inline () -> Vec2f {
    return context.omg.input.mouse_delta;
}

GetMouseWheel :: inline () -> Vec2f {
    return context.omg.input.mouse_wheel;
}

IsAnyMouseButtonDown :: inline () -> bool {
    return IsMouseButtonDown(.Left) || IsMouseButtonDown(.Middle) || IsMouseButtonDown(.Right);
}

IsMouseButtonDown :: inline (button : MouseButton) -> bool {
    return context.omg.input.mouse_button_states[button] & .Down != 0;
}

IsAnyMouseButtonPressed :: inline (repeated := true) -> bool {
    return IsMouseButtonPressed(.Left, repeated) || IsMouseButtonPressed(.Middle, repeated) || IsMouseButtonPressed(.Right, repeated);
}

IsMouseButtonPressed :: inline (button : MouseButton, repeated := true) -> bool {
    return context.omg.input.mouse_button_states[button] & .Pressed != 0 || (repeated && context.omg.input.mouse_button_states[button] & .Repeated != 0);
}

IsMouseButtonDoubleClicked :: inline (button : MouseButton) -> bool {
    return context.omg.input.mouse_button_states[button] & .Repeated != 0;
}

IsAnyMouseButtonReleased :: inline () -> bool {
    return IsMouseButtonReleased(.Left) || IsMouseButtonReleased(.Middle) || IsMouseButtonReleased(.Right);
}

IsMouseButtonReleased :: inline (button : MouseButton) -> bool {
    return context.omg.input.mouse_button_states[button] & .Released != 0;
}

KeyCode :: enum u8 {
    Invalid;

    Backspace;
    Tab;
    Return;
    Shift;
    Ctrl;
    Alt;
    Cmd;
    LeftShift;
    RightShift;
    LeftCtrl;
    RightCtrl;
    LeftAlt;
    RightAlt;
    LeftSuper;
    RightSuper;
    LeftCmd;
    RightCmd;
    CapsLock;
    Escape;
    Space;
    Left;
    Up;
    Right;
    Down;
    Insert;
    Delete;
    PageUp;
    PageDown;
    Home;
    End;
    Help;
    PrintScreen;
    ScrollLock;
    Pause;
    Number0;
    Number1;
    Number2;
    Number3;
    Number4;
    Number5;
    Number6;
    Number7;
    Number8;
    Number9;
    A; B; C; D; E; F; G; H; I; J; K; L; M;
    N; O; P; Q; R; S; T; U; V; W; X; Y; Z;
    F1; F2; F3; F4; F5; F6; F7; F8; F9; F10; F11; F12;

    Semicolon;

    Minus;
    Equals;
    Comma;
    Period;
    Slash;
    Backtick;

    OpenBracket;
    CloseBracket;
    Backslash;

    Quote;

    OEM8;
    OEM102;

    Count;
}

IsKeyDown :: inline (key : KeyCode) -> bool {
    if key < 0 || cast(int, key) >= context.omg.input.key_states.count {
        return false;
    }

    return context.omg.input.key_states[key] & .Down != 0;
}

IsKeyPressed :: inline (key : KeyCode, repeated := true) -> bool {
    if key < 0 || cast(int, key) >= context.omg.input.key_states.count {
        return false;
    }

    return context.omg.input.key_states[key] & .Pressed != 0 || (repeated && context.omg.input.key_states[key] & .Repeated != 0);
}

IsKeyRepeated :: inline (key : KeyCode) -> bool {
    if key < 0 || cast(int, key) >= context.omg.input.key_states.count {
        return false;
    }

    return context.omg.input.key_states[key] & .Repeated != 0;
}

IsKeyReleased :: inline (key : KeyCode) -> bool {
    if key < 0 || cast(int, key) >= context.omg.input.key_states.count {
        return false;
    }

    return context.omg.input.key_states[key] & .Released != 0;
}

ModState :: enum_flags {
    Shift;
    Ctrl;
    Alt;
}

GetModState :: inline () -> ModState {
    state : ModState;
    if IsKeyDown(.Shift) {
        state |= .Shift;
    }
    if IsKeyDown(.Ctrl) {
        state |= .Ctrl;
    }
    if IsKeyDown(.Alt) {
        state |= .Alt;
    }

    return state;
}
