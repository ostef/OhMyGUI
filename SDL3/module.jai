#import "OhMyGUI";
#import "SDL";
#import "Basic";

#if OS == .WINDOWS {

#load "windows.jai";

}

GetPlatformFuncs :: () -> PlatformFunctions {
    using funcs : PlatformFunctions;

    GetWindowTitle = (handle : PlatformWindowHandle) -> string {
        title := SDL_GetWindowTitle(handle);
        return copy_string(to_string(title));
    }

    SetWindowTitle = (handle : PlatformWindowHandle, title : string) {
        ctitle := to_c_string(title ,, temp);
        SDL_SetWindowTitle(handle, ctitle);
    }

    GetWindowPosition = (handle : PlatformWindowHandle) -> int, int {
        x, y : s32;
        SDL_GetWindowPosition(handle, *x, *y);
        return x, y;
    }

    SetWindowPosition = (handle : PlatformWindowHandle, x : int, y : int) {
        SDL_SetWindowPosition(handle, xx x, xx y);
    }

    GetWindowSize = (handle : PlatformWindowHandle) -> int, int {
        w, h : s32;
        SDL_GetWindowSize(handle, *w, *h);
        return w, h;
    }

    SetWindowSize = (handle : PlatformWindowHandle, width : int, height : int) {
        #if OS == .WINDOWS {
            if SetCustomWindowDecorationsSize(handle, xx width, xx height) {
                return;
            }
        }

        SDL_SetWindowSize(handle, xx width, xx height);
    }

    GetWindowFlags = (handle : PlatformWindowHandle) -> PlatformWindowFlags {
        flags := SDL_GetWindowFlags(handle);

        result : PlatformWindowFlags;
        if flags & .MINIMIZED {
            result |= .Minimized;
        }
        if flags & .MAXIMIZED {
            result |= .Maximized;
        }
        if flags & .MOUSE_FOCUS {
            result |= .HasMouseFocus;
        }
        if flags & .INPUT_FOCUS {
            result |= .HasInputFocus;
        }

        return result;
    }

    GetMousePosition = () -> int, int {
        mx, my : float;
        SDL_GetGlobalMouseState(*mx, *my);

        return xx mx, xx my;
    }

    CaptureMouse = (capture : bool) {
        SDL_CaptureMouse(xx capture);
    }

    SetCursor = (handle : PlatformCursorHandle) {
        SDL_SetCursor(handle);
    }

    CreateRGBA8Cursor = (pixels : *void, width : u32, height : u32, hot_x_01 : float, hot_y_01 : float) -> PlatformCursorHandle {
        surface := SDL_CreateSurfaceFrom(xx width, xx height, .ABGR8888, pixels, xx (width * 4));
        defer SDL_DestroySurface(surface);

        if !surface {
            log_error("Could not create SDL surface for cursor image");
            return null;
        }

        hot_x := cast(s32, (cast(s32, width) - 1) * hot_x_01);
        hot_y := cast(s32, (cast(s32, height) - 1) * hot_y_01);

        result := SDL_CreateColorCursor(surface, hot_x, hot_y);
        if !result {
            log_error("Could not create SDL cursor: %", to_string(SDL_GetError()));
            return null;
        }

        return result;
    }

    CreateSystemCursor = (system_cursor : SystemCursor) -> PlatformCursorHandle {
        SDL_Cursors :: SDL_SystemCursor.[
            .DEFAULT,
            .TEXT,
            .WAIT,
            .CROSSHAIR,
            .PROGRESS,
            .NWSE_RESIZE,
            .NESW_RESIZE,
            .EW_RESIZE,
            .NS_RESIZE,
            .MOVE,
            .NOT_ALLOWED,
            .POINTER,
        ];
        return xx SDL_CreateSystemCursor(SDL_Cursors[system_cursor]);
    }

    DestroyCursor = (cursor : PlatformCursorHandle) {
        SDL_DestroyCursor(xx cursor);
    }

    GetClipboardText = () -> string {
        ctext := SDL_GetClipboardText();
        defer SDL_free(ctext);

        return copy_string(to_string(ctext));
    }

    SetClipboardText = (text : string) {
        ctext := to_c_string(text ,, temp);
        SDL_SetClipboardText(ctext);
    }

    HasClipboardText = () -> bool {
        return xx SDL_HasClipboardText();
    }

    EnableCustomWindowDecorations = (window : *Window) -> bool {
        #if OS == .WINDOWS {
            return InitCustomWindowDecorations(window);
        } else {
            return false;
        }
    }

    return funcs;
}

