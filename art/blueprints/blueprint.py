"""Planos de proporciones de referencia, generados por código a partir de medidas reales (no del modelo).
Cada plano es una función f(u, v) -> bool en centímetros, en el mismo sistema que los modelos:

MANO (derecha, guante de nitrilo, mano relajada y plana; origen en el centro de la muñeca):
  vista superior (u = x, v = y): x hacia el meñique, y hacia los dedos.
  vista lateral  (u = y, v = z): z hacia el dorso.
  Medidas: promedios de adultos (ANSUR II, mezcla de sexos, redondeadas): largo de mano 18,7 cm
  (muñeca a punta del medio), largo de palma 10,6, ancho de palma 8,4, ancho de muñeca 5,8 (perímetro
  de muñeca de 16,9 cm), ancho del antebrazo a 10 cm 6,4; dedos índice 7,2 / medio 8,1 / anular 7,6 / meñique 6,0 cm, ancho de dedo
  2,0-1,6 cm; pulgar 6,2 cm a ~40° de abducción; espesor de palma 3,0, muñeca 4,0, antebrazo 5,4 cm.
  Guante: +0,15 cm por lado y puño enrollado de ~1,4 cm a 3,5 cm de la muñeca.

BOTA de trabajo (talle 42; origen en el centro de la suela, en el suelo; y hacia la punta):
  vista superior (u = x, v = y) y lateral (u = y, v = z). Medidas típicas de una bota de trabajo de
  15 cm de caña: largo total 30 cm, ancho de suela 11 cm en el antepié y 8 cm en el talón, alto de
  caña 21 cm detrás, boca 10 x 8 cm, puntera de 5 cm de alto, suela de 2,5 cm con taco de 3 cm.
"""
import math

GLOVE = 0.15


def _seg_dist(px, py, ax, ay, bx, by):
    abx, aby = bx - ax, by - ay
    t = ((px - ax) * abx + (py - ay) * aby) / max(abx * abx + aby * aby, 1e-9)
    t = max(0.0, min(1.0, t))
    dx, dy = px - (ax + abx * t), py - (ay + aby * t)
    return math.hypot(dx, dy), t


def _capsule(px, py, a, b, r0, r1):
    d, t = _seg_dist(px, py, a[0], a[1], b[0], b[1])
    return d <= r0 + (r1 - r0) * t


def _poly(px, py, pts):
    inside = False
    n = len(pts)
    for i in range(n):
        x1, y1 = pts[i]
        x2, y2 = pts[(i + 1) % n]
        if (y1 > py) != (y2 > py) and px < (x2 - x1) * (py - y1) / (y2 - y1) + x1:
            inside = not inside
    return inside


# --- Mano -------------------------------------------------------------------------------------
FINGERS = [  # (x de la base, y de la base, largo, ancho base, ancho punta, abanico en grados)
    (-2.85, 10.1, 7.2, 2.0, 1.65, -5.0),   # índice
    (-0.95, 10.6, 8.1, 2.0, 1.65, -1.0),   # medio
    (0.95, 10.3, 7.6, 1.9, 1.55, 3.0),     # anular
    (2.75, 9.4, 6.0, 1.7, 1.4, 8.0),       # meñique
]
THUMB = ((-3.4, 3.2), 6.2, 2.3, 1.95, 40.0)  # base, largo, anchos, abducción


def hand_top(x, y, arm=True):
    g = GLOVE
    if arm and -10.0 <= y <= 0.0:  # antebrazo: 6,9 cm a 10 cm, 6,2 en la muñeca
        half = 2.9 + (3.2 - 2.9) * (-y / 10.0) + g
        if abs(x) <= half:
            return True
        if -4.2 <= y <= -2.8 and abs(x) <= half + 1.15:  # puño enrollado
            return True
    # Palma: de la muñeca (6,2) a los nudillos (8,4), con la eminencia tenar del lado del pulgar.
    palm = [(-2.9 - g, 0.0), (2.9 + g, 0.0), (4.2 + g, 6.5), (4.0 + g, 9.6), (2.0, 10.6), (-2.0, 10.8),
            (-4.0 - g, 10.2), (-4.3 - g, 5.0), (-3.9 - g, 1.8)]
    if _poly(x, y, palm):
        return True
    for (bx, by, length, w0, w1, fan) in FINGERS:
        a = math.radians(fan)
        reach = length - w1 / 2  # la punta redonda de la cápsula agrega su radio: el largo total es `length`
        tip = (bx + math.sin(a) * reach, by + math.cos(a) * reach)
        if _capsule(x, y, (bx, by - 0.6), tip, w0 / 2 + g, w1 / 2 + g):
            return True
    (tx, ty), tl, tw0, tw1, ab = THUMB
    a = math.radians(-ab)
    treach = tl - tw1 / 2
    ttip = (tx + math.sin(a) * treach, ty + math.cos(a) * treach)
    return _capsule(x, y, (tx, ty), ttip, tw0 / 2 + g, tw1 / 2 + g)


def hand_side(y, z, arm=True):
    """Perfil lateral (y hacia los dedos, z hacia el dorso)."""
    g = GLOVE
    if arm and -10.0 <= y <= 0.0:
        half = 2.0 + (2.7 - 2.0) * (-y / 10.0) + g
        if abs(z) <= half:
            return True
        if -4.2 <= y <= -2.8 and abs(z) <= half + 1.15:
            return True
    if 0.0 <= y <= 10.6:  # palma: 4,0 en la muñeca a 2,8 en los nudillos, un poco hacia la palma
        k = y / 10.6
        half = 2.0 * (1.0 - k) + 1.4 * k + g
        center = -0.3 * k
        if abs(z - center) <= half:
            return True
    if 10.0 <= y <= 18.7:  # dedos superpuestos: 2,0 -> 1,5 cm de espesor
        k = (y - 10.0) / 8.7
        half = 1.0 * (1.0 - k) + 0.75 * k + g
        center = -0.3 - 0.4 * k
        return abs(z - center) <= half
    return False


# --- Bota -------------------------------------------------------------------------------------
def boot_top(x, y):
    if not -14.8 <= y <= 15.2:
        return False
    u = (y + 14.8) / 30.0
    half = 4.0 + 1.6 * math.sin(min(u, 1.0) * math.pi * 0.9)  # talón 8 cm, antepié 11 cm
    if u > 0.85:  # punta redonda
        half *= math.sqrt(max(0.0, 1.0 - ((u - 0.85) / 0.15) ** 2)) * 0.6 + 0.4 * (1.0 - (u - 0.85) / 0.15)
    return abs(x) <= half


def boot_side(y, z):
    if z < 0.0 or not -14.8 <= y <= 15.2:
        return False
    if z <= 2.6:  # suela y entresuela
        return True
    # Caña: de -14 a +1 cm, alta atrás (21) y baja adelante (18,5).
    if -14.0 <= y <= 1.0:
        top = 21.0 - 2.5 * (y + 14.0) / 15.0
        back_curve = -14.0 + 0.6 * math.sin(min(z / 21.0, 1.0) * math.pi)  # tendón
        if y >= back_curve and z <= top:
            return True
    # Empeine: baja de 12 cm (y = 1) a la puntera de 5 cm (y = 12) y redondea hasta 15.
    if 1.0 <= y <= 15.2:
        if y <= 12.0:
            top = 12.0 - 7.0 * (y - 1.0) / 11.0
        else:
            top = 5.0 * math.sqrt(max(0.0, 1.0 - ((y - 12.0) / 3.2) ** 2))
        return z <= top
    return False
