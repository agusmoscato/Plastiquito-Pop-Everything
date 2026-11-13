# Plastiquito: Pop Everything

Clicker incremental 3D hecho en Godot 4 (GDScript tipado). Reventás plástico de burbujas con herramientas cada vez más absurdas, del dedo al meteorito, sobre una lámina que crece hasta el millón de burbujas. El diseño completo está en [docs/DESIGN.md](docs/DESIGN.md).

## Correr el juego

Requiere Godot 4.4.1 (ver [CLAUDE.md](CLAUDE.md)). Abrí la carpeta con el editor de Godot y apretá F5, o:

```
godot --path .
```

En la Fase 0 todavía no hay escena jugable: solo la simulación pura en `src/sim/`.

## Correr los tests

Los tests usan [GUT](https://github.com/bitwes/Gut) y corren sin pantalla:

```
./tools/run_tests.sh
```

El script usa `godot` del PATH, o el ejecutable indicado en la variable de entorno `GODOT`. Devuelve un código de salida distinto de 0 si algún test falla.
