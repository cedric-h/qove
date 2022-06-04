const std = @import("std");
const windows = std.os.windows;

const usr = windows.user32;

pub fn panic(_: []const u8, _: ?*const std.builtin.StackTrace) noreturn {
    std.os.exit(0);
}

export fn winproc(
    hwnd: windows.HWND,
    msg: windows.UINT,
    wParam: windows.WPARAM,
    lParam: windows.LPARAM,
) callconv(windows.WINAPI) windows.LRESULT {
    switch (msg) {
        usr.WM_DESTROY => {
            usr.PostQuitMessage(0);
            return 0;
        },
        else => {},
    }
    return usr.defWindowProcA(hwnd, msg, wParam, lParam); 
}

pub export fn wWinMainCRTStartup() callconv(windows.WINAPI) noreturn {
    const name = "Qove";
    const instance = @ptrCast(
        windows.HINSTANCE,
        windows.kernel32.GetModuleHandleW(null)
    );
    _ = usr.registerClassExA(&std.mem.zeroInit(usr.WNDCLASSEXA,.{
        .cbSize = @sizeOf(usr.WNDCLASSEXA),
        .lpfnWndProc = winproc,
        .hInstance = instance,
        .lpszClassName = name,
    })) catch unreachable;

    const hwnd = usr.CreateWindowExA(
        usr.WS_EX_APPWINDOW, name, name,
        usr.WS_OVERLAPPEDWINDOW,
        0, 0, 640, 480, // size
        null, null, instance, null,
    ) orelse unreachable;

    _ = usr.ShowWindow(hwnd, usr.SW_SHOWDEFAULT);

    while (true) {
        var msg: usr.MSG = undefined;
        while (usr.PeekMessageA(&msg, null, 0, 0, usr.PM_REMOVE) > 0) {
            if (msg.message == usr.WM_QUIT)
                std.os.exit(0);
            _ = usr.TranslateMessage(&msg);
            _ = usr.DispatchMessageA(&msg);
        }
        windows.kernel32.Sleep(5);
    }

    std.os.exit(0);
}
