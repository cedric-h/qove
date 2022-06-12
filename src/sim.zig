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

var     fire = @ptrCast(*const [8*8][3]u8, @embedFile("../fire.bin"));
var    sword = @ptrCast(*const [8*8][3]u8, @embedFile("../sword.bin"));
var  hp_full = @ptrCast(*const [8*8][3]u8, @embedFile("../hp_full.bin"));
var hp_empty = @ptrCast(*const [8*8][3]u8, @embedFile("../hp_empty.bin"));

pub const Pixels = struct {
    width: u32,
    height: u32,
    data: []u32,
    row_pitch: usize,

    fn plot(pix: Pixels, xy: [2]usize, rgb: [3]u8) void {
        if (xy[0] > (pix.width-1)) return;
        if (xy[1] > (pix.height-1)) return;

        const r: u32 = rgb[0];
        const g: u32 = rgb[1];
        const b: u32 = rgb[2];

        pix.data[xy[1]*pix.row_pitch + xy[0]] = (r<<16) | (g<<8) | (b<<0);
    }
};


pub fn draw(pix: Pixels) void {
    // var n: usize = 0;
    // while (n < 3) : (n += 1) {
    //     for (if (hp > n) hp_full else hp_empty) |p, i| {
    //         const r: u32 = p[0];
    //         const g: u32 = p[1];
    //         const b: u32 = p[2];
    //         if (r+g+b < 15) continue;
    //         const rgb = (r << 16) | (g << 8) | (b << 0);

    //         const S = 3;
    //         const u = @intCast(u32, i % 8)*S + S + n*S*(1+8);
    //         const v = @intCast(u32, i / 8)*S + S;
    //         var q: usize = 0;
    //         while (q < S*S) : (q += 1) {
    //             data[(v+q%S) * row_pitch + (u+q/S)] = rgb;
    //         }
    //     }
    // }

    const widthf = @intToFloat(f32, pix.width);
    const heightf = @intToFloat(f32, pix.height);
    const aspect = widthf/heightf;

    for (sword) |pixel, i| {
        if (pixel[0]+pixel[1]+pixel[2] < 15) continue;

        const x = 1 - @intToFloat(f32, i % 8) / 8 * 2;
        const y = 1 - @intToFloat(f32, i / 8) / 8 * 2;
        const worldp = vec3(x*0.15, y*0.15, -1);

        const delta = worldp.sub(cam.pos);
        const dmag = delta.mag();

        if (delta.dot(cam.look()) < 0) continue;

        var point = cam.q.conj().rot(delta);
        point.x = point.x / dmag;
        point.y = point.y / dmag;

        point = point.add(vec3(0.5, 0.5, 0));
        const px = @floatToInt(usize,           widthf *      point.x);
        const py = @floatToInt(usize, aspect * heightf * (1 - point.y));

        const size = @floatToInt(usize, 17/dmag);
        var oy: usize = 0;
        while (oy < size) : (oy += 1) {
            var ox: usize = 0;
            while (ox < size) : (ox += 1) {
                // if (ox%2 ^ oy%2 > 0) continue;
                pix.plot(.{ px+size/2-ox, py+size/2-oy }, pixel);
            }
        }
    }
}

pub const cam = struct {
    var pos = vec3(0, 0, 0);
    var q = Quat.IDENTITY;
    fn look() Vec3 { return q.rot(vec3(0, 0, -1)); }
};

pub fn onMouseMove(x: f32, y: f32) void {
    const q_pitch = Quat.axisAngle(vec3(1, 0, 0), y * 0.01);
    const q_yaw = Quat.axisAngle(vec3(0, 1, 0), x * 0.01);

    cam.q = q_pitch.mul(cam.q.mul(q_yaw));
}

pub fn frame() void {

    // controls
    var fwd = cam.look(); fwd.y = 0; fwd = fwd.norm();
    const side = fwd.cross(vec3(0, -1, 0));
    var mv = vec3(0, 0, 0);
    if (keysdown[@enumToInt(ScanCode.W)]) mv = mv.add(fwd);
    if (keysdown[@enumToInt(ScanCode.S)]) mv = mv.add(fwd.mulf(-1));
    if (keysdown[@enumToInt(ScanCode.A)]) mv = mv.add(side);
    if (keysdown[@enumToInt(ScanCode.D)]) mv = mv.add(side.mulf(-1));
    if (keysdown[@enumToInt(ScanCode.Shift)]) cam.pos.y -= 0.03;
    if (keysdown[@enumToInt(ScanCode.Space)]) cam.pos.y += 0.03;
    const mvmag = mv.mag();
    if (mvmag > 0)
        cam.pos = cam.pos.add(mv.mulf(0.03 / mvmag));
}
