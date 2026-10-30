#import "OhMyGUI";
#import "SDL";
#import "Basic";

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
        mouse_button, ok := SDLMouseButtonToMouseButton(event.button.button);
        if ok {
            if (event.button.clicks % 2) == 0 {
                omg.input.mouse_button_states[mouse_button] |= .Repeated | .Down;
            } else {
                omg.input.mouse_button_states[mouse_button] |= .Pressed | .Down;
            }
        }

    case SDL_MOUSEBUTTONUP;
        mouse_button, ok := SDLMouseButtonToMouseButton(event.button.button);
        if ok {
            omg.input.mouse_button_states[mouse_button] &= ~.Down;
            omg.input.mouse_button_states[mouse_button] |= .Released;
        }

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

SDLMouseButtonToMouseButton :: (button : u8) -> MouseButton, bool {
    if button == {
    case SDL_BUTTON_LEFT; return .Left, true;
    case SDL_BUTTON_MIDDLE; return .Middle, true;
    case SDL_BUTTON_RIGHT; return .Right, true;
    case SDL_BUTTON_X1; return .Extra1, true;
    case SDL_BUTTON_X2; return .Extra2, true;
    }

    return .Left, false;
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

#scope_file

#if OS == .WINDOWS {

Win32 :: #import "Windows";

CustomWindowDecorations :: struct {
    window : *Window;
    hwnd: Win32.HWND;
    event_context: *#Context;
    prev_window_proc : *void;
}

WindowHitTestResult :: enum {
    Outside;
    Client;
    Caption;
    ResizeLeft;
    ResizeRight;
    ResizeTop;
    ResizeBottom;
    ResizeTopLeft;
    ResizeTopRight;
    ResizeBottomLeft;
    ResizeBottomRight;
}

g_custom_window_decorations : [..]*CustomWindowDecorations;

InitCustomWindowDecorations :: (window : *Window) -> bool {
    info : SDL_SysWMinfo;
    SDL_VERSION(*info.version);
    if !SDL_GetWindowWMInfo(window.platform_handle, *info) {
        log_error("SDL_GetWindowWMInfo failed: %", to_string(SDL_GetError()));
        return false;
    }

    client_width, client_height: s32;
    SDL_GetWindowSize(window.platform_handle, *client_width, *client_height);

    decorations := New(CustomWindowDecorations);
    decorations.window = window;
    decorations.hwnd = info.info.win.window;
    decorations.event_context = *context;
    decorations.prev_window_proc = xx Win32.SetWindowLongPtrW(decorations.hwnd, Win32.GWL_WNDPROC, xx cast(*void, CustomWindowDecorationsProc));
    SDL_SetWindowData(window, "CustomWindowDecorations", decorations);
    array_add(*g_custom_window_decorations, decorations);

    Win32.SetWindowPos(decorations.hwnd, null, 0, 0, 0, 0, Win32.SWP_FRAMECHANGED | Win32.SWP_NOMOVE | Win32.SWP_NOSIZE | Win32.SWP_NOZORDER | Win32.SWP_NOACTIVATE);

    SetCustomWindowDecorationsSize(window.platform_handle, client_width, client_height);

    return true;
}

SetCustomWindowDecorationsSize :: (window: *SDL_Window, width: s32, height: s32) -> bool {
    decorations: *CustomWindowDecorations = SDL_GetWindowData(window, "CustomWindowDecorations");
    if !decorations {
        return false;
    }

    window_rect, client_rect: Win32.RECT;
    Win32.GetWindowRect(decorations.hwnd, *window_rect);
    Win32.GetClientRect(decorations.hwnd, *client_rect);

    frame_width := (window_rect.right - window_rect.left) - client_rect.right;
    frame_height := (window_rect.bottom - window_rect.top) - client_rect.bottom;
    Win32.SetWindowPos(decorations.hwnd, null, 0, 0, width + frame_width, height + frame_height, Win32.SWP_NOMOVE | Win32.SWP_NOZORDER | Win32.SWP_NOACTIVATE);

    return true;
}

CustomWindowDecorationsProc :: (hwnd: Win32.HWND, message: u32, wparam: Win32.WPARAM, lparam: Win32.LPARAM) -> Win32.LRESULT #c_call {
    decorations: *CustomWindowDecorations;
    for g_custom_window_decorations {
        if it.hwnd == hwnd {
            decorations = it;
            break;
        }
    }

    if !decorations {
        return Win32.DefWindowProcW(hwnd, message, wparam, lparam);
    }

    push_context,defer_pop decorations.event_context.*;

    if message == {
    case Win32.WM_NCCALCSIZE;
        if wparam {
            params := cast(*NCCALCSIZE_PARAMS, lparam);
            original_top := params.rgrc[0].top;
            CallWindowProcW(xx decorations.prev_window_proc, hwnd, message, wparam, lparam);

            params.rgrc[0].top = original_top;

            // Maximized windows' top edge go outside the bounds of the screen for some reason
            // Replicate that behavior
            if IsZoomed(decorations.hwnd) {
                params.rgrc[0].top += GetMaximizedWindowTopInset(hwnd);
            }

            return 0;
        }

    case Win32.WM_NCHITTEST;
        result := CallWindowProcW(xx decorations.prev_window_proc, hwnd, message, wparam, lparam);
        if result != HTCLIENT {
            return result;
        }

        cursor := Win32.POINT.{xx cast,trunc(s16, lparam), xx cast,trunc(s16, lparam >> 16)};
        area := CustomWindowDecorationsHitTest(decorations, cursor);
        return WindowHitTestResultToWin32(area);
    }

    return CallWindowProcW(xx decorations.prev_window_proc, hwnd, message, wparam, lparam);
}

