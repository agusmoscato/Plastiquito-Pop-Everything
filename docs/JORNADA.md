# Jornada de pulido — 2026-11-17

Trabajo autónomo en la PC del dueño en **modo invisible**: nada con ventana ni sonido. Godot solo
`--headless`, Blender solo `-b`, procesos pesados con prioridad BelowNormal y de a uno. El render
del juego (capturas, prueba de humo con imagen, clips) quedó preparado en GitHub Actions
(`.github/workflows/render.yml`), con resultados en la rama `renders`, carpeta `<sha corto>/`.

## Estado en una línea

**No se mergea a `main` y la rama no está pusheada.** Desde esta sesión no se puede hacer push a
GitHub (ver "Bloqueo de push"), así que `render.yml` todavía no corrió nunca. Hay 7 commits locales
en `fase-3b` con lint, tests (159) y prueba de humo headless en verde. El balance completo no cierra
para los tres perfiles (tabla abajo).

## Bloqueo de push (lo primero que hay que resolver)

- HTTPS: no hay credencial guardada y la sesión no puede abrir el inicio de sesión de Git Credential
  Manager (sería una ventana). `git push` falla con "terminal prompts disabled".
- SSH: `~/.ssh/config` usa `id_ed25519_botdesk` para github.com y GitHub la rechaza ("Permission
  denied (publickey)") para este repo. No probé otras claves (se bloqueó, con razón: no es la
  identidad configurada).
- Consecuencia: ninguna corrida de `render.yml`. **No hay capturas del juego de hoy**: lo visual del
  juego (B2, B3, B4) está implementado pero sin ver. Los modelos (B1) sí se vieron con renders de
  Blender.
- **Para destrabar:** desde la PC, `git push origin fase-3b`, o agregar la clave pública de
  `botdesk` como deploy key con escritura en el repo. El push dispara `render.yml` en Actions:
  capturas, prueba de humo con imagen y (con `[clips]` en el mensaje del commit, o a mano con
  `workflow_dispatch` y "clips") los 5 clips con reporte de audio.

## Incidente previo a la jornada

Antes de arrancar se probó `tools/run_office.ps1`, que abría Godot con ventana y la mandaba al
escritorio virtual 2. La ventana llegaba al escritorio 2 en 8-13 ms, pero en la segunda prueba tomó
el foco y cambió el escritorio activo del dueño durante ~3 s. Se cerró todo, se borró el script y
desde entonces está prohibido abrir ventanas en esta PC. Quedó instalado el módulo de PowerShell
`VirtualDesktop` (alcance de usuario; se saca con `Uninstall-Module VirtualDesktop`).

---

## B0. Estabilizar — HECHO (salvo la corrida de CI)

- **`render.yml`** (y `.github/actions/setup-godot`, `tools/ci/*.sh`): lavapipe + xvfb, Godot 4.4.1
  de Linux en caché, trabajos en paralelo (`--demo-shot`, `--demo3`, `--demo-tools`, `--smoke`) y
  clips solo con `[clips]`. Publica JPG (1600 px, calidad 85), logs y `RESUMEN.md` en
  `renders/<sha>/`, y falla si un log tiene `ERROR`, `NaN`, `!v.is_finite()` o `SCRIPT ERROR`
  (sube igual las capturas). **Sin probar**: no se pudo pushear.
- **Prueba de humo** (`SmokeBot`, `--smoke=<carpeta> --minutes=N`): juega el juego real con eventos
  de entrada, compra haciendo clic en la hoja de pedidos, cambia de herramienta, recicla con Tab y
  salta de fase con DEV. Con ventana (CI) usa eventos reales; sin pantalla (`tools/smoke_headless.sh`,
  en esta PC) entrega los clics al control y las teclas al juego, porque `--headless` no reparte la
  entrada. Resultado headless: `SMOKE OK`, 12 compras, 3 reciclados, 3 saltos de fase, sin errores.
