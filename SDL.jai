#import "OhMyGUI";
#import "SDL";
#import "Basic";

Init :: () {
    using _ := *context.omg.platform_funcs;

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
        SDL_SetWindowSize(handle, xx width, xx height);
    }

    GetWindowFlags = (handle : PlatformWindowHandle) -> PlatformWindowFlags {
        flags := SDL_GetWindowFlags(handle);

        result : PlatformWindowFlags;
        if flags & SDL_WINDOW_MINIMIZED {
            result |= .Minimized;
        }
        if flags & SDL_WINDOW_MAXIMIZED {
            result |= .Maximized;
        }
        if flags & SDL_WINDOW_MOUSE_FOCUS {
            result |= .HasMouseFocus;
        }
        if flags & SDL_WINDOW_INPUT_FOCUS {
            result |= .HasInputFocus;
        }

        return result;
    }

    GetMousePosition = () -> int, int {
        mx, my : s32;
        SDL_GetGlobalMouseState(*mx, *my);
        return mx, my;
    }

    CaptureMouse = (capture : bool) {
        SDL_CaptureMouse(xx capture);
    }

    SetCursor = (handle : PlatformCursorHandle) {
        SDL_SetCursor(handle);
    }

    CreateRGBA8Cursor = (pixels : *void, width : u32, height : u32, hot_x_01 : float, hot_y_01 : float) -> PlatformCursorHandle {
        SDL_PIXELFORMAT_RGBA8888 :: 0x16462004;
        SDL_PIXELFORMAT_ABGR8888 :: 0x16762004;

        surface := SDL_CreateRGBSurfaceWithFormatFrom(pixels, width, height, 4, width * 4, SDL_PIXELFORMAT_ABGR8888);
        defer SDL_FreeSurface(surface);

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
            ARROW,
            IBEAM,
            WAIT,
            CROSSHAIR,
            WAITARROW,
            SIZENWSE,
            SIZENESW,
            SIZEWE,
            SIZENS,
            SIZEALL,
            NO,
            HAND,
        ];
        return xx SDL_CreateSystemCursor(SDL_Cursors[system_cursor]);
    }

    DestroyCursor = (cursor : PlatformCursorHandle) {
        SDL_FreeCursor(xx cursor);
    }

    GetClipboardText = () -> string {
        SDL_free :: (ptr : *void) #foreign SDL2;

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

    InitSystemCursors();
}

HandleEvent :: (event : SDL_Event) {
    if event.type == SDL_WINDOWEVENT {
        if event.window.event == SDL_WINDOWEVENT_CLOSE {
            sdl_window := SDL_GetWindowFromID(event.window.windowID);
            window := GetWindow(sdl_window, create=false);
            if window {
                DestroyWindow(window);
            }
        }
    }

    HandleInputEvent(event);
}

HandleInputEvent :: (event : SDL_Event) {
    omg := context.omg;

    if event.type == {
    case SDL_KEYDOWN;
        key_code := SDLScancodeToKeyCode(event.key.keysym.scancode);
        flag := ifx event.key.repeat > 0 then KeyState.Repeated | .Down else .Pressed | .Down;

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

    case SDL_KEYUP;
        key_code := SDLScancodeToKeyCode(event.key.keysym.scancode);
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

    case SDL_MOUSEBUTTONDOWN;
        mouse_button := SDLMouseButtonToMouseButton(event.button.button);
        if event.button.clicks > 1 {
            omg.input.mouse_button_states[mouse_button] |= .Repeated | .Down;
        } else {
            omg.input.mouse_button_states[mouse_button] |= .Pressed | .Down;
        }

    case SDL_MOUSEBUTTONUP;
        mouse_button := SDLMouseButtonToMouseButton(event.button.button);
        omg.input.mouse_button_states[mouse_button] &= ~.Down;
        omg.input.mouse_button_states[mouse_button] |= .Released;

    case SDL_MOUSEWHEEL;
        if event.wheel.direction == xx SDL_MouseWheelDirection.SDL_MOUSEWHEEL_FLIPPED {
            omg.input.mouse_wheel.x -= event.wheel.x * context.omg.mouse_wheel_multiplier;
            omg.input.mouse_wheel.y -= event.wheel.y * context.omg.mouse_wheel_multiplier;
        } else {
            omg.input.mouse_wheel.x += event.wheel.x * context.omg.mouse_wheel_multiplier;
            omg.input.mouse_wheel.y += event.wheel.y * context.omg.mouse_wheel_multiplier;
        }

    case SDL_TEXTINPUT;
        text := to_string(cast(*u8, event.text.text.data));

        offset := 0;
        while offset < text.count {
            codepoint, size := DecodeUtf8Character(xx text, offset);
            array_add(*omg.input.text, codepoint);
            offset += size;
        }
    }
}

SDLMouseButtonToMouseButton :: (button : u8) -> MouseButton {
    if button == {
    case SDL_BUTTON_LEFT; return .Left;
    case SDL_BUTTON_MIDDLE; return .Middle;
    case SDL_BUTTON_RIGHT; return .Right;
    }

    return .Left;
}