CustomWindowDecorationsHitTest :: (decorations: *CustomWindowDecorations, screen_point: Win32.POINT) -> WindowHitTestResult {
    point := screen_point;
    Win32.ScreenToClient(decorations.hwnd, *point);

    client: Win32.RECT;
    Win32.GetClientRect(decorations.hwnd, *client);
    if point.x < 0 || point.y < 0 || point.x >= client.right || point.y >= client.bottom {
        result := Win32.DefWindowProcW(decorations.hwnd, Win32.WM_NCHITTEST, 0, cast(s64, screen_point.y << 16) | (screen_point.x & 0xffff));
        return Win32ToWindowHitTestResult(result);
    }

    if !IsZoomed(decorations.hwnd) {
        dpi := GetDpiForWindow(decorations.hwnd);
        band := GetSystemMetricsForDpi(Win32.SM_CYFRAME, dpi);

        if point.y < band {
            corner := band + GetSystemMetricsForDpi(Win32.SM_CXPADDEDBORDER, dpi);

            if point.x < corner {
                return .ResizeTopLeft;
            }
            if point.x >= client.right - corner {
                return .ResizeTopRight;
            }

            return .ResizeTop;
        }
    }

    if #complete decorations.window.hovered_area == {
    case .None; return .Client;
    case .Draggable; return .Caption;
    }

    return .Client;
}

WindowHitTestResultToWin32 :: (area: WindowHitTestResult) -> Win32.LRESULT {
    if #complete area == {
    case .Outside;           return HTNOWHERE;
    case .Client;            return HTCLIENT;
    case .Caption;           return HTCAPTION;
    case .ResizeLeft;        return HTLEFT;
    case .ResizeRight;       return HTRIGHT;
    case .ResizeTop;         return HTTOP;
    case .ResizeBottom;      return HTBOTTOM;
    case .ResizeTopLeft;     return HTTOPLEFT;
    case .ResizeTopRight;    return HTTOPRIGHT;
    case .ResizeBottomLeft;  return HTBOTTOMLEFT;
    case .ResizeBottomRight; return HTBOTTOMRIGHT;
    }

    return HTNOWHERE;
}

Win32ToWindowHitTestResult :: (result: Win32.LRESULT) -> WindowHitTestResult {
    if result == {
    case HTCLIENT;      return .Client;
    case HTCAPTION;     return .Caption;
    case HTLEFT;        return .ResizeLeft;
    case HTRIGHT;       return .ResizeRight;
    case HTTOP;         return .ResizeTop;
    case HTBOTTOM;      return .ResizeBottom;
    case HTTOPLEFT;     return .ResizeTopLeft;
    case HTTOPRIGHT;    return .ResizeTopRight;
    case HTBOTTOMLEFT;  return .ResizeBottomLeft;
    case HTBOTTOMRIGHT; return .ResizeBottomRight;
    }

    return .Outside;
}

GetMaximizedWindowTopInset :: (hwnd: Win32.HWND) -> s32 {
    dpi := GetDpiForWindow(hwnd);
    return GetSystemMetricsForDpi(Win32.SM_CYFRAME, dpi) + GetSystemMetricsForDpi(Win32.SM_CXPADDEDBORDER, dpi);
}

user32_dll :: #library,system "user32";

CallWindowProcW        :: (previous: *void, hwnd: Win32.HWND, message: u32, wparam: Win32.WPARAM, lparam: Win32.LPARAM) -> Win32.LRESULT #foreign user32_dll;
IsZoomed               :: (hwnd: Win32.HWND) -> Win32.BOOL #foreign user32_dll;
GetDpiForWindow        :: (hwnd: Win32.HWND) -> u32 #foreign user32_dll;
GetSystemMetricsForDpi :: (index: s32, dpi: u32) -> s32 #foreign user32_dll;

NCCALCSIZE_PARAMS :: struct {
    rgrc:  [3]Win32.RECT;
    lppos: *WINDOWPOS;
}

WINDOWPOS :: struct {
    hwnd:            Win32.HWND;
    hwndInsertAfter: Win32.HWND;
    x, y:            s32;
    cx, cy:          s32;
    flags:           u32;
}

HTNOWHERE     :: 0;
HTCLIENT      :: 1;
HTCAPTION     :: 2;
HTLEFT        :: 10;
HTRIGHT       :: 11;
HTTOP         :: 12;
HTTOPLEFT     :: 13;
HTTOPRIGHT    :: 14;
HTBOTTOM      :: 15;
HTBOTTOMLEFT  :: 16;
HTBOTTOMRIGHT :: 17;

}
