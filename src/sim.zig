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
var   kraken = @ptrCast(Img, @embedFile("../assets/kraken.bin"));
var  hp_full = @ptrCast(Img, @embedFile("../assets/hp_full.bin"));
var hp_empty = @ptrCast(Img, @embedFile("../assets/hp_empty.bin"));
var    staff = @ptrCast(Img, @embedFile("../assets/staff.bin"));
var      oak = @ptrCast(Img, @embedFile("../assets/oak.bin"));
var     pine = @ptrCast(Img, @embedFile("../assets/pine.bin"));

// Draw flecks from begin -> end, animate as a function of T
const Ray = struct {
    begin: Vec3,
    end: Vec3,
    elapsed: f32 = 0,

    fn draw(r: *Ray) void {
        r.elapsed += 0.1;
        const delta = r.end.sub(r.begin);
        const dmag = delta.mag();

        const FADE_AFTER = 8;
        if (r.elapsed > 30) return;

        var t: f32 = 0;
        var a: f32 = 0.1;
        while (t < dmag) : ({ t += a; a += 0.03; }) {
            var prog = math.easeOutSine((r.elapsed - FADE_AFTER)/20);
            prog = if (prog < 0) 0 else prog;
            Fleck.queue(.{
                .pos = r.begin.add(delta.mulf(t / dmag)),
                .rgb = .{
                    @floatToInt(u8, 205 * (1-prog)),
                    @floatToInt(u8,  80 * (1-prog)),
                    @floatToInt(u8, 180 * (1-prog))
                },
                .size = 2 + if (r.elapsed > FADE_AFTER) (prog)*10 else 0,
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

    var pending: [1 << 13]@This() = undefined;
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
        quat: Quat = Quat.IDENTITY,
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
                var quat = Quat.axisAngle(vec3(0, 1, 0), t * std.math.tau);
                quat = quat.mul(arg.quat);

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

fn sign(f: f32) f32 {
    if (f < 0) return -1;
    if (f > 0) return 1;
    return 0;
}

fn round(f: f32) f32 {
    return @intToFloat(f32, @floatToInt(isize, f + 0.5*sign(f)));
}

fn fabs(f: f32) f32 {
    return f * sign(f);
}

fn cubeRound(frac: Vec3) Vec3 {
    var q = round(frac.x);
    var r = round(frac.y);
    var s = round(frac.z);

    const q_diff = fabs(q - frac.x);
    const r_diff = fabs(r - frac.y);
    const s_diff = fabs(s - frac.z);

    if (q_diff > r_diff and q_diff > s_diff) {
        q = -r-s;
    } else if (r_diff > s_diff) {
        r = -q-s;
    } else
        s = -q-r;

    return vec3(q, r, s);
}

const HEX_SIZE = 3;
fn worldToHex(p: Vec3) Vec3 {
    const q = (@sqrt(3.0)/3.0 * p.x  -  1.0/3.0 * p.z) / HEX_SIZE;
    const r = (                         2.0/3.0 * p.z) / HEX_SIZE;
    return cubeRound(vec3(q, r, - q - r));
}

fn hexToWorld(hex: Vec3) Vec3 {
    var x = HEX_SIZE * (@sqrt(3.0) * hex.x  +  @sqrt(3.0) / 2.0 * hex.y);
    var y = HEX_SIZE * (                             3.0  / 2.0 * hex.y);
    return vec3(x, 0.0, y);
}

fn grassHex(center_h: Vec3) void {
    const center = hexToWorld(center_h);
    var o: f32 = 0;
    while (o < 30) : (o += 2) {
        var n: f32 = 0;
        while (n < o) : (n += 1) {
            const t = n/o;
            const r = t * std.math.tau - o*1.5;
            const pos = vec3(cos(r), 0, sin(r)).mulf(o/10).add(center);
            var fadeout = 1-(@maximum(pos.sub(cam.pos).mag(), 7)-7)/3;
            if (center_h.sub(worldToHex(pos)).mag() > 0.1) continue;
            Fleck.queue(.{
                .pos = pos,
                .rgb = .{
                    @floatToInt(u8, 20  * (1 + 0.3*sin(t*20+0))),
                    @floatToInt(u8, 100 * (1 + 0.3*sin(t*20+5))),
                    @floatToInt(u8, 40  * (1 + 0.3*sin(t*20-5))),
                },
                .tex = .Solid,
                .size = (5 + 1 * sin(t*20+2)) * fadeout,
            });
        }
    }
}

fn ground() void {
    const center_h = worldToHex(cam.pos);
    const neighbors = [_]Vec3{
        vec3(1, 0, -1), vec3(1, -1, 0), vec3(0, -1, 1), 
        vec3(-1, 0, 1), vec3(-1, 1, 0), vec3(0, 1, -1),
        vec3(0, 0, 0),
        vec3(1, 1, -2), vec3(2, -1, -1), vec3(-1, -1, 2), 
        vec3(-2,  1,  1), vec3(-1, 2, -1), vec3(1, -2, 1),

        vec3(2, 0, -2), vec3(2, -2, 0), vec3(0, -2, 2), 
        vec3(-2, 0, 2), vec3(-2, 2, 0), vec3(0, 2, -2),
    };
    for (neighbors) |n| grassHex(center_h.add(n));
}


var held: ?Img = null;
var ray: ?Ray = null;
const Ent = struct {
    pos : Vec3 = vec3(0, 0, 0),
    quat : Quat = Quat.IDENTITY,
    size : f32 = 0.6,
    fn forward(e: Ent) Vec3 { return e.quat.rot(vec3(0, 0, -1)); }
};
var ent : ?Ent = .{ .pos = vec3(1, 0, -1) };
pub fn draw(pix: Pixels) void {
    if (ray) |*r| r.draw();

    const ticker = struct { var t: f32 = 0; };
    ticker.t += 0.1;

    if (held == null) {
        Fleck.img(.{
            .pixels = staff,
            .pos = pickup_pos,
            .size = .{ 0.3, 0.3 },
            .quat = Quat.axisAngle(vec3(0,1,0), ticker.t/10),
        });
    } else if (ent) |*e| {
        Fleck.img(.{
            .pixels = kraken,
            .pos = e.pos,
            .fleckSize = 2.6,
            .size = .{ e.size, e.size },
            .quat = e.quat
        });
    }

    Fleck.spin(.{
        .pixels = pine,
        .pos = vec3(1, -0.3, 1),
        .size = .{ 2, 3.5 },
        .fleckSize = 4,
    });
    Fleck.spin(.{
        .pixels = oak,
        .pos = vec3(3, -0.3, 1.5),
        .size = .{ 2, 3 },
        .quat = Quat.axisAngle(vec3(0,1,0), 1.8),
        .fleckSize = 4,
    });

    ground();

    Fleck.applyCam();
    if (held) |pixels| {
        Fleck.img(.{
            .pixels = pixels,
            .center = true,
            .pos = vec3(0.36, -0.37, -0.5),
            .quat = Quat.axisAngle(
                vec3(0,1,0.2).norm(),
                -0.9 + 0.05*sin(ticker.t)
            ),
            .fleckSize = 18,
            .size = .{ 0.34, 0.34 },
        });
    }
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

const pickup_pos = vec3(1, 0, -1);
var cooldown: f32 = 100;
pub fn onMouseDown() void {
    cooldown = 0;

    if (held == null) {
        cooldown = 100;
        if (cam.pos.sub(pickup_pos).mag() < 2)
            held = staff;
        return;
    }

    // start
    var begin = cam.pos.add(cam.look().mulf(0.5));
    begin = begin.add(cam.side().mulf(0.28*0.5));
    begin = begin.add(cam.  up().mulf(0.24*0.5));

    var mid = cam.pos.add(cam.look().mulf(3));
    var end = begin.lerp(mid, 2);

    const norm = end.sub(begin).norm();

    if (ent) |e| {
        const d = e.pos.dot(e.forward().mulf(-1));
        const qZ = -(d + e.forward().dot(begin)) / e.forward().dot(norm);
        const hit = begin.add(norm.mulf(qZ));
        const center = e.pos.add(vec3(0, e.size/2, 0));
        if (hit.sub(center).mag() < e.size/2) {
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
        latch.cast.y = 2 * sin(t * std.math.pi);
        Fleck.img(.{
            .pos = latch.cast,
            .size = .{ 0.2, 0.2 },
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
