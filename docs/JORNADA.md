# Jornada de pulido — 2026-11-17

Trabajo autónomo en la PC del dueño en **modo invisible**: nada con ventana ni sonido. Godot solo
`--headless`, Blender solo `-b`, procesos pesados con prioridad BelowNormal y de a uno. El render
del juego (capturas, prueba de humo con imagen, clips) corre en GitHub Actions
(`.github/workflows/render.yml`) y queda en la rama `renders`, carpeta `<sha corto>/`.

## Estado en una línea (fin de la tercera sesión)

`fase-3b` pusheada, CI de render en verde (capturas, herramientas, prueba de humo y demo3), lint y
170 tests en verde. **No se mergea a `main`**: el dueño revisa las capturas primero.

---

# Sesión 3 (misma fecha, noche): cámara, legibilidad, íconos

Antes / después (todo en [screens/sesion3/](screens/sesion3/)):

| | Antes | Después |
| --- | --- | --- |
| Mesa | [mesa_antes](screens/sesion3/mesa_antes.jpg) (c300a6a) | [mesa_despues](screens/sesion3/mesa_despues.jpg) (7b69b59) |
| Mano en el juego | [mano_juego_antes](screens/sesion3/mano_juego_antes.jpg) | [mano_juego_despues](screens/sesion3/mano_juego_despues.jpg) · [primer plano apretando](screens/sesion3/mano_primer_plano.jpg) |
| Mano (Blender) | [mano_antes](screens/sesion3/mano_antes.jpg) | [mano_despues](screens/sesion3/mano_despues.jpg) |
| Bota (Blender) | [bota_antes](screens/sesion3/bota_antes.jpg) | [bota_despues](screens/sesion3/bota_despues.jpg) |
| Íconos | [iconos_antes](screens/sesion3/iconos_antes.jpg) | [iconos_despues](screens/sesion3/iconos_despues.jpg) · [hoja de contactos con la prueba a 48 px](screens/iconos.jpg) |

Una captura por fase con la cámara de trabajo: [Mesa](screens/sesion3/t050_fase1.jpg) ·
[Piso](screens/sesion3/t100_fase2.jpg) · [Galpón](screens/sesion3/t200_fase3.jpg) ·
[Estacionamiento](screens/sesion3/t275_fase4.jpg) · [sello de cadena](screens/sesion3/cadena.jpg).
Todas las corridas están en la rama `renders` (carpetas `c495e56` a `7b69b59`).

## 1. Encuadre (lo más grave)
- **Regla nueva** (`CameraRig.work_plan`): la lámina entera llena el área de juego (la zona a la
  izquierda de la hoja de pedidos) mientras sus burbujas midan 10 px o más; si no entra, la cámara
  queda a 10 px y sigue a la herramienta. Informe por tamaño de lámina:
  [escala_herramientas.txt](escala_herramientas.txt) (Mesa 8x8: 82 px por burbuja; Piso 40x40: 16 px;
  Galpón y Estacionamiento: 10 px, y la cámara sigue).
- La herramienta mide una **fracción fija del alto de la pantalla** (`tool_screen_fraction`: mano 16 %,
  plancha 16 %, resto 12 %, manitos 8 %). En las capturas de CI encontré un error mío: medía el alto
  con la caja alineada a los ejes, y la mano girada 55° salía 2,3 veces más chica. Ahora proyecta los
  vértices reales (con test). El rebote del pisotón ya no crece con esa escala (en la fase 4 mandaba la
  bota a la otra punta).
- **Utilería**: se fue la lámpara (el disco oscuro con palo y la mancha amarilla); queda solo su luz
  cálida. La taza y los lápices, a escala real, se ubican con el mismo `camera_sheet_fill` para que
  asomen por los bordes sin tocar la lámina (test de geometría).
- **Revisión externa de e37b696**: la lámina de la Mesa llenaba el 84 % (la perspectiva agranda el
  borde cercano) y pasaba por debajo de las tarjetas, y la taza y los lápices quedaban fuera de cuadro.
  Bajé `camera_sheet_fill` a 0,58 y la zona libre del seguimiento al 35 % central (en la fase 4 la mano
  se iba a la esquina de la orden de trabajo).
  En el render de 7b69b59 la lámina llena ~70 % y no pasa bajo ninguna tarjeta. **Todavía no se cumple**:
  la taza y los lápices siguen fuera de cuadro (el film de la lámina tiene un margen grande y la
  utilería se ubica contra él), y en la fase 4 la mano sigue quedando en el tercio de arriba, con
  números flotantes que se pisan ([t275_fase4](screens/sesion3/t275_fase4.jpg)).

