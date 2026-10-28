#!/usr/bin/env bash
# Restaura los dotfiles en un PC (pensado para Fedora con GNOME).
#
#   ./install.sh                 todo: paquetes, recursos, copias, enlaces, GNOME y NEPTUNO
#   ./install.sh --solo-enlaces  solo vuelve a crear los enlaces de stow
#   ./install.sh --sin-paquetes --sin-recursos --sin-gnome --sin-neptuno
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

PAQUETES=1 RECURSOS=1 COPIAS_ON=1 GNOME=1 NEPTUNO=1
for arg in "$@"; do
	case "$arg" in
	--solo-enlaces) PAQUETES=0 RECURSOS=0 COPIAS_ON=0 GNOME=0 NEPTUNO=0 ;;
	--sin-paquetes) PAQUETES=0 ;;
	--sin-recursos) RECURSOS=0 ;;
	--sin-gnome) GNOME=0 ;;
	--sin-neptuno) NEPTUNO=0 ;;
	-h | --help) sed -n '2,7p' "$0"; exit 0 ;;
	*) aviso "Opción desconocida: $arg"; exit 1 ;;
	esac
done

DOTFILES_REAL="$(readlink -f "$DOTFILES")"
RESPALDO="$HOME/.dotfiles-respaldo/$(date +%Y%m%d-%H%M%S)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

