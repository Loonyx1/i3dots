# Correcciones Técnicas y Soporte de Variantes

Este documento detalla los cambios realizados para mejorar la detección de variantes y la fiabilidad de la instalación en el sistema `mahogara-dots`.

## 1. Detección Inteligente de Argumentos (Orquestador `dots`)

Se ha mejorado la lógica de parseo de argumentos para diferenciar entre **Acciones** y **Variantes/Argumentos**, introduciendo comandos explícitos para eliminar ambigüedades.

### El Problema
Anteriormente, la detección automática podía causar colisiones si el nombre de una variante coincidía con el de una acción. Además, se ejecutaba `install.sh` incluso para acciones rápidas, lo cual era innecesario.

### La Solución
Se han añadido los comandos `install`, `apply` y `run`:
1. **`install` / `apply`**: Comandos dedicados a la instalación y aplicación completa. Ignoran la detección de acciones para sus argumentos, tratándolos siempre como variantes. Ejecutan siempre `install.sh`.
2. **`run`**: Comando para ejecutar acciones específicas (secuencias o scripts). No ejecuta `install.sh`, lo que agiliza la ejecución de utilidades y scripts rápidos.

La detección automática (sin comando explícito) se mantiene por compatibilidad:
- Si el argumento coincide con una acción, se comporta como `run`.
- Si no coincide, se comporta como `install`.

**Ejemplo de uso:**
```bash
# Forzar instalación de variante 'void' aunque existiera una acción 'void'
./dots install i3dots void

# Ejecutar una acción sin pasar por install.sh
./dots run i3dots launcher
```


---

## 2. Ejecución de Comandos Complejos en `install.sh`

Se ha corregido la forma en que los scripts de instalación procesan las variables de entorno de las variantes.

### El Problema
Las variables como `PKG_INSTALL_CMD` suelen contener operadores de shell (ej: `update && sudo apt install`). Al ejecutarlas directamente (`$CMD`), Bash trataba `&&` como un texto literal, intentando buscar un paquete llamado "&&".

### La Solución
Se ha implementado `eval` en los scripts de instalación:
```bash
eval "$PKG_MANAGER $PKG_INSTALL_CMD $PKG_LIST"
```
Esto permite que el shell interprete correctamente los operadores (`&&`, `|`, `;`), permitiendo comandos de instalación multi-paso definidos en los archivos `.env`.

---

## 3. Persistencia de Variante

El sistema de instalación ahora es más robusto al registrar la variante seleccionada:
1. Si pasas un argumento (ej: `void`), se guarda en `.current_variant`.
2. Las ejecuciones posteriores de `dots` cargarán automáticamente esa variante desde `config.env` para mantener la consistencia de los comandos (gestores de paquetes, comandos de apagado, etc.).
