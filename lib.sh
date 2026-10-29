#!/usr/bin/env bash
# Tablas y funciones compartidas por install.sh y backup.sh.

DOTFILES="${DOTFILES:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"

# Configuraciones que se enlazan con stow: "paquete destino elemento...".
# Cada paquete guarda solo sus elementos, sin repetir la ruta del destino
# (cava/config, no cava/.config/cava/config).
ENLACES=(
	"bash          $HOME                                           .bashrc .bash_profile"
	"cava          $HOME/.config/cava                              config shaders"
	"fastfetch     $HOME/.config/fastfetch                         config.jsonc"
	"kitty         $HOME/.config/kitty                             kitty.conf"
	"aplicaciones  $HOME/.local/share/applications                 kitty.desktop"
	"neofetch      $HOME/.config/neofetch                          config.conf"
	"ghostty       $HOME/.config/ghostty                           config wallust.conf"
	"wezterm       $HOME/.config/wezterm                           wezterm.lua"
	"starship      $HOME/.config                                   starship.toml"
	"mimeapps      $HOME/.config                                   mimeapps.list"
	"pavucontrol   $HOME/.config                                   pavucontrol.ini"
	"kde           $HOME/.config                                   kdeglobals kdenliverc"
	"gtk-3.0       $HOME/.config/gtk-3.0                           settings.ini bookmarks"
	"gtk-4.0       $HOME/.config/gtk-4.0                           settings.ini"
	"nwg-look      $HOME/.config/nwg-look                          config"
	"xfce4         $HOME/.config/xfce4                             helpers.rc xfconf"
	"tide-island   $HOME/.config/tide-island                       config-app.ini"
	"gridcraft     $HOME/.config/gridcraft                         prefs.json ui.json"
	"deckcraft     $HOME/.config/deckcraft                         prefs.json ui.json"
	"wordcraft     $HOME/.config/wordcraft                         ui.json"
	"rstudio       $HOME/.config/rstudio                           rstudio-prefs.json dictionaries"
	"vscode        $HOME/.var/app/com.visualstudio.code/config/Code/User   settings.json mcp.json"
	"obs-studio    $HOME/.var/app/com.obsproject.Studio/config/obs-studio  basic global.ini user.ini"
)

# Carpetas que se copian en vez de enlazarse: "carpeta-del-repo origen".
# Los agentes se copian porque NEPTUNO y gentle-ai regeneran sus archivos;
# los recursos de escritorio, porque GNOME y las apps los actualizan solos.
COPIAS=(
	"agentes/claude          $HOME/.claude"
	"agentes/opencode        $HOME/.config/opencode"
	"agentes/gentle-ai       $HOME/.gentle-ai"
	"escritorio/extensiones  $HOME/.local/share/gnome-shell/extensions"
	"escritorio/temas        $HOME/.local/share/themes"
	"escritorio/temas-gtk    $HOME/.themes"
	"escritorio/fondos       $HOME/.local/share/backgrounds"
	"escritorio/cursor       $HOME/.icons/default"
	"escritorio/fuentes      $HOME/.local/share/fonts"
	"spotifast               $HOME/.var/app/rocks.spotifast.Spotifast/config/spotifast"
)

# Reglas de rsync de cada copia. El orden importa: gana la primera que coincide.
filtro_copia() {
	case "$1" in
	agentes/claude)
		# Fuera quedan credenciales, historial de chats, telemetría y cachés.
		printf '%s\n' '+ /CLAUDE.md' '+ /settings.json' '+ /.neptuno-sync.json' \
			'+ /agents/***' '+ /docs/***' '+ /hooks/***' \
			'- /skills/synced/' '- node_modules/' '+ /skills/***' \
			'+ /plugins/' '+ /plugins/installed_plugins.json' '+ /plugins/known_marketplaces.json' \
			'- *'
		;;
	agentes/opencode)
		# config.json, service.json y antigravity-accounts.json guardan una API key, una contraseña y cuentas.
		printf '%s\n' '- node_modules/' '- *.bak*' '- /config.json' '- /service.json' \
			'- /antigravity-accounts.json' '- /.gentle-ai-telemetry-runtime.json' '- /.Rhistory'
		;;
	agentes/gentle-ai)
		# review-context.key es una clave privada: no sale de la máquina.
		printf '%s\n' '+ /state.json' '- *'
		;;
	escritorio/fuentes)
		# El resto de fuentes se descarga en install.sh; SF Pro es de Apple y no se redistribuye.
		printf '%s\n' '+ /rain-clock/***' '+ /geist/***' '- *'
		;;
	escritorio/fondos)
		# Fondos de Apple: no se redistribuyen.
		printf '%s\n' '- *macos*' '- *.bak*'
		;;
	spotifast)
		# Los 135 MB de presets de MilkDrop se vuelven a bajar desde la app ("Get pack").
		printf '%s\n' '- /milkdrop/' '- *.bak*'
		;;
	*)
		printf '%s\n' '- *.bak*'
		;;
	esac
}

