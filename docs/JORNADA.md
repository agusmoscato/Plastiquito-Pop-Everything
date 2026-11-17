# Jornada de pulido — 2026-11-17

Trabajo autónomo en la PC del dueño en **modo invisible**: nada con ventana ni sonido. Godot solo
`--headless`, Blender solo `-b`, procesos pesados con prioridad BelowNormal y de a uno. Todo lo
visual (capturas, prueba de humo, clips) se renderiza en GitHub Actions (`.github/workflows/render.yml`)
y queda en la rama `renders`, carpeta `<sha corto>/`.

## Incidente previo a la jornada

Antes de arrancar se probó `tools/run_office.ps1`, que abría Godot con ventana y la mandaba al
escritorio virtual 2. La ventana llegaba al escritorio 2 en 8-13 ms, pero en la segunda prueba tomó
el foco y cambió el escritorio activo del dueño durante ~3 s. Se cerró todo, se borró el script y
desde entonces está prohibido abrir ventanas en esta PC. Queda instalado el módulo de PowerShell
`VirtualDesktop` (alcance de usuario); se puede sacar con `Uninstall-Module VirtualDesktop`.

## B0. Estabilizar

### Línea de base (WIP 99cdf3c)
- Lint y 143 tests en verde.
- Balance completo (`tools/balance_full.sh`, semilla 1), antes de tocar nada:

| Métrica | Objetivo | Activo | Casual | Idle |
| --- | --- | --- | --- | --- |
| % tiempo con compra pagable o a < 30 s | >= 70 % | 63,0 FALLÓ | 68,0 FALLÓ | |
| Mediana entre compras 45-210 min | 30-120 s | 50,1 | 20,5 FALLÓ | |
| Máx. sin poder comprar 45-210 min | <= 180 s | 163 | 309 FALLÓ | |
| Llegada al Galpón | 72-108 min | 91,9 | 93,7 | |
| Llegada al Estacionamiento | 120-180 min | 171,4 | 110,2 FALLÓ | |
| Recuperación tras reciclar | < 40 % | 15,2 | 57,8 FALLÓ | |
| Herramienta nueva contra la anterior | >= 2x | 3,5 | 3,6 | |

(El resto de las métricas de las fases 1 y 2 aprueba en los dos perfiles.)
