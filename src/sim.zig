const std = @import("std");

const math = @import("./math.zig");
const Vec3 = math.Vec3;
const vec3 = math.vec3;
const Quat = math.Quat;
const sin =  math.sin;
const cos =  math.cos;


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

const Img = *const [8*8][3]u8;

var     fire = @ptrCast(Img, @embedFile("../assets/fire.bin"));
var    staff = @ptrCast(Img, @embedFile("../assets/staff.bin"));
var  hp_full = @ptrCast(Img, @embedFile("../assets/hp_full.bin"));
var hp_empty = @ptrCast(Img, @embedFile("../assets/hp_empty.bin"));
var      oak = @ptrCast(Img, @embedFile("../assets/oak.bin"));
var     pine = @ptrCast(Img, @embedFile("../assets/pine.bin"));

// Draw flecks from begin -> end, animate as a function of T
const Ray = struct {
    begin: Vec3,
    end: Vec3,

    fn draw(r: Ray) void {
        const delta = r.end.sub(r.begin);
        const dmag = delta.mag();

        var t: f32 = 0;
        var a: f32 = 0.1;
        while (t < dmag) : ({ t += a; a += 0.03; }) {
            Fleck.queue(.{
                .pos = r.begin.add(delta.mulf(t / dmag)),
                .rgb = .{ 255, 255, 255 },
                .tex = .Diamond,
            });
        }
    }
};

// Fleck pipeline:
// 
// queue() your general world flecks
//
// applyCam() - applies camera transform, filters some out
//
// queue() your special screenspace flecks
//
// render() - sorts by depth and puts that shit on the screen
const Fleck = struct {
    pos: Vec3,
    rgb: [3]u8,
    size: f32 = 1,
    tex: Texture,

    const Texture = enum {
        Solid,
        Diamond,
    };

    var pending: [1 << 12]@This() = undefined;
    var count: usize = 0;

    fn queue(f: Fleck) void {
        pending[count] = f;
        count += 1;
    }

    // Queue a grid of Flecks colored as in the image
    fn img(arg: struct {
        pixels: Img,
        pos: Vec3,
        size: [2]f32,
        quat: Quat = Quat.IDENTITY,
        center : bool = false, // centers on Y axis
        fleckSize: f32 = 1,
        tex: Fleck.Texture = .Solid,
    }) void {
        const hw = arg.size[0];
        const hh = arg.size[1];
        for (arg.pixels) |pixel, i| {
            if (pixel[0]+pixel[1]+pixel[2] < 15) continue;

            var x = 1 - @intToFloat(f32, i % 8) / 8 - 0.5;
            var y = 1 - @intToFloat(f32, i / 8) / 8;
            if (arg.center) y -= 0.5;
            queue(.{
                .pos = arg.pos.add(arg.quat.rot(vec3(x*hw, y*hh, 0))),
                .rgb = pixel,
                .tex = arg.tex,
                .size = arg.fleckSize,
            });
        }
    }

    fn spin(arg: struct {
        pixels: Img,
        pos: Vec3,
        size: [2]f32,
        fleckSize: f32 = 1,
    }) void {
        const hw = arg.size[0];
        const hh = arg.size[1];
        for (arg.pixels) |pixel, i| {
            if (pixel[0]+pixel[1]+pixel[2] < 15) continue;

            if (i != 0 and arg.pixels[i-1][0] +
                           arg.pixels[i-1][1] +
                           arg.pixels[i-1][2] > 15)
                continue;

            const px = @intToFloat(f32, i % 8);
            const x = 1 -                      px / 8 - 0.5;
            const y = 1 - @intToFloat(f32, i / 8) / 8;

            const max = 4 * (2 + 3*(4 - px));
            var n: f32 = 0;
            while (n < max) : (n += 1) {
                const t = n/max;
                const quat = Quat.axisAngle(vec3(0, 1, 0), t * std.math.tau);

                var rgb = pixel;
                var r = @intToFloat(f32, rgb[0]);
                var g = @intToFloat(f32, rgb[1]);
                var b = @intToFloat(f32, rgb[2]);
                rgb[0] = @floatToInt(u8, r*(1 + 0.3*sin(t*20+0)));
                rgb[1] = @floatToInt(u8, g*(1 + 0.3*sin(t*20+5)));
                rgb[2] = @floatToInt(u8, b*(1 + 0.3*sin(t*20-5)));
                queue(.{
                    .pos = arg.pos.add(quat.rot(vec3(x*hw, (t + y)*hh, 0))),
                    .rgb = rgb,
                    .tex = .Solid,
                    .size = arg.fleckSize,
                });
            }
        }
    }

    fn lessThan(_: @TypeOf({}), a: Fleck, b: Fleck) bool {
        return a.pos.z > b.pos.z;
    }

    fn applyCam() void {
        var wtr: usize = 0;
        for (pending[0..count]) |*f| {
            const delta = f.pos.sub(cam.pos);
            const dmag = delta.mag();

            // memory for this Fleck will get reused because no wtr += 1
            if (delta.dot(cam.look()) < 0) continue;

            f.pos = cam.q.conj().rot(delta);

            // perspective divide
            // we get the glorious pinhole effect because we use dmag
            // rather than the original Z here
            f.pos.x /= dmag;
            f.pos.y /= dmag;
            f.pos.z = dmag;

            // scale size based on distance
            f.size *= 17/dmag;

            // safe to write while we iterate because wtr <= i
            pending[wtr] = f.*;
            wtr += 1;
        }
        count = wtr;
    }

    fn render(pix: Pixels) void {
        std.sort.insertionSort(
            Fleck,
            pending[0..count],
            {}, 
            lessThan,
        );

        for (pending[0..count]) |f| pix.fleck(f);
        count = 0;
    }
};