## 2. Legibilidad
- **Contorno** (`shaders/toon_outline.gdshader`): casco invertido en espacio de pantalla (1,6 px),
  oscuro en la mano y las herramientas. En las manitos va dentro de su material, en la cola
  transparente entre la pasada de profundidad y la visible: como overlay opaco las rellenaba enteras
  (se vio en CI y se corrigió).
- **Guante**: roughness 0,64, coat 0,15, luz de borde suave y color de vértice horneado en Blender, con
  oclusión en los pliegues y la palma un 14 % más oscura.
- **Mano**: antebrazo de 6 cm que se afina hacia la muñeca, borde enrollado fino (3,4 mm) pegado a la
  muñeca, pulgar en reposo a 44°. **Manitos** con subdivisión (Godot genera los LOD al importar; 12.900
  triángulos) y relleno al 6 %.
- **Bota**: seis pares de ojales, cordones más gruesos, moño con puntas largas y taco más alto (sube
  sobre el cuero en vez de levantar la bota).
- **IoU** contra los planos (actualizados a 6 cm de antebrazo y borde enrollado de 3 mm): bota 0,896 /
  0,850 (aprobada); mano 0,847 / 0,851. **La vista superior de la mano queda en 0,847, por debajo de
  0,85**: el antebrazo corto saca la zona que mejor coincidía con el plano. Probé el pulgar a 36, 40, 44
  y 48°, y 44 es el mejor. No toqué el plano para que pase.

## 3. Íconos
- `art/icons.py` (Blender -b) arma una escena por ícono a 256 px: fondo transparente, tres luces
  relativas a la cámara, contorno Freestyle y cámara ortográfica de encuadre cerrado. Las manos salen
  de `hand_mpfb.py --icon-poses` (señalar, palma y agarre, con los ángulos de `HandRig`).
- Herramientas: yema apretando una burbuja, palma desde arriba, mano agarrando el palo y la plancha,
  bota, manito, rodillo y burbuja. Mejoras, una por categoría: regla (tamaño), burbuja reventando
  (fuerza), estela (velocidad) y manitos (automatización). Las demás usan el ícono de su herramienta.
- `ToolIcon` pasa a ser un `TextureRect` con la misma API (ya no hay un SubViewport por ícono). Hay un
  test de que cada ícono existe. Prueba a 48 px: [iconos.jpg](screens/iconos.jpg).

## 4. Sello "CADENA ×N"
Ancho máximo del 35 % del área de juego. Si cae sobre un panel del HUD, prueba otras posiciones y se
queda con la que no tapa nada (con test). El revisor externo lo midió en 33-36 %, sin tapar paneles.

## 5. Balance (congelado)
Único cambio: **memoria del turno** rinde el doble (10 % de los niveles anteriores por nivel, hasta 8
niveles). Corrí `balance_full` una vez (215 min, 3 perfiles x 3 semillas), sin perseguir métricas:

| Perfil | Semilla 1 | Semilla 2 | Semilla 3 |
| --- | --- | --- | --- |
| Activo | falla solo recuperación (66 %) | falla solo recuperación (63 %) | falla solo recuperación (45 %; en la sesión 2 aprobaba) |
| Casual | % con compra 66 %, mediana 29 s, espera 254 s | % 66 %, espera 345 s, recuperación 89 % | % 66 %, espera 231 s |
| Idle | 41 % ✔ | 32 % ✔ | 24 % ✔ |

Las llegadas no cambian (Piso 30/37 min, Galpón 92/94, Estacionamiento 138-143). La memoria más fuerte
no movió la "recuperación": esa métrica la marcan los reciclados dentro del Estacionamiento.

## Revisor externo (capturas de e37b696)
- Aprobado: íconos a 48 px ("mucho mejor" que antes) y sello de cadena.
- Parcial: mano entre 11 y 17 % del alto; contorno (se ve en la mano, poco en la bota); guante menos
  globo; bota (los cordones se ven en el ícono, poco en el juego).
- Fallado: encuadre de la Mesa y utilería (corregidos en 7b69b59; ver el punto 1).
- No lo comparto: tomó por "la lámpara amarilla" a la burbuja dorada especial, que es una mecánica del
  juego.

