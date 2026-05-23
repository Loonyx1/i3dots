# 📊 Módulo Core: engine_bar.sh

Este motor permite gestionar la configuración de la barra (Polybar en X11, Waybar en Wayland) de forma dinámica, permitiendo cambiar estilos (como bordes redondos vs cuadrados) y configuraciones sin editar archivos manualmente.

## 🚀 Capacidades

El motor puede ser usado de forma interactiva o mediante argumentos.

### Argumentos:
| Flag | Parámetro | Descripción |
| :--- | :--- | :--- |
| `-s` | `--style <style>` | Cambia el estilo de los bordes (`round`, `square`). |
| `-p` | `--pos <pos>` | Cambia la posición de la barra (`top`, `bottom`). |
| `-t` | `--trans <bool>` | Activa o desactiva la transparencia (`true`, `false`). |
| `-b` | `--bar <config>` | Cambia el archivo de configuración de la barra (ej: `minimal.ini`). |
| `-L` | `--list` | Lista los estilos y configuraciones disponibles para el entorno actual. |

### Uso Interactivo:
Si se ejecuta sin argumentos, abrirá un selector (Rofi/Wofi) con opciones para Estilo, Posición y Transparencia.

## 🛠 Configuración en `config.env`

Puedes definir los valores por defecto en tu paquete:

```bash
export BAR_STYLE="square"
export BAR_POSITION="bottom"
export BAR_TRANSPARENCY="true"
```

## 📂 Integración con Hooks

Para que este módulo funcione, los hooks de componentes (`polybar.sh`, `waybarbase.sh`) deben leer el estado desde:
- `$STATE_DIR/$CURRENT_ENV/bar/style`

### Ejemplo de Aplicación (Polybar):
```bash
STYLE=$(cat "$STATE_DIR/$CURRENT_ENV/bar/style" 2>/dev/null || echo "$BAR_STYLE")
if [ "$STYLE" == "round" ]; then
    RADIUS=10
else
    RADIUS=0
fi
sed -i "s/^radius = .*/radius = $RADIUS/" "$HOME/.config/polybar/config.ini"
```