pub const Pixels = struct {
    width: u32,
    height: u32,
    data: []u32,
    row_pitch: isize,

    // fill in the given pixel, if it is valid 
    fn plot(pix: Pixels, xy: [2]isize, rgb: [3]u8) void {
        if (xy[0] < 0) return;
        if (xy[1] < 0) return;
        if (xy[0] > (pix.width-1)) return;
        if (xy[1] > (pix.height-1)) return;

        const r: u32 = rgb[0];
        const g: u32 = rgb[1];
        const b: u32 = rgb[2];

        const i = @intCast(usize, xy[1]*pix.row_pitch + xy[0]);
        pix.data[i] = (r<<16) | (g<<8) | (b<<0);
    }

    fn fleck(pix: Pixels, f: Fleck) void {
        const widthf = @intToFloat(f32, pix.width);
        const heightf = @intToFloat(f32, pix.height);
        const aspect = widthf/heightf;

        // world -> screen space
        var point = f.pos.add(vec3(0.5, 0.5, 0));
        pix.fill(
            f, 
            @floatToInt(isize, 0.5 * f.size),
            @floatToInt(isize, widthf / aspect * point.x),
            @floatToInt(isize,          heightf * (1 - point.y)),
        );
    }

    // Second step of drawing Fleck
    // Fill in a bunch of pixels on the screen here with the given texture
    //
    // Ideally these textures could be fleck agnostic, but atm not the case
    fn fill(pix: Pixels, f: Fleck, rawsize: isize, px: isize, py: isize) void {
        var size = rawsize;
        switch (f.tex) {
            .Solid => {
                var oy: isize = 0;
                while (oy < size*2) : (oy += 1) {
                    var ox: isize = 0;
                    while (ox < size*2) : (ox += 1) {
                        pix.plot(.{ px+size-ox, py+size-oy }, f.rgb);
                    }
                }
            },
            .Diamond => {
                size = @maximum(size, 3);
                var oy: isize = 0;
                while (oy < size*2) : (oy += 1) {
                    var ox: isize = 0;
                    while (ox < size*2) : (ox += 1) {
                        const abs = std.math.absCast;
                        const qx = abs(size-ox);
                        const qy = abs(size-oy);
                        const d = abs(size)-qx - qy;
                        if (d > abs(size)/3) continue;
                        pix.plot(.{ px+size-ox, py+size-oy }, f.rgb);
                    }
                }
            }
        }
    }

};