## Pendientes
1. **Revisión del dueño** de las capturas (no se mergea antes).
2. **Utilería de la Mesa**: que la taza y las puntas de los lápices asomen de verdad (hoy no se ven).
   **Fase 4**: centrar mejor la herramienta al seguirla y separar los números flotantes.
3. **Rodillo automático**: a la escala de su franja real, el mango tapa media lámina en la Mesa. Hay
   que acostarlo o achicar el mango en `roller.py`.
4. **Puño en el juego**: el borde enrollado es tan fino que el contorno de 1,6 px lo pinta casi entero
   y se lee como una banda negra. Opciones: contorno más fino en la mano, o puño algo más grueso.
5. Mano: la vista superior del IoU en 0,847 (punto 2). Bota: los cordones casi no se leen a la escala
   del juego.
6. Burbujas: las vetas de la madera se ven como franjas a través de cada burbuja (refracción). En la
   tienda, los números flotantes se pisan y los cuatro íconos de mejoras globales son iguales.
7. Balance: la "recuperación" del activo y la disponibilidad de compras del casual (sin tocar, porque
   el balance está congelado).

---

## Estado al cierre de la sesión 2

`fase-3b` pusheada. CI de render en verde. Lint y 165 tests en verde. **No se mergea a `main`**: el
dueño revisa los modelos primero, y el balance de las fases 3-4 todavía no cierra para el activo y el
casual.

# Sesión 2 (misma fecha, tarde)

## Paso 0: push
- Se habilitó UNA vez la ventana de inicio de sesión de Git Credential Manager (permitido por el dueño
  para git) y el push funcionó. GCM tiene dos cuentas de GitHub; para pushear sin ventanas se fijó
  `credential.https://github.com.username = agusmoscato` en la config **local** del repo. Desde ahí,
  push sin ventanas después de cada tarea.
- Primera corrida de `render.yml` (`a922c12`): los 4 trabajos renderizaron; falló solo el chequeo de
  logs de `demo3` por "Invalid polygon data, triangulation failed" (el ticket sin conexión dibujaba una
  hoja de pocos píxeles). Arreglado en `UiKit` con test. Las corridas siguientes (`5d269e9`, `bcc26a9`)
  terminaron **en verde**: capturas, prueba de humo con imagen (26-27 capturas, 5 reciclados, 3 saltos
  de fase) y logs sin ERROR ni NaN. El bug 2 (la mano invisible) quedó confirmado como resuelto.

## Decisiones de diseño aplicadas (en DESIGN.md)
1. **Cámara de trabajo**: zoom fijo por fase (burbuja de 22/12/10/10 px, mínimo 10) que sigue a la
   herramienta con paneo suave; la transición de reciclado muestra la lámina entera 1,2 s y vuelve;
   con la rueda se ve todo. Las herramientas miden 9-15 % del alto con esa cámara
   ([informe](escala_herramientas.txt)). La Mesa usa 22 px: con 16 px la lámina de 8x8 quedaba como
   un parche chico sobre la mesa en la captura de CI.
2. **Plancha que quema**: quieta casi no aplasta (15 %), el calor solo se acumula si se desliza y,
   quieta más de 0,6 s, derrite el plástico (sin valor ni aire) con humo y chirrido. Tests.

## Modelos (prioridad principal)

### Licencias
| Modelo | Fuente | Licencia | Verificado en |
| --- | --- | --- | --- |
| Mano y manitos | MakeHuman / MPFB 2.0.18 (extensions.blender.org, sha256 verificado) | Assets **CC0** (código GPL, no se distribuye) | https://static.makehumancommunity.org/about/license.html (2026-11-17) |
| Bota | Propia: no hay bota de trabajo CC0 en Poly Haven (solo "Rubber Boots", de lluvia), Kenney ni Quaternius | Propia | API de Poly Haven y búsqueda web (2026-11-17) |
| Utilería | Sin cambios: lo CC0 de Poly Haven (cajas, cajones) es fotorrealista y con nuestros materiales planos perdía su detalle | Propia | — |

Registro completo: [assets/models/LICENSES.md](../assets/models/LICENSES.md).

