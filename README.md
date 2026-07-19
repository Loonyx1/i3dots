# i3 dots

# Imagenes

<details><summary><h2>Fullscreen</h2></summary>

![](/assets/Screenshot_2026-04-30_17-12-09.jpg)

</details><br>

<details><summary><h2>Rofi Launcher</h2></summary>

![](/assets/Screenshot_2026-04-30_17-12-45.jpg)

</details><br>

<details><summary><h2>Wallpaper Selector</h2></summary>

![](/assets/Screenshot_2026-04-30_17-13-07.jpg)

</details><br>

<details><summary><h2>Rofi Powermenu</h2></summary>

![](/assets/Screenshot_2026-04-30_17-13-40.jpg)

</details><br>

# Instalacion 

```
mkdir screenshots
```

```
git clone --depth 1 https://github.com/Loonyx1/i3dots.git
```

```
cd i3dots
```
### Para install del dotfile en debian y void
```
./dots install i3dots (name distro)
```

# Teclas/Atajos

| Keys | Action |
|:-|:-|
|<kbd>super</kbd> + <kbd>D</kbd>|Rofi Launcher
|<kbd>super</kbd> + <kbd>F</kbd>| Fullscreen switcher
|<kbd>super</kbd> + <kbd>Q</kbd>| Kill Focused Window
|<kbd>super</kbd> + <kbd>W</kbd>|  wallpaper Selector
|<kbd>super</kbd> + <kbd>Tab</kbd>|Powermenu
|<kbd>Super</kbd> + <kbd> E | pcmanfm-qt
|<kbd>super</kbd> + <kbd>Shift</kbd> + <kbd>R</kbd>| Restart I3
|<kbd>super</kbd> + <kbd>Shift</kbd> + <kbd>B</kbd>| Abrir el menu para cambiar la polybar
|<kbd>super</kbd> + <kbd>Shift</kbd> + <kbd>M</kbd>| Abrir el menu para cambiar la polybar de tamaño
|<kbd>super</kbd> + <kbd>Shift</kbd> + <kbd>D</kbd>| Abrir el menu para cambiar la resolucion de pantalla
|<kbd>super</kbd> + <kbd>H</kbd>| Abrir visor de atajos (Cheatsheet)
|<kbd>super</kbd> + <kbd>B</kbd>| Alternar bordes de la ventana enfocada
|<kbd>Super</kbd> | Hold to drag floating windows to the desired position
# Screenshots keys on clipboard

| Keys | Screenshot  |
|:-|:-|
|<kbd>super</kbd> + <kbd>Shift</kbd> + <kbd>S</kbd>|Selection|
|<kbd>super</kbd> + <kbd>print</kbd>|Active Window
|<kbd>Print</kbd>|Full Screen|

# Screenshots (Carpeta ~/screenshots)

| Keys | Screenshot  |
|:-|:-|
|<kbd>Shift</kbd> + <kbd>print</kbd>|Selection|
|<kbd>super</kbd> + <kbd>Ctrl</kbd> + <kbd>print</kbd>|Active Window
|<kbd>Ctrl</kbd> + <kbd>Print</kbd> |Full Screen|

# Live Wallpaper

El motor detecta configuración desde el nombre del archivo:

| Nombre                          | Skip          | FPS  |
|---------------------------------|---------------|------|
| `video.mp4`                     | `nonref`      |  ∞   |
| `video_noskip.mp4`              | `none`        |  ∞   |
| `video_fps30.mp4`               | `nonref`      |  30  |
| `video_noskip_fps60.mp4`        | `none`        |  60  |

- `_noskip` → desactiva el skip de frames. Por defecto mpv salta frames no-referencia (`nonref`) para reducir CPU. Con `_noskip` se renderiza cada frame, mayor calidad pero más consumo.
- `_fps<N>` → limita los FPS (ej. `_fps30`, `_fps60`). Reduce consumo en videos de alta tasa.
- Se pueden combinar: `video_noskip_fps30.mp4`.

### Uso

- **Selector Rofi**: los wallpapers se ponen en `~/wall/live/` y aparecen automáticamente en el menú (<kbd>Super</kbd> + <kbd>Ctrl</kbd> + <kbd>W</kbd>).
- **Gestor de archivos**: botón derecho sobre el archivo → `Wallpaper i3` (se integra solo en Thunar y pcmanfm).