- **Bug 1 (NaN en `instance_set_transform`)**: el resorte de la herramienta usaba Euler explícito con
  rigidez 260; con frames de más de ~0,1 s (render por software en CI, primer frame) divergía a
  infinito. `SpringMath` integra en subpasos de 1/240 s, acota el delta y vuelve al reposo si algo
  no es finito. `test_spring.gd` reproduce el bug con el método viejo.
- **Bug 2 (la mano no se ve en 02_hud_tienda)**: misma causa. En Linux con lavapipe los primeros
  frames duran segundos, el resorte explotaba, el transform quedaba NaN y la mano no se dibujaba (en
  Windows, con frames normales, sí se veía). Queda para confirmar en la primera corrida de CI.
- **Bug nuevo, encontrado por la prueba de humo**: cada salida dejaba
  `ERROR: 1 resources still in use at exit` con el ambiente que sonaba (el servidor de audio suelta
  las reproducciones paradas recién en su update del hilo principal). `PopAudio.quit_clean()` para
  todo, deja pasar 3 frames reales y sale; todas las salidas del juego pasan por ahí.
- Lint, tests y paso "balance" de `run_tests.sh` (fases 1 y 2, activo y casual, 3 semillas): verdes.

## B1. Modelos 3D — PARCIAL (aprobados plancha y palo; mano, manitos y bota no)

Tres rondas con el subagente revisor (no vio el trabajo; recibió renders, UI_STYLE y checklist).

- **Mano** (`art/models/hand.py`, reescrita): dedos como tubos propios de 2,4 cm (1/4 de la palma)
  con nudillos, yema y punta redonda, largos 100/93/93/75 %, abanico y curva; pulgar a 45° con
  eminencia tenar y 2 falanges; palma con espesor; muñeca al 80 %; 8 cm de antebrazo; pesos por
  anillo (el Skin + pesos automáticos dejaban membranas y dedos estirados). Empties `contact_point`
  y `contact_palm` que `HandRig` usa en vez de coordenadas fijas. **Se encontró que el signo de
  rotación de `HandRig` estaba invertido** (los dedos cerraban hacia el dorso); `test_hand_rig.gd`
  lo fija. Giro en el juego 55° (el índice se ve de perfil).
- **Bota** (`boot.py`, reescrita): loft de secciones con forma de planta sobre una silueta lateral;
  cuello acolchado abierto, lengüeta, puntera y contrafuerte (color por vértice con ribete), suela
  que sigue el contorno con taco y tacos, ojales y cordones cruzados sobre la superficie. 3.838 tris.
- **Plancha**: cable sobre curva Catmull-Rom con protector; asa más gruesa. **Palo**: sin el anillo
  duplicado del medio (era la costura); barniz brillante y canto redondeado.
- **Manitos**: material en dos pasadas (profundidad + fresnel tenue: solo la cara de afuera), solo la
  mano al 80 % de la del jugador, todas igual orientadas y separadas (`AutomationView.separate`).

| Modelo | (1) 64 px | (2) juguete limpio | (3) proporciones | (4) silueta | Revisor | Render |
| --- | --- | --- | --- | --- | --- | --- |
| Mano | no | no | no | no | NO APROBADO | [juego](screens/jornada/B1/despues_hand_juego.jpg) · [64](screens/jornada/B1/despues_hand_juego_64.jpg) · [lado](screens/jornada/B1/despues_hand_lado.jpg) |
| Manitos | a medias | no | no | no | NO APROBADO | [juego](screens/jornada/B1/despues_hand_ghost_juego.jpg) |
| Bota | sí (lateral), no (juego) | casi | regular | regular | NO APROBADO ("le falta poco") | [lado](screens/jornada/B1/despues_boot_lado.jpg) · [juego](screens/jornada/B1/despues_boot_juego.jpg) |
| Plancha | sí | sí | sí | sí | APROBADO | [juego](screens/jornada/B1/despues_iron_juego.jpg) |
| Palo | sí | sí | sí | sí | APROBADO | [3/4](screens/jornada/B1/despues_pin.jpg) · [64](screens/jornada/B1/despues_pin_64.jpg) |

