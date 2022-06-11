// never do this in real software lol
// https://www.intel.com/content/www/us/en/developer/articles/technical/the-difference-between-x87-instructions-and-mathematical-functions.html
pub fn cos(x: f32) f32 {
    return @floatCast(f32, asm volatile ("fcos"
        : [ret] "={st}" (-> f64)
        : [x] "0" (x)
    ));
}
pub fn sin(x: f32) f32 {
    return @floatCast(f32, asm volatile ("fsin"
        : [ret] "={st}" (-> f64)
        : [x] "0" (x)
    ));
}

pub const Vec3 = struct {
    x: f32,
    y: f32,
    z: f32,

    pub fn mulf(v: Vec3, f: f32) Vec3 {
        return .{ .x = v.x * f,
                  .y = v.y * f,
                  .z = v.z * f };
    }
    
    pub fn divf(v: Vec3, f: f32) Vec3 {
        return .{ .x = v.x / f,
                  .y = v.y / f,
                  .z = v.z / f };
    }

    pub fn sub(v: Vec3, o: Vec3) Vec3 {
        return .{ .x = v.x - o.x,
                  .y = v.y - o.y,
                  .z = v.z - o.z };
    }

    pub fn add(v: Vec3, o: Vec3) Vec3 {
        return .{ .x = v.x + o.x,
                  .y = v.y + o.y,
                  .z = v.z + o.z };
    }

    pub fn dot(v: Vec3, o: Vec3) f32 {
        return v.x * o.x +
               v.y * o.y +
               v.z * o.z;
    }

    pub fn mag(v: Vec3) f32 {
        return @sqrt(v.dot(v));
    }

    pub fn cross(v: Vec3, o: Vec3) Vec3 {
        return .{ .x = v.y * o.z - v.z * o.y,
                  .y = v.z * o.x - v.x * o.z,
                  .z = v.x * o.y - v.y * o.x };
    }

    pub fn norm(v: Vec3) Vec3 {
        return v.divf(v.mag());
    }

    pub fn lerp(a: Vec3, b: Vec3, t: f32) Vec3 {
        return a.mulf(1 - t) .add( b.mulf(t) );
    }
};
pub fn vec3(x: f32, y: f32, z: f32) Vec3 { return .{ .x = x, .y = y, .z = z }; }

pub const Quat = struct {
    xyz: Vec3,
    w: f32,

    pub const IDENTITY: Quat = .{ .xyz = vec3(0, 0, 0), .w = 1 };

    pub fn conj(v: Quat) Quat {
        return .{ .xyz = v.xyz.mulf(-1), .w = v.w };
    }

    pub fn axisAngle(axis: Vec3, angle: f32) Quat {
        var a = angle / 2;
        return .{ .xyz = axis.mulf(sin(a)), .w = cos(a) };
    }

    pub fn rot(q: Quat, a: Vec3) Vec3 {
        const b = q.xyz;
        return a
            .mulf(q.w * q.w - b.dot(b))
            .add(b.mulf(a.dot(b) * 2))
            .sub(b.cross(a).mulf(q.w * 2));
    }

    pub fn mul(a: Quat, b: Quat) Quat {
        const x0 = a.xyz.x;
        const y0 = a.xyz.y;
        const z0 = a.xyz.z;
        const w0 = a.w;
        const x1 = b.xyz.x;
        const y1 = b.xyz.y;
        const z1 = b.xyz.z;
        const w1 = b.w;
        return .{
            .xyz = vec3(
                w0 * x1 + x0 * w1 + y0 * z1 - z0 * y1,
                w0 * y1 - x0 * z1 + y0 * w1 + z0 * x1,
                w0 * z1 + x0 * y1 - y0 * x1 + z0 * w1,
            ),
            .w = w0 * w1 - x0 * x1 - y0 * y1 - z0 * z1,
        };
    }
};