instalar_paquetes() {
	if command -v apt-get >/dev/null; then
		instalar_apt
	elif ! command -v dnf >/dev/null; then
		aviso "Ni Fedora ni Ubuntu/Debian: instala a mano lo de paquetes/"
	else
		info "Repositorios"
		local fedora
		fedora="$(rpm -E %fedora)"
		sudo dnf install -y \
			"https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$fedora.noarch.rpm" \
			"https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$fedora.noarch.rpm"
		sudo install -m 644 "$DOTFILES"/paquetes/repos/*.repo /etc/yum.repos.d/
		info "Paquetes dnf ($(wc -l <"$DOTFILES/paquetes/dnf.txt"))"
		# shellcheck disable=SC2046
		sudo dnf install -y --skip-unavailable --skip-broken $(cat "$DOTFILES/paquetes/dnf.txt")
	fi
	if command -v flatpak >/dev/null; then
		info "Flatpaks"
		flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
		local origen app remotos
		remotos="$(flatpak remotes --columns=name)"
		while read -r origen app; do
			# "<app>-origin" es un paquete .flatpak suelto: lo instala instalar_apps_github.
			[[ $origen == *-origin ]] && continue
			# Un remoto propio de la distro (p. ej. "fedora" en Ubuntu) se cambia por Flathub.
			grep -qx "$origen" <<<"$remotos" || origen=flathub
			flatpak install --user -y --noninteractive "$origen" "$app" ||
				aviso "No se pudo instalar $app desde $origen"
		done <"$DOTFILES/paquetes/flatpak.txt"
	fi
	if ! command -v starship >/dev/null && [[ ! -x $HOME/.local/bin/starship ]]; then
		info "Starship"
		mkdir -p "$HOME/.local/bin"
		curl -fsSL https://starship.rs/install.sh | sh -s -- -y -b "$HOME/.local/bin" >/dev/null
	fi
	instalar_apps_github
}

# URL del primer recurso de la última release de un repo de GitHub que cumple el patrón.
recurso_github() {
	curl -fsSL "https://api.github.com/repos/$1/releases/latest" |
		grep -oE '"browser_download_url": *"[^"]+"' | cut -d'"' -f4 | grep -E "$2" | head -1
}

# Apps que no están en ningún repositorio: se bajan de sus releases de GitHub.
instalar_apps_github() {
	local ext gestor app url
	if command -v dnf >/dev/null; then
		ext=rpm gestor="sudo dnf install -y"
	elif command -v apt-get >/dev/null; then
		ext=deb gestor="sudo apt-get install -y"
	fi
	if [[ -n ${ext:-} ]]; then
		info "Suite Artcraft (Deckcraft, Gridcraft, Wordcraft)"
		for app in deckcraft gridcraft wordcraft; do
			url="$(recurso_github "storytold/$app" "linux-x86_64\.$ext$")" &&
				[[ -n $url ]] && descargar "$url" "$TMP/$app.$ext" &&
				$gestor "$TMP/$app.$ext" >/dev/null ||
				aviso "No se pudo instalar $app (https://getartcraft.com)"
		done
	fi
	if command -v flatpak >/dev/null; then
		info "Spotifast"
		url="$(recurso_github crmne/spotifast 'x86_64\.flatpak$')" &&
			[[ -n $url ]] && descargar "$url" "$TMP/spotifast.flatpak" &&
			flatpak install --user -y --noninteractive "$TMP/spotifast.flatpak" ||
			aviso "No se pudo instalar Spotifast (https://github.com/crmne/spotifast/releases)"
	fi
	if command -v gnome-shell >/dev/null; then
		# Isle 1.4.0 trae el demonio isled; restaurar_copias pone encima mi versión en español
		# (fork en https://github.com/Gdearmascasta/Notch).
		info "Isle 1.4.0"
		curl -fsSL https://raw.githubusercontent.com/zickrian/isle/v1.4.0/get.sh |
			ISLE_VERSION=1.4.0 bash || aviso "No se pudo instalar Isle"
	fi
}

instalar_apt() {
	info "Paquetes apt"
	sudo apt-get update -qq
	local p disponibles=() faltan=()
	while read -r p; do
		[[ -z $p || $p == \#* ]] && continue
		if apt-cache show "$p" >/dev/null 2>&1; then disponibles+=("$p"); else faltan+=("$p"); fi
	done <"$DOTFILES/paquetes/apt.txt"
	# Un paquete que no se pueda descargar no debe impedir restaurar las configuraciones.
	sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --fix-missing "${disponibles[@]}" ||
		aviso "apt no pudo instalar todo; revisa la red y vuelve a ejecutar install.sh"
	((${#faltan[@]} == 0)) || aviso "No están en los repos de esta versión: ${faltan[*]}"
}

descargar() { curl -fL --retry 3 -o "$2" "$1"; }

instalar_recursos() {
	local iconos="$HOME/.local/share/icons" fuentes="$HOME/.local/share/fonts"
	mkdir -p "$iconos" "$HOME/.icons" "$fuentes"

	info "Iconos Colloid y WhiteSur"
	git clone -q --depth 1 https://github.com/vinceliuice/Colloid-icon-theme "$TMP/colloid"
	(cd "$TMP/colloid" && ./install.sh -d "$iconos" >/dev/null)
	git clone -q --depth 1 https://github.com/vinceliuice/WhiteSur-icon-theme "$TMP/whitesur"
	(cd "$TMP/whitesur" && ./install.sh -d "$iconos" >/dev/null)

	info "Iconos Flat-Remix (azul claro y oscuro)"
	git clone -q --depth 1 --filter=blob:none --sparse https://github.com/daniruiz/flat-remix "$TMP/flat-remix"
	git -C "$TMP/flat-remix" sparse-checkout set Flat-Remix-Blue-Dark Flat-Remix-Blue-Light
	cp -a "$TMP/flat-remix/Flat-Remix-Blue-Dark" "$TMP/flat-remix/Flat-Remix-Blue-Light" "$HOME/.icons/"

	info "Tema Nordic"
	git clone -q --depth 1 https://github.com/EliverLara/Nordic "$TMP/nordic"
	rm -rf "$TMP/nordic/.git"
	rm -rf "$iconos/Nordic-master"
	cp -a "$TMP/nordic" "$iconos/Nordic-master"

	info "Cursor Bibata-Modern-Ice"
	descargar https://github.com/ful1e5/Bibata_Cursor/releases/latest/download/Bibata-Modern-Ice.tar.xz "$TMP/bibata.tar.xz"
	tar -xJf "$TMP/bibata.tar.xz" -C "$HOME/.icons"

	info "Fuentes Nerd (JetBrainsMono, FantasqueSansMono) y VictorMono"
	local f
	for f in JetBrainsMono FantasqueSansMono; do
		descargar "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/$f.tar.xz" "$TMP/$f.tar.xz"
		mkdir -p "$fuentes/${f}Nerd"
		tar -xJf "$TMP/$f.tar.xz" -C "$fuentes/${f}Nerd"
	done
	descargar https://rubjo.github.io/victor-mono/VictorMonoAll.zip "$TMP/victor.zip"
	mkdir -p "$fuentes/VictorMono"
	unzip -qo "$TMP/victor.zip" -d "$fuentes/VictorMono"
}

restaurar_copias() {
	info "Agentes y recursos de escritorio"
	local linea carpeta origen
	for linea in "${COPIAS[@]}"; do
		read -r carpeta origen <<<"$linea"
		[[ -d $DOTFILES/$carpeta ]] || continue
		mkdir -p "$origen"
		# Sin --delete: no se borra lo que solo existe en este PC (credenciales, historial).
		rsync -a "$DOTFILES/$carpeta/" "$origen/"
		echo "  $origen"
	done
	command -v fc-cache >/dev/null && fc-cache -f >/dev/null
	local dir
	if command -v npm >/dev/null; then
		for dir in "$HOME/.config/opencode" "$HOME"/.claude/skills/*/; do
			[[ -f $dir/package.json && ! -d $dir/node_modules ]] || continue
			(cd "$dir" && npm install --silent --no-fund --no-audit) || aviso "npm install falló en $dir"
		done
	fi
}

