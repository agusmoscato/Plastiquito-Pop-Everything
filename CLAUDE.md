# CLAUDE.md — Plastiquito: Pop Everything

Reglas permanentes para Claude Code en todas las fases. La fuente de verdad del diseño es [docs/DESIGN.md](docs/DESIGN.md). Si algo de un prompt lo contradice, avisar al usuario en vez de elegir por cuenta propia.

## Versiones fijadas

- **Godot: 4.4.1-stable** (`4.4.1.stable.official.49a5bc7b6`). No se actualiza salvo que un bug lo obligue.
- **GUT: v9.4.0** (repo oficial `bitwes/Gut`, copiado en `addons/gut`).

## Correr los tests

```
./tools/run_tests.sh
```

Comando equivalente directo (sin pantalla):

```
godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gexit
```

`run_tests.sh` usa `$GODOT` si está definido (ruta al ejecutable), si no `godot` del PATH. En esta máquina Godot no está en el PATH:

```
GODOT="C:/Users/sopor/Desktop/Agustin/1-JUEGOS/Inflación Idle/tools/godot_bin/Godot_v4.4.1-stable_win64_console.exe" ./tools/run_tests.sh
```

Si se agregan clases con `class_name` nuevas, `run_tests.sh` ya corre `godot --headless --import` antes para registrarlas.

## Arquitectura (reglas de oro)

- `src/sim/` es **lógica pura**: clases `RefCounted`, sin nodos, sin escenas, sin acceso a la pantalla. La vista (`src/view/`) solo lee el estado.
- **Todo número de balance vive en `data/*.json`**, nunca en el código.
- **Sin colliders por burbuja.** Clic → rayo contra el plano y=0 → matemática hexagonal.
- Estructura de carpetas según la sección 8 de DESIGN.md.

## Estilo de código

- GDScript con **tipado estático en todo**. En `project.godot` las advertencias `untyped_declaration`, `inferred_declaration` y `unsafe_*` son **errores**. Consecuencias: no usar `:=`; escribir `var x: int = 0`; los `for` van tipados (`for i: int in range(n)`); castear Variants a un tipo antes de pasarlos como argumento.
- `class_name` en todas las clases de `src/sim/`.
- Funciones cortas, con una sola responsabilidad.
- Textos de cara al jugador en español e inglés (los ids de datos en inglés, `snake_case`).

## Flujo de trabajo

- Una rama por fase (`fase-N`). Un commit por tarea terminada, con mensajes tipo `feat(sim): ...`, `chore: ...`, `test: ...`.
- **Tests en verde antes de cada commit.** Nunca commitear con tests rotos.
- Al cerrar la fase: merge a `main` y push de las ramas a `origin`.
- Al final de cada fase, escribir/actualizar `docs/CHANGELOG.md` con lo hecho, las decisiones tomadas y lo pendiente.
- Todo cambio en `data/` que afecte el balance se valida con el simulador de balance (`tools/balance_sim.gd`, a partir de la fase que lo cree).

## Legal y assets

- Nada de marcas ni personajes con derechos.
- Solo sonidos propios o CC0, y fuentes con licencia OFL.
