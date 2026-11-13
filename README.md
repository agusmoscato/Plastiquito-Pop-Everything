# Plastiquito: Pop Everything

Clicker incremental 3D hecho en Godot 4 (GDScript tipado). Reventás plástico de burbujas con herramientas cada vez más absurdas, del dedo al meteorito, sobre una lámina que crece hasta el millón de burbujas. El diseño completo está en [docs/DESIGN.md](docs/DESIGN.md).

## Correr el juego

Requiere Godot 4.4.1 (ver [CLAUDE.md](CLAUDE.md)). Abrí la carpeta con el editor de Godot y apretá F5, o:

```
godot --path .
```

Controles: mantener apretado el botón izquierdo y arrastrar para reventar; 1, 2 y 3 eligen la herramienta; rueda para el zoom; Tab abre el reciclado; B el Burbujario; Esc el menú; F12 saca una captura.

## Correr los tests

Los tests usan [GUT](https://github.com/bitwes/Gut) y corren sin pantalla:

```
./tools/run_tests.sh
```

El script usa `godot` del PATH, o el ejecutable indicado en la variable de entorno `GODOT`. Devuelve un código de salida distinto de 0 si algún test falla.

## Builds para playtest

```
./tools/build.sh      # o tools/build.ps1 en Windows
```

Corre lint y tests, exporta Windows y Linux a `builds/<versión>/`, arma los zips portables y, si hay Inno Setup, el instalador de Windows. La versión sale de `application/config/version` en `project.godot`. Guía para testers: [docs/PLAYTEST_TESTERS.md](docs/PLAYTEST_TESTERS.md).