Lo que el revisor sigue marcando (última ronda) y el próximo paso:
- Mano: la unión palma-puño se ve como dos piezas apoyadas; el antebrazo sigue dominando con la
  cámara del juego (cumple los 8-10 cm de la especificación, pero el revisor lo quiere más corto: la
  especificación manda y queda anotado); a 64 px es "una salchicha". Próximo paso: fundir palma, muñeca
  y puño en una sola malla (remallado por vóxeles con pesos por distancia a los huesos) y probar un
  ángulo de juego con el índice más despegado.
- Manitos: palma demasiado grande al lado de los dedos y pulgar que cuelga. Próximo paso: modelo
  propio más chico de palma.
- Bota con la cámara del juego: se lee como "maceta"; falta quiebre en el tobillo.

## B2. Íconos y legibilidad del HUD — HECHO EN CÓDIGO, SIN VER

- "+N": como mucho 12 en pantalla (los que sobran se suman al más cercano), una cadena = un solo "+N"
  que sale del centro de la cadena cuando termina, contorno de papel, y nunca se dibujan dentro de un
  panel del HUD (nacen afuera y pasan "por detrás"). Tests.
- Odómetro: recorte explícito del dibujo de cada rodillo y dígito centrado de 25 px (no se enciman).
- Sello CADENA ×N: arriba del origen de la cadena (95 px más arriba que la ola), dentro de la zona
  libre de paneles, al 85 % de opacidad. F9 oculta todo el HUD, así que no aparece. Test.
- **Pendiente**: íconos de herramientas y tienda ("manchitas azules"). Usan el modelo 3D real en un
  SubViewport (`ToolIcon`); el encuadre cerrado (yema apretando, palma desde arriba, mano agarrando
  el palo) necesita ver el resultado y no hubo forma hoy.

## B3. Escala y escenarios — PARCIAL, CON UN CONFLICTO PARA EL DUEÑO

- `tools/tool_scale_report.gd` mide sin pantalla qué fracción del alto ocupa cada herramienta con la
  cámara por defecto de cada fase ([informe](escala_herramientas.txt)):

| Fase | Herramienta | Lámina | Burbuja en pantalla | Alto de la herramienta |
| --- | --- | --- | --- | --- |
| 1 Mesa | dedo / palma | 8x8 | 122 px | 99 % / 165 % |
| 2 Piso | palo | 40x40 | 22 px | 13,2 % |
| 3 Galpón | plancha | 80x80 | 9,4 px | 11,2 % |
| 4 Estacionamiento | bota | 150x150 | 4,3 px | 3,4 % |

- **Conflicto (no lo decidí yo, CLAUDE.md pide avisar):** el pedido dice "burbujas de al menos
  10-12 px" y "herramienta 8-15 % del alto con su tamaño visual igual a su área de golpe". DESIGN.md
  (pilar 3) dice que la cámara se aleja en cada fase y que la lámina enorme se ve entera. Las dos
  cosas no entran: encuadrar 150x150 deja burbujas de 4 px, y una mano cuyo dedo mida una burbuja
  ocupa la pantalla entera sobre la lámina de 8x8. Dejé implementado un tope de cámara por tamaño de
  burbuja (`camera_min_bubble_px` en `data/juice.json`, con test), **apagado (0)**. Con 11 px: plancha
  13,2 %, bota 7,9 %, pero las fases 3 y 4 quedan a la misma distancia (se pierde el alejamiento) y los
  escenarios quedan fuera de cuadro. Para la Mesa, cumplir 8-15 % pide alejar la cámara hasta que la
  lámina de 8x8 ocupe ~11 % de la pantalla. Opciones: (a) mantener DESIGN y aceptar burbujas chicas de
  lejos, (b) activar el tope en las fases 3-4, (c) achicar la mano en la Mesa aunque el dedo sea más
  chico que la burbuja.
