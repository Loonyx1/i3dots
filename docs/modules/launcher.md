# Módulo: launcher.sh

Lanzador de aplicaciones universal agnóstico al WM. Permite inyectar estilos dinámicos (como el wallpaper actual) de forma automática.

## Funcionamiento

El módulo es "inteligentemente tonto":
1. Lee la configuración del paquete.
2. Si existe un wallpaper activo (`CURRENT_WALLPAPER_LINK`) y una plantilla de estilo, genera el comando de inyección.
3. Ejecuta el binario definido pasando los argumentos y el estilo dinámico.

## Variables de Configuración (`config.env`)

| Variable | Descripción | Valor Ejemplo / Defecto |
|----------|-------------|-------------------|
| `LAUNCHER_BIN` | Ejecutable del lanzador. | `rofi` |
| `LAUNCHER_ARGS` | Argumentos base (tema, modo, iconos). | `-show drun -theme path/to/theme.rasi` |
| `LAUNCHER_STYLE_TEMPLATE` | Plantilla CSS/estilo. El placeholder `%s` se reemplaza por la ruta de la imagen. | `'inputbar { background-image: url("%s", width); }'` |
| `LAUNCHER_STYLE_FLAG` | Flag para inyectar el string de estilo. | `-theme-str` (por defecto para Rofi) |

## Ejemplo para Rofi

```bash
export LAUNCHER_BIN="rofi"
export LAUNCHER_ARGS="-show drun -theme $PACKAGE_DIR/dotfiles/rofi/launcher.rasi"
export LAUNCHER_STYLE_TEMPLATE='inputbar { background-image: url("%s", width); }'
```

## Ejemplo para Wofi (Conceptuado)

```bash
export LAUNCHER_BIN="wofi"
export LAUNCHER_ARGS="--show drun"
# Wofi usa CSS externo, aquí se podría pasar un flag si el usuario lo implementa
```
