# Changelog

## Fase 3 — Escala (2026-11-13)

El juego llega jugable hasta el final del Estacionamiento (DESIGN 4), la lámina de 1.000x1.000 se dibuja de lejos con una textura de estado, hay cuatro escenarios con identidad, plancha, bota, Eco, Manitos y rodillo automático, reciclado completo con tablero de corcho, ganancias sin conexión y herramienta de clips. **El balance de las fases 3 y 4 solo está calibrado para el perfil activo; el casual y el idle no cumplen todas las métricas (ver abajo).**

### Hecho
- **Dibujo de lejos** (rama `fase-3-render`, `SheetView`, `FarView`, `StatePacker`, `shaders/far_sheet.gdshader`): textura de estado RGBA8 de un píxel por burbuja, subida solo por bloques que cambiaron; plano de lejos con domos falsos en el fragmento; fundido por bloque según la distancia; bloques lejanos apagados; láminas de más de 60.000 celdas usan un domo de 54 triángulos. Se activa con más de 20.000 celdas, así que la lámina de 150x150 ya lo usa. Detalle y límites en [BENCHMARK_FASE3.md](BENCHMARK_FASE3.md).
- **Escenarios** (rama `fase-3-scen`, `src/view/scenarios/`): Mesa (madera con veta, lámpara, taza, lápices), Piso (damero, zócalo, pata de silla, ventana con persiana), Galpón (hormigón manchado, estanterías con cajas, luz cenital fría, polvo) y Estacionamiento (asfalto, líneas, conos, luz de atardecer), con ambiente sonoro propio por fase. Cada reciclado que abre fase cambia el escenario durante 3,5 s mientras la cámara se aleja (`ToyWorld.transition_to_phase`).
- **Contenido** (sim pura, con tests): **Plancha** (calor que sube la presión hasta 1,4 antes de tocar, sin crear aire), **Bota** (pisotón con recarga visible en el HUD y onda expansiva pagada con el aire de lo pisado), **Eco** (se vuelve a inflar una sola vez a los 2 s), **Manitos** (dedos fantasma que respetan su ritmo y no tocan reventadas; las inteligentes están preparadas y bloqueadas hasta la Fase 6) y **rodillo automático** (barridas con velocidad y ancho mejorables). Se ven siempre en el mundo (`AutomationView`).
- **Reciclado completo**: fases 3 y 4 con "Lámina más grande" (1, 18 y 110 Pellets), +5% global, herramientas iniciales mejoradas, automatización desde el arranque, probabilidad de especiales y "memoria del turno". Tablero de corcho con fichas clavadas con chinches e hilo rojo entre las que se requieren (`RecyclePanel`, `PermCard`).
- **Ganancias sin conexión** (`OfflineEarnings`, `OfflineTicket`): lo que producen Manitos y rodillo, al 50% y con tope de 2 horas (en `data/economy.json`), con un ticket de etiquetadora que se imprime y un TOTAL que se suma al odómetro rodando. Si la hora retrocede no se otorga nada (tests).
- **Descubrimiento de la tienda**: la primera vez que algo se vuelve pagable la etiqueta se despega más, el clip tiembla y una flecha dibujada con marcador la señala 3 s; después de la primera compra, nunca más (`Settings.discovery_done`).
- **Íconos por categoría**: tamaño (herramienta junto a una regla), fuerza (reventando una burbuja de una grilla de 3x3), velocidad (estela), especial (burbuja al lado), cantidad (copias). Los SubViewports se crean recién cuando el ícono se ve.
- **Herramienta de clips** (rama `fase-3-scen`, `scenes/clips/`, `tools/record_clip.*`): 4 clips con el Movie Maker de Godot, F9 oculta toda la interfaz. Duración y peso en [CLIPS.md](CLIPS.md).
- **Save versión 3** con migración desde la 2 (y desde la 1): memoria del turno y datos de ganancias sin conexión. Tests de ida y vuelta y de migración.
- Simulador de balance hasta 3 h 30 (`tools/balance_sim.gd --minutes=215`, `tools/balance_full.sh`); el paso "balance" de `run_tests.sh` sigue corriendo las fases 1 y 2 (activo y casual, 3 semillas).

