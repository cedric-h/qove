const std = @import("std");

const Vec3 = @import("./math.zig").Vec3;
const vec3 = @import("./math.zig").vec3;
const Quat = @import("./math.zig").Quat;
const sin = @import("./math.zig").sin;
const cos = @import("./math.zig").cos;


// for games, scancodes > virtual keycodes because they're 
// about a location on a keyboard, not the letter on the key
// (not QWERTY? game still worky)
pub const ScanCode = enum(usize) {
    W = 17,
    S = 31,
    A = 30,
    D = 32,
    Shift = 42,
    Space = 57,
    MAX,
};
pub var keysdown = std.mem.zeroes([@enumToInt(ScanCode.MAX)]bool);
pub var cursor_locked = false;
var hp: usize = 3;

// var  fire = @ptrCast(*const [8*8][4]u16, @embedFile("../fire.bin"));
// var sword = @ptrCast(*const [8*8][4]u16, @embedFile("../sword.bin"));
var  hp_full = @ptrCast(*const [8*8][4]u16, @embedFile("../hp_full.bin"));
var hp_empty = @ptrCast(*const [8*8][4]u16, @embedFile("../hp_empty.bin"));

pub fn draw(data: []u32, width: u32, height: u32, row_pitch: usize) void {
    _ = height;
    _ = width;
    // const widthf = @intToFloat(f32, width);
    // const heightf = @intToFloat(f32, height);

    var n: usize = 0;
    while (n < 3) : (n += 1) {
        for (if (hp > n) hp_full else hp_empty) |p, i| {
            const r: u32 = p[0];
            const g: u32 = p[1];
            const b: u32 = p[2];
            if (r+g+b < 15) continue;
            const rgb = (r << 16) | (g << 8) | (b << 0);

            const S = 3;
            const u = @intCast(u32, i % 8)*S + S + n*S*(1+8);
            const v = @intCast(u32, i / 8)*S + S;
            var q: usize = 0;
            while (q < S*S) : (q += 1) {
                data[(v+q%S) * row_pitch + (u+q/S)] = rgb;
            }
        }
    }

    // return (r << 16) | (g << 8) | (b << 0);
}

pub const cam = struct {
    var pos = vec3(0, 0, -1);
    var look = vec3(0, 0, 1);
};

pub fn onMouseMove(x: f32, y: f32) void {
    const rot = struct { var pitch: f32 = 0; var yaw: f32 = 0; };
    
    rot.pitch = @maximum(-1.57, @minimum(1.57, rot.pitch + y*0.01));
    // rot.yaw = @mod(rot.yaw + x*0.01, std.math.pi);
    rot.yaw += x*0.01;

    cam.look = .{
        .x = sin(rot.yaw) * cos(rot.pitch),
        .y = sin(rot.pitch),
        .z = cos(rot.yaw) * cos(rot.pitch),
    };
}

pub fn frame() void {

    // controls
    // var fwd = cam.look; fwd.y = 0; fwd = fwd.norm();
    // const side = cam.look.cross(vec3(0, 1, 0));
    // var mv = vec3(0, 0, 0);
    // if (keysdown[@enumToInt(ScanCode.W)]) mv = mv.add(fwd);
    // if (keysdown[@enumToInt(ScanCode.S)]) mv = mv.add(fwd.mulf(-1));
    // if (keysdown[@enumToInt(ScanCode.A)]) mv = mv.add(side);
    // if (keysdown[@enumToInt(ScanCode.D)]) mv = mv.add(side.mulf(-1));
    // const mvmag = mv.mag();
    // if (mvmag > 0)
    //     cam.pos = cam.pos.add(mv.mulf(0.03 / mvmag));
}
