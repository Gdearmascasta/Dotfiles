#!/usr/bin/env bash
# Restaura los dotfiles en un PC (pensado para Fedora con GNOME).
#
#   ./install.sh                 todo: paquetes, recursos, agentes, copias, enlaces, GNOME y NEPTUNO
#   ./install.sh --solo-enlaces  solo vuelve a crear los enlaces de stow
#   ./install.sh --sin-paquetes --sin-recursos --sin-agentes --sin-gnome --sin-neptuno
set -Eeuo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

PAQUETES=1 RECURSOS=1 AGENTES=1 COPIAS_ON=1 GNOME=1 NEPTUNO=1
for arg in "$@"; do
	case "$arg" in
	--solo-enlaces) PAQUETES=0 RECURSOS=0 AGENTES=0 COPIAS_ON=0 GNOME=0 NEPTUNO=0 ;;
	--sin-paquetes) PAQUETES=0 ;;
	--sin-recursos) RECURSOS=0 ;;
	--sin-agentes) AGENTES=0 ;;
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
trap 'aviso "install.sh se detuvo en la línea $LINENO: $BASH_COMMAND"; aviso "Vuelve a ejecutarlo; los pasos ya hechos no se repiten mal."' ERR

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
			"https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$fedora.noarch.rpm" ||
			aviso "No se pudo instalar RPM Fusion; sus paquetes se omitirán"
		sudo install -m 644 "$DOTFILES"/paquetes/repos/*.repo /etc/yum.repos.d/
		info "Paquetes dnf ($(wc -l <"$DOTFILES/paquetes/dnf.txt"))"
		# Un paquete que falle (p. ej. drivers atados a otro kernel) no debe impedir restaurar las configuraciones.
		# shellcheck disable=SC2046
		sudo dnf install -y --skip-unavailable --skip-broken $(cat "$DOTFILES/paquetes/dnf.txt") ||
			aviso "dnf no pudo instalar todo; el resto de la instalación continúa"
	fi
	if command -v flatpak >/dev/null; then
		info "Flatpaks"
		flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
		local origen app remotos
		# Solo los remotos del usuario: los del sistema (p. ej. "fedora") no sirven con --user.
		remotos="$(flatpak remotes --user --columns=name)"
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
		curl -fsSL https://starship.rs/install.sh | sh -s -- -y -b "$HOME/.local/bin" >/dev/null ||
			aviso "No se pudo instalar Starship"
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

# Claude Code, opencode y gentle-ai (con Engram). Va antes de restaurar_copias para que mi
# configuración de agentes/ quede encima de la que genera gentle-ai.
instalar_agentes() {
	local bin="$HOME/.local/bin"
	mkdir -p "$bin"
	export PATH="$bin:$HOME/.opencode/bin:$PATH"
	# Los instaladores no deben escribir en ~/.bashrc: es un enlace al repo y ya trae estas rutas.
	if ! command -v claude >/dev/null; then
		info "Claude Code"
		curl -fsSL https://claude.ai/install.sh | bash || aviso "No se pudo instalar Claude Code"
	fi
	if ! command -v opencode >/dev/null; then
		info "opencode"
		curl -fsSL https://opencode.ai/v2/install | bash -s -- --no-modify-path || aviso "No se pudo instalar opencode"
	fi
	# El plugin de Engram para Claude Code necesita jq.
	if ! command -v jq >/dev/null; then
		if command -v dnf >/dev/null; then
			sudo dnf install -y jq || aviso "No se pudo instalar jq"
		elif command -v apt-get >/dev/null; then
			sudo apt-get install -y jq || aviso "No se pudo instalar jq"
		fi
	fi
	if ! command -v gentle-ai >/dev/null; then
		info "gentle-ai"
		curl -fsSL https://raw.githubusercontent.com/Gentleman-Programming/gentle-ai/main/scripts/install.sh | bash ||
			aviso "No se pudo instalar gentle-ai"
	fi
	# gentle-ai exige que el plugin de opencode 2 ya esté en ~/.config/opencode/node_modules.
	local oc="$HOME/.config/opencode"
	if [[ -f $DOTFILES/agentes/opencode/package.json ]] && command -v npm >/dev/null; then
		mkdir -p "$oc"
		cp "$DOTFILES"/agentes/opencode/package{,-lock}.json "$oc/" 2>/dev/null || true
		(cd "$oc" && npm install --silent --no-fund --no-audit) || aviso "npm install falló en $oc"
	fi
	local estado="$DOTFILES/agentes/gentle-ai/state.json" opciones
	if command -v gentle-ai >/dev/null && [[ -f $estado ]]; then
		info "gentle-ai: agentes, Engram y skills"
		# Las mismas opciones que tengo en este equipo, leídas del respaldo.
		opciones="$(python3 -I - "$estado" <<'EOF'
import json, sys
e = json.load(open(sys.argv[1]))
print(' '.join([
    '--agents', ','.join(e.get('installed_agents', [])),
    '--components', ','.join(e.get('components', [])),
    '--skills', ','.join(e.get('skills', [])),
    '--preset', e.get('preset', 'custom'),
    '--persona', e.get('persona', 'custom'),
]))
EOF
		)"
		# shellcheck disable=SC2086
		gentle-ai install $opciones || aviso "gentle-ai install falló; ejecútalo a mano: gentle-ai install $opciones"
	fi
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
	# El repo puede volverse privado o cambiar de sitio; la configuración de los agentes ya está en agentes/.
	if git clone -q https://github.com/Jmyukopila/NEPTUNO.git "$destino"; then
		echo "  clonado en $destino"
	else
		aviso "No se pudo clonar NEPTUNO; la configuración de Claude y opencode ya quedó restaurada desde agentes/"
	fi
}

configurar_filtro
((PAQUETES)) && instalar_paquetes
((RECURSOS)) && instalar_recursos
((AGENTES)) && instalar_agentes
((COPIAS_ON)) && restaurar_copias
crear_enlaces
((GNOME)) && aplicar_gnome
((NEPTUNO)) && clonar_neptuno

info "Listo"
if ((COPIAS_ON)); then
	cat <<'EOF'
Falta a mano (no se guardan en el repo por seguridad):
  - Iniciar sesión en Claude Code (claude, luego /login) y en opencode (opencode auth login).
  - Recrear ~/.config/opencode/config.json (API key) y service.json.
  - La memoria de Engram empieza vacía.
EOF
fi