- Escenarios a escala real (1 u = 1 cm): pared de 120 cm, zócalo de 8, ventana de 60x70, líneas de
  10 cm, cordón de 15x15, farol de 4 m, estacionamiento con lugares de 250 cm (antes medían 6,5 cm)
  y líneas con antialias solo fuera de la lámina. Test: ninguna malla pisa la lámina ni queda entre
  la cámara y la lámina, en las 4 fases. El polvo del galpón (partículas) sí flota sobre la lámina.
- Lámina de lejos: borde de cada domo con antialias por derivadas (`fwidth`) en vez de `discard`.
  FXAA activado (solo 3D). **Sin compilar**: `--headless` no compila shaders espaciales; lo verifica
  la primera corrida de CI.
- **Pendiente**: pulir cada escenario con el revisor (necesita capturas).

## B4. Habilidades — HECHO EN CÓDIGO, SIN VER

- Eco: brillo que late cada vez más rápido en los 1,4 s antes de reinflarse (`EchoGlow`, test) y
  sonido de aire al reinflarse (`ph_air.wav`, provisorio, generado).
- Plancha: vapor que sale de la suela (partículas en `ToolView`). Bota: anillo de polvo radial y
  burbujas que saltan en cada pisotón (`FxPool.stomp_at`).
- Clip 3 con la plancha real (`ToolModel` rectangular con calor, tope y alcance de `economy.json`,
  y su modelo): `_apply_heat()` eliminado. Clip 5 nuevo: tres pisotones de bota en el Estacionamiento.
- Rollo de reciclado también en láminas lejanas: `roll_up_z` y `crumple` en `far_sheet.gdshader`.
- **Pendiente**: la pregunta "¿esta herramienta se siente distinta y mejor que la anterior?" necesita
  jugar; ver la lista para ojos y oídos humanos.

## B5. Lo incremental — PARCIAL

- **TURNO NOCHE** hecho y documentado en DESIGN.md 3.5: tras 8 s sin tocar, las Manitos tocan x1,5
  y rinden x8 en total; sello en el HUD, luz y ambiente más fríos, manitos más rápidas, entrada en
  ~2 s y salida en ~0,7 s. Tests de la sim.
- `idle_hand_mult` 16 → 8. Con 16 el idle rendía el 136 % del activo.
- **Cambio en la medición** (documentado en DESIGN 3.5): el cociente idle/activo se mide en Pops
  normalizados por la base de cada fase. En crudo saltaba de 2 % a 83 % según quién cruzara de fase
  unos minutos antes (probado con 4, 5, 7, 9, 13 y 16): no había valor que cerrara.
- `tools/balance_full.sh` ahora corre 3 semillas (y `SEEDS`/`PROFILES` para iterar).
- **Lo que no cierra y por qué** (medido con el desglose de Pops por origen que agregué al simulador):
  1. El casual llega al Estacionamiento antes que el activo (110 contra 171 min) porque usa la
     plancha como sello: cada golpe revienta el rectángulo entero (~120 burbujas/s) contra ~32/s
     planchando. En el Galpón el casual saca el 46 % de directo; el activo, el 11 %.
  2. Probé que la plancha aplaste al 25 % quieta y entero deslizándose (`iron_still_force`, en el
     código, hoy en 1,0 = apagado): el casual pasa a llegar a los 132 min (aprueba), pero la plancha
     deja de rendir más que el palo para el casual (0,01x) y el activo empeora en esperas. Necesita
     rebalancear la plancha entera, no un número.
  3. El "% del tiempo con compra a mano" del activo (63-64 %) falla porque solo recicla al juntar
     para la lámina siguiente: partidas de 60 y 80 minutos en las que los costos crecen más rápido
     que el ingreso. Propuesta: más mejoras baratas por fase o crecimiento de costo más bajo en las
     fases 3-4.
  4. Bajar el tope del calor (1,4 → 1,32) o endurecer los rendimientos decrecientes de las cadenas
     no movió nada (revertido).

