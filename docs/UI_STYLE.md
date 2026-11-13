# Guía de estilo de la interfaz

La interfaz es **el escritorio de un depósito de embalaje**. Todo es material físico: cartón kraft,
etiquetas de papel blanco, cinta de embalar marrón translúcida, sellos de goma con tinta roja, un
contador mecánico y una etiquetadora. Nada de paneles flotantes de "app". Todo se dibuja por código
(`_draw()`, `StyleBox`, shaders): no hay imágenes descargadas ni sets de íconos.

Código base: [src/ui/ui_kit.gd](../src/ui/ui_kit.gd) (paleta, fuentes y dibujos), [shaders/paper.gdshader](../shaders/paper.gdshader) (grano de cartón).

## Paleta (no se usa nada fuera de ella)

| Uso | Color |
| --- | --- |
| Kraft (cartón claro) | `#C8A27A` |
| Cartón oscuro | `#5A4330` (sombras de kraft: `#8E6B47`) |
| Papel blanco cálido | `#F4EFE6` (sombreado: `#DDD4C2`) |
| Tinta negra | `#1E1B18` |
| Rojo sello | `#C8322B` |
| Cinta de embalar | marrón translúcido (`#9E6E3B`, alfa 0,62) |
| Celeste burbuja | `#8FD0F2`, solo para lo que es plástico (íconos de burbuja, lámina) |

Dorado `#E7B73A` aparece únicamente en las etiquetas de hito (cada 25 niveles) y en la burbuja dorada.

## Fuentes (licencia OFL, en `assets/fonts/` junto a sus licencias)

- **Bowlby One**: títulos, nombres de mejoras y sellos.
- **Archivo**: texto corrido (descripciones).
- **Space Mono**: números, el contador y las líneas de la etiquetadora.

Obtenidas del repo oficial `google/fonts`.

## Imperfección controlada

- Cada etiqueta tiene una inclinación fija entre -1,5° y +1,5°, **determinística por id** (`UiKit.tilt`), nunca al azar por frame.
- Los bordes de papel son levemente irregulares (`UiKit.paper_polygon`, jitter por semilla de texto).
- Pedacitos de cinta en las esquinas de los paneles y las etiquetas (`UiKit.draw_tape`).
- Cada etiqueta de la tienda se pegó un poco corrida (±8 px determinístico).
- El grano de cartón (fibras horizontales, ruido fino y manchas) sale de un shader de ruido.
- Los sellos tienen puntitos de desgaste (la tinta no llega a todos lados).

## Piezas

- **Contador de Pops**: odómetro de rodillos (`Odometer`, `DigitWheel`). Los dígitos ruedan, no saltan. Cada "+N" vuela desde la burbuja reventada hasta el contador y se suma al llegar; cuando llegan muchos se agrupan por zona.
- **Hoja de pedidos** (la tienda): una hoja sujeta con un clip metálico, pestañas por herramienta y una etiqueta por mejora (nombre, línea graciosa, nivel, efecto actual > próximo, precio). Compra con clic o manteniendo apretado (acelera). x1, x10 y MAX.
- **Íconos en vivo**: cada pestaña y cada etiqueta renderiza el modelo 3D real de la herramienta, girando, en un `SubViewport` chico (`ToolIcon`).
- **Orden de trabajo**: la próxima meta grande, con su progreso.
- **Siguiente pedido**: siempre visible; la barra de la mejora más barata que todavía no se puede pagar.
- **Ritmo**: el multiplicador de combo en un sello.
- **Sello de CADENA xN**: crece mientras la cadena sigue y golpea al terminar con el total ganado.
- **Centro de reciclado**: Pellets en vivo, mejoras permanentes y el botón de reciclar.
- **Menú de pausa**: una hoja con deslizador de tinta (`InkSlider`).

## Anticipación y feedback de compra

- Una mejora que se vuelve pagable "se despega": sube 2 px con sombra y suena un tic suave (como mucho 1 vez cada 3 s).
- Al comprar: sello rojo "SELLADO" que golpea la etiqueta, leve sacudida de la interfaz, el número rueda hacia abajo en el odómetro y la línea de nivel se reimprime letra por letra.
- Cada 25 niveles: etiqueta dorada, arpegio y un texto corto con humor.
- Cada compra se ve **en el mundo**: la herramienta crece con el tamaño, sigue al cursor más rápido con la velocidad y cambia de color o material en cada hito.

## Voz

Cortos, secos, como de una empresa de embalaje seria que se toma demasiado en serio las burbujas.
Descripciones de 60 caracteres o menos (hay un test). Siempre con un número cuando hay efecto.
Sin signos de exclamación en serie.

Ejemplos: "Yema curtida: Años de práctica. +20% de fuerza.", "Uña larga: No preguntes. +1 de radio.", "Departamento de Reventones".

## Señales de IA prohibidas

- Degradados violeta, azul o rosa, glassmorphism, neón, brillos genéricos.
- Tarjetas redondeadas idénticas en grilla perfecta con sombra suave.
- Emojis o íconos de librerías genéricas.
- Textos tipo "¡Desbloqueá tu potencial!", "Mejorá tu experiencia" o descripciones vagas sin número.
- Todo centrado y simétrico, o espaciado igual en todas partes.
- Animaciones de "fade + slide" iguales para todo.

## Proceso de revisión

Con el juego corriendo con ventana se sacan capturas del HUD, la tienda, una cadena grande y la
pantalla de reciclado, se revisan contra la lista anterior, se corrige y se repite. Las capturas
finales están en [docs/screens/fase-2/](screens/fase-2/). El modo `--demo-shot=<carpeta>` de la
escena principal genera las capturas de forma reproducible.
