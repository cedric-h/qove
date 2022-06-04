const std = @import("std");

extern "kernel32" fn GetFileTime(
    hWnd: *anyopaque,
    lpCreationTime: ?*std.os.windows.FILETIME,
    lpLastAccessTime: ?*std.os.windows.FILETIME,
    lpLastWriteTime: ?*std.os.windows.FILETIME,
) c_int;

fn fileTimeAsUnixNs(ft: std.os.windows.FILETIME) i64 {
    const t = @intCast(i64, @intCast(u64, ft.dwLowDateTime) | @intCast(u64, ft.dwHighDateTime) << 32);
    return (t - 0x019db1ded53e8000) * 100;
}

fn lastChangeTime() !i64 {
    const plug = try std.fs.cwd().openFile("plug.zig", .{ .mode = .read_only });
    defer plug.close();

    var last_write: std.os.windows.FILETIME = undefined;
    _ = GetFileTime(plug.handle, null, &last_write, null);
    return fileTimeAsUnixNs(last_write);
}

fn run(gpa: std.mem.Allocator) !void {
    { // build
        const args = .{ "zig", "build-lib", "plug.zig", "-dynamic" };
        var child = std.ChildProcess.init(&args, gpa);
        child.stdin_behavior = .Inherit;
        child.stdout_behavior = .Inherit;
        child.stderr_behavior = .Inherit;

        _ = try child.spawnAndWait();
    }

    { // run 
        var dynlib = try std.DynLib.open("./plug.dll");
        defer dynlib.close();
        dynlib.lookup(fn() void, "init").?();
    }
}

pub fn main() !void {
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(!general_purpose_allocator.deinit());
    const gpa = general_purpose_allocator.allocator();

    var last_run = try lastChangeTime();
    try run(gpa);

    while (true) {
        if (last_run < try lastChangeTime()) {
            try run(gpa);
            last_run = try lastChangeTime();
        }

        std.time.sleep(std.time.ns_per_ms * 500);
    }
}