### Tabla del simulador completo (215 min, `--dt=20`, semillas 1-3)

Datos finales del día (`idle_hand_mult` 8, resto igual al WIP). Valores de las semillas 1 / 2 / 3.

| Métrica | Objetivo | Activo | Casual | Idle |
| --- | --- | --- | --- | --- |
| Mediana entre compras 0-10 min | 15-40 s | 19,0 / 18,0 / 18,5 ✔ | 21,0 / 20,5 / 20,5 ✔ | n/a |
| Mediana entre compras 10-45 min | 30-90 s | 33,5 / 32,5 / 33,0 ✔ | 36,9 / 37,5 / 38,5 ✔ | n/a |
| Máx. sin poder comprar 0-45 min | <= 120 s | 74 / 69 / 93 ✔ | 83 / 89 / 117 ✔ | n/a |
| % tiempo con compra pagable o a < 30 s | >= 70 % | 63,0 / 61,1 / 63,4 ✘ | 68,0 / 61,5 / 60,7 ✘ | n/a |
| Primera cadena 10+, primera dorada, palma | < 3 / < 4 / < 8 min | ✔ | ✔ | n/a |
| Llegada al Piso y primer reciclado | 28-42 min | 30,1 / 30,0 / 30,0 ✔ | 36,9 / 37,3 / 37,7 ✔ | 36,9 / 37,3 / 37,7 |
| Mediana entre compras 45-210 min | 30-120 s | 50 / 51 / 50 ✔ | 20,5 / 21,0 / 20,0 ✘ | n/a |
| Máx. sin poder comprar 45-210 min | <= 180 s | 163 / 211 / 262 ✘ (1 de 3 ✔) | 309 / 440 / 594 ✘ | n/a |
| Llegada al Galpón | 72-108 min | 91,9 / 92,4 / 92,4 ✔ | 93,7 / 94,0 / 94,0 ✔ | 93,7 / 94,0 / 94,0 |
| Llegada al Estacionamiento | 120-180 min | 171,4 / 174,5 / 172,9 ✔ | 110,2 / 111,0 / 110,9 ✘ | no llega |
| Recuperación tras reciclar | < 40 % | 15 / 0,3 / 47 ✘ (2 de 3 ✔) | 58 / 69 / 92 ✘ | n/a |
| Herramienta nueva contra la anterior | >= 2x | 3,5 / 5,2 / 3,5 ✔ | 3,6 / 2,2 / 3,0 ✔ | n/a |
| Idle contra activo (normalizado por fase) | 20-45 % | n/a | n/a | 33 / 30 / 32 ✔ |

Resumen: idle aprobado en las 3 semillas (antes 136 %). Fases 1 y 2 aprobadas en los dos perfiles
activos. Fallan, como en la línea de base, las métricas de las fases 3-4 del activo (disponibilidad
de compras) y del casual (va demasiado rápido al Estacionamiento y después se queda sin compras).

## B6. Clips, repo y exportación — PARCIAL

- 5 clips listos para `render.yml` (`[clips]`): MP4 H.264 veryfast CRF 20 + AAC (recodifica a CRF 26
  si pasa 15 MB), 4 cuadros de control por clip y reporte de audio con volumedetect, astats y RMS por
  segundo (para ver si el crepitar se dispara). **Sin correr** (sin push).
- `docs/screens`: 44 PNG pasadas a JPG (1600 px, calidad 85, todas < 500 KB; 65 MB → 8,6 MB) y
  `docs/screens/_tmp` borrada.
- Versión 0.2.0. Exportaciones con `--headless --export-release` en esta PC, sin ejecutarlas:
  `builds/0.2.0/windows/Plastiquito.exe` (99 MB) y `builds/0.2.0/linux/Plastiquito.x86_64` (73 MB),
  logs sin errores. (`builds/` no va a git.)
- Benchmarks de rendimiento: suspendidos hoy (necesitan ventana).

---

## Galería ANTES / DESPUÉS

