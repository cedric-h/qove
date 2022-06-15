const std = @import("std");
const png = @import("png.zig");

fn compileImages() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const ally = gpa.allocator();

    const ss0 = try std.fs.cwd().openFile("colored_tilemap_packed.png", .{});
    const img0 = try png.Image.read(ally, ss0.reader());
    defer img0.deinit(ally);

    const ss1 = try std.fs.cwd().openFile("glyphs.png", .{});
    const img1 = try png.Image.read(ally, ss1.reader());
    defer img1.deinit(ally);

    const imgs = [2]png.Image{ img0, img1 };
    const quality = [2]f32   { 1<<16, 1<<16 };
    var pixels = std.mem.zeroes([8*8][3]u8);

    const sprites = .{
        .{   "kraken", .{ 11,  1 }, 0 },
        .{     "fire", .{  8,  8 }, 0 },
        .{  "hp_full", .{  6,  6 }, 0 },
        .{ "hp_empty", .{  4,  6 }, 0 },
        .{    "staff", .{  5, 12 }, 1 },
        .{      "oak", .{  5,  5 }, 0 },
        .{     "pine", .{  4,  5 }, 0 },
    };

    inline for (sprites) |sprite| {
        const img = imgs[sprite[2]];
        const qual = quality[sprite[2]];

        for (pixels) |_, i| {
            const x = @intCast(u32, i % 8);
            const y = @intCast(u32, i / 8);
            var pix = img.pix(sprite[1][0]*8 + x, sprite[1][1]*8+y);
            for (pix[0..3]) |p, pi| {
                var f = @intToFloat(f32, p) / qual;
                if (sprite[2] == 0)
                    f = std.math.pow(f32, f, 1/img.gamma);
                f = @minimum(1, @maximum(0, f));

                const out = @floatToInt(u8, f * 255);
                pixels[y*8 + x][pi] = if (pix[3] > 0) out else 0;
            }
        }

        const path = "assets/" ++ sprite[0] ++ ".bin";
        const file = try std.fs.cwd().createFile(path, .{});
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
    // exe.want_lto = true;
    exe.strip = true;
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
