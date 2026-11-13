# Control de calidad 1 — Protocolo de playtest

Objetivo: confirmar que reventar da gusto antes de construir el resto (DESIGN.md, sección 10). Se prueba con **5 personas sin contexto**, de a una.

## Preparación
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

## 4 preguntas al final
1. ¿Qué te dio ganas de seguir?
2. ¿Qué te molestó?
3. ¿Cómo describirías el sonido? (¿algo te sonó raro o fuerte?)
4. ¿Cuánto le pondrías de 1 a 10 a lo bien que se siente reventar?

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
