# Plastiquito: Pop Everything — Guía para testers

Gracias por probar el juego. Es un juego de reventar plástico de burbujas. No hace falta saber nada más: jugá unos 5 minutos.

## Cómo instalar

**Opción 1: instalador (Windows, la más fácil)**
1. Hacé doble clic en `Plastiquito_<versión>_setup.exe`.
2. Seguí los pasos del instalador. No pide permisos de administrador.
3. Al final dejá tildado "Jugar ahora".

**Opción 2: zip portable (Windows o Linux)**
1. Descomprimí `Plastiquito_<versión>_windows.zip` (o `_linux.zip`) en cualquier carpeta.
2. En Windows, hacé doble clic en `Plastiquito.exe`. En Linux, abrí una terminal en la carpeta y corré `./Plastiquito.x86_64`.

### Aviso "Windows protegió su PC"
Es normal. Aparece porque el instalador todavía no está firmado digitalmente (la firma cuesta plata y es un juego de prueba). Para seguir:
1. Hacé clic en **"Más información"**.
2. Hacé clic en **"Ejecutar de todas formas"**.

## Cómo se juega
- Mantené apretado el botón izquierdo del mouse y pasá sobre el plástico.
- Rueda del mouse: acercar o alejar.
- Alt+Enter: pantalla completa o ventana.
- Esc: menú (volumen, sacudida de cámara, abrir carpeta de datos, salir).

## Cómo desinstalar
- Instalado con el instalador: Configuración de Windows → Aplicaciones → "Plastiquito: Pop Everything" → Desinstalar (o desde el menú Inicio).
- Zip portable: borrá la carpeta.

## Cómo mandar tu archivo de sesión
El juego guarda en tu disco un archivo con datos simples de tu partida (cuánto jugaste, cuántas burbujas reventaste, etc.). **No se envía nada por internet.** Si querés compartirlo:
1. Dentro del juego apretá **Esc** y después **"Abrir carpeta de datos"**.
2. Entrá a la carpeta `playtest`.
3. Mandá el archivo más nuevo (`sesion_<fecha>.csv`) a quien te pasó el juego.

Por si no abre desde el menú, la carpeta está en `%APPDATA%\Plastiquito\playtest` (Windows) o `~/.local/share/Plastiquito/playtest` (Linux).