# Ramas de dconf que se respaldan (apariencia, extensiones, atajos).
DCONF_RUTAS=(
	/org/gnome/shell/
	/org/gnome/desktop/interface/
	/org/gnome/desktop/background/
	/org/gnome/desktop/screensaver/
	/org/gnome/desktop/wm/preferences/
	/org/gnome/desktop/wm/keybindings/
	/org/gnome/mutter/
	/org/gnome/settings-daemon/plugins/media-keys/
)

dconf_archivo() {
	local nombre="${1#/}"
	nombre="${nombre%/}"
	echo "$DOTFILES/escritorio/dconf/${nombre//\//-}.ini"
}

# Activa el filtro de .gitattributes que quita datos personales al hacer commit.
configurar_filtro() {
	git -C "$DOTFILES" rev-parse --git-dir >/dev/null 2>&1 || return 0
	git -C "$DOTFILES" config filter.privado.clean 'python3 -I filtros/privado.py clean %f'
	git -C "$DOTFILES" config filter.privado.smudge 'python3 -I filtros/privado.py smudge %f'
	git -C "$DOTFILES" config filter.privado.required true
	git -C "$DOTFILES" config core.hooksPath .githooks
	# Lo que se clonó antes de activar el filtro aún tiene @HOME@: se vuelve a sacar del repo para
	# poner la carpeta de este equipo. Solo si no tiene cambios locales.
	local f
	while IFS= read -r -d '' f; do
		git -C "$DOTFILES" diff --quiet -- "$f" || continue
		rm -f "$DOTFILES/$f" && git -C "$DOTFILES" checkout -- "$f"
	done < <(git -C "$DOTFILES" grep -lzF '@HOME@' -- . ':!README.md' ':!filtros' ':!lib.sh' ':!install.sh' ':!backup.sh' || true)
}

# kitty.conf incluye distro.conf: los colores de esta distro, si hay tema en kitty/temas/.
tema_kitty() {
	local id distro="$HOME/.config/kitty/distro.conf"
	[[ -d $HOME/.config/kitty ]] || return 0
	id="$(. /etc/os-release 2>/dev/null; echo "${ID:-}")"
	if [[ -n $id && -f $DOTFILES/kitty/temas/$id.conf ]]; then
		ln -sfn "temas/$id.conf" "$distro"
	elif [[ -L $distro ]]; then
		rm "$distro"
	fi
}

# Enlaza lo que falte sin apartar nada: si un destino ya tiene un archivo propio, stow no toca
# ese paquete y se avisa. Lo usa el hook post-merge después de cada git pull.
enlazar_nuevos() {
	command -v stow >/dev/null || return 0
	local linea paquete destino
	for linea in "${ENLACES[@]}"; do
		read -r paquete destino _ <<<"$linea"
		# Un destino que es enlace viene de la estructura vieja: eso lo arregla install.sh.
		[[ -d $DOTFILES/$paquete && ! -L $destino ]] || continue
		mkdir -p "$destino"
		stow -d "$DOTFILES" -t "$destino" "$paquete" 2>/dev/null ||
			aviso "$paquete: hay archivos propios en $destino; ejecuta ./backup.sh y luego ./install.sh --solo-enlaces"
	done
	tema_kitty
}

info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
aviso() { printf '\033[1;33m[!]\033[0m %s\n' "$*" >&2; }
