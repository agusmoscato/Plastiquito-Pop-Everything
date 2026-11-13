# Plastiquito: Pop Everything — Documento de diseño

Nov 13, 2026 · @Agustin · v0.1 · Repo: agusmoscato/Plastiquito-Pop-Everything

## 1. Pitch

**Reventás plástico de burbujas con herramientas cada vez más absurdas, del dedo al meteorito, sobre una lámina que no para de crecer.**

Para la tienda en inglés: *Pop bubble wrap with increasingly absurd tools — from a fingertip to a meteor — on a sheet that never stops growing.*

**Gancho de 3 segundos:** una aplanadora pasa por una lámina gigante de plástico de burbujas y revientan cientos de burbujas seguidas. Se entiende sin texto ni sonido, y con sonido mejor.

### Ficha

| Campo | Valor |
| --- | --- |
| Género | Clicker incremental 3D, ASMR, con automatización y prestige |
| Motor | Godot 4, GDScript tipado, todo hecho por código |
| Precio | USD 3,99 (10–20% de descuento de lanzamiento) |
| Duración | 5–7 h hasta el final, 8–10 h para el 100% |
| Plataformas | Windows y Linux, Steam Deck verificado como objetivo; Mac opcional |
| Desarrollo | 16 semanas más 2 de colchón |

### Pilares

1. **Cada reventón se siente.** Sonido grabado de plástico real, la burbuja se aplasta antes de reventar, partículas y una pausa breve en los reventones grandes.
2. **El aire es la estrategia.** Al apretar una burbuja, el aire pasa a las vecinas. Las burbujas tensas valen más y revientan en cadena. Hay que aprender a apretar, no solo a hacer clic.
3. **La escala se ve.** La herramienta y la lámina crecen juntas, y con cada reciclado la cámara se aleja: de una mesa a una vista satelital.

### Diferencial frente a la competencia

Todos los juegos de plástico de burbujas que encontramos en Steam (Pupple Pop, Sporbs, PopWork, Unboxathon, Bubble Wrap) son 2D o pixel art. Ninguno tiene herramientas físicas ni escala. Plastiquito ocupa ese hueco: 3D, herramientas y una lámina que crece hasta el millón de burbujas. Es la misma idea que en *Sir, We Have an Orc Problem* (multiplicar un solo elemento) y en *Bills Must Be Paid* (que dé gusto tocar).

## 2. Loop de juego

El juego tiene tres ciclos uno dentro del otro: reventar (segundos), vaciar la lámina (minutos) y reciclar (horas).

1. **Micro, 1 a 3 segundos.** Apretás o arrastrás la herramienta y la burbuja se aplasta. El aire pasa a las vecinas, la burbuja revienta y ganás **Pops** (la moneda). Si hay burbujas tensas cerca, se arma una cadena.
2. **Meso, 1 a 5 minutos.** Cuando la lámina queda reventada al 90%, llega una lámina nueva (el rollo se desenrolla con animación). En el medio comprás mejoras: fuerza, tamaño de la herramienta, probabilidad de burbujas especiales y automatización.
3. **Macro, 30 a 70 minutos.** Desbloqueás una herramienta nueva y después **reciclás**: la lámina y los Pops se convierten en **Pellets**, la moneda permanente. Con los Pellets comprás una lámina más grande y mejoras permanentes. Al reciclar cambia el escenario y la cámara se aleja.

**El momento que vende el juego** es la primera pasada de una herramienta nueva sobre una lámina cargada de burbujas tensas. Todo el balance apunta a que ese momento llegue cada 40 a 60 minutos.

## 3. Sistemas

### 3.1 La lámina

La lámina es una grilla hexagonal, como el plástico de burbujas real. Arranca en 8×8 y termina en 1000×1000 (un millón de burbujas). Cada burbuja guarda tres datos: **presión** (número decimal, arranca en 1,0), **estado** (intacta, tensa o reventada) y **tipo** (normal o especial).

### 3.2 Aire y tensión

Es la mecánica central. Las reglas son simples y todos los números salen del simulador de balance:

- La herramienta suma **fuerza** a cada burbuja que toca. Cuando la fuerza acumulada supera la **resistencia** de la burbuja, revienta.
- Una burbuja apretada sin reventar le pasa una parte de su aire a las vecinas intactas. Su presión sube.
- Con presión de 1,5 o más, la burbuja queda **tensa**: se ve más grande y brillante, suena más agudo y su valor se multiplica.
- Cuando revienta, reparte una fracción *k* de su presión entre las vecinas. Si alguna llega a la presión máxima (2,0), revienta sola. Así se arman las cadenas.
- *k* tiene que quedar por debajo del punto crítico para que las cadenas terminen. Las mejoras lo acercan a ese punto, pero nunca lo pasan. Hay un test que verifica que el aire no se crea de la nada.

