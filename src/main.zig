const std = @import("std");
const windows = std.os.windows;
const usr = windows.user32;

const win32 = @import("win32/win32.zig");
const d3d11 = win32.graphics.direct3d11;
const dxgi = win32.graphics.dxgi;
const wind = win32.ui.windows_and_messaging;

pub fn panic(_: []const u8, _: ?*const std.builtin.StackTrace) noreturn {
    // std.debug.print("{s}\n{}\n", .{ msg, st });
    std.os.exit(0);
}

// for games, scancodes > virtual keycodes because they're 
// about a location on a keyboard, not the letter on the key
// (not QWERTY? game still worky)
const ScanCode = enum(usize) {
    W = 17,
    S = 31,
    A = 30,
    D = 32,
    Shift = 42,
    Space = 57,
    MAX,
};
var keysdown = std.mem.zeroes([@enumToInt(ScanCode.MAX)]bool);

// never do this in real software lol
// https://www.intel.com/content/www/us/en/developer/articles/technical/the-difference-between-x87-instructions-and-mathematical-functions.html
fn cos(x: f32) f32 {
    return @floatCast(f32, asm volatile ("fcos"
        : [ret] "={st}" (-> f64)
        : [x] "0" (x)
    ));
}
fn sin(x: f32) f32 {
    return @floatCast(f32, asm volatile ("fsin"
        : [ret] "={st}" (-> f64)
        : [x] "0" (x)
    ));
}

const Vec3 = struct {
    x: f32,
    y: f32,
    z: f32,

    pub fn mulf(v: Vec3, f: f32) Vec3 {
        return .{ .x = v.x * f,
                  .y = v.y * f,
                  .z = v.z * f };
    }

    pub fn sub(v: Vec3, o: Vec3) Vec3 {
        return .{ .x = v.x - o.x,
                  .y = v.y - o.y,
                  .z = v.z - o.z };
    }

    pub fn add(v: Vec3, o: Vec3) Vec3 {
        return .{ .x = v.x + o.x,
                  .y = v.y + o.y,
                  .z = v.z + o.z };
    }

    pub fn dot(v: Vec3, o: Vec3) f32 {
        return v.x * o.x +
               v.y * o.y +
               v.z * o.z;
    }

    pub fn mag(v: Vec3) f32 {
        return @sqrt(v.dot(v));
    }

    pub fn cross(v: Vec3, o: Vec3) Vec3 {
        return .{ .x = v.y * o.z - v.z * o.y,
                  .y = v.z * o.x - v.x * o.z,
                  .z = v.x * o.y - v.y * o.x };
    }
};
fn vec3(x: f32, y: f32, z: f32) Vec3 { return .{ .x = x, .y = y, .z = z }; }

const Quad = struct {
    pos: Vec3,
    norm: Vec3,
    tan: Vec3,
    size: f32,
};

const cam = struct {
    var pos = vec3(0, 0, 0);
    var look = vec3(0, 0, 1);
};
var quad: Quad = .{
    .pos = vec3(0, 0, 1),
    .norm = vec3(0, 0, -1),
    .tan = vec3(0, 1, 0),
    .size = 0.25,
};
fn colorAt(x: f32, y: f32) u32 {
    var orig = cam.pos.add(vec3(x, y, 0));
    
    // get time until plane intersection
    var d = quad.pos.dot(quad.norm.mulf(-1));
    var t = -(d + quad.norm.dot(orig)) / quad.norm.dot(cam.look);

    // didn't hit the plane
    if (t < 0) return 0;

    // where the ray hits the surface 
    var p = orig.add(cam.look.mulf(t));

    var to_p = p.sub(quad.pos);
    var u = quad.tan.dot(to_p);
    var v = quad.tan.cross(quad.norm).dot(to_p);
    u = u / quad.size + 0.5;
    v = v / quad.size + 0.5;

    var r = @floatToInt(u32, u * 256);
    var g = @floatToInt(u32, v * 256);

    if (u <= 0 or v <= 0) { r = 0; g = 0; }
    if (u >= 1 or v >= 1) { r = 0; g = 0; }

    var b = @floatToInt(u32, 0);
    return (r << 16) | (g << 8) | (b << 0);
}

fn onMouseMove(x: f32, y: f32) void {
    const rot = struct { var pitch: f32 = 0; var yaw: f32 = 0; };
    
    rot.pitch = @maximum(-1.57, @minimum(1.57, rot.pitch + y*0.01));
    // rot.yaw = @mod(rot.yaw + x*0.01, 3.14);
    rot.yaw += x*0.01;

    cam.look = .{
        .x = sin(rot.yaw) * cos(rot.pitch),
        .y = sin(rot.pitch),
        .z = cos(rot.yaw) * cos(rot.pitch),
    };
}