### Método nuevo
- **Mano** (`art/models/hand_mpfb.py`): MPFB se carga dentro de Blender -b sin instalarlo
  (`art/mpfb_load.py`; `tools/get_mpfb.sh` lo baja y verifica). Humano adulto promedio, mano derecha +
  10 cm de antebrazo con los pesos reales de MakeHuman; reposo = mano plana estándar (dedos con
  abanico -5/-1/3/8°, pulgar a 40°), largo de mano 18,7 cm desde el pliegue (ANSUR II), dedos +10 %
  (en MakeHuman la palma es algo larga), guante (subdivisión, 1,5 mm, arrugas en articulaciones, caña
  floja, puño enrollado) y cortes redondeados. Esqueleto con los nombres de HandRig; `test_hand_rig`
  (sentido de flexión y pulgar pegado) en verde. 16.600 triángulos (la mano del jugador es una sola).
- **Manitos**: la misma mano sin antebrazo, cortada en el pliegue, sin subdivisión (3.200 triángulos).
- **Bota** (`art/models/boot.py`): perfil lateral 2D extruido como loft con ancho variable (pie),
  **Skin Modifier** para la caña (frente alto, quiebre en el tobillo), los dos volúmenes fundidos con
  remallado por vóxeles y decimados, boca abierta, suela por offset del contorno, origen en la base de
  la suela. 3.972 triángulos.
- **HandRig**: aducción del pulgar en "señalar" (sin eso la mano se leía como "pistola de dos caños").

### Verificación objetiva: IoU contra planos de proporciones reales
`art/blueprints/blueprint.py` genera los planos por código (medidas antropométricas y de una bota de
trabajo de 15 cm de caña); `art/check_iou.py` rasteriza la silueta del .glb en celdas de 1 mm, hace un
registro rígido chico (giro ±10°, corrimiento ±3 cm, **sin escala**) y calcula el IoU.

| Modelo | Vista superior | Vista lateral | Resultado | Superposición |
| --- | --- | --- | --- | --- |
| Mano | 0,851 | 0,852 | APROBADO (con poco margen) | [sup.](screens/modelos/iou_mano_superior.jpg) · [lat.](screens/modelos/iou_mano_lateral.jpg) |
| Bota | 0,895 | 0,853 | APROBADO | [sup.](screens/modelos/iou_bota_superior.jpg) · [lat.](screens/modelos/iou_bota_lateral.jpg) |
| Manitos (informativo) | 0,835 | 0,835 | no exigido | — |

Errores que encontré en el propio método y corregí, para que el número sea honesto: las cápsulas de los
dedos del plano agregaban su radio más allá del largo indicado; girar celdas ya rasterizadas dejaba
agujeros; la icoesfera que crea el importador glTF como forma de los huesos se colaba en la silueta.
El IoU de la mano se mide con la mano abierta (la pose de reposo): compara proporciones, no la pose.

### Revisor externo y las 4 preguntas
Cuatro rondas con subagentes que no vieron el trabajo (renders, superposiciones de IoU y capturas del
juego de la rama `renders`). Entre rondas se corrigieron el pulgar (aducción), el puño flotante, los
cortes en estrella, la costura dentada de la bota, la lengüeta que se leía como agujero y la bota
parada derecha en el juego. **Ronda final:**

| Modelo | (1) 64 px | (2) juguete limpio | (3) proporciones | (4) silueta | Revisor |
| --- | --- | --- | --- | --- | --- |
| Mano | no ("mancha azul") | a medias (grumos en el índice, cierre del antebrazo) | en planta bien; en 3/4 el antebrazo pesa mucho | puño como aro aparte | NO APROBADO |
| Manitos | no | no (facetado, espalda plana) | palma enorme | no | NO APROBADO (la peor pieza) |
| Bota | sí de perfil, no desde el juego | sí (una sola masa) | perfil bien, caña cilíndrica | cuello con dientes, cordones cortos, taco chico | NO APROBADO ("cerca") |
| Plancha | sí | sí | sí | sí | APROBADO |
| Palo | sí | sí | sí | sí | APROBADO |

Lo que pide para aprobar, en orden: (1) manitos recortadas de la mano buena **con subdivisión** (hoy
van sin ella para ahorrar triángulos: 12 manitos), (2) puño que salga del mismo volumen del guante y
antebrazo más corto en la vista de juego, (3) cuello de la bota fundido con la caña, lengüeta visible y
3-4 cruces de cordones, taco del ancho de la suela, (4) bota más de perfil con la cámara de 55°,
(5) ícono "DEDO" con la mano entera, (6) base de la plancha con un borde oscuro.
El IoU aprueba la mano y la bota; el revisor no. Son medidas distintas: el IoU dice que las
proporciones son reales, el revisor juzga la lectura y el acabado. **Ningún modelo nuevo queda aprobado
para mergear: necesitan la revisión del dueño.**