SDLScancodeToKeyCode :: (scancode : SDL_Scancode) -> KeyCode {
    if scancode == {
    case .SDL_SCANCODE_UNKNOWN; return .Invalid;
    case .SDL_SCANCODE_A; return .A;
    case .SDL_SCANCODE_B; return .B;
    case .SDL_SCANCODE_C; return .C;
    case .SDL_SCANCODE_D; return .D;
    case .SDL_SCANCODE_E; return .E;
    case .SDL_SCANCODE_F; return .F;
    case .SDL_SCANCODE_G; return .G;
    case .SDL_SCANCODE_H; return .H;
    case .SDL_SCANCODE_I; return .I;
    case .SDL_SCANCODE_J; return .J;
    case .SDL_SCANCODE_K; return .K;
    case .SDL_SCANCODE_L; return .L;
    case .SDL_SCANCODE_M; return .M;
    case .SDL_SCANCODE_N; return .N;
    case .SDL_SCANCODE_O; return .O;
    case .SDL_SCANCODE_P; return .P;
    case .SDL_SCANCODE_Q; return .Q;
    case .SDL_SCANCODE_R; return .R;
    case .SDL_SCANCODE_S; return .S;
    case .SDL_SCANCODE_T; return .T;
    case .SDL_SCANCODE_U; return .U;
    case .SDL_SCANCODE_V; return .V;
    case .SDL_SCANCODE_W; return .W;
    case .SDL_SCANCODE_X; return .X;
    case .SDL_SCANCODE_Y; return .Y;
    case .SDL_SCANCODE_Z; return .Z;
    case .SDL_SCANCODE_1; return .Number1;
    case .SDL_SCANCODE_2; return .Number2;
    case .SDL_SCANCODE_3; return .Number3;
    case .SDL_SCANCODE_4; return .Number4;
    case .SDL_SCANCODE_5; return .Number5;
    case .SDL_SCANCODE_6; return .Number6;
    case .SDL_SCANCODE_7; return .Number7;
    case .SDL_SCANCODE_8; return .Number8;
    case .SDL_SCANCODE_9; return .Number9;
    case .SDL_SCANCODE_0; return .Number0;
    case .SDL_SCANCODE_RETURN; return .Return;
    case .SDL_SCANCODE_ESCAPE; return .Escape;
    case .SDL_SCANCODE_BACKSPACE; return .Backspace;
    case .SDL_SCANCODE_TAB; return .Tab;
    case .SDL_SCANCODE_SPACE; return .Space;
    case .SDL_SCANCODE_MINUS; return .Minus;
    case .SDL_SCANCODE_EQUALS; return .Equals;
    case .SDL_SCANCODE_LEFTBRACKET; return .OpenBracket;
    case .SDL_SCANCODE_RIGHTBRACKET; return .CloseBracket;
    case .SDL_SCANCODE_BACKSLASH; return .Backslash;
    case .SDL_SCANCODE_SEMICOLON; return .Semicolon;
    case .SDL_SCANCODE_APOSTROPHE; return .Quote;
    case .SDL_SCANCODE_GRAVE; return .Backtick;
    case .SDL_SCANCODE_COMMA; return .Comma;
    case .SDL_SCANCODE_PERIOD; return .Period;
    case .SDL_SCANCODE_SLASH; return .Slash;
    case .SDL_SCANCODE_CAPSLOCK; return .CapsLock;
    case .SDL_SCANCODE_F1; return .F1;
    case .SDL_SCANCODE_F2; return .F2;
    case .SDL_SCANCODE_F3; return .F3;
    case .SDL_SCANCODE_F4; return .F4;
    case .SDL_SCANCODE_F5; return .F5;
    case .SDL_SCANCODE_F6; return .F6;
    case .SDL_SCANCODE_F7; return .F7;
    case .SDL_SCANCODE_F8; return .F8;
    case .SDL_SCANCODE_F9; return .F9;
    case .SDL_SCANCODE_F10; return .F10;
    case .SDL_SCANCODE_F11; return .F11;
    case .SDL_SCANCODE_F12; return .F12;
    case .SDL_SCANCODE_PRINTSCREEN; return .PrintScreen;
    case .SDL_SCANCODE_SCROLLLOCK; return .ScrollLock;
    case .SDL_SCANCODE_PAUSE; return .Pause;
    case .SDL_SCANCODE_INSERT; return .Insert;
    case .SDL_SCANCODE_HOME; return .Home;
    case .SDL_SCANCODE_PAGEUP; return .PageUp;
    case .SDL_SCANCODE_DELETE; return .Delete;
    case .SDL_SCANCODE_END; return .End;
    case .SDL_SCANCODE_PAGEDOWN; return .PageDown;
    case .SDL_SCANCODE_RIGHT; return .Right;
    case .SDL_SCANCODE_LEFT; return .Left;
    case .SDL_SCANCODE_DOWN; return .Down;
    case .SDL_SCANCODE_UP; return .Up;
    case .SDL_SCANCODE_LCTRL; return .LeftCtrl;
    case .SDL_SCANCODE_LSHIFT; return .LeftShift;
    case .SDL_SCANCODE_LALT; return .LeftAlt;
    case .SDL_SCANCODE_LGUI; return .LeftSuper;
    case .SDL_SCANCODE_RCTRL; return .RightCtrl;
    case .SDL_SCANCODE_RSHIFT; return .RightShift;
    case .SDL_SCANCODE_RALT; return .RightAlt;
    case .SDL_SCANCODE_RGUI; return .RightSuper;
    case .SDL_SCANCODE_HELP; return .Help;
    }

    return .Invalid;
}