### Simulador (semilla 1, 215 min, `--dt=20`)
| Métrica | Objetivo | Activo | Casual | Idle |
| --- | --- | --- | --- | --- |
| Mediana entre compras, 0-10 min | 15-40 s | 19,0 APROBADO | 21,0 APROBADO | n/a |
| Mediana entre compras, 10-45 min | 30-90 s | 33,0 APROBADO | 36,9 APROBADO | n/a |
| Mediana entre compras, 45-210 min | 30-120 s | 37,0 APROBADO | 4,4 FALLÓ | n/a |
| Mayor espera sin comprar (0-45 / 45-210 min) | <= 120 / <= 180 s | 107 / 179 APROBADO | 83 / 113 APROBADO | n/a |
| % del tiempo con compra pagable o a < 30 s | >= 70 % | 68,8 FALLÓ | 88,3 APROBADO | n/a |
| Llegada al Piso | 28-42 min | 30,1 APROBADO | 36,9 APROBADO | 36,9 |
| Llegada al Galpón | 72-108 min | 90,5 APROBADO | 86,9 APROBADO | 86,9 |
| Llegada al Estacionamiento | 120-180 min | 147,8 APROBADO | 95,5 FALLÓ | no llega |
| Recuperación tras reciclar | < 40 % de la partida | 2,3 % APROBADO | 63,6 % FALLÓ | n/a |
| Herramienta nueva contra la anterior al máximo | >= 2x | 2,9x APROBADO | 1,3x FALLÓ | n/a |
| Idle: Pops/min tras Manitos contra el activo | 20-45 % | n/a | n/a | ~0 % FALLÓ |

**Qué no cumple y por qué.** Pasé muchas iteraciones calibrando el perfil activo y no alcanzó el tiempo para cerrar el casual y el idle:
- La economía de las fases 3 y 4 está dominada por las cadenas sobre láminas de 6.400 y 22.500 burbujas (el 90% de los reventones). El bot casual arma cadenas enormes con la plancha y las Manitos (sube al Estacionamiento a los 95 min), mientras que las Manitos solas producen del orden de 0,002% de los Pops del activo al final. Para que el idle llegue al 20-45% hay que bajar la dominancia de las cadenas (por ejemplo, `chain_k` o un tope de tamaño de cadena por frame) y volver a calibrar todo.
- La métrica "% del tiempo con compra pagable" del activo queda en 68,8% (a 1,2 puntos); el hueco está justo después de cada reciclado de fase.
- **Propuesta**: antes de la Fase 4, limitar la ganancia de las cadenas grandes (valor decreciente por reventón pasado cierto tamaño) y recalibrar con las Manitos como fuente principal del perfil idle.

### Decisiones y desvíos de DESIGN.md
- **Base por fase x100** (no x50): `phase_base_values` = 1, 100, 10.000, 1.000.000, con escalas de costo [1, 320, 40.000, 8.000.000]. El x50 de DESIGN dejaba la primera hora de la fase siguiente por debajo del pico de la anterior.
- **"Lámina más grande"** abre una fase por nivel con costos a mano (1, 18 y 110 Pellets), `cost_table` en `data/upgrades.json`.
- **Cadenas**: `chain_k_max` bajó de 0,9 a 0,62 y la mejora de aire comprimido tiene 3 niveles (antes 10); el umbral de tensión mínimo es 1,4. Sin ese tope, las láminas grandes se despejaban enteras de un golpe.
- **Plancha**: el calor sube la presión hasta `iron_heat_cap` = 1,4 (menor que el umbral de tensión de 1,5): prepara las cadenas sin crear aire por encima de lo que dicen las reglas. **Bota**: la onda se paga con `min(wave_k, 1 - chain_k)` de la presión pisada, así el aire total nunca aumenta.
- **Manitos inteligentes** existen en `data/upgrades.json` con requisito de fase 6 (nunca disponibles en esta fase).
- **Eco** vuelve a inflarse como burbuja normal (no repite). El aviso de brillo previo al reinflado quedó pendiente.
- La plancha del clip 3 sigue simulando el calor a mano (`_apply_heat()` del clip); falta enchufar el `ToolModel` real.
- Linux: no hay WSL ni VM en esta máquina, así que la build de Linux se genera pero no se pudo ejecutar.
- El shader de lejos no soporta todavía el rollo de reciclado (las láminas de más de 20.000 celdas se reciclan sin la animación de enrollado).