HandleEvent :: (event : SDL_Event) {
    if event.type == xx SDL_EventType.WINDOW_CLOSE_REQUESTED {
        sdl_window := SDL_GetWindowFromID(event.window.windowID);
        window := GetWindow(sdl_window, create=false);
        if window {
            DestroyWindow(window);
        }
    }

    HandleInputEvent(event);
}

HandleInputEvent :: (event : SDL_Event) {
    omg := context.omg;

    if cast(SDL_EventType, event.type) == {
    case .KEY_DOWN;
        key_code := SDLScancodeToKeyCode(event.key.scancode);
        flag := ifx event.key.repeat then KeyState.Repeated | .Down else .Pressed | .Down;

        omg.input.key_states[key_code] |= flag;

        if key_code == .LeftShift || key_code == .RightShift {
            omg.input.key_states[KeyCode.Shift] |= flag;
        }
        if key_code == .LeftCtrl || key_code == .RightCtrl {
            omg.input.key_states[KeyCode.Ctrl] |= flag;
        }
        if key_code == .LeftAlt || key_code == .RightAlt {
            omg.input.key_states[KeyCode.Alt] |= flag;
        }

    case .KEY_UP;
        key_code := SDLScancodeToKeyCode(event.key.scancode);
        omg.input.key_states[key_code] &= ~.Down;
        omg.input.key_states[key_code] |= .Released;

        if key_code == .LeftShift || key_code == .RightShift {
            omg.input.key_states[KeyCode.Shift] &= ~.Down;
            omg.input.key_states[KeyCode.Shift] |= .Released;
        }
        if key_code == .LeftCtrl || key_code == .RightCtrl {
            omg.input.key_states[KeyCode.Ctrl] &= ~.Down;
            omg.input.key_states[KeyCode.Ctrl] |= .Released;
        }
        if key_code == .LeftAlt || key_code == .RightAlt {
            omg.input.key_states[KeyCode.Alt] &= ~.Down;
            omg.input.key_states[KeyCode.Alt] |= .Released;
        }

    case .MOUSE_BUTTON_DOWN;
        mouse_button, ok := SDLMouseButtonToMouseButton(event.button.button);
        if ok {
            if (event.button.clicks % 2) == 0 {
                omg.input.mouse_button_states[mouse_button] |= .Repeated | .Down;
            } else {
                omg.input.mouse_button_states[mouse_button] |= .Pressed | .Down;
            }
        }

    case .MOUSE_BUTTON_UP;
        mouse_button, ok := SDLMouseButtonToMouseButton(event.button.button);
        if ok {
            omg.input.mouse_button_states[mouse_button] &= ~.Down;
            omg.input.mouse_button_states[mouse_button] |= .Released;
        }

    case .MOUSE_WHEEL;
        if event.wheel.direction == .FLIPPED {
            omg.input.mouse_wheel.x -= event.wheel.x * context.omg.mouse_wheel_multiplier;
            omg.input.mouse_wheel.y -= event.wheel.y * context.omg.mouse_wheel_multiplier;
        } else {
            omg.input.mouse_wheel.x += event.wheel.x * context.omg.mouse_wheel_multiplier;
            omg.input.mouse_wheel.y += event.wheel.y * context.omg.mouse_wheel_multiplier;
        }

    case .TEXT_INPUT;
        text := to_string(event.text.text);

        offset := 0;
        while offset < text.count {
            codepoint, size := DecodeUtf8Character(xx text, offset);
            array_add(*omg.input.text, codepoint);
            offset += size;
        }
    }
}

