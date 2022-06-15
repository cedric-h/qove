# Exports the map from Blender into a json file
import bpy
import bmesh
import struct
D = bpy.data

out = bytearray()

circles = [o for o in D.objects if o.name.startswith("Circle")]
# out += struct.pack('!L', len(circles))
for c in circles:
    out += struct.pack('f', c.scale.x)
    out += struct.pack('f', c.location[0])
    out += struct.pack('f', c.location[1])

with open('circle.bytes', 'wb') as f:
    f.write(out)