Valor de un reventón:

```latex
\text{Pops} = \text{base}_{\text{fase}} \cdot p^{2} \cdot m_{\text{tipo}} \cdot m_{\text{combo}} \cdot m_{\text{global}}
```

*p* es la presión al reventar, así que una burbuja tensa (p = 2) vale 4 veces más que una normal.

### 3.3 Herramientas

Hay 8 herramientas, cada una con su propio árbol de 4 o 5 mejoras (tamaño, fuerza, velocidad y una especial). Son la progresión visible del juego.

| # | Herramienta | Forma del golpe | Qué la hace distinta | Escenario |
| --- | --- | --- | --- | --- |
| 1 | Dedo | 1 burbuja | Si mantenés apretado, infla a las vecinas sin reventar. Enseña la tensión. | Mesa |
| 2 | Palma | Círculo de radio 2 | Aplasta lento: tensa el borde y después revienta el centro. | Mesa |
| 3 | Palo de amasar | Franja que se arrastra | Empuja el aire hacia adelante y arma una ola. | Piso |
| 4 | Plancha | Rectángulo con aura de calor | El calor infla las burbujas antes de tocarlas. | Galpón |
| 5 | Bota | Pisotón en círculo | Cráter con onda expansiva y tiempo de recarga. | Estacionamiento |
| 6 | Aplanadora | Línea larga | Recorre la lámina sola por una ruta: es la herramienta idle. | Campo |
| 7 | Prensa hidráulica | Rectángulo enorme | El aire sale por los costados y arma una cadena en el perímetro. | Salar |
| 8 | Meteorito | Cráter gigante | Cae del cielo y su onda recorre la lámina entera. Es el final. | Órbita |

Las herramientas 1 a 6 son el mínimo viable. Si el tiempo no alcanza, la 7 se recorta.

### 3.4 Burbujas especiales

Aparecen con una probabilidad que se puede mejorar. Cada una tiene forma y color propios, para que también se distingan sin ver colores.

| Burbuja | Efecto | Se desbloquea en |
| --- | --- | --- |
| Dorada | Vale ×10 | Mesa |
| Bomba | Revienta las burbujas a radio 3 | Piso |
| Línea | Revienta toda su fila hexagonal | Galpón |
| Eco | Se vuelve a inflar una vez después de reventar | Estacionamiento |
| Gigante | Ocupa 7 celdas y al reventar reparte 7 veces la presión | Campo |
| Hielo | Hay que golpearla dos veces; con calor se derrite | Salar |
| Arcoíris | Duplica todo durante 10 segundos | Salar |

Cada especial nueva entra al **Burbujario**, la colección, que cuenta para el 100%.

### 3.5 Automatización y juego activo

- **Manitos:** dedos fantasma que tocan burbujas al azar y después se mejoran para que elijan las tensas.
- **Rodillo automático** y **aplanadora con ruta:** recorren la lámina solos.
- **Recarga automática** de lámina.
- El juego activo siempre rinde más: el **combo** (reventones por segundo) llega hasta ×5. Así jugar activo vale la pena, pero dejarlo solo también avanza.
- Para no lastimar la muñeca, mantener apretado cuenta como clic continuo. Nunca hace falta hacer clic sin parar.

### 3.6 Economía

- Una sola moneda por partida, **Pops**, guardada como `float` de 64 bits (alcanza hasta 1e308) y mostrada con sufijos (K, M, B…).
- Costo de las mejoras: `costo(n) = base · g^n`, con *g* entre 1,12 y 1,20 según la mejora.
- Todos los números viven en archivos JSON en `data/`. El balance se cambia sin tocar código.

### 3.7 Reciclado (prestige)

Reciclar convierte lo hecho en la partida en **Pellets**:

```latex
\text{Pellets} = \left\lfloor \sqrt{\frac{\text{Pops de la partida}}{10^{5}}} \right\rfloor
```

Con los Pellets se compran mejoras permanentes: lámina más grande (lo que abre el escenario siguiente), +5% global por nivel, herramienta inicial mejorada, automatización desde el arranque y más probabilidad de especiales. La fórmula es un punto de partida y la ajusta el simulador.

### 3.8 Final y 100%

