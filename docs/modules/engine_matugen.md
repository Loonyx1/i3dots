# 🎨 Módulo Core: engine_matugen.sh

Este motor integra **Matugen** (Material You color generator) de forma nativa en el gestor. Permite generar paletas de colores con contraste garantizado y jerarquía visual siguiendo la lógica de Material Design 3.

## 🚀 Capacidades

El motor es 100% automático y no interactivo por defecto (selecciona el color más dominante).

### Uso con el Orquestador `dots`:
Puedes pasar parámetros directamente al motor usando el prefijo `-P:engine_matugen`:

| Flag | Parámetro Matugen | Descripción |
| :--- | :--- | :--- |
| `-L` | `--mode light` | Fuerza el modo claro. |
| `-D` | `--mode dark` | Fuerza el modo oscuro (Default). |
| `-T` | `--type scheme-xxx` | Cambia el tipo de esquema (vibe). |
| `-P` | `--prefer xxx` | Prefiere un atributo (saturation, darkness, lightness). |
| `-I` | `--source-color-index` | Selecciona manualmente el índice de dominancia (0-4). |

### Tipos de Esquemas (`-T`) disponibles:
- `scheme-fruit-salad` (Vívido, recomendado por defecto)
- `scheme-expressive` (Colores audaces y saturados)
- `scheme-monochrome` (Elegante, escala de grises del tono principal)
- `scheme-rainbow` (Maximiza la variedad de colores)
- `scheme-fidelity` (Fiel estrictamente a la imagen)
- `scheme-neutral` (Suave, tonos pastel)

## 🛠 Configuración en `config.env`

Para que tus atajos de teclado siempre usen tu configuración favorita, define la secuencia así:

```bash
export DOT_SEQUENCE=(
    "wp_select.sh"
    "engine_matugen.sh -D -T scheme-expressive"
    "apply_dots.sh"
)
```

## 📂 Archivos de Estado
El motor genera automáticamente el archivo `~/.config/matugen/wallpaper.txt` con la ruta del wallpaper actual si existe la plantilla correspondiente en el paquete. Esto permite que Rofi, i3 y otros componentes se sincronicen sin usar `pywal`.
