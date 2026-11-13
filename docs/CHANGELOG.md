# Changelog

## Fase 1b — Builds e instalador para playtest (2026-11-13)

Sistema operativo de esta máquina: Windows 11.

### Hecho
- Versión única en `application/config/version` (`0.1.0`); `AppInfo` la lee y el juego la muestra tenue abajo a la derecha ("v0.1.0 playtest" / "dev").
- `export_presets.cfg` con "Windows" y "Linux" (x86_64, .pck embebido, feature tag `playtest`, excluye tests/, addons/gut/, tools/, docs/, installer/ y la escena de benchmark).
- Ícono generado por código (`tools/gen_icon.gd`): `icon.png` y `icon.ico` con 256/128/64/48/32/16 px, usado como ícono del proyecto y del .exe (rcedit v2.0.0 descargado a `tools/bin/`, ignorado por git, y configurado en los ajustes del editor de Godot).
- Modo playtest/release (`PlaytestMode`, `Playtest`, `PauseMenu`): sin F3 ni selector de tamaño, F12 sí, pantalla completa sin bordes, Alt+Enter, menú Esc (volumen, sacudida, "Abrir carpeta de datos", salir), y registro de sesión `sesion_<fecha>.csv` cada 10 s y al salir (`SessionLog`).
- `config/use_custom_user_dir`: los datos van a `%APPDATA%\Plastiquito` (Linux `~/.local/share/Plastiquito`) en vez de la carpeta larga con el nombre del proyecto.
- `tools/build.sh` y `tools/build.ps1`: lint + tests, export, zips (con `LEEME.txt`) e instalador. `tools/zip_dir.py` arma los zips y marca ejecutable el binario de Linux.
- `installer/plastiquito.iss` (Inno Setup 6.7.3, instalado con winget): por usuario sin admin, accesos en Inicio y escritorio, desinstalador, español e inglés, "Jugar ahora".
- `docs/PLAYTEST_TESTERS.md` y `docs/PLAYTEST_GATE1.md` actualizado.
- 9 tests nuevos (64 en total): versión, SessionLog y PlaytestMode.

### Verificado
- `tools/build.sh` de punta a punta en esta máquina. La build exportada (no el editor) arranca, revienta (79 reventones en la prueba con mouse simulado) y escribe el CSV. El instalador instala en silencio, el .exe instalado corre y el desinstalador lo borra.

### Decisiones y notas
- Solo se extrajeron del .tpz oficial (1,2 GB, verificado con CRC) las plantillas de release de Windows y Linux, que son las que usa el build; la descarga completa iba a tardar ~1 hora.
- El .exe pesa ~98 MB (la plantilla es casi todo); el zip de Windows 32 MB y el instalador 24 MB.
- Sin firma de código: Windows muestra "Windows protegió su PC" (explicado en PLAYTEST_TESTERS.md).
- El clic suelto se cuenta como apretar y soltar sin salir de la celda; en la prueba con mouse simulado el temblor del cursor puede sumar algún arrastre/clic de más.
- Los sonidos siguen siendo provisorios.
- No se probó el build de Linux (solo se generó y se verificó el contenido del zip).

## Fase 1 — Juguete (2026-11-13)

### Hecho
- **Sim**: `SheetModel.press` (aplastamiento), evento `reload_requested` al llegar a `reload_threshold`, `ToolModel` (fuerza por segundo, recuperación al soltar, arrastre con bono de entrada, `pop_cells` para debug). Parámetros en `data/sheet.json`, `data/tools.json`, `data/juice.json` y `data/audio.json`, validados por `DataDB`.
- **Vista**: `ToyWorld` (mesa, luz con sombras suaves, SSAO, glow, tonemap filmic), `CameraRig` (55°, rueda, interpolación, trauma), `SheetView` (MultiMesh en bloques de 64x64, solo actualiza celdas cambiadas), `shaders/bubble.gdshader`, `ToolView` (dedo con resorte y squash/stretch), rollo de recarga de 0,8 s.
- **Audio**: `PopAudioLogic` (lógica pura testeada) + autoload `PopAudio` (24 voces, tono ±8% y por racha, crepitar masivo >30 pops/frame), buses Master (limitador)/Pops/Tools/UI/Music, carga por carpeta de `assets/audio/pops/*` y `assets/audio/loops/`. `tools/gen_placeholder_sfx.gd` genera los `ph_*.wav` provisorios.
- **Juice**: autoload `Juice` (hitstop, trauma de cámara) y `FxPool` (14 emisores reutilizables).
- **Debug**: F3 (stats, tamaño de lámina, pop masivo, ajustes), F12 (captura en `user://screenshots`), `Settings` en `user://settings.cfg`.
- **Benchmark**: `scenes/benchmark.tscn` (`--auto-quit`, `--seconds=N`), CSV en `user://benchmark.csv`.
- `docs/PLAYTEST_GATE1.md`.
- `tools/lint.gd`: `run_tests.sh` ahora carga todos los scripts antes de los tests, porque el cargador de GUT no aplicaba las advertencias de tipos como errores y `--check-only` sí.

