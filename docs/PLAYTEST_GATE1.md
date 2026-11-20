# Control de calidad 1 — Protocolo de playtest

Objetivo: confirmar que reventar da gusto antes de construir el resto (DESIGN.md, sección 10). Se prueba con **5 personas sin contexto**, de a una.

## Preparación
- Pasarle a cada persona el instalador o el zip (ver [PLAYTEST_TESTERS.md](PLAYTEST_TESTERS.md)); las builds salen de `tools/build.sh`.
- Cada sesión escribe un CSV en `%APPDATA%\Plastiquito\playtest` (Windows). Se recoge al final de cada prueba. Es un **complemento** de las anotaciones de quien observa, no las reemplaza.
- Build o editor con `scenes/main.tscn`, resolución 1600x900, auriculares o parlantes decentes.
- Volumen inicial de Master en 80% (valor por defecto). Anotar si la persona lo cambia.
- Grabar pantalla y audio si la persona lo permite. F12 guarda capturas en `user://screenshots`.
- Overlay de debug (F3) apagado. No mostrar el menú.
- Con los sonidos provisorios (`ph_*`) el resultado vale solo para la sensación general; repetir con las grabaciones reales antes de dar el control por aprobado.

## Qué se les dice
Solo esto: **"Es un juego de reventar plástico de burbujas, probalo."** Nada más: ni controles, ni objetivo, ni que se puede arrastrar.

## Durante 5 minutos
Sin ayuda y sin explicar. Quien observa mira y anota, sin hablar. Si la persona pregunta algo: "hacé lo que quieras".

Anotar:
| Qué observar | Minuto / notas |
| --- | --- |
| ¿Sonríe o se ríe? ¿Cuándo? | |
| ¿Sigue jugando sola después del minuto 2, sin que se le diga nada? | |
| ¿Hace clic suelto o mantiene apretado y arrastra? ¿Cuándo descubre el arrastre? | |
| ¿Sube el volumen o se acerca al parlante? | |
| ¿Usa la rueda para acercar o alejar? | |
| ¿Se frustra o se queda quieta sin saber qué hacer? | |

## Datos del CSV de sesión
Campos: duración, reventones totales, segundo del primer arrastre, clics sueltos y arrastres, cambios de volumen (`valor@segundo`), usos de la rueda, recargas de lámina y racha máxima. Cruzarlos con lo observado:
- Duración mayor a 120 s y reventones que siguen creciendo: apoya el criterio de "sigue jugando solo".
- Primer arrastre tardío o ningún arrastre: el gesto no se descubre solo (ajustar el cursor o la pista visual).
- Cambios de volumen hacia arriba: suma a la señal de que el sonido gusta.

## 4 preguntas al final
1. ¿Qué te dio ganas de seguir?
2. ¿Qué te molestó?
3. ¿Cómo describirías el sonido? (¿algo te sonó raro o fuerte?)
4. ¿Cuánto le pondrías de 1 a 10 a lo bien que se siente reventar?

## Datos nuevos del CSV (0.7.2)
`uso_herramientas` (reventones por herramienta), `herramienta_trabada` (veces que se recalentó o se cansó cada una), `pedidos_grandes_cumplidos` / `pedidos_grandes_vencidos` (`escenario@minuto`), `compras_accesorios` (`id@minuto`), `minuto_apertura_escenarios` y `final_visto`. Cruzar con lo observado:
- Una herramienta con casi todos los reventones y ninguna traba: el cansancio no está empujando a cambiar (ver el reparto en JORNADA.md).
- Pedidos vencidos seguidos en el mismo escenario: plazo o meta demasiado duros (la espera máxima y la recuperación del casual están **pendientes de playtest humano**, congeladas hasta tener estos datos).
- Escenarios abiertos muy rápido o muy tarde frente a los objetivos del simulador (Living ~20-35 min, Depósito ~62-100, Estacionamiento ~105-170).

## Preguntas extra para la 0.7.2
5. ¿Entendiste para qué sirve cada herramienta? ¿Cambiaste de herramienta por algo?
6. ¿Viste los accesorios en la mano? ¿Cuáles tenías?
7. ¿Se entiende qué hay que hacer para abrir el escenario siguiente?
8. ¿La historia te hizo gracia? ¿Entendiste quién te escribe los memos?

## Criterio para aprobar
- **Al menos 4 de 5** siguen jugando por su cuenta después del minuto 2.
- **Nadie** menciona que el sonido moleste.

Si no se cumple: no se avanza a la Fase 2. Se ajustan primero los parámetros de `data/juice.json`, `data/audio.json` y `data/sheet.json` (fuerza, recuperación, hitstop, sacudida, tono) y los sonidos, y se repite con 5 personas nuevas.

## Registro
| # | Edad / perfil | Sigue tras min 2 | Arrastra | Sube volumen | Sonido molesta | Qué le dio ganas | Qué molestó |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | | | | | | | |
| 2 | | | | | | | |
| 3 | | | | | | | |
| 4 | | | | | | | |
| 5 | | | | | | | |