### Pendiente
- Cerrar el balance del casual y el idle (ver arriba) y repetir las capturas con ese cambio.
- Aviso de brillo del Eco, vapor de la plancha y polvo de la bota con partículas propias.
- Sonido real y mezcla.

## Fase 2 — Núcleo (2026-11-13)

La primera hora (Mesa y Piso) completa: aire y cadenas, 3 herramientas, 3 especiales, economía, tienda, HUD, combo, reciclado básico, guardado y simulador de balance v1.

### Hecho
- **Aire y cadenas** (`AirModel`, `ChainSolver`, `SheetModel`): al apretar sin reventar, la burbuja pasa aire a las vecinas libres (se conserva); presión >= 1,5 = tensa; al reventar reparte `k * presión` y el resto se pierde; las que llegan a 2,0 revientan solas. Cola con presupuesto por frame (la ola se dibuja en varios frames). Tests con 1000 semillas: el aire nunca aumenta, toda cadena termina (incluso con k = 1), se respeta el presupuesto, nunca revienta dos veces y es determinística.
- **Herramientas** (`ToolModel`, `ToolMeshes`, `ToolView`): Dedo, Palma (círculo, el centro cede primero, el borde se tensa) y Palo de amasar (franja perpendicular al arrastre, aire sesgado hacia adelante). Teclas 1, 2 y 3 más botones. Cada compra se ve en el mundo: la herramienta crece, sigue más rápido, aprieta más hondo y cambia de color en cada hito de 25 niveles.
- **Especiales** (`SpecialsView`): Dorada (x10, joya con facetas y glow), Bomba (radio 3, mecha) y Línea (su fila en las dos direcciones, cápsula con bandas), con partículas y sonido propios y etiqueta "NUEVA" la primera vez. Burbujario simple (`BubbleLog`).
- **Economía** (`Economy`, `Upgrades`, `ComboTracker`, `NumberFormat`): valor = base x p^2 x tipo x combo x global; costo base * g^n con compra x1, x10 y MAX; hito x2 cada 25 niveles; combo por ritmo con escalones (x1 a x5, no sube más allá del último); formato de números de hasta 4 cifras con sufijos (K, M, B, T, Qa...), coma en español y punto en inglés, sin notación científica. 24 mejoras en `data/upgrades.json`.
- **Reciclado** (`Prestige`, `GameState`): Pellets = floor(sqrt(Pops de la corrida / divisor)); botón con el total en vivo; 4 mejoras permanentes (lámina más grande que abre el Piso, +5% global por nivel, dedo inicial mejorado, probabilidad de dorada); transición con la lámina que se arruga, se enrolla y se va, y la cámara que se aleja en 3,5 s.
- **Guardado** (`GameState`, `SaveSystem`): `user://save.json`, versión 2 con migración desde el save de la Fase 1 (la lámina sola), autosave cada 30 s y al salir. Tests de ida y vuelta, de migración y de saves inválidos.
- **Interfaz** (ver [UI_STYLE.md](UI_STYLE.md)): depósito de embalaje dibujado por código: odómetro de rodillos, "+N" que vuelan al contador, hoja de pedidos con íconos 3D en vivo, orden de trabajo, siguiente pedido, ritmo, sello de CADENA, centro de reciclado y menú de pausa. Fuentes OFL (Bowlby One, Archivo, Space Mono).
- **Simulador de balance v1** (`tools/balance_sim.gd`, `GameSim`): misma sim que el juego, perfiles activo, casual e idle, CSV en `tools/out/`, APROBADO/FALLÓ por métrica. Integrado a `run_tests.sh` como paso "balance" (activo y casual, 3 semillas cada uno).
- Registro de sesión de playtest con compras, cadena máxima, minuto del primer reciclado y uso de cada herramienta.
- `GameSim` es el orquestador único de las reglas (lo usan el juego y el simulador); `Cfg` lee valores tipados de los JSON.

