# Benchmark de dibujo, Fase 3

Máquina de referencia: AMD Radeon integrada (la medimos como sustituto de Steam Deck), Vulkan Forward+, vsync apagado, `scenes/benchmark.tscn`, 20 s por variante (15 s la c), 2 s de calentamiento, modo ventana.

```
godot --path . --resolution 1280x800 scenes/benchmark.tscn -- --variant=all --seconds=20 --auto-quit
godot --path . --resolution 1600x900 scenes/benchmark.tscn -- --variant=all --seconds=20 --auto-quit
```

Variantes: **a** 500x500 con la cámara cerca recorriendo la lámina (círculos de radio 3 a 10 por frame); **b** 1000x1000 con la cámara lejos y cadenas masivas (círculos de radio 10 a 24 por frame); **c** 1000x1000 con zoom de cerca a lejos en 5 s (y de vuelta). `--shots=<carpeta>` guarda capturas.

## Resultados (corrida con la máquina tranquila)

| Variante | Resolución | fps promedio | p1 (fps) | frame prom | p95 | draw calls |
| --- | --- | --- | --- | --- | --- | --- |
| a) 500x500 cerca | 1280x800 | 94,4 | 60,5 | 10,6 ms | 13,9 ms | 8 |
| b) 1000x1000 lejos + cadenas | 1280x800 | 136,5 | 85,4 | 7,3 ms | 8,6 ms | 225 |
| c) zoom cerca a lejos | 1280x800 | 144,9 | 140,8 | 6,9 ms | 7,0 ms | 260 |
| a) 500x500 cerca | 1600x900 | 95,9 | 76,2 | 10,4 ms | 12,3 ms | 8 |
| b) 1000x1000 lejos + cadenas | 1600x900 | 108,5 | 66,0 | 9,2 ms | 11,1 ms | 228 |
| c) zoom cerca a lejos | 1600x900 | 101,7 | 70,6 | 9,8 ms | 12,8 ms | 72 |

Objetivo (60 fps promedio y p1 >= 45 a 1280x800): **cumplido en las tres variantes**.

**Advertencia de ruido**: esa GPU integrada la comparten todos los procesos de Godot abiertos. Con 4 a 6 procesos de Godot corriendo a la vez (otros benchmarks, grabaciones) las mismas variantes dieron 76 a 98 fps promedio y p1 de 35 a 48 fps, con picos aislados de 20 a 100 ms que no se repiten en los mismos frames. Para medir hay que cerrar todo lo demás. Antes del dibujo de lejos, la variante b a 1280x800 daba ~6 fps (1000x1000 con 228 bloques de MultiMesh de ~240 triángulos por burbuja).

## Qué se hizo

- **Textura de estado** (`StatePacker`, `FarView`): un píxel RGBA8 por burbuja (R presión/2, G aplastamiento, B progreso de reventón, A tipo*32). Un buffer, una imagen y una textura por bloque de 64x64; las celdas se escriben directo en bytes (sin crear `Color`) y solo se vuelve a subir la textura de los bloques que cambiaron y que se ven de lejos.
- **Plano de lejos** (`shaders/far_sheet.gdshader`): un plano por bloque. Calcula la celda hexagonal en el fragmento, dibuja domos falsos (normal y brillo del fragmento, iluminados por la luz de la escena), reventadas aplastadas con arrugas, y especiales con color y forma simplificada (dorada, bomba con punto, línea con bandas, eco verde). Cuando una celda ocupa menos de ~4 px pasa a un color plano promedio leído de un mipmap de la textura, para evitar moiré.
- **Cerca/lejos sin saltos** (`SheetView._update_far_flags`): por bloque, según la distancia de la cámara a su centro, el plano de lejos aparece con un fundido corto (margen 18 unidades alrededor de 55) encima de los domos y estos se apagan cuando el de lejos ya es opaco. Los bloques de MultiMesh lejanos se ocultan. El frustum culling por bloque lo hace el motor con el `custom_aabb` de cada MultiMesh y con la caja de cada plano.
- **Menos trabajo de CPU**: en bloques que solo se ven de lejos no se animan los reventones (quedan directo reventados); láminas de más de 60.000 celdas usan un domo de 54 triángulos (3 anillos, 9 segmentos) en vez de 240. Antes del cambio, 10.000 celdas animándose por frame costaban ~21 ms de CPU en la vista; ahora ~1 ms.

## Qué limita

- **Cerca (a)**: el relleno de domos transparentes con alfa (muchas capas sin ordenar) y los ~250.000 x 54 triángulos de la zona visible. Es lo más pesado (10,6 ms): GPU, no CPU (la vista gasta ~1 ms).
- **Lejos (b, c)**: relleno del plano con el shader de hexágonos (una lectura de textura más matemática por píxel) y 225 draw calls de bloques; sigue por debajo de 9 ms.
- **Pendiente**: el shader de lejos no soporta todavía el rollo de reciclado (solo láminas chicas se reciclan hoy) y el plano de lejos no proyecta sombra.

## Notas para mergear

- Archivos nuevos: `src/view/far_view.gd`, `src/view/state_packer.gd`, `shaders/far_sheet.gdshader`, `tests/test_state_packer.gd`, este documento.
- Modificados: `src/view/sheet_view.gd` (la API pública no cambió; ahora tiene `far`, `near_distance`, `fade_margin` y `last_process_us`) y `src/view/benchmark.gd`.
- No se tocaron `src/sim/`, `data/`, `main.gd` ni `toy_world.gd`.
- El dibujo de lejos solo se activa para láminas de más de 20.000 celdas (`SheetView.FAR_MIN_CELLS`), así que el juego actual (hasta 40x40) no cambia. Para láminas de 80x80 y 150x150 de la Fase 3 también queda en el modo de domos reales (6.400 y 22.500 celdas): la de 150x150 (22.500) ya usa el dibujo de lejos.
- No se pudo correr la build de Linux (esta tarea no la incluía).