Renders: [mano señalando, cámara del juego](screens/modelos/hand_juego.jpg) ·
[mano 64 px](screens/modelos/hand_juego_64.jpg) · [mano de perfil](screens/modelos/hand_lado.jpg) ·
[manitos](screens/modelos/hand_ghost_juego.jpg) · [bota de perfil](screens/modelos/boot_lado.jpg) ·
[bota 3/4](screens/modelos/boot.jpg) · [bota 64 px](screens/modelos/boot_64.jpg) ·
[plancha](screens/modelos/iron_juego.jpg) · [palo](screens/modelos/pin.jpg).
Capturas del juego en la rama `renders` (carpetas por commit; las de los modelos finales:
`2b67524` con la mano final y `c300a6a` con la bota de perfil, todas en verde).

## Balance (3 perfiles x 3 semillas, 215 min)
Cambios: costos de la fase 3 -32 %; plancha de radio 4 (antes 2,5); bota de radio 5 y 2 s de recarga
(antes 3 y 4 s: con la plancha mejor, la bota recién comprada rendía 0,41x); el bot casual arrastra la
plancha (sellar ya no rinde); `idle_hand_mult` 8.

| Perfil | Semilla 1 | Semilla 2 | Semilla 3 |
| --- | --- | --- | --- |
| Activo | falla solo recuperación tras reciclar (66 %) | falla solo recuperación (63 %) | **todo APROBADO** |
| Casual | % con compra 66 %, mediana 45-210 29 s, espera 253 s | % 67 %, espera 252 s, recuperación 89 % | % 66 %, espera 231 s |
| Idle | 42 % ✔ | 33 % ✔ | 26 % ✔ |

Llegadas: Piso 30/37 min, Galpón 92/94, Estacionamiento 138-143 (activo/casual), todo dentro de los
objetivos. **No cierra todo en verde.** Lo que queda es de la economía de las fases 3-4: las mejoras
salen en ráfagas (descuento de fase nueva) y después hay esperas de unos 4 minutos; la "recuperación"
falla por los reciclados dentro del Estacionamiento, que vuelven a 0 sin mejoras permanentes que
alcancen. Propuesta: más mejoras baratas por fase (no solo descuento en las 3 primeras compras) y
mejoras permanentes que aceleren el arranque de cada reciclado.

## Íconos (B2)
Los íconos de herramienta (pestañas y barra) usan un primer plano por herramienta: la yema apretando una
burbuja, la palma desde arriba, la bota de perfil, quietos con un vaivén. En la captura de CI se leen
mejor que la "manchita", pero todavía no están revisados por el revisor externo.

## Pendientes y próximos pasos
1. Revisión humana de la mano y la bota (el dueño pidió no mergear antes).
2. Balance de las fases 3-4 para el activo (recuperación) y el casual (disponibilidad de compras).
3. Clips con `[clips]` y su reporte de audio (no se corrieron esta sesión).
4. Benchmarks de rendimiento (necesitan ventana), sobre todo con la mano de 16.600 triángulos.
5. Pendientes solo de Windows: JUGAR.bat, accesos directos, instalador e ícono con rcedit.

---

# Sesión 1

## Bloqueo de push (resuelto en la sesión 2)

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


---

# 0.7.0 (en curso)

Prompt de la 0.7.0 (ocho secciones). Este diario se va completando por sección; lo no hecho queda en
"Pendientes de la 0.7.0" al final de la sección.

## Sección 1 · Recarga, rollo y auditoría de mejoras

**Causa del "se carga sola"**: la permanente *Automatización de fábrica* (`perm_auto`) encendía la
recarga automática en silencio (`global_stats` miraba `perm_auto`), sin que la mejora "Recarga
automática" figurara comprada. Ahora `global_stats` solo mira `global_reload`, y la fábrica (al reciclar y
al cargar) deja `global_reload` en nivel 1: queda comprada y visible en la hoja de pedidos.

**Tirá del rollo**: sin la mejora, al terminar la lámina el rollo late, el cartel dice "TIRÁ DEL ROLLO" y
se arrastra el rollo hacia abajo 110 px (o se lo deja apretado 0,7 s); el rollo gira con la mano y suelta
si no se completa (`main.gd`, `_update_pull`). Con la mejora, se ve una manivela roja que gira
(`ScenarioProps._crank`). Tests: `test_reload_waits_for_the_player_without_auto_reload`,
`test_auto_reload_creates_new_sheet_after_90_percent`, `test_nothing_is_active_without_being_bought`,
`test_factory_automation_leaves_reload_visibly_bought`.

