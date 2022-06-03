const std = @import("std");
const windows = std.os.windows;

pub fn panic(_: []const u8, _: ?*const std.builtin.StackTrace) noreturn {
    std.os.exit(0);
}

pub export fn wWinMainCRTStartup() callconv(windows.WINAPI) noreturn {
    _ = windows.user32.messageBoxA(null, "gettin ziggy wit it, eh?", "ced's 1st zig", 0) catch {};
    std.os.exit(0);
}