- **Final:** el meteorito cae sobre la lámina de un millón de burbujas y los créditos pasan mientras siguen reventando.
- **100%:** las 8 herramientas al máximo, el Burbujario completo y unos 40 logros de Steam, ninguno de pura repetición.
- **Después del final:** modo zen, una lámina infinita sin números para relajarse, pensado para el público ASMR y para Steam Deck.

## 4. Progresión

El juego tiene 7 fases, una por escenario. El final llega a las 6,5 horas y el 100% entre las 8 y las 10. Los tiempos son los objetivos que el simulador de balance tiene que cumplir, con una tolerancia de ±20%.

| Fase | Escenario | Llega a los | Herramienta nueva | Especiales nuevas | Lámina (burbujas) | Automatización |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | Mesa | 0 min | Dedo, Palma | Dorada | 8×8 → 20×20 (400) | — |
| 2 | Piso | 35 min | Palo de amasar | Bomba | 40×40 (1.600) | Recarga automática |
| 3 | Galpón | 1 h 30 | Plancha | Línea | 80×80 (6.400) | Manitos |
| 4 | Estacionamiento | 2 h 30 | Bota | Eco | 150×150 (22.500) | Rodillo automático |
| 5 | Campo | 3 h 30 | Aplanadora | Gigante | 300×300 (90.000) | Aplanadora con ruta |
| 6 | Salar | 4 h 45 | Prensa hidráulica | Hielo, Arcoíris | 600×600 (360.000) | Manitos inteligentes |
| 7 | Órbita | 6 h | Meteorito | — | 1000×1000 (1.000.000) | — |

- **Primer reciclado:** alrededor de los 35 minutos, al terminar la fase 1. Tiene que sentirse como un premio, no como una pérdida.
- **Demo para Next Fest:** fases 1 y 2, unos 45 minutos. Termina con un adelanto de la aplanadora.
- **Ritmo:** algo nuevo (mejora, especial o herramienta) cada 3 a 5 minutos en la primera hora, y cada 10 a 15 minutos después.
- **Escalada:** cada fase multiplica la base de Pops por unos 50. Los números grandes aparecen, pero no son el foco: el foco es la lámina.

### Lo que cambió al implementar las fases 3 y 4 (Fase 3 del desarrollo)

- **Escalada x100, no x50:** la base de Pops por fase es 1, 100, 10.000 y 1.000.000. Los costos de las mejoras en Pops se multiplican por una escala propia de cada fase (1, 320, 40.000, 8.000.000) porque las láminas grandes amplifican por cadenas.
- **Lámina más grande** abre una fase por nivel y cuesta 1, 18 y 110 Pellets (escalones a mano). Tiempos que logra el perfil activo del simulador: Piso a los 30 min, Galpón a los 90 y Estacionamiento a los 148.
- **Cadenas:** `k` máximo 0,62 y umbral de tensión mínimo 1,4. Con los valores originales (0,9 y 1,3) las láminas de 6.400 y 22.500 burbujas se despejaban enteras de un golpe y rompían la economía.
- **Plancha (3.3):** el calor sube la presión de las burbujas del aura hasta 1,4 antes de tocarlas; no crea aire por encima del tope (menor que el umbral de tensión). Su aura se ve como un rectángulo anaranjado que pulsa.
- **Bota (3.3):** un pisotón por apretada, con recarga de 4 s (mejorable) visible en el HUD. La onda expansiva empuja hacia afuera una parte de la presión de lo pisado, limitada para que el aire total nunca aumente.
- **Eco (3.4):** vuelve a inflarse una sola vez a los 2 s y queda como burbuja normal.
- **Automatización (3.5):** las **Manitos** (Galpón) y el **rodillo automático** (Estacionamiento) revientan sin combo, así que jugar activo siempre rinde más; las manitos inteligentes existen pero requieren la Fase 6. Con el juego cerrado producen al 50% de eficiencia con tope de 2 horas.
- **Reciclado (3.7):** además de la lámina más grande, hay mejoras permanentes por herramienta inicial, automatización desde el arranque, probabilidad de especiales y "memoria del turno" (arrancás con un porcentaje de los niveles de la partida anterior). Se compran en un tablero de corcho.
- **Escenarios (pilar 3):** cada fase tiene su escenario (madera, baldosas, hormigón, asfalto) y cambia durante la transición del reciclado.


## 5. Estilo visual (todo por código)

La estética es de "juguete limpio": plástico brillante, formas simples y colores saturados. Todo sale de shaders y de las formas primitivas de Godot, sin modelos ni texturas dibujadas a mano.