### Auditoría: efecto, cómo se ve, test

| Mejora | Efecto (solo con la compra) | Cómo se ve | Test |
| --- | --- | --- | --- |
| `*_size` (dedo, palma, palo, plancha, bota) | radio/largo de la herramienta | la herramienta crece en pantalla y en el cursor | `test_tool_model`, `test_game_sim` |
| `*_force` | fuerza por segundo | revienta más rápido (pops/s en la hoja) | `test_game_sim` |
| `*_speed` | arrastre / enfriamiento de la bota | el trazo y el pisotón | `test_game_sim` |
| `*_special` | aire, vapor, onda | más cadenas, anillo y vapor | `test_air_chain`, `test_phase3_sim` |
| `unlock_*` | habilita la herramienta | aparece su botón | `test_game_sim` |
| `global_hold` | revienta mientras apretás | el trazo continuo | `test_game_sim` |
| `global_reload` | la lámina se repone sola | manivela que gira en el rollo | los cuatro de arriba |
| `global_value`, `global_special`, `global_tense`, `global_chain`, `global_sheet` | valor, especiales, umbral, cadena, tamaño | números, especiales, láminas más grandes | `test_economy`, `test_game_sim` |
| `hands_*`, `unlock_hands` | manitos fantasma | las manitos en la lámina | `test_phase3_sim` |
| `unlock_roller`, `roller_*` | rodillo automático | el rodillo recorre la lámina | `test_phase3_sim` |
| `perm_*` | arranques y bonos permanentes | tablero de corcho | `test_economy`, `test_game_sim` |

Pendiente de la auditoría: los efectos de `perm_*` no tienen todavía una marca visible en el mundo más allá
del tablero (se resuelve con los accesorios de la sección 3).

## Sección 2 · Desgaste por herramienta (parcial)

Hecho:
- `WearModel` (`src/sim/wear_model.gd`) y `GameSim.wear`: cada herramienta tiene un medidor que sube al
  usarla y baja al descansar (también cuando se usa otra, así cambiar de herramienta es la decisión).
  Al llenarse se traba hasta bajar de `resume`. Dedo casi nada, palma y palo cansancio leve, plancha se
  recalienta, bota cansa por pisotón; manitos y rodillo no tienen medidor. Todo en `data/economy.json`,
  clave `wear`; las mejoras de velocidad suben capacidad y recuperación (`speed_gain`) sin quitar el límite.
- Botones de la barra: termómetro de desgaste (verde → ámbar → rojo) y cartel RECALENTADA / CANSADA
  parpadeando (`StampButton.meter`).
- Tests: `tests/test_wear.gd` (7). El bot del simulador (`_rested_enough`) alterna herramienta según el desgaste.

Resultado del simulador (perfil activo, semilla 1, 215 min), **balance NO cerrado**:

| | Sin desgaste (0.6.1) | Desgaste suave | Desgaste ajustado (en data) |
| --- | --- | --- | --- |
| Galpón / Estacionamiento (min) | 64 / 107 | 52 / 89 | 47 / 82 |
| Bota vs. herramienta anterior | 6,4x (plancha) | 1,12x | 0,81x |

Un bot que alterna herramientas progresa MÁS rápido que el que usaba siempre la última: el desgaste
premia la variedad, pero hoy las fases llegan antes del objetivo (62-100 y 105-170 min) y la bota sale
peor que la plancha. Hay que reencuadrar costos de fase o los valores de `wear` antes de dar el balance por bueno.

Pendiente de la sección 2: tabla herramienta × tipo de burbuja (film térmico, burbuja fría, racimos,
gigantes), trabajo propio del rodillo, humo/sonido al trabarse, métricas de reparto de Pops por herramienta
(45 % / 10 % / 15-40 %) y su tabla.

## Pendientes de la 0.7.0 (no empezados)

Secciones 3 (una sola mano y accesorios), 4 (pedidos grandes), 5 (progresión y mapa RUTA), 6 (escenarios
y plano de presentación nuevos), 7 (historia, Steam, final) y 8 (rendimiento). Tampoco se corrió
render.yml ni el revisor externo para las secciones 1 y 2, ni se subió la versión a 0.7.0 ni hay build.
