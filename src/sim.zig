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
    const widthf = @intToFloat(f32, width);
    const heightf = @intToFloat(f32, height);

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

    for ([_]Vec3{
        vec3(-0.15, -0.15, -1),
        vec3( 0.15, -0.15, -1),
        vec3( 0.15,  0.15, -1),
        vec3(-0.15,  0.15, -1),
    }) |worldp| {
        if (cam.pos.sub(worldp).dot(cam.look()) > 0) continue;
        const delta = worldp.sub(cam.pos);
        const dmag = delta.mag();
        var point = cam.q.conj().rot(delta);

        point.x = point.x / dmag;
        point.y = point.y / dmag;

        point = point.add(vec3(0.5, 0.5, 0));
        var px = @floatToInt(usize,  widthf * point.x);
        var py = @floatToInt(usize, heightf * point.y);
        if (px > (width-2)) continue;
        if (py > (height-2)) continue;

        data[(py+0) * row_pitch + (px+0)] = (0<<16) | (255<<8) | (128<<0);
        data[(py-1) * row_pitch + (px-1)] = (0<<16) | (255<<8) | (128<<0);
        data[(py+1) * row_pitch + (px-1)] = (0<<16) | (255<<8) | (128<<0);
        data[(py-1) * row_pitch + (px+1)] = (0<<16) | (255<<8) | (128<<0);
        data[(py+1) * row_pitch + (px+1)] = (0<<16) | (255<<8) | (128<<0);
    }
}

pub const cam = struct {
    var pos = vec3(0, 0, 0);
    var q = Quat.IDENTITY;
    fn look() Vec3 { return q.rot(vec3(0, 0, -1)); }
};

pub fn onMouseMove(x: f32, y: f32) void {
    const q_pitch = Quat.axisAngle(vec3(-1, 0, 0), y * 0.01);
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
    if (keysdown[@enumToInt(ScanCode.Shift)]) cam.pos.y += 0.03;
    if (keysdown[@enumToInt(ScanCode.Space)]) cam.pos.y -= 0.03;
    const mvmag = mv.mag();
    if (mvmag > 0)
        cam.pos = cam.pos.add(mv.mulf(0.03 / mvmag));
}
