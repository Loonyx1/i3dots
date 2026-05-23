# Módulo: powermenu.sh

Menú de apagado/reinicio universal. Permite personalizar etiquetas (iconos o texto) y comandos de ejecución.

## Funcionamiento

1. **Labels**: Lee las etiquetas configuradas en el paquete. Esto permite cambiar entre "Shutdown" o simplemente un icono "⏻" sin tocar el código.
2. **Selector**: Ejecuta el binario configurado (`rofi`, `wofi`, etc) para mostrar las opciones.
3. **Acciones**: Ejecuta los comandos asociados a cada opción. Los comandos tienen fallbacks estándar de `systemctl` y `loginctl`.

## Variables de Configuración (`config.env`)

| Variable | Descripción | Valor por defecto |
|----------|-------------|-------------------|
| `POWERMENU_BIN` | Binario del selector. | `rofi` |
| `POWERMENU_ARGS` | Argumentos (tema, flags). | (vacío) |
| `POWERMENU_LABEL_SHUTDOWN` | Texto/Icono para apagar. | `Shutdown` |
| `POWERMENU_LABEL_REBOOT` | Texto/Icono para reiniciar. | `Reboot` |
| `POWERMENU_LABEL_SUSPEND` | Texto/Icono para suspender. | `Suspend` |
| `POWERMENU_LABEL_LOGOUT` | Texto/Icono para cerrar sesión. | `Logout` |
| `POWERMENU_CMD_SHUTDOWN` | Comando a ejecutar para apagar. | `systemctl poweroff` |
| `POWERMENU_CMD_REBOOT` | Comando a ejecutar para reiniciar. | `systemctl reboot` |
| `POWERMENU_CMD_SUSPEND` | Comando a ejecutar para suspender. | `systemctl suspend` |
| `POWERMENU_CMD_LOGOUT` | Comando a ejecutar para cerrar sesión. | `loginctl terminate-user $USER` |

## Ejemplo de Configuración

```bash
export POWERMENU_LABEL_SHUTDOWN="⏻"
export POWERMENU_LABEL_REBOOT=""
export POWERMENU_CMD_SUSPEND="mpc pause; lock; systemctl suspend"
```
