# Módulo: apply_dots.sh

El motor de aplicación de componentes. Es el encargado de orquestar la ejecución de los hooks definidos en el paquete.

## Funcionamiento

1. **Iteración de Componentes**: Lee la variable `MANAGED_COMPONENTS` (una lista separada por espacios).
2. **Mapeo de Variables**: Para cada componente (ej: `kitty`), busca una variable llamada `COMPONENT_KITTY`.
3. **Ejecución de Hooks de Componente**: Si la variable tiene valor, busca el script en `$HOOK_DIR/components/kitty.sh` y lo ejecuta pasando el valor de la variable como `$1`.
4. **Ejecución de Hook de Entorno**: 
    - Si se usa `-E <nombre>`, ejecuta `hooks/envs/<nombre>.sh`.
    - Si no, intenta auto-detectar usando `$CURRENT_ENV`.

## Variables Requeridas

| Variable | Descripción |
|----------|-------------|
| `MANAGED_COMPONENTS` | Lista de componentes a procesar. |
| `HOOK_DIR` | Directorio donde residen los hooks. |
| `COMPONENT_<NOMBRE>` | Valor que se pasará al hook del componente. |

## Ejemplo de Flujo

Si `MANAGED_COMPONENTS="waybar"`, `apply_dots.sh` hará:
1. Buscar `COMPONENT_WAYBAR` en `config.env`.
2. Ejecutar `hooks/components/waybar.sh "valor_de_la_variable"`.
