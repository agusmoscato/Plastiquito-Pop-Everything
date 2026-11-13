"""Utilería de escenarios: cup, pencil, chair_leg, shelf (estante con cajas de cartón) y cone.
Uso: props.py -- --out x.glb --which cup|pencil|chair_leg|shelf|cone. Origen en la base."""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
import bpy
from art import lib

A = lib.args()
which = sys.argv[sys.argv.index("--which") + 1] if "--which" in sys.argv else "cup"
lib.reset()
parts = []
if which == "cup":
    ceramic = lib.material("ceramic", lib.hex_color("#E9E3D3"), rough=0.3)
    coffee = lib.material("coffee", lib.hex_color("#4A2E1E"), rough=0.2)
    body = lib.revolve_profile("cup", [(0.0, 0.0), (0.030, 0.0), (0.036, 0.004), (0.046, 0.045), (0.048, 0.085), (0.044, 0.085), (0.040, 0.080), (0.0, 0.080)], 28)
    body.data.materials.append(ceramic)
    lib.bevel(body, 0.0012, 1)
    liquid = lib.revolve_profile("liquid", [(0.0, 0.0), (0.043, 0.0), (0.0, 0.0)], 24)
    liquid.location = (0, 0, 0.070)
    liquid.data.materials.append(coffee)
    handle = lib.tube_along("handle", [(0.045, 0, 0.070), (0.072, 0, 0.068), (0.078, 0, 0.045), (0.060, 0, 0.022), (0.040, 0, 0.020)], [0.007, 0.0075, 0.0075, 0.0075, 0.007], sides=10)
    handle.data.materials.append(ceramic)
    parts += [body, liquid, handle]
elif which == "pencil":
    yellow = lib.material("pencil_yellow", lib.hex_color("#F2B531"), rough=0.4)
    wood = lib.material("pencil_wood", lib.hex_color("#E3BE8C"), rough=0.7)
    lead = lib.material("pencil_lead", lib.hex_color("#2B2A33"), rough=0.5)
    pink = lib.material("eraser", lib.hex_color("#E88A8A"), rough=0.8)
    metal = lib.material("ferrule", lib.hex_color("#C9CDD1"), rough=0.3, metal=0.9)
    body = lib.revolve_profile("body", [(0.0, 0.0), (0.0035, 0.0), (0.0035, 0.19), (0.0, 0.19)], 6)
    body.data.materials.append(yellow)
    cone = lib.revolve_profile("tip", [(0.0, 0.19), (0.0035, 0.19), (0.0010, 0.215), (0.0, 0.215)], 6)
    cone.data.materials.append(wood)
    mine = lib.revolve_profile("lead", [(0.0, 0.208), (0.0010, 0.208), (0.0, 0.2165)], 6)
    mine.data.materials.append(lead)
    fer = lib.revolve_profile("ferrule", [(0.0, -0.012), (0.0037, -0.012), (0.0037, 0.0), (0.0, 0.0)], 12)
    fer.data.materials.append(metal)
    er = lib.revolve_profile("eraser", [(0.0, -0.022), (0.003, -0.022), (0.0034, -0.012), (0.0, -0.012)], 12)
    er.data.materials.append(pink)
    for o in (body, cone):
        o.location = (0, 0, 0.0)
    parts += [body, cone, mine, fer, er]
    for o in parts:
        o.rotation_euler = (math.radians(90.0), 0.0, 0.0)
    for o in parts:
        o.location.z += 0.0035
elif which == "chair_leg":
    wood = lib.material("chair_wood", lib.hex_color("#8A5A34"), rough=0.6)
    metal = lib.material("chair_cap", lib.hex_color("#2B2A33"), rough=0.5)
    leg = lib.revolve_profile("leg", [(0.0, 0.02), (0.018, 0.02), (0.020, 0.12), (0.024, 0.28), (0.026, 0.40), (0.026, 0.42), (0.0, 0.42)], 12)
    leg.data.materials.append(wood)
    lib.bevel(leg, 0.002, 1)
    cap = lib.revolve_profile("cap", [(0.0, 0.0), (0.017, 0.0), (0.019, 0.010), (0.018, 0.022), (0.0, 0.022)], 14)
    cap.data.materials.append(metal)
    parts += [leg, cap]
elif which == "cone":
    orange = lib.material("cone_orange", lib.hex_color("#F0642A"), rough=0.5)
    refl = lib.material("cone_reflect", lib.hex_color("#F4EFE6"), rough=0.2)
    base = lib.box("base", (0.16, 0.16, 0.014), (0, 0, 0.007))
    base.data.materials.append(orange)
    lib.bevel(base, 0.004, 2)
    body = lib.revolve_profile("cone", [(0.0, 0.014), (0.062, 0.014), (0.056, 0.10), (0.036, 0.26), (0.020, 0.40), (0.016, 0.42), (0.0, 0.42)], 20)
    body.data.materials.append(orange)
    stripe = lib.revolve_profile("stripe", [(0.0, 0.0), (0.0455, 0.18), (0.0405, 0.23), (0.0, 0.23)], 20)
    stripe = lib.revolve_profile("stripe", [(0.0455, 0.18), (0.0462, 0.18), (0.0407, 0.235), (0.0400, 0.235)], 20)
    stripe.data.materials.append(refl)
    parts += [base, body, stripe]
else:
    # Estante: dos laterales, tres tablas y cajas de cartón con solapas y cinta.
    wood = lib.material("shelf_wood", lib.hex_color("#6E7076"), rough=0.6)
    card = lib.material("cardboard", lib.hex_color("#C49A63"), rough=0.85)
    tape = lib.material("tape", lib.hex_color("#E8DDB5"), rough=0.4)
    parts.append(lib.box("side", (0.03, 0.30, 1.0), (-0.44, 0, 0.5)))
    parts.append(lib.box("side", (0.03, 0.30, 1.0), (0.44, 0, 0.5)))
    for z in (0.02, 0.35, 0.68, 0.99):
        parts.append(lib.box("board", (0.90, 0.30, 0.03), (0, 0, z)))
    for p in parts:
        p.data.materials.append(wood)
    boxes = [(-0.20, 0.035, 0.14, 0.34, 0.26, 0.28), (0.18, 0.035, 0.12, 0.32, 0.24, 0.24), (-0.22, 0.365, 0.12, 0.30, 0.26, 0.24), (0.10, 0.365, 0.15, 0.30, 0.24, 0.30)]
    for (x, z, _a, w, d, h) in boxes:
        b = lib.box("carton", (w, d, h), (x, 0.0, z + h / 2 + 0.015), (0, 0, math.radians(3.0 * (1 if x < 0 else -1))))
        lib.bevel(b, 0.004, 1)
        b.data.materials.append(card)
        t = lib.box("tape", (0.05, d * 1.02, 0.004), (x, 0.0, z + h + 0.017), (0, 0, math.radians(3.0 * (1 if x < 0 else -1))))
        t.data.materials.append(tape)
        parts += [b, t]
lib.finish(parts, "prop_" + which, A)
