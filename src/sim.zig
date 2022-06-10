const std = @import("std");

const Vec3 = @import("./math.zig").Vec3;
const vec3 = @import("./math.zig").vec3;
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
pub var hp: usize = 3;

const Quad = struct {
    pos: Vec3,
    norm: Vec3,
    tan: Vec3,
    size: f32,
};

pub const cam = struct {
    var pos = vec3(0, 0, 0);
    var look = vec3(0, 0, 1);
};
const prim = struct {
    var quads: [2]Quad = .{
        .{
            .pos = vec3(0, 0, 1),
            .norm = vec3(0, 0, -1),
            .tan = vec3(0, 1, 0),
            .size = 0.25,
        },
        .{
            .pos = vec3(0, 0, 1.2),
            .norm = vec3(0, 0, -1),
            .tan = vec3(0, 1, 0),
            .size = 0.25,
        }
    };
};

var    fire = @ptrCast(*const [8*8][4]u16, @embedFile("../fire.bin"));
pub fn colorAt(x: f32, y: f32) u32 {
    const up = vec3(0, 1, 0);
    const side = up.cross(cam.look);

    const orig = cam.pos;
    const ray = cam
        .look
        .add(side.mulf(x))
        .add(  up.mulf(y))
        .norm();

    var z : f32 = 1000.0;

    var rgb: u32 = 0;
    for (prim.quads) |quad| {
        // get time until plane intersection
        const d = quad.pos.dot(quad.norm.mulf(-1));
        const qZ = -(d + quad.norm.dot(orig)) / quad.norm.dot(ray);

        // where the ray hits the surface 
        const p = orig.add(ray.mulf(qZ));

        const to_p = p.sub(quad.pos);
        var u = quad.tan.dot(to_p);
        var v = quad.tan.cross(quad.norm).dot(to_p);
        u = u / quad.size + 0.5;
        v = v / quad.size + 0.5;

        if (u <= 0 or v <= 0) continue;
        if (u >= 1 or v >= 1) continue;
        if (qZ > z) continue;

        const ui = @floatToInt(usize, u * 8);
        const vi = @floatToInt(usize, v * 8);
        var r: u32 = fire.*[ui*8 + vi][0];
        var g: u32 = fire.*[ui*8 + vi][1];
        var b: u32 = fire.*[ui*8 + vi][2];

        if (r+g+b < 15) continue;
        z = qZ; // write to "depth buffer"

        rgb = (r << 16) | (g << 8) | (b << 0);
    }
    return rgb;
}

pub fn onMouseMove(x: f32, y: f32) void {
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

const latch = struct {
    var caster = vec3(0, 0, 0);

    var cast = vec3(0, 0, 0);
    var start_pos = vec3(0, 0, 0);
    var end_pos = vec3(0, 0, 0);

    var until_land: u32 = 0;
    var until_next: u32 = 0;
};

pub fn frame() void {
    latch.until_next -|= 1;
    latch.until_land -|= 1;

    const LAND_T = 70;

    if (latch.until_next == 0) {
        latch.start_pos = latch.caster;
        latch.end_pos = cam.pos;
        latch.until_land = LAND_T;
        latch.until_next = 200;
    }

    if (latch.until_land < LAND_T and latch.until_land != 0) {
        const t = 1 - @intToFloat(f32, latch.until_land) / LAND_T;
        latch.cast = latch.start_pos.lerp(latch.end_pos, t);
        latch.cast.y = 0.3 * sin(t * 3.14159 * 2) - 0.3*(1-t);
        prim.quads[0].pos = latch.cast;
        prim.quads[0].size = 0.1;
    }
    prim.quads[1].pos = latch.caster;
    prim.quads[1].size = 0.35;

    if (latch.until_land == 1 and latch.cast.sub(cam.pos).mag() < 1) {
        hp -= 1;
    }

    var fwd = cam.look; fwd.y = 0; fwd = fwd.norm();
    const side = cam.look.cross(vec3(0, 1, 0));
    var mv = vec3(0, 0, 0);
    if (keysdown[@enumToInt(ScanCode.W)]) mv = mv.add(fwd);
    if (keysdown[@enumToInt(ScanCode.S)]) mv = mv.add(fwd.mulf(-1));
    if (keysdown[@enumToInt(ScanCode.A)]) mv = mv.add(side);
    if (keysdown[@enumToInt(ScanCode.D)]) mv = mv.add(side.mulf(-1));
    const mvmag = mv.mag();
    if (mvmag > 0)
        cam.pos = cam.pos.add(mv.mulf(0.03 / mvmag));
}
