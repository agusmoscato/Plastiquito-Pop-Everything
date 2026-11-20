"""Sonidos propios de la interfaz (generados por código, licencia CC0 por ser propios).
Uso: python tools/gen_ui_sfx.py  -> assets/audio/ui/ph_<nombre>.wav
  clink: campanita de joyería (dos senos inarmónicos con caída rápida) al ponerse un accesorio.
  paper: sello de papel seco para pedidos grandes (CUMPLIDO / VENCIDO distintos por tono).
"""
import math
import os
import struct
import wave

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "audio", "ui")
RATE = 44100


def write(name, samples):
    path = os.path.join(OUT, "ph_%s.wav" % name)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s)) * 32000)) for s in samples))
    print("escrito", path)


def tone(freqs, dur, decay, gains=None):
    n = int(RATE * dur)
    gains = gains or [1.0] * len(freqs)
    out = []
    for i in range(n):
        t = i / RATE
        env = math.exp(-decay * t) * min(1.0, t * 400)
        out.append(sum(g * math.sin(2 * math.pi * f * t) for f, g in zip(freqs, gains)) * env * 0.35)
    return out


write("clink", tone([2093, 3135, 4186], 0.55, 9.0, [1.0, 0.55, 0.3]))
write("done", tone([523, 659, 784], 0.7, 5.0, [1.0, 0.7, 0.5]))
write("fail", tone([196, 147], 0.8, 4.0, [1.0, 0.8]))