### Resultados del simulador (46 min, 3 semillas por perfil; todo APROBADO)
| Métrica | Objetivo | Activo | Casual |
| --- | --- | --- | --- |
| Mediana entre compras, 0-10 min | 15-40 s | 18-19 s | 19-20 s |
| Mediana entre compras, 10-45 min | 30-90 s | 32-34 s | 36-38 s |
| Mayor espera sin poder comprar | <= 120 s | 57-87 s | 79-98 s |
| % del tiempo con compra pagable o a < 30 s | >= 70 % | 86-89 % | 80-82 % |
| Primera cadena de 10+ | < 3 min | 0,2-0,4 min | 0,2-0,4 min |
| Primera dorada | < 4 min | 0-0,1 min | 0-0,2 min |
| Palma comprada | < 8 min | ~1 min | ~2,2 min |
| Llegada al Piso / palo de amasar | 28-42 min | ~30 min | ~37 min |
| Primer reciclado | 28-42 min | ~30 min | ~37 min |

La primera compra llega a los 6-13 s (fuerza del dedo al 15% del precio de lista) y la segunda a los 14-40 s.

### Valores de balance clave (`data/`)
- `sheet.json`: tensa 1,5; máxima 2,0; mínima 0,4; `chain_k` 0,5 (máx. 0,9 con mejoras); presupuesto de cadena 40/frame a 60 fps; recarga al 90%.
- `economy.json`: base por fase [1, 50]; **escala de costos por fase [1, 160]** (el Piso paga x50 pero cuesta x160 porque la lámina de 40x40 amplifica por cadenas); combo en [0; 0,75; 1,5; 2,25; 3,0] golpes/s para x[1; 1,5; 2; 3; 5]; **divisor de Pellets 2,4 millones** (DESIGN decía 100.000: con las cadenas el primer reciclado llega a los 30-37 min); dorada 2%, bomba 1,2%, línea 1,2%.
- `tools.json`: dedo 6/s, palma 3,5/s (centro x2,5), palo 5/s; aire 0,3 a 0,6 según la herramienta.

### Curvas de las que estoy menos seguro
- **Reciclados posteriores al primero**: el simulador calibra los primeros 45 min; después de reciclar la economía del Piso crece muy rápido y hay que recalibrar con la Fase 3.
- **Cadenas en el Piso**: la lámina de 40x40 con k = 0,5 sostiene cadenas de cientos de burbujas. Es el espectáculo buscado, pero explica la escala de costos x160. Conviene revisar `chain_k` y el umbral de tensión con el playtest.
- **Activo contra casual**: la diferencia hasta el primer reciclado es de ~7 min (30 contra 37). Los bots son aproximaciones de personas; el playtest real manda.
- El bot ahorra para desbloquear herramientas; una persona podría comprar mejoras baratas antes.

### Decisiones y desvíos de DESIGN.md
- **Línea** se desbloquea en el Piso (`unlock_phase` 2) y no en el Galpón (DESIGN 3.4): el pedido pide 3 especiales en esta fase y la demo termina antes del Galpón.
- **Divisor de Pellets** 2,4 x 10^6 en vez de 10^5 (DESIGN 3.7 ya dice que el simulador lo ajusta).
- Costos por fase y `first_level_cost_factor` son parámetros nuevos en `data/economy.json`.
- `window/stretch` pasó a `canvas_items` con aspecto `expand` (base 1600x900) para que el HUD escale.
- El overlay F3 perdió el selector de tamaño de lámina (ya no hay láminas arbitrarias) y ganó la trampa "+1M Pops"; sigue sin existir en builds playtest y release.
- Los sonidos de interfaz (tic, sello, hito, cadena, reciclado) son provisorios, generados por `tools/gen_placeholder_sfx.gd`. No pude escuchar el audio desde esta sesión.
- La pantalla completa del Burbujario es de la Fase 4; por ahora es una lista.

### Pendiente
- Sonido real y mezcla.
- Manitos y rodillo automático (Fase 3).
- Dibujo de lejos para láminas grandes (Fase 3).
- Burbujario completo y logros (Fase 4).

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