### Decisiones
- **Transparencia**: alpha blend (`blend_mix`) con `cull_back` y `depth_draw_opaque`. Los domos convexos no se superponen entre sí, así que el orden por instancia que MultiMesh no resuelve no genera artefactos visibles; la lámina base usa `render_priority = -1` para dibujarse antes. Alpha hash/dither se descartó por el grano; la "falsa transparencia" por perder el efecto de plástico. Verificado con capturas cerca y lejos.
- `INSTANCE_CUSTOM`: r = presión - 1, g = aplastamiento, b = progreso de reventón (0 entera, 0..1 animando, 1 reventada), a = tipo. El estado se funde en `b`; es un desvío leve de "presión, estado, tipo, aplastamiento".
- Arrastre: una celda a la que se entra con el botón apretado recibe `drag_entry_fraction` de la resistencia al instante (así revienta todo lo que cruza el cursor).
- Estado de la animación de reventón vive en la vista (`_anims`), no en la sim.
- Se mantiene el límite de dibujo de lejos para la Fase 3 (sin textura de estado todavía).

### Rendimiento (esta máquina: AMD Radeon integrada, vsync apagado, 1600x900)
- Cerca, 500x500, 30 s: 83,9 fps promedio, p1 55,6 fps, 11,92 ms promedio, p95 14,00 ms, 6 draw calls promedio.
- Lejos, 1000x1000, 30 s (solo dato): 6,2 fps, p1 6,0 fps, 161 ms promedio, p95 164 ms, 228 draw calls. Limitado por vértices (1M domos); lo resuelve el dibujo de lejos de la Fase 3.

### Pendiente / dudas
- Los sonidos son provisorios: sin grabaciones reales no se puede aprobar el control (ver PLAYTEST_GATE1).
- No pude escuchar el audio desde esta sesión; solo verifiqué que carga y corre sin errores.
- Aire, cadenas, burbujas tensas y economía: Fase 2.

## Fase 0 — Base (2026-11-13)

### Hecho
- Proyecto Godot 4.4.1 (Forward+, 1600x900, "Plastiquito: Pop Everything"). Advertencias `untyped_declaration`, `inferred_declaration` y `unsafe_*` configuradas como errores.
- Estructura de carpetas de DESIGN.md sección 8, `.gitignore`, `.gitattributes` (LF), `README.md`, `CLAUDE.md`.
- GUT v9.4.0 en `addons/gut`, `.gutconfig.json` y `tools/run_tests.sh` (sale con código != 0 si falla algo).
- `HexGrid`: grilla pointy-top odd-r, vecinos, `cell_to_world`/`world_to_cell` (redondeo cúbico) y formas de golpe (`cells_in_circle`, `cells_in_segment`, `cells_in_rect`) que recorren solo las filas y columnas del área.
- `SheetModel`: presión, estado y tipo en arrays empaquetados, `pop`/`pop_many`, contadores incrementales, señal `cells_changed(indices)`, `to_dict`/`from_dict` con `version`.
- `data/phases.json`, `tools.json`, `bubbles.json` y `DataDB` con validación de campos, tipos, formas y `unlock_phase`.
- 32 tests en verde (HexGrid, SheetModel, DataDB, rendimiento).

### Decisiones
- **Radio de burbuja**: el constructor de `HexGrid` recibe el radio del círculo de la burbuja; las burbujas vecinas se tocan, así que la distancia entre centros es `2 * radio` y el circunradio del hexágono es `2 * radio / sqrt(3)`. El prompt no fijaba esta convención.
- **Formas de golpe**: una celda entra si su **centro** está dentro de la forma (círculo, cápsula o rectángulo rotado). El rectángulo usa ejes locales: `size.x` sobre el eje rotado.
- **`count_intact()`** cuenta solo estado 0 (intacta). Se agregaron `count_tense()` y `count_popped()`; "sin reventar" = intactas + tensas.
- **Guardado de la lámina**: los arrays se serializan en base64 (un millón de celdas como listas JSON sería enorme). La versión del formato es 1.
- `from_dict` devuelve `false` y deja el motivo en `last_error` en vez de usar `push_error`.
- **`bubbles.json`**: se agregó `type_id` (1..7) para enlazar con el campo `type` de `SheetModel`; `shape` describe el área de efecto (`single`, `circle`, `row`, `hex7`). La "forma visual" para daltónicos de DESIGN.md 3.4 queda para la fase de vista.
- **`phases.json`**: `sheet_start`/`sheet_end` por fase (la fase 1 va de 8x8 a 20x20; el resto es fijo).
- Los archivos `.uid` de Godot 4.4 se commitean.
- Mantener la versión 4.4.1 de Godot (la que había en la máquina) en lugar de la última estable, a pedido del usuario.

### Rendimiento (informativo)
- Crear la lámina de 1000x1000: ~1 ms.
- 10.000 x (`cells_in_circle` radio 3 + `pop_many`): ~213 ms (~21 us por consulta).

### Dudas abiertas / pendientes
- DESIGN.md pide la versión "última estable" de Godot; está fijada 4.4.1. Conviene decidir si se actualiza antes de la Fase 1.
- El prompt citaba GUT en `bitwarden/gut`, que no existe; el repo oficial es `bitwes/Gut` (se usó ese).
- GUT 9.4.0 no detecta errores del motor (`push_error`) en los tests.
- No hay escena principal todavía (`godot --path .` abre un proyecto sin escena jugable).
- Mecánica de aire y cadenas (DESIGN.md 3.2) pendiente para la Fase 2.
- Los números de balance en `data/` son placeholders marcados con `"placeholder": true`.
