# Clips para marketing

Escenas guionadas sin interfaz en `scenes/clips/` (código en `src/view/clips/`). Cámara y herramienta automáticas, lámina precargada de tensas. `ClipBase` resuelve la lámina, las cadenas (`ChainSolver`), el audio y las partículas; cada clip solo escribe `setup()` y `script_step()`.

## Grabar

```
tools/record_clip.sh <1|2|3|4> [vertical|horizontal]
.\\tools\\record_clip.ps1 -Clip 1 -Format horizontal
```

Usa el Movie Maker de Godot (`--write-movie`, 60 fps fijos, con el audio del juego). Vertical = 1080x1920 (shorts), horizontal = 1920x1080. El archivo queda en `builds/clips/<clip>_<formato>.avi` (MJPEG, carpeta ignorada por git). No hay ffmpeg en esta máquina; para subirlos a las redes conviene recomprimir a MP4 con `ffmpeg -i x.avi -c:v libx264 -crf 18 x.mp4`.

Para revisar un clip sin grabarlo: `godot --path . scenes/clips/clip_1_zoom_out.tscn -- --clip-shots=<carpeta>` guarda 4 cuadros.

## Clips de prueba generados (vertical, 1080x1920, 60 fps)

| Clip | Qué muestra | Duración | Peso (AVI MJPEG) | Tiempo de grabación |
| --- | --- | --- | --- | --- |
| 1 `clip_1_zoom_out` | Una burbuja de cerca; el dedo la revienta; la cámara se aleja hasta la lámina de 150x150 reventando en cadena | 15 s | 150 MB | 44 s |
| 2 `clip_2_pin_wave` | Tres pasadas del palo de amasar; el aire corre por delante y arma una ola de tensas | 13 s | 124 MB | 36 s |
| 3 `clip_3_iron_bomb` | La plancha prepara (calor) y una bomba dispara la cadena | 15 s | 100 MB | 35 s |
| 4 `clip_4_transition` | Transición Piso a Galpón: la lámina se arruga y se enrolla, entra la nueva, cambian escenario, luz y cámara en 4 s | 13 s | 97 MB | 28 s |

## Enchufes pendientes

- **Plancha (clip 3):** el calor se simula a mano en `_apply_heat()` de `clip_3_iron_bomb.gd` (sube presiones en un rectángulo) y la plancha es un `Node3D` de cajas. Cuando exista la plancha real en la sim, reemplazar `_apply_heat()` y `_iron` por su `ToolModel` y su visual.
- **Dibujo de lejos:** el clip 1 termina con la lámina de 150x150 vista desde lejos; mejora cuando se integre el plano de lejos de la sección 1.
- **Audio:** el Movie Maker graba lo que reproduce el motor (pops, crepitar y ambiente del escenario). No pude escucharlo desde esta sesión.
