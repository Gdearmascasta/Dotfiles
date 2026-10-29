#!/usr/bin/env bash
# Actualiza el repo con el estado actual del sistema. Después: git add -A && git commit.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

DOTFILES_REAL="$(readlink -f "$DOTFILES")"

respaldar_enlaces() {
	info "Configuraciones enlazadas"
	local linea paquete destino item vivo real
	for linea in "${ENLACES[@]}"; do
		read -r paquete destino items <<<"$linea"
		for item in $items; do
			vivo="$destino/$item"
			if [[ ! -e $vivo ]]; then
				aviso "No existe $vivo (se omite)"
				continue
			fi
			real="$(readlink -f "$vivo")"
			# Ya apunta al repo: el contenido está al día.
			[[ $real == "$DOTFILES_REAL/$paquete/$item" ]] && continue
			# Copia real (o la app reemplazó el enlace al guardar): se absorbe al repo.
			mkdir -p "$DOTFILES/$paquete"
			if [[ -d $real ]]; then
				rsync -a --delete --exclude='*.bak*' "$real/" "$DOTFILES/$paquete/$item/"
			else
				rsync -a "$real" "$DOTFILES/$paquete/$item"
			fi
			echo "  $paquete/$item"
		done
	done
}

respaldar_copias() {
	info "Agentes y recursos de escritorio"
	local linea carpeta origen
	for linea in "${COPIAS[@]}"; do
		read -r carpeta origen <<<"$linea"
		if [[ ! -d $origen ]]; then
			aviso "No existe $origen (se omite)"
			continue
		fi
		mkdir -p "$DOTFILES/$carpeta"
		# --copy-unsafe-links: un enlace que apunta fuera (p. ej. al repo) se guarda como archivo real.
		rsync -a --delete --copy-unsafe-links --filter='merge -' "$origen/" "$DOTFILES/$carpeta/" < <(filtro_copia "$carpeta")
		echo "  $carpeta"
	done
}

respaldar_dconf() {
	command -v dconf >/dev/null || { aviso "Sin dconf: no se respalda GNOME"; return; }
	info "Ajustes de GNOME (dconf)"
	mkdir -p "$DOTFILES/escritorio/dconf"
	local ruta
	for ruta in "${DCONF_RUTAS[@]}"; do
		# El filtro de git guarda la carpeta personal como @HOME@ al hacer commit.
		dconf dump "$ruta" >"$(dconf_archivo "$ruta")"
	done
}

respaldar_paquetes() {
	info "Listas de paquetes"
	mkdir -p "$DOTFILES/paquetes/repos"
	if command -v dnf >/dev/null; then
		dnf repoquery --userinstalled --qf '%{name}\n' 2>/dev/null | sort -u >"$DOTFILES/paquetes/dnf.txt"
		# Repos de terceros; Fedora y RPM Fusion se instalan con sus paquetes oficiales.
		find "$DOTFILES/paquetes/repos" -name '*.repo' -delete
		find /etc/yum.repos.d -name '*.repo' ! -name 'fedora*' ! -name 'rpmfusion*' \
			-exec cp {} "$DOTFILES/paquetes/repos/" \;
	fi
	if command -v flatpak >/dev/null; then
		flatpak list --app --columns=origin,application | sort >"$DOTFILES/paquetes/flatpak.txt"
	fi
}

buscar_secretos() {
	info "Buscando secretos"
	local hallazgos
	hallazgos="$(grep -rlIE --exclude-dir=.git \
		'github_pat_[A-Za-z0-9_]{20,}|gh[pousr]_[A-Za-z0-9]{30,}|sk-[A-Za-z0-9_-]{30,}|-----BEGIN [A-Z ]*PRIVATE KEY|"(password|server_password|api_key|API_KEY)" *: *"[^"]{6,}' \
		"$DOTFILES" || true)"
	if [[ -n $hallazgos ]]; then
		aviso "Posibles secretos, revísalos antes de hacer commit:"
		echo "$hallazgos" >&2
		return 1
	fi
	echo "  ninguno"
}

configurar_filtro
respaldar_enlaces
respaldar_copias
respaldar_dconf
respaldar_paquetes
buscar_secretos
info "Listo. Revisa con: git -C \"$DOTFILES\" status"