export fn winproc(
    hwnd: win32.everything.HWND,
    msg: windows.UINT,
    wParam: win32.everything.WPARAM,
    lParam: win32.everything.LPARAM,
) callconv(windows.WINAPI) windows.LRESULT {

    // https://docs.microsoft.com/en-us/windows/win32/inputdev/virtual-key-codes
    const VK_ESCAPE = 0x1B;

    switch (msg) {
        usr.WM_DESTROY => {
            usr.PostQuitMessage(0);
            return 0;
        },
        usr.WM_INPUT => {
            var dwSize: u32 = undefined;
            var bytes: [256]u8 = undefined;
            var dest = @ptrCast(*anyopaque, &bytes);

            const wpt = win32.ui.input;
            const size = @sizeOf(wpt.RAWINPUTHEADER);

            var raw = @intToPtr(wpt.HRAWINPUT, @intCast(usize, lParam));
            _ = wpt.GetRawInputData(raw, wpt.RID_INPUT, null, &dwSize, size);
            _ = wpt.GetRawInputData(raw, wpt.RID_INPUT, dest, &dwSize, size);

            var input = @ptrCast(         *wpt.RAWINPUT,
                      @alignCast(@alignOf(*wpt.RAWINPUT), &bytes));
            if (input.*.header.dwType == @enumToInt(wpt.RIM_TYPEMOUSE))
                onMouseMove(@intToFloat(f32, input.*.data.mouse.lLastX),
                            @intToFloat(f32, input.*.data.mouse.lLastY));
        },
        usr.WM_KEYUP, usr.WM_KEYDOWN => {
            if (wParam == VK_ESCAPE)
                usr.PostQuitMessage(0);

            const KF_EXTENDED = win32.everything.KF_EXTENDED;
            const WM_KEYDOWN = win32.everything.WM_KEYDOWN;

            const hiword = @intCast(usize, lParam) >> 16 & 0xFFFF;
            var scancode = hiword & (KF_EXTENDED | 0xFF);
            if (scancode < keysdown.len) {
                keysdown[scancode] = msg == WM_KEYDOWN;
            }
            return 0;
        },
        else => {},
    }
    return wind.DefWindowProcA(hwnd, msg, wParam, lParam); 
}