var ray: ?Ray = null;
const Ent = struct {
    pos : Vec3 = vec3(0, 0, 0),
    quat : Quat = Quat.IDENTITY,
    size : f32 = 0.3,
    fn forward(e: Ent) Vec3 { return e.quat.rot(vec3(0, 0, -1)); }
};
var ent : ?Ent = .{ .pos = vec3(1, 0, -1) };
pub fn draw(pix: Pixels) void {
    if (ray) |r| r.draw();

    const ticker = struct { var t: f32 = 0; };
    ticker.t += 0.1;

    if (ent) |*e| {
        e.quat = Quat.axisAngle(vec3(0,1,0), ticker.t/10);
        Fleck.img(.{
            .pixels = staff,
            .pos = e.pos,
            .size = .{ e.size, e.size },
            .quat = e.quat
        });
    }

    Fleck.spin(.{
        .pixels = pine,
        .pos = vec3(1, 0, 1),
        .size = .{ 2, 3.5 },
        .fleckSize = 4,
    });
    Fleck.spin(.{
        .pixels = oak,
        .pos = vec3(3, 0, 1.5),
        .size = .{ 2, 3 },
        .fleckSize = 4,
    });
    var qqq = cam.pos.add(cam.look());
    qqq.y = 0;
    Fleck.queue(.{
        .pos = qqq,
        .rgb = .{ 255, 0, 255 },
        .tex = .Solid
    });

    Fleck.applyCam();
    Fleck.img(.{
        .pixels = staff,
        .center = true,
        .pos = vec3(0.36, -0.37, -0.5),
        .quat = Quat.axisAngle(vec3(0,1,0.2).norm(), -0.9 + 0.05*sin(ticker.t)),
        .fleckSize = 18,
        .size = .{ 0.34, 0.34 },
    });
    var n: f32 = 0;
    while (n < 3) : (n += 1) {
        const size = 0.08;
        const edge = 0.5 - size + size/2.0;
        const full = @intToFloat(f32, hp) > n;
        Fleck.img(.{
            .pixels = if (full) hp_full else hp_empty,
            .tex = if (full) .Solid else .Diamond,
            .pos = vec3(n * size * 9/8 - edge, edge, -0.5),
            .quat = Quat.axisAngle(vec3(0,1,0), ticker.t/10 + n*0.1),
            .center = true,
            .fleckSize = 6,
            .size = .{ size, size },
        });
    }

    Fleck.render(pix);
}

pub const cam = struct {
    var pos = vec3(0, 1, 0);
    var q = Quat.IDENTITY;
    fn look() Vec3 { return q.rot(vec3(0, 0, -1)); }
    fn side() Vec3 { return cam.look().cross(vec3(0, 1, 0)); }
    fn up() Vec3 { return cam.look().cross(cam.side()); }
};

var cooldown: f32 = 100;
pub fn onMouseDown() void {
    cooldown = 0;

    // start
    var begin = cam.pos.add(cam.look().mulf(0.5));
    begin = begin.add(cam.side().mulf(0.28*0.5));
    begin = begin.add(cam.  up().mulf(0.24*0.5));

    var mid = cam.pos.add(cam.look().mulf(2.5));
    var end = begin.lerp(mid, 2);

    const norm = end.sub(begin).norm();

    if (ent) |e| {
        const d = e.pos.dot(e.forward().mulf(-1));
        const qZ = -(d + e.forward().dot(begin)) / e.forward().dot(norm);
        const hit = begin.add(norm.mulf(qZ));
        if (hit.sub(e.pos).mag() < e.size/2) {
            end = hit;
            ent = null;
        }
    }
    else ent = .{ .pos = vec3(2, 0, -4) };

    ray = .{ .begin = begin,
             .end   = end };
}

pub fn onMouseMove(x: f32, y: f32) void {
    const q_pitch = Quat.axisAngle(vec3(1, 0, 0), y * 0.01);
    const q_yaw = Quat.axisAngle(vec3(0, 1, 0), x * 0.01);

    cam.q = q_pitch.mul(cam.q.mul(q_yaw));
}

const latch = struct {
    var cast = vec3(0, 0, 0);
    var start_pos = vec3(0, 0, 0);
    var end_pos = vec3(0, 0, 0);

    var until_land: u32 = 0;
    var until_next: u32 = 0;
};

pub fn frame() void {
    cooldown += 0.1;
    if (cooldown < 0.8) {
        onMouseMove(0, -10*math.easeOutSine(cooldown/0.8));
    }

    // enemy/projectile behavior
    if (ray != null) {
        latch.until_next -|= 1;
        latch.until_land -|= 1;
    }

    const LAND_T = 70;

    if (latch.until_next == 0) {
        if (ent) |e| {
            latch.start_pos = e.pos;
            latch.end_pos = cam.pos;
            latch.until_land = LAND_T;
            latch.until_next = 200;
        }
    }

    if (latch.until_land < LAND_T and latch.until_land != 0) {
        const t = 1 - @intToFloat(f32, latch.until_land) / LAND_T;
        latch.cast = latch.start_pos.lerp(latch.end_pos, t);
        latch.cast.y = 0.3 * sin(t * std.math.pi);
        Fleck.img(.{
            .pos = latch.cast,
            .size = .{ 0.1, 0.1 },
            .quat = Quat.axisAngle(vec3(0, 1, 0), t * 20),
            .pixels = fire,
        });
    }

    if (latch.until_land == 1 and latch.cast.sub(cam.pos).mag() < 1) {
        hp -= 1;
    }

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
