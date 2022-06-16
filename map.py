# Exports the map from Blender into a json file
import bpy
import bmesh
import struct
D = bpy.data


out = bytearray()
for o in D.objects:
    if o.name.startswith("Circle"):
        out += struct.pack('f', o.scale.x)
        out += struct.pack('f', o.location[0])
        out += struct.pack('f', o.location[1])
with open('assets/circle.bytes', 'wb') as f:
    f.write(out)


out = bytearray()
# out += struct.pack('!L', len(circles))
for o in D.objects:
    if o.name.startswith("Tree"):
        out += struct.pack('f', o.location[0])
        out += struct.pack('f', o.location[1])
with open('assets/tree.bytes', 'wb') as f:
    f.write(out)