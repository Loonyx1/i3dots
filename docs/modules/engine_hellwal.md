# Módulo: engine_hellwal.sh

Motor de generación de colores basado en Hellwal. Se encarga de extraer la paleta de colores del wallpaper activo y aplicarla a través de plantillas.

## Funcionamiento

1. **Wallpaper Activo**: Obtiene la ruta del wallpaper desde `$CURRENT_WALLPAPER_LINK`.
2. **Motor de Wallpaper**: Si se define `$WP_ENGINE` (ej: `awww`), ejecuta el script correspondiente en `core/engines/` para establecer físicamente el fondo de pantalla.
3. **Generación de Colores**: Ejecuta `hellwal` sobre la imagen detectada.
4. **Plantillas y Caché**: 
    - Si `$HELLWAL_TEMPLATES_DIR` existe, usa esas plantillas para generar archivos de configuración.
    - Los archivos generados se guardan en `$HELLWAL_CACHE_DIR`.

## Variables de Configuración (`config.env`)

| Variable | Descripción |
|----------|-------------|
| `WP_ENGINE` | Motor de renderizado de wallpaper (ej: `awww`, `feh`). |
| `HELLWAL_TEMPLATES_DIR` | Directorio que contiene las plantillas `.hellwal`. |
| `HELLWAL_CACHE_DIR` | Directorio donde se guardarán los archivos procesados. |

## Argumentos del Módulo

| Flag | Descripción |
|------|-------------|
| `-L` | Genera un tema claro (Light). |
| `-D` | Genera un tema oscuro (Dark - por defecto). |
| `-N` | Usa el modo de 16 colores. |
| `-T` | Omite la actualización de colores de la terminal. |

## Uso desde `dots`

```bash
./dots run <paquete> engine_hellwal.sh        # Generar tema oscuro
./dots run <paquete> engine_hellwal.sh -L     # Generar tema claro
```