Solo hay pares de los modelos (renders de Blender). El resto de los cambios visuales espera la
primera corrida de `render.yml`: el "antes" va a ser la carpeta del commit `2485fbf` en la rama
`renders` (el WIP sin arreglos, con el workflow) y el "después", la del último commit.

| Modelo | Antes | Después |
| --- | --- | --- |
| Mano (3/4) | [antes](screens/jornada/B1/antes_hand.jpg) | [después](screens/jornada/B1/despues_hand.jpg) |
| Mano (lado) | [antes](screens/jornada/B1/antes_hand_lado.jpg) | [después](screens/jornada/B1/despues_hand_lado.jpg) |
| Mano (cámara del juego) | — | [después](screens/jornada/B1/despues_hand_juego.jpg) |
| Bota (3/4) | [antes](screens/jornada/B1/antes_boot.jpg) | [después](screens/jornada/B1/despues_boot.jpg) |
| Bota (lado) | [antes](screens/jornada/B1/antes_boot_lado.jpg) | [después](screens/jornada/B1/despues_boot_lado.jpg) |
| Plancha | [antes](screens/jornada/B1/antes_iron.jpg) | [después](screens/jornada/B1/despues_iron.jpg) |
| Palo | [antes](screens/jornada/B1/antes_pin.jpg) | [después](screens/jornada/B1/despues_pin.jpg) |

## PARA REVISAR CON OJOS Y OÍDOS HUMANOS

- **Todo lo visual del juego de hoy**, porque nadie lo vio: HUD ("+N", odómetro, sello de cadena y de
  turno noche), luz fría del turno noche, vapor, polvo de la bota, brillo del Eco, rollo en láminas
  grandes, escenarios a escala real, FXAA y antialias de la lámina de lejos.
- La mano nueva en movimiento: si al apretar el índice se dobla hacia la lámina (se corrigió el signo
  de las poses: antes los dedos cerraban hacia el dorso).
- El sonido de aire del Eco (provisorio, generado) y si el crepitar masivo no satura (los clips traen
  el reporte de ffmpeg cuando corran).
- Sensación: ¿el turno noche da gracia o se siente como castigo por jugar? ¿Cada herramienta se siente
  distinta y mejor que la anterior? ¿El pisotón de la bota pesa?
- Si la plancha "como sello" es divertida aunque rompa el balance, o si conviene que solo planche.

## Pendientes que necesitan ventana o al dueño en Windows

- Push de `fase-3b` (destraba todo lo de CI). Ver "Bloqueo de push".
- Benchmarks de rendimiento (sobre todo con FXAA y el antialias nuevo de la lámina de lejos).
- `JUGAR.bat`, accesos directos del escritorio, instalador con Inno Setup e ícono con rcedit.
- Decidir el conflicto de escala de cámara contra el pilar 3 (B3).

## Próximos pasos, por prioridad

1. Pushear `fase-3b`, revisar la carpeta de la rama `renders` (capturas, humo con imagen, logs) y
   arreglar lo que aparezca. El shader de lejos cambiado no se compiló nunca.
2. Pasar las capturas al revisor externo por bloque (B2, B3 y B4) y corregir.
3. Commit con `[clips]` para los 5 clips y el reporte de audio.
4. Balance de las fases 3-4: rediseñar la plancha (sello contra planchado) y la cadencia de compras
   del activo; métricas con 3 semillas.
5. Mano, manitos y bota hasta la aprobación del revisor (fundir la malla de la mano).
6. Íconos de la tienda con encuadre cerrado (necesita ver el resultado).

## Definición de terminado: NO se cumple, no se mergeó

- Lint y tests: ✔ (159). Balance completo con los 3 perfiles: ✘ (activo y casual en fases 3-4).
- Prueba de humo de `render.yml`: ✘ (no corrió; la headless da ✔).
- Modelos aprobados por el revisor: ✘ (plancha y palo sí; mano, manitos y bota no).
- CHANGELOG y DESIGN.md: ✔.