# Aparta lo que ocupa el sitio de un enlace, sea un archivo real o un enlace de otra estructura.
apartar() {
	local ruta="$1"
	[[ -e $ruta || -L $ruta ]] || return 0
	local dest="$RESPALDO/${ruta#"$HOME"/}"
	mkdir -p "$(dirname "$dest")"
	mv "$ruta" "$dest"
	echo "  apartado: $ruta"
}

crear_enlaces() {
	command -v stow >/dev/null || { aviso "Falta stow (sudo dnf install stow)"; exit 1; }
	info "Enlaces con stow"
	local linea paquete destino item t
	for linea in "${ENLACES[@]}"; do
		read -r paquete destino _ <<<"$linea"
		[[ -d $DOTFILES/$paquete ]] || continue
		# El destino puede ser un enlace de la estructura vieja (~/.config/cava -> .../cava/.config/cava).
		[[ -L $destino ]] && apartar "$destino"
		mkdir -p "$destino"
		for item in $(ls -A "$DOTFILES/$paquete"); do
			t="$destino/$item"
			[[ -L $t && $(readlink -f "$t") == "$DOTFILES_REAL/$paquete/$item" ]] && continue
			apartar "$t"
		done
		stow -d "$DOTFILES" -t "$destino" -R "$paquete"
		echo "  $paquete -> $destino"
	done
	[[ -d $RESPALDO ]] && info "Lo que estaba antes quedó en $RESPALDO"

	# GTK 4 lee el tema desde ~/.config/gtk-4.0; estos enlaces dependen del tema instalado.
	local tema="$HOME/.local/share/themes/Orchis-Grey-Dark/gtk-4.0" f
	if [[ -d $tema ]]; then
		for f in assets gtk.css gtk-dark.css; do
			ln -sfn "$tema/$f" "$HOME/.config/gtk-4.0/$f"
		done
	fi
}

aplicar_gnome() {
	command -v dconf >/dev/null || { aviso "Sin dconf: se omiten los ajustes de GNOME"; return; }
	info "Ajustes de GNOME"
	local ruta archivo antes
	# Se guarda la lista de extensiones del sistema (p. ej. el dock de Ubuntu) para sumarla a la mía.
	antes="$(dconf read /org/gnome/shell/enabled-extensions)"
	for ruta in "${DCONF_RUTAS[@]}"; do
		archivo="$(dconf_archivo "$ruta")"
		[[ -f $archivo ]] && sed "s|@HOME@|$HOME|g" "$archivo" | dconf load "$ruta"
	done
	dconf write /org/gnome/shell/enabled-extensions "$(python3 -I - "$antes" \
		"$(dconf read /org/gnome/shell/enabled-extensions)" <<'EOF'
import ast, sys
def lista(v):
    v = v.strip().removeprefix('@as').strip()
    return ast.literal_eval(v) if v else []
union = []
for uuid in lista(sys.argv[1]) + lista(sys.argv[2]):
    if uuid not in union:
        union.append(uuid)
print(repr(union))
EOF
	)"
	revisar_extensiones
	echo "  Cierra sesión y vuelve a entrar para que GNOME cargue las extensiones."
}

# Avisa de las extensiones que no declaran la versión de GNOME de este PC.
revisar_extensiones() {
	command -v gnome-shell >/dev/null || return 0
	local version
	version="$(gnome-shell --version | grep -oE '[0-9]+' | head -1)"
	python3 -I - "$version" "$HOME/.local/share/gnome-shell/extensions" <<'EOF'
import json, pathlib, sys
version, raiz = sys.argv[1], pathlib.Path(sys.argv[2])
for meta in sorted(raiz.glob('*/metadata.json')):
    soportadas = json.loads(meta.read_text()).get('shell-version', [])
    if not any(str(v).split('.')[0] == version for v in soportadas):
        print(f"\033[1;33m[!]\033[0m {meta.parent.name} no declara GNOME {version} (declara {', '.join(map(str, soportadas))})",
              file=sys.stderr)
EOF
}

clonar_neptuno() {
	local destino="$HOME/Documentos/Neptuno/NEPTUNO"
	[[ -d $destino/.git ]] && return
	info "NEPTUNO"
	mkdir -p "$(dirname "$destino")"
	git clone -q https://github.com/Jmyukopila/NEPTUNO.git "$destino"
	echo "  clonado en $destino"
}

configurar_filtro
((PAQUETES)) && instalar_paquetes
((RECURSOS)) && instalar_recursos
((COPIAS_ON)) && restaurar_copias
crear_enlaces
((GNOME)) && aplicar_gnome
((NEPTUNO)) && clonar_neptuno

info "Listo"
if ((COPIAS_ON)); then
	cat <<'EOF'
Falta a mano (no se guardan en el repo por seguridad):
  - Iniciar sesión en Claude Code y en opencode.
  - Recrear ~/.config/opencode/config.json (API key) y service.json.
  - Instalar gentle-ai y engram; la memoria de Engram empieza vacía.
EOF
fi