### Plástico y burbujas

- **Shader de burbuja:** translúcido, con borde iluminado (fresnel), brillo especular y un tinte celeste leve.
- **Deformación por instancia:** la presión infla la burbuja y la fuerza la aplasta. Se hace en el vértice con los datos propios de cada instancia, sin física real.
- **Burbuja reventada:** queda aplastada, con arrugas hechas con ruido en las normales y un poco más opaca.
- **Lámina:** un plano translúcido debajo de las burbujas que se ve desenrollarse cuando llega la lámina nueva.

### Herramientas y escenarios

- Las herramientas se arman con cilindros, cajas y esferas, cada una con un color propio. La aplanadora, por ejemplo, son dos cilindros y una caja.
- Cada escenario es un piso de color con 3 a 6 objetos primitivos (patas de mesa, líneas de estacionamiento, cactus de cajas) y su propia luz.
- La luz es una direccional con oclusión ambiental (SSAO) y brillo (glow) solo en las doradas y en el arcoíris.

### Checklist de "juice"

- [ ] Pausa de 30 a 60 ms en reventones grandes (hitstop)
- [ ] Sacudida de cámara proporcional al tamaño de la cadena, con opción de apagarla
- [ ] Partículas de plástico y polvito al reventar, reutilizadas de un pool
- [ ] El tono sube a medida que crece la cadena
- [ ] La herramienta se aplasta y rebota al golpear (squash and stretch)
- [ ] La cámara se aleja suave al reciclar, con una transición de 3 a 4 segundos que vale como clip
- [ ] Números flotantes que se pueden apagar
- [ ] Vibración en el control y en Steam Deck

### Interfaz y accesibilidad

- La interfaz es el escritorio de un depósito de embalaje: cartón kraft, etiquetas de papel con inclinación fija, cinta de embalar, sellos de goma rojos, un contador mecánico (odómetro) y la tienda como "hoja de pedidos" con clip. Todo se dibuja por código, con fuentes OFL (Bowlby One, Archivo, Space Mono). Guía completa y lista de señales de IA prohibidas en [UI_STYLE.md](UI_STYLE.md).
- Cada especial tiene forma y color propios. Hay modo para daltónicos.
- Volumen separado por canal, opción de reducir el movimiento y juego completo con control.

## 6. Sonido

El sonido es la mitad del juego. Los reventones se graban con plástico de burbujas real; solo los motores y los efectos de ambiente se generan por código.

### Grabación propia (semana 3)

1. Conseguir 3 o 4 tipos de plástico de burbujas: burbuja chica, mediana, grande y uno viejo medio desinflado.
2. Grabar con el celular dentro de un placard con ropa, que absorbe el eco, a 10–15 cm del plástico.
3. Grabar entre 80 y 120 sonidos en 5 categorías: reventón chico, reventón grande, reventón tenso (plástico bien inflado), aplastado sin reventar (crujido) y arrugado o rasgado.
4. En Audacity: recortar, reducir ruido, normalizar a −1 dB y exportar en `.ogg`.

### Sistema de audio

- **Pool de 24 voces** (`AudioStreamPlayer`), cada una con tono al azar de ±8% y la muestra elegida al azar dentro de su categoría.
- **Tono por presión y combo:** las tensas suenan más agudo y la cadena va subiendo el tono.
- **Crepitar masivo:** si revientan más de 30 burbujas en un frame, en lugar de 30 sonidos sueltos suena un loop de crepitar cuyo volumen y densidad siguen la cantidad de reventones por segundo. Así 10.000 reventones suenan como lluvia de plástico y no como ruido. Es la decisión de audio más importante del juego.
- **Herramientas:** motor de la aplanadora y zumbido de la prensa generados por código (`AudioStreamGenerator`) o tomados de bancos con licencia CC0.
- **Música:** lo-fi suave, con licencia CC0 o comprada con licencia libre de regalías, y apagada por defecto en modo zen. Mucha gente del público ASMR juega sin música.
- **Mezcla:** canales separados para reventones, herramientas, interfaz y música, con límite de volumen en el canal maestro.

## 7. Marketing

El marketing arranca en la semana 6, con la página de Steam y los videos cortos diarios, apenas el juego tenga el primer tramo jugable y pulido (vertical slice).

### Página de Steam

