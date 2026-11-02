#scope_module

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
