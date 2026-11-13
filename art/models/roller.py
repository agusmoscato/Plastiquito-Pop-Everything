"""Rodillo automático: rodillo de pintor con estructura de alambre y mango, pasa como una máquina chica.
Eje del rodillo a lo largo de X (0,26 m); el origen está abajo, en el punto de contacto."""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
import bpy
from art import lib

A = lib.args()
lib.reset()
nap = lib.material("nap", lib.hex_color("#E9DFC8"), rough=0.95)
steel = lib.material("steel", lib.hex_color("#C9CDD1"), rough=0.3, metal=0.9)
grip = lib.material("grip", lib.hex_color("#C8322B"), rough=0.55)
dark = lib.material("dark", lib.hex_color("#2B2A33"), rough=0.5)

R = 0.040
body = lib.revolve_profile("roll", [(0.0, -0.130), (0.034, -0.130), (R, -0.122), (R + 0.002, -0.10), (R + 0.003, 0.0), (R + 0.002, 0.10), (R, 0.122), (0.034, 0.130), (0.0, 0.130)], 28)
body.rotation_euler = (0.0, math.radians(90.0), 0.0)
body.location = (0.0, 0.0, R + 0.003)
body.data.materials.append(nap)
parts = [body]
# Tapas laterales y buje.
for sx in (-1, 1):
    cap = lib.revolve_profile("cap", [(0.0, 0.0), (0.030, 0.0), (0.034, 0.006), (0.020, 0.012), (0.0, 0.012)], 20)
    cap.rotation_euler = (0.0, math.radians(90.0 * sx), 0.0)
    cap.location = (sx * 0.133, 0.0, R + 0.003)
    cap.data.materials.append(dark)
    parts.append(cap)
# Estructura: eje, brazo en Z y mango.
axle = lib.tube_along("axle", [(-0.150, 0.0, R + 0.003), (0.150, 0.0, R + 0.003)], [0.0045, 0.0045], sides=8)
axle.data.materials.append(steel)
parts.append(axle)
frame_pts = [(0.150, 0.0, R + 0.003), (0.152, 0.0, 0.085), (0.120, 0.0, 0.122), (0.0, 0.0, 0.130), (-0.060, 0.0, 0.130)]
frame = lib.tube_along("frame", frame_pts, [0.0045] * 5, sides=8)
frame.data.materials.append(steel)
parts.append(frame)
handle = lib.tube_along("handle", [(-0.060, 0.0, 0.130), (-0.12, 0.0, 0.150), (-0.20, 0.0, 0.178), (-0.28, 0.0, 0.205)], [0.010, 0.0150, 0.0175, 0.0140], sides=14)
lib.subsurf(handle, 1)
handle.data.materials.append(grip)
parts.append(handle)
# Una chapita con motor para que se vea como una máquina.
motor = lib.revolve_profile("motor", [(0.0, 0.0), (0.020, 0.0), (0.022, 0.03), (0.016, 0.045), (0.0, 0.045)], 18)
motor.rotation_euler = (0.0, math.radians(90.0), 0.0)
motor.location = (0.150, 0.0, R + 0.003)
motor.data.materials.append(dark)
parts.append(motor)
lib.finish(parts, "roller", A)
