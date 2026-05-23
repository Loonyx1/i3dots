# Dots Manager - Gestor de Dotfiles Autocontenidos

Orquestador modular diseñado para la portabilidad absoluta. Gestiona entornos (Sway, Hyprland, etc.) como paquetes independientes con sus propios scripts, hooks y configuraciones.

> **Nota sobre la nomenclatura**: En esta documentación, **TU_PAQUETE** hace referencia al nombre de la carpeta que crees dentro del directorio `packages/` (por ejemplo: `swaydots`, `hyprland`, `i3`).

## Estructura del Proyecto

- dots: Ejecutable principal (Orquestador).
- wall: Atajo rápido para gestión de wallpapers.
- core/: Núcleo del sistema.
  - bin/: Scripts compartidos (selección de wall, motores de color).
  - engines/: Motores de fondo de pantalla (swww, feh, etc.).
  - state/: Persistencia (link del wallpaper actual, caché de colores).
- packages/: Repositorio de dotfiles. Cada subcarpeta es un paquete.
  - TU_PAQUETE/config.env: Configuración y secuencias.
  - TU_PAQUETE/bin/: Scripts exclusivos del paquete.
  - TU_PAQUETE/hooks/: Lógica de componentes (Waybar, Kitty).
  - TU_PAQUETE/templates/: Plantillas para generadores de color.
  - TU_PAQUETE/dotfiles/: Archivos de configuración reales (opcional).
  - TU_PAQUETE/install.sh: Script de instalación de enlaces simbólicos.

## Uso de Comandos (CLI)

### 1. Gestión de Paquetes
```bash
./dots install <paquete> [variante] [argumentos]
# Ejemplo: Instalar con variante debian
./dots install i3dots debian

./dots apply <paquete> [variante] [argumentos]
# Ejemplo: Aplicar configuración actual (alias de install)
./dots apply swaydots

./dots run <paquete> <accion> [argumentos]
# Ejemplo: Ejecutar solo el lanzador de swaydots
./dots run swaydots launcher
```
Nota: Si no se especifica comando, el sistema intentará detectar si el segundo argumento es una acción (secuencia/script). Si no lo es, se asume `install`.

### 2. Exportación e Importación (Portabilidad)
```bash
# Exportar un paquete a un archivo .tar.gz
./dots export swaydots

# Importar un paquete desde un archivo
./dots import mi_setup.tar.gz
```


### 3. Argumentos Dirigidos (-P:prefijo)
Envía parámetros a scripts específicos de la secuencia:
```bash
./dots swaydots -D -P:engine_hellwal -L -P:apply_dots -E sway
```
- -D: Argumento general para todos.
- -P:engine_hellwal -L: Pasa -L solo al motor de colores.
- -P:apply_dots -E sway: Pasa -E sway solo al aplicador de hooks.

## Creación de Secuencias Personalizadas

En tu config.env puedes definir flujos de ejecución a medida:

```bash
# Secuencia por defecto (ejecutada con ./dots paquete)
export DOT_SEQUENCE=("wp_select.sh" "engine_hellwal.sh" "apply_dots.sh")

# Secuencia personalizada (ejecutada con ./dots paquete reload)
export DOT_SEQUENCE_RELOAD=("engine_hellwal.sh" "apply_dots.sh")

# Secuencia para un lanzador (ejecutada con ./dots paquete launcher)
export DOT_SEQUENCE_LAUNCHER=("slauncher.sh")
```
```
## Quien hace que (Responsabilidades)

Para entender el sistema, es vital saber que **dots** no hace el trabajo pesado; solo organiza a los que si lo hacen:

### El Orquestador (dots)
- Detecta el entorno activo o forzado.
- Carga las variables de entorno desde el `config.env` del paquete.
- **Enruta los argumentos**: Si mandas `-P:engine_hellwal -L`, el se encarga de que ese `-L` le llegue solo a quien debe.
- Ejecuta la lista de scripts en el orden indicado.

### Scripts de Secuencia (core/bin/ o paquete/bin/)
- **wp_select.sh**: Su unico trabajo es dejarte elegir una imagen y guardar la ruta en `core/state/`.
- **engine_hellwal.sh**: Toma la imagen guardada en `state/`, lee si quieres modo claro/oscuro, y genera los archivos de colores usando `hellwal`.
- **apply_dots.sh**: Lee tu lista de `MANAGED_COMPONENTS` y llama a los hooks correspondientes. No sabe que hace cada hook, solo los llama.

### Los Hooks (hooks/)
- **Componentes**: Son los que realmente tocan tus archivos de configuracion (ej: mueven el `colors.css` a la carpeta de Waybar).
- **Entorno**: Es el que finalmente apaga y enciende los programas (ej: `pkill waybar && waybar`).

## Arquitectura de Hooks

El sistema utiliza hooks para aplicar cambios de configuración y reiniciar servicios. Se dividen en dos categorías:

### 1. Componentes (hooks/components/)
Son scripts modulares para aplicaciones individuales (Kitty, Waybar, Dunst).
- **Ejecución**: Se activan solo si el componente está listado en la variable `MANAGED_COMPONENTS` de tu `config.env`.
- **Propósito**: Realizar tareas quirúrgicas como mover archivos de colores o configuraciones específicas de la app.
- **Flujo**: Se ejecutan en orden secuencial al inicio del proceso de aplicación.

### 2. Entornos (hooks/envs/)
Scripts de propósito general para el gestor de ventanas o entorno de escritorio (Sway, Hyprland).
- **Ejecución Automática**: Para que un hook de entorno se ejecute automáticamente sin usar flags, **debe llamarse igual que el paquete** (ej: `swaydots.sh` para el paquete `swaydots`).
- **Propósito**: Orquestación final. Es el lugar ideal para reiniciar barras de estado (pkill waybar), recargar el compositor o aplicar cambios globales.
- **Flujo**: Se ejecuta siempre al final de toda la secuencia, asegurando que todos los componentes ya estén configurados.

## Prioridad de Scripts y Acciones
...
Cuando dots ejecuta una acción, la busca en este orden:
1. packages/PAQUETE/bin/ (Exclusivo)
2. core/bin/ (Compartido)
3. $PATH (Sistema)

## Filosofia
El sistema está diseñado para ser autocontenido. Todo lo que define el "look and feel" de tu escritorio debe vivir dentro de su respectiva carpeta en packages/, permitiéndote cambiar de setup o de PC simplemente moviendo esa carpeta.