pub export fn wWinMainCRTStartup() callconv(windows.WINAPI) noreturn {
    const name = "Qove";
    const instance = @ptrCast(
        win32.foundation.HINSTANCE,
        windows.kernel32.GetModuleHandleW(null)
    );
    _ = wind.RegisterClassExA(&std.mem.zeroInit(wind.WNDCLASSEXA,.{
        .cbSize = @sizeOf(wind.WNDCLASSEXA),
        .lpfnWndProc = winproc,
        .hInstance = instance,
        .lpszClassName = name,
    }));

    const default = win32.everything.CW_USEDEFAULT;
    const hwnd = wind.CreateWindowExA(
        .APPWINDOW, name, name,
        win32.everything.WS_OVERLAPPEDWINDOW,
        default, default, 500, 500,
        null, null, instance, null,
    );

    { // so we can get raw mouse input
        const wpt = win32.ui.input;
        var device = std.mem.zeroes(wpt.RAWINPUTDEVICE);
        device.usUsagePage = win32.everything.HID_USAGE_PAGE_GENERIC;
        device.usUsage = win32.everything.HID_USAGE_GENERIC_MOUSE;
        device.hwndTarget = hwnd;
        _ = wpt.RegisterRawInputDevices(
            @ptrCast([*]wpt.RAWINPUTDEVICE, &device),
            1,
            @sizeOf(wpt.RAWINPUTDEVICE)
        );
    }

    _ = wind.ShowWindow(hwnd, .SHOWDEFAULT);


    var device      : ?*d3d11.ID3D11Device        = undefined;
    var context     : ?*d3d11.ID3D11DeviceContext = undefined;
    var swap_chain  : ?*dxgi.IDXGISwapChain       = undefined;
    var back_buffer : ?*d3d11.ID3D11Texture2D     = null;
    var cpu_buffer  : ?*d3d11.ID3D11Texture2D     = null;

    var rect : win32.foundation.RECT = undefined;
    _ = wind.GetClientRect(hwnd, &rect);

    var width = @intCast(u32, rect.right);
    var height = @intCast(u32, rect.bottom);

    var desc = std.mem.zeroes(dxgi.DXGI_SWAP_CHAIN_DESC);
    desc.BufferDesc = .{
        .Width = @intCast(u32, width),
        .Height = @intCast(u32, height),
        .RefreshRate = .{ .Numerator = 60, .Denominator = 1 },
        .Format = .B8G8R8A8_UNORM,
        .ScanlineOrdering = .UNSPECIFIED,
        .Scaling = .UNSPECIFIED,
    };
    desc.SampleDesc = .{ .Count = 1, .Quality = 0 };
    desc.BufferUsage = dxgi.DXGI_USAGE_BACK_BUFFER;
    desc.BufferCount = 1;
    desc.OutputWindow = hwnd;
    desc.Windowed = 1;
    desc.SwapEffect = dxgi.DXGI_SWAP_EFFECT_DISCARD;

    const flags = lbl: {
        if (@import("builtin").mode == .Debug)
            break :lbl d3d11.D3D11_CREATE_DEVICE_DEBUG;

        break :lbl std.mem.zeroes(d3d11.D3D11_CREATE_DEVICE_FLAG);
    };

    _ = d3d11.D3D11CreateDeviceAndSwapChain(
            null, .HARDWARE, null, flags,
            null, 0, d3d11.D3D11_SDK_VERSION,
            &desc, &swap_chain, &device, null, &context);

    while (true) {
        var msg: usr.MSG = undefined;
        while (usr.PeekMessageA(&msg, null, 0, 0, usr.PM_REMOVE) > 0) {
            if (msg.message == usr.WM_QUIT)
                std.os.exit(0);
            _ = usr.TranslateMessage(&msg);
            _ = usr.DispatchMessageA(&msg);
        }

        _ = wind.GetClientRect(hwnd, &rect);
        var new_width = @intCast(u32, rect.right);
        var new_height = @intCast(u32, rect.bottom);

        // handle resize
        if ((width != new_width or height != new_height) or back_buffer == null) {
            if (back_buffer != null) {
                _ = back_buffer.?.IUnknown_Release();
                _ = cpu_buffer.?.IUnknown_Release();
                back_buffer = null;
                cpu_buffer = null;
            }

            width = new_width;
            height = new_height;

            // in case window is minimized, the size will be 0, no need to allocate resources
            if (width > 0 and height > 0) {
                _ = swap_chain.?.IDXGISwapChain_ResizeBuffers(1, width, height, .B8G8R8A8_UNORM, 0);

                _ = swap_chain.?.IDXGISwapChain_GetBuffer(0, d3d11.IID_ID3D11Texture2D, @ptrCast(?*?*anyopaque, &back_buffer));

                _ = device.?.ID3D11Device_CreateTexture2D(&.{
                    .Width = width,
                    .Height = height,
                    .MipLevels = 1,
                    .ArraySize = 1,
                    .Format = .B8G8R8A8_UNORM,
                    .SampleDesc = .{ .Count = 1, .Quality = 0 },
                    .Usage = .DYNAMIC,
                    .BindFlags = .SHADER_RESOURCE,
                    .CPUAccessFlags = .WRITE,
                    .MiscFlags = d3d11.D3D11_RESOURCE_MISC_FLAG.initFlags(.{}),
                }, null, &cpu_buffer);
            }
        }

        // // do your drawing to memory

        if (width > 0 and height > 0) {
            var mapped : d3d11.D3D11_MAPPED_SUBRESOURCE = undefined;

            _ = context.?.ID3D11DeviceContext_Map(@ptrCast(*d3d11.ID3D11Resource, cpu_buffer), 0, .WRITE_DISCARD, 0, &mapped);


            const counter = struct { var i: f32 = 0; };
            counter.i += 0.01;
            quad.tan.x = sin(counter.i);
            quad.tan.y = cos(counter.i);
            quad.norm.x = cos(counter.i);
            quad.norm.z = sin(counter.i);
            // quad.tan.x = quad.norm.x;
            // quad.tan.y = quad.norm.z;

            var data = @ptrCast([*]u32, @alignCast(@alignOf([*]u32), mapped.pData));

            const widthf = @intToFloat(f32, width);
            const heightf = @intToFloat(f32, height);
            var y: u32 = 0;
            while (y < height) : (y += 1) {
                var x: u32 = 0;
                while (x < width) : (x += 1) {
                    data[y * mapped.RowPitch/4 + x] = colorAt(
                        @intToFloat(f32, x) /  widthf - 0.5,
                        @intToFloat(f32, y) / heightf  - 0.5
                    );
                }
            }

            context.?.ID3D11DeviceContext_Unmap(@ptrCast(*d3d11.ID3D11Resource, cpu_buffer), 0);
            context.?.ID3D11DeviceContext_CopyResource(
                @ptrCast(*d3d11.ID3D11Resource, back_buffer),
                @ptrCast(*d3d11.ID3D11Resource, cpu_buffer)
            );
        }

        // swap buffers to display to window, 1 here means use vsync

        var hr = swap_chain.?.IDXGISwapChain_Present(1, 0);

        if (hr == win32.foundation.DXGI_STATUS_OCCLUDED) {
            windows.kernel32.Sleep(5);
        } else {
        }
    }

    std.os.exit(0);
}