- **Nombre:** Plastiquito: Pop Everything.
- **Etiquetas:** Incremental, Clicker, Idler, Relaxing, Physics, Casual, 3D, Singleplayer, Short.
- **Tráiler de 30 segundos:** los primeros 3 segundos son la aplanadora. Después, la escalera de herramientas en cortes rápidos, y cierra con la cámara alejándose y el meteorito.
- **Cápsula:** el título grande, una aplanadora y burbujas sobre fondo celeste. Es el único arte que conviene pagar, porque decide los clics en la tienda.
- **Primer GIF de la descripción:** una pasada de palo de amasar armando una ola de tensas.

### Videos cortos diarios (TikTok, Shorts y Reels)

| Formato | Ejemplo | Para qué sirve |
| --- | --- | --- |
| Herramienta nueva | "Día 23: ahora con plancha" | Diario de desarrollo con progreso visible |
| Real contra juego | Mano reventando plástico real y el mismo gesto en el juego | Gancho más fuerte, porque todos conocen la sensación |
| ¿Cuántas revienta? | "¿Cuántas burbujas revienta una aplanadora?" | Curiosidad y comentarios |
| ASMR puro | 15 segundos sin música ni texto | Público ASMR y satisfying |
| 1 contra 1.000.000 | Una burbuja y después la lámina entera | La escala en 3 segundos |

### Lanzamiento

- **Next Fest:** demo con las fases 1 y 2. La página tiene que estar publicada por lo menos 2 o 3 meses antes.
- **Precio:** USD 3,99, con 10–20% de descuento la primera semana.
- **Idiomas:** el juego tiene poco texto, así que traducir es barato. Español, inglés, portugués de Brasil, chino simplificado, japonés, ruso, alemán y francés.
- **Promoción cruzada con INFLATION? What Inflation?:** links entre las dos páginas y un bundle del desarrollador cuando salga Plastiquito.
- **Bundles de incrementales:** en Steam hay bundles armados entre desarrolladores de incrementales. Conviene escribirles a los organizadores en el lanzamiento.

## 8. Plan técnico en Godot 4

La regla que manda: **la simulación no sabe que existe la pantalla.** Toda la lógica (lámina, aire, cadenas, economía) vive en clases puras de GDScript sin nodos, y por eso se puede testear y simular sin abrir el juego. La parte visual solo lee el estado y lo dibuja.

### Versión y configuración

- Godot 4.4.1-stable, la misma versión que INFLATION, fijada en el repo. Actualizar se evalúa una sola vez, cuando arranque el desarrollo completo después del lanzamiento de INFLATION.
- Render Forward+ (Vulkan), que funciona en Steam Deck.
- GDScript con tipado estático obligatorio, con las advertencias de tipos tratadas como errores.

### Estructura del repo

```
Plastiquito-Pop-Everything/
  CLAUDE.md            reglas para Claude Code
  docs/DESIGN.md       este documento
  data/                tools.json, upgrades.json, bubbles.json, phases.json
  src/sim/             lógica pura, sin nodos
    hex_grid.gd        coordenadas hexagonales, vecinos, formas de golpe
    sheet_model.gd     presión, estado y tipo en arrays empaquetados
    chain_solver.gd    cola de cadenas con presupuesto por frame
    economy.gd         costos, valor de reventones, formato de números
    prestige.gd        fórmula de Pellets y mejoras permanentes
    game_state.gd      estado completo y serializable
  src/view/            sheet_view, tool_view, camera_rig, fx_pool
  src/audio/           pop_audio (voces + crepitar masivo)
  src/ui/              hud, tienda, reciclado, ajustes
  src/autoload/        Game, Events (señales), SaveSystem, Settings
  shaders/             bubble.gdshader, sheet.gdshader
  tests/               tests con GUT
  tools/balance_sim.gd simulador de balance sin pantalla
```

### Rendimiento: un millón de burbujas

- **Simulación:** arrays empaquetados (`PackedFloat32Array` para presión y `PackedByteArray` para estado y tipo). No hay un nodo ni un collider por burbuja.
- **Clic a burbuja:** un rayo contra el plano y = 0, y después matemática hexagonal para saber qué celda es. Las herramientas son formas (círculo, segmento, rectángulo) que devuelven la lista de celdas tocadas.
- **Cadenas:** una cola con presupuesto de N reventones por frame. Repartir la cadena entre varios frames no solo cuida el rendimiento, también dibuja la ola.
- **Dibujo de cerca:** `MultiMeshInstance3D` en bloques de 64×64, con los datos de cada burbuja en `INSTANCE_CUSTOM`. Solo se actualizan los bloques que cambiaron.
- **Dibujo de lejos:** cuando la cámara está lejos, los bloques se cambian por un plano con shader que lee una textura de estado (un píxel por burbuja). Con eso un millón de burbujas se dibuja con un solo plano.
- **Objetivos:** 60 fps en Steam Deck con 250.000 burbujas visibles de cerca y con el millón de lejos. Hay una escena de benchmark desde la semana 2.

