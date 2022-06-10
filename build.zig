const std = @import("std");
const png = @import("png.zig");

fn compileImages() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const ally = gpa.allocator();

    const ss = try std.fs.cwd().openFile("colored_tilemap_packed.png", .{});
    const img = try png.Image.read(ally, ss.reader());
    defer img.deinit(ally);

    std.debug.print("{}\n", .{img.gamma});

    var pixels = std.mem.zeroes([8*8][4]u16);

    const sprites = .{
        .{     "fire", .{ 8, 8 } },
        .{  "hp_full", .{ 6, 6 } },
        .{ "hp_empty", .{ 4, 6 } },
    };

    inline for (sprites) |sprite| {
        for (pixels) |_, i| {
            const x = @intCast(u32, i % 8);
            const y = @intCast(u32, i / 8);
            var pix = img.pix(sprite[1][0]*8 + x, sprite[1][1]*8+y);
            for (pix) |p, pi| {
                var f = @intToFloat(f32, p) / (1 << 16);
                f = std.math.pow(f32, f, 1/img.gamma);
                f = @minimum(1, @maximum(0, f));
                pix[pi] = @floatToInt(u16, f * 255);
            }
            pixels[y*8 + x] = pix;
        }

        const file = try std.fs.cwd().createFile(sprite[0] ++ ".bin", .{});
        try file.writeAll(std.mem.sliceAsBytes(pixels[0..]));
    }
}

pub fn build(b: *std.build.Builder) void {
    compileImages() catch |e|
        std.debug.print("could not compile images! {}", .{e});

    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable("qove", "src/main.zig");
    // exe.strip = true;
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_tests = b.addTest("src/main.zig");
    exe_tests.setTarget(target);
    exe_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&exe_tests.step);
}
