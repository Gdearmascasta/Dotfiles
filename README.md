# Dotfiles

Mi escritorio Fedora + GNOME: configuraciones de apps, temas, extensiones, fuentes, lista de paquetes
y la configuración de Claude Code, opencode y gentle-ai (NEPTUNO).

## Instalar en un PC nuevo

El repo es público: se clona por HTTPS, sin clave SSH ni cuenta de GitHub.

Fedora:

```bash
sudo dnf install -y git stow rsync
git clone https://github.com/Gdearmascasta/Dotfiles.git ~/dotfiles
~/dotfiles/install.sh
```

Ubuntu/Debian:

```bash
sudo apt install -y git stow rsync
git clone https://github.com/Gdearmascasta/Dotfiles.git ~/dotfiles
~/dotfiles/install.sh
```

En Ubuntu el script usa `paquetes/apt.txt` (omite lo que no exista en esa versión), cambia los
flatpaks de remotos de Fedora por Flathub y suma tus extensiones a las del sistema, sin apagar el
dock de Ubuntu. Avisa de las extensiones que no declaran la versión de GNOME instalada.

Pide la contraseña de sudo para los paquetes y descarga unos 700 MB de iconos y fuentes. Antes
conviene crear un punto de restauración del sistema:
`sudo timeshift --create --comments "antes de dotfiles"` (Timeshift se instala con dnf o apt).

Después, cierra sesión y vuelve a entrar para que GNOME cargue extensiones y tema.

Si solo clonas el repo para editarlo, ejecuta antes `./install.sh --solo-enlaces` o `./backup.sh`: activan el
filtro que quita los datos personales y el hook que impide hacer commit sin él. Para hacer push
necesitas permiso de escritura en el repo (SSH o `gh auth login`).

Opciones: `--solo-enlaces`, `--sin-paquetes`, `--sin-recursos`, `--sin-agentes`, `--sin-gnome`, `--sin-neptuno`.

El paso de agentes instala Claude Code, opencode y gentle-ai (con Engram, Context7 y las skills de
`agentes/gentle-ai/state.json`), y después pone encima la configuración de `agentes/`. Falta iniciar
sesión a mano: `claude` y luego `/login`, y `opencode auth login`.
Lo que ocupaba el sitio de un enlace no se borra: queda en `~/.dotfiles-respaldo/<fecha>/`.

## Actualizar el respaldo

```bash
~/dotfiles/backup.sh
git -C ~/dotfiles add -A && git -C ~/dotfiles commit -m "chore: actualizar dotfiles" && git -C ~/dotfiles push
```

`backup.sh` termina con error si encuentra algo con pinta de secreto.

## Cómo está organizado

| Carpeta | Qué es | Cómo se instala |
|---|---|---|
| `cava/`, `kitty/`, `starship/`, `bash/`… | Configuración de cada app, sin repetir `.config/<app>` | Enlace con `stow`; el destino de cada una está en `ENLACES` de `lib.sh` |
| `agentes/` | `~/.claude`, `~/.config/opencode`, `~/.gentle-ai` | Copia (NEPTUNO y gentle-ai regeneran esos archivos) |
| `escritorio/` | Extensiones, temas GTK/Shell, fondos, fuentes propias, dconf | Copia + `dconf load` |
| `spotifast/` | Ajustes y temas de Spotifast (sin los presets de MilkDrop, que se bajan desde la app) | Copia |
| `paquetes/` | Paquetes dnf, flatpaks y repos de terceros | `dnf` / `flatpak` |

Se descargan al instalar (no van en git por tamaño): iconos Colloid, WhiteSur y Flat-Remix,
Nordic, cursor Bibata-Modern-Ice y las fuentes Nerd JetBrainsMono, FantasqueSansMono y VictorMono.

Apps que no están en ningún repositorio y se bajan de la última release de GitHub: la suite
Artcraft (Deckcraft, Gridcraft y Wordcraft, en `.rpm` o `.deb`), Spotifast (`.flatpak`) e Isle 1.4.0,
que trae el demonio `isled`. Encima de Isle queda mi versión en español, respaldada en
`escritorio/extensiones` (fork en https://github.com/Gdearmascasta/Notch).

Para añadir una app nueva: agrega una línea a `ENLACES` en `lib.sh` y ejecuta `backup.sh`.

## Lo que no se respalda

- Datos personales de archivos que sí se respaldan: los documentos recientes de Deckcraft, Wordcraft y
  Gridcraft, las búsquedas de Spotifast, el historial de música de GNOME y el token de captura de OBS.
  Los quita `filtros/privado.py` al hacer commit (filtro de git declarado en `.gitattributes`), sin
  tocar los archivos de las apps; `backup.sh` e `install.sh` lo activan en el clon.
- Las fuentes SF Pro y los fondos de macOS, que son de Apple: se instalan a mano
  (https://developer.apple.com/fonts/).

- Credenciales de Claude Code, la API key de opencode (`config.json`, `service.json`) y la clave de gentle-ai.
- Historial de chats, telemetría, cachés y la memoria de Engram.
- El perfil de Obsidian (está en cada bóveda, en `.obsidian/`).

Las rutas a la carpeta personal se guardan en el repo como `@HOME@` y cada equipo las recupera con la
suya al clonar o hacer `git pull`, así que da igual el nombre de usuario. Si clonaste antes de que
existiera esto, `./install.sh --solo-enlaces` convierte los archivos que aún tengan `@HOME@`.
