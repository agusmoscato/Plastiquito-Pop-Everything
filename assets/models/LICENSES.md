# Licencias de los modelos

Regla: para formas orgánicas se aceptan bases CC0 o equivalentes sin atribución obligatoria. Todo lo
demás se modela por código en `art/models/`. Cada fila se verificó en la página oficial de la fuente.

| Modelo (archivo) | Base | Fuente y URL | Licencia | Verificado |
| --- | --- | --- | --- | --- |
| `hand.glb`, `hand_ghost.glb` | Humano adulto promedio generado con MPFB 2.0.18 (MakeHuman Plugin For Blender): se toma la mano derecha, 10 cm de antebrazo y los pesos de su esqueleto "default". El guante, el puño y el esqueleto del juego se hacen en `art/models/hand_mpfb.py`. | MakeHuman Community. Licencia: https://static.makehumancommunity.org/about/license.html · Extensión: https://extensions.blender.org/add-ons/mpfb/ (zip v2.0.18, sha256 `c075b3e9b94b8e5556a5f03f4653602d02ea306de08126e8f55ed6dee28a2dad`) | Assets: **CC0** ("All core assets are shared under Creative Commons, CC0 [...] You do not need to pay anything, include any copyright notices nor give attribution"). El código de MPFB es GPL-3.0 y no se distribuye con el juego (solo se usa para generar el modelo). | 2026-11-17 |
| `pin.glb`, `iron.glb`, `boot.glb`, `roller.glb`, `special_*.glb`, `prop_*.glb` | Propios, modelados por código (`art/models/*.py`). | Este repo | Propia del proyecto | — |

No se usa ningún modelo con atribución obligatoria ni con licencia no libre.