### Tests

- Se usa **GUT** (Godot Unit Test) v9.4.0, del repo bitwes/Gut, y se corre sin pantalla desde la línea de comandos.
- Casos obligatorios: vecinos hexagonales y bordes, formas de golpe, que el aire se conserve, que toda cadena termine, que las fórmulas de costo y Pellets den lo esperado, que guardar y cargar devuelva el mismo estado, y que los saves viejos se migren bien.
- Ningún commit con tests rotos.

### Simulador de balance

- Se corre con `godot --headless --script tools/balance_sim.gd`.
- Usa la misma simulación que el juego, con un jugador bot y tres perfiles: activo (8 clics por segundo con buen apunte), casual (3 por segundo) e idle (solo automatización). El bot siempre compra la mejora que más rinde por Pop gastado.
- Corre el juego entero en segundos, con pasos de tiempo grandes, y escribe un CSV con el minuto en que cae cada hito.
- Compara contra la tabla de progresión (sección 4) y falla si algún hito se desvía más de 20%. Se corre antes de cada commit que toque `data/`.

### Guardado y Steam

- Guardado en JSON en `user://`, automático cada 30 segundos y al salir, con número de versión y migraciones.
- Logros y guardado en la nube con **GodotSteam** (GDExtension). Se integra en la semana 14, detrás de una interfaz que no hace nada cuando Steam no está.

### Git

- Repo: agusmoscato/Plastiquito-Pop-Everything.
- Un commit por tarea terminada, con mensajes del estilo `feat(sim): cadena con presupuesto por frame`.
- Una rama por fase y merge a `main` cuando la fase pasa sus tests y el simulador.

## 9. Roadmap por semanas

Son 16 semanas de trabajo más 2 de colchón, contadas desde que arranca Plastiquito después del lanzamiento de INFLATION. Cada fase termina con sus tests y el simulador en verde, y los tres controles frenan el avance hasta que se cumplen.

&#91;embedded content: Roadmap · 6 fases y 3 controles en 18 semanas\]

El control de la semana 3 es el más importante: si reventar no da gusto, nada de lo que viene después lo arregla. Cada fase va a tener su propio prompt para Claude Code.

## 10. Riesgos y mitigaciones

El riesgo más grande es que reventar no dé gusto. Por eso hay un control en la semana 3 que frena todo hasta que ese punto esté bien.

| Riesgo | Impacto | Mitigación |
| --- | --- | --- |
| Reventar no da gusto | Alto | Control en la semana 3: no se avanza hasta que 5 personas sin contexto quieran seguir reventando. Sonido grabado, no generado. |
| El nicho de reventar burbujas ya está lleno | Alto | Cada video y cada captura muestra lo que los demás no tienen: 3D, herramientas y escala. Nunca una lámina 2D quieta. |
| Rendimiento con un millón de burbujas | Alto | Simulación en arrays, dibujo de lejos con textura y benchmark desde la semana 2. Si no alcanza, el final queda en 500.000. |
| 10.000 reventones suenan a ruido | Medio | Crepitar masivo a partir de 30 reventones por frame. |
| Balance roto (demasiado rápido o se estanca) | Medio | Simulador con objetivos por fase y ±20% de tolerancia, y playtests en las semanas 6 y 15. |
| Cansancio o dolor por hacer clic | Medio | Mantener apretado sirve como clic, automatización temprana y combo que premia el ritmo, no la velocidad. |
| Demasiado alcance (8 herramientas) | Medio | Las herramientas 1 a 6 son el mínimo. La prensa se recorta si hace falta. Hay 2 semanas de colchón. |
| Se superpone con el juego 1 | Medio | Plastiquito arranca después del lanzamiento de INFLATION. Mientras tanto, solo diseño y quizás el prototipo de la semana 2. |
| Claude Code se desvía de la arquitectura | Medio | CLAUDE.md con reglas, tests obligatorios, prompts cortos por fase y revisión al final de cada fase. |
| Problemas de derechos | Bajo | Nada de marcas ni personajes. La aplanadora y las herramientas son genéricas y sin logos. Sonidos propios o CC0, fuentes OFL. |