SDLMouseButtonToMouseButton :: (button : u8) -> MouseButton, bool {
    if button == {
    case 1; return .Left, true;
    case 2; return .Middle, true;
    case 3; return .Right, true;
    case 4; return .Extra1, true;
    case 5; return .Extra2, true;
    }

    return .Left, false;
}

SDLScancodeToKeyCode :: (scancode : SDL_Scancode) -> KeyCode {
    if scancode == {
    case .UNKNOWN; return .Invalid;
    case .A; return .A;
    case .B; return .B;
    case .C; return .C;
    case .D; return .D;
    case .E; return .E;
    case .F; return .F;
    case .G; return .G;
    case .H; return .H;
    case .I; return .I;
    case .J; return .J;
    case .K; return .K;
    case .L; return .L;
    case .M; return .M;
    case .N; return .N;
    case .O; return .O;
    case .P; return .P;
    case .Q; return .Q;
    case .R; return .R;
    case .S; return .S;
    case .T; return .T;
    case .U; return .U;
    case .V; return .V;
    case .W; return .W;
    case .X; return .X;
    case .Y; return .Y;
    case .Z; return .Z;
    case ._1; return .Number1;
    case ._2; return .Number2;
    case ._3; return .Number3;
    case ._4; return .Number4;
    case ._5; return .Number5;
    case ._6; return .Number6;
    case ._7; return .Number7;
    case ._8; return .Number8;
    case ._9; return .Number9;
    case ._0; return .Number0;
    case .RETURN; return .Return;
    case .ESCAPE; return .Escape;
    case .BACKSPACE; return .Backspace;
    case .TAB; return .Tab;
    case .SPACE; return .Space;
    case .MINUS; return .Minus;
    case .EQUALS; return .Equals;
    case .LEFTBRACKET; return .OpenBracket;
    case .RIGHTBRACKET; return .CloseBracket;
    case .BACKSLASH; return .Backslash;
    case .SEMICOLON; return .Semicolon;
    case .APOSTROPHE; return .Quote;
    case .GRAVE; return .Backtick;
    case .COMMA; return .Comma;
    case .PERIOD; return .Period;
    case .SLASH; return .Slash;
    case .CAPSLOCK; return .CapsLock;
    case .F1; return .F1;
    case .F2; return .F2;
    case .F3; return .F3;
    case .F4; return .F4;
    case .F5; return .F5;
    case .F6; return .F6;
    case .F7; return .F7;
    case .F8; return .F8;
    case .F9; return .F9;
    case .F10; return .F10;
    case .F11; return .F11;
    case .F12; return .F12;
    case .PRINTSCREEN; return .PrintScreen;
    case .SCROLLLOCK; return .ScrollLock;
    case .PAUSE; return .Pause;
    case .INSERT; return .Insert;
    case .HOME; return .Home;
    case .PAGEUP; return .PageUp;
    case .DELETE; return .Delete;
    case .END; return .End;
    case .PAGEDOWN; return .PageDown;
    case .RIGHT; return .Right;
    case .LEFT; return .Left;
    case .DOWN; return .Down;
    case .UP; return .Up;
    case .LCTRL; return .LeftCtrl;
    case .LSHIFT; return .LeftShift;
    case .LALT; return .LeftAlt;
    case .LGUI; return .LeftSuper;
    case .RCTRL; return .RightCtrl;
    case .RSHIFT; return .RightShift;
    case .RALT; return .RightAlt;
    case .RGUI; return .RightSuper;
    case .HELP; return .Help;
    }

    return .Invalid;
}
