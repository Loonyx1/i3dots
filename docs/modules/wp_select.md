# Módulo: wp_select.sh

Selector de wallpaper universal. Gestiona la búsqueda de imágenes, la interfaz de selección y la persistencia del estado.

## Funcionamiento

1. **Búsqueda**: Escanea el directorio `$WALLPAPER_DIR` buscando extensiones comunes (jpg, png, webp, etc).
2. **Interfaz**: 
    - Modo Gráfico (por defecto): Usa el selector configurado (Rofi/Wofi).
    - Modo CLI (`-CT`): Muestra una lista numerada en la terminal.
    - Modo Directo (`-C <ruta>`): Salta la selección y usa la ruta proporcionada.
3. **Persistencia**: 
    - Actualiza un enlace simbólico en `$CURRENT_WALLPAPER_LINK`.
    - Guarda la ruta absoluta en `$LAST_WALLPAPER_PATH_FILE`.

## Variables de Configuración (`config.env`)

| Variable | Descripción | Valor por defecto |
|----------|-------------|-------------------|
| `WALLPAPER_DIR` | Directorio donde están las imágenes. | **Requerido** |
| `CURRENT_WALLPAPER_LINK` | Ruta del symlink que apunta al actual. | **Requerido** |
| `LAST_WALLPAPER_PATH_FILE` | Archivo para persistir la ruta de texto. | **Requerido** |
| `WP_SELECTOR_BIN` | Binario para seleccionar (rofi, wofi). | `rofi` |
| `WP_SELECTOR_ARGS` | Argumentos del selector. | `-dmenu -p "Wallpaper" -theme "${ROFI_THEME}"` |
| `WP_SELECTOR_STYLE` | Estilos extra (flags de tema). | Estilo de iconos grandes para Rofi. |

## Uso desde `dots`

```bash
dots <paquete> wp_select.sh        # Modo gráfico
dots <paquete> wp_select.sh -CT    # Modo terminal
dots <paquete> wp_select.sh -C /path/to/img.jpg  # Modo directo
```
