#!/usr/bin/env python3
# Genera fastfetch/ubuntu.jsonc y neofetch/config.conf a partir de fastfetch/config.jsonc:
# mismos módulos, orden e iconos, con la paleta de la marca Ubuntu
# (https://design.ubuntu.com/brand/colour-palette). Ejecútalo tras cambiar config.jsonc:
#   python3 tema-ubuntu.py
import json
import pathlib
import re

D = pathlib.Path(__file__).resolve().parent
c = json.loads(re.sub(r'^\s*//.*$', '', (D / 'fastfetch/config.jsonc').read_text(), flags=re.M))

# Color de Fedora -> color de Ubuntu, grupo por grupo.
COLORES = {
    '#A1A1AA': '#AEA79F',  # DISTRO: warm grey
    '#D1D5DB': '#DEDBD8',  # DE/WM: warm grey 40 %
    '#3B82F6': '#E95420',  # SYSTEM: Ubuntu orange
    '#2563EB': '#AD79A8',  # AUDIO: light aubergine 60 %
}
BLOQUES = ['#AEA79F', '#FFFFFF', '#E95420', '#AD79A8']


def truecolor(h):
    return '\x1b[38;2;%d;%d;%dm' % tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))


u = json.loads(json.dumps(c))
u['logo']['color'] = {'1': '#E95420', '2': '#FFFFFF'}
for m in u['modules']:
    if isinstance(m, dict) and 'keyColor' in m:
        m['keyColor'] = COLORES[m['keyColor']]
    if isinstance(m, dict) and m.get('type') == 'custom':
        glifo = re.findall(r'\x1b\[\d+m(\S)', m['format'])[0]
        m['format'] = '  '.join(truecolor(h) + glifo for h in BLOQUES)
(D / 'fastfetch/ubuntu.jsonc').write_text(json.dumps(u, ensure_ascii=False, indent=4) + '\n')

# neofetch: los módulos que no trae (cursor, swap, sonido, reproductor) salen de comandos propios.
NEO = {'os': 'distro', 'kernel': 'kernel', 'packages': 'packages', 'shell': 'shell', 'wm': 'wm',
       'wmtheme': 'wm_theme', 'icons': 'icons', 'terminalfont': 'term_font', 'terminal': 'term',
       'host': 'model', 'cpu': 'cpu', 'gpu': 'gpu', 'memory': 'memory', 'uptime': 'uptime'}
PROPIOS = {'cursor': 'cursor_tema', 'swap': 'swap_uso', 'sound': 'sonido',
           'player': 'reproductor', 'media': 'cancion'}
lineas, pantalla_vista = [], False
for m in u['modules']:
    if m == 'break':
        lineas.append('    prin')
        continue
    t = m['type']
    if t == 'custom':
        lineas.append('    prin "%s"' % m['format'].replace('\x1b', '\\e'))
        continue
    clave = "$(c '%s')%s" % (m['keyColor'], m['key'])
    if t == 'display':
        # neofetch muestra todas las pantallas en una sola línea; la línea anterior cierra el grupo.
        if not pantalla_vista:
            lineas.append('    info "%s" resolution' % clave)
        else:
            lineas[-1] = lineas[-1].replace('│ ├', '│ └')
        pantalla_vista = True
    elif t in NEO:
        lineas.append('    info "%s" %s' % (clave, NEO[t]))
    else:
        lineas.append('    linea "%s" "$(%s)"' % (clave, PROPIOS[t]))

CABECERA = r'''# neofetch para Ubuntu, que en 24.04 no trae fastfetch. Lo genera tema-ubuntu.py desde
# fastfetch/config.jsonc: no lo edites a mano.

c() { printf '\e[38;2;%d;%d;%dm' "0x${1:1:2}" "0x${1:3:2}" "0x${1:5:2}"; }

# Una línea propia solo si el comando dio algo, como hace fastfetch con los módulos vacíos.
linea() { [[ -n $2 ]] && prin "$1" "$2"; }

cursor_tema() {
    command -v gsettings >/dev/null || return
    local tema tam
    tema=$(gsettings get org.gnome.desktop.interface cursor-theme 2>/dev/null | tr -d "'")
    tam=$(gsettings get org.gnome.desktop.interface cursor-size 2>/dev/null)
    [[ -n $tema ]] && printf '%s (%spx)' "$tema" "$tam"
}

swap_uso() {
    free -b 2>/dev/null | awk '/^Swap/ && $2 > 0 {printf "%.2f GiB / %.2f GiB (%d%%)", $3/2^30, $2/2^30, 100*$3/$2}'
}

sonido() {
    command -v wpctl >/dev/null || return
    wpctl inspect @DEFAULT_AUDIO_SINK@ 2>/dev/null | sed -n 's/.*node\.description = "\(.*\)"/\1/p' | head -1
}

reproductor() { command -v playerctl >/dev/null && playerctl metadata --format '{{playerName}}' 2>/dev/null; }
cancion() { command -v playerctl >/dev/null && playerctl metadata --format '{{title}} - {{artist}}' 2>/dev/null; }

print_info() {
'''

PIE = r'''}

separator="%s"
bold="on"
colors=(15 15 15 15 7 7)
kernel_shorthand="on"
distro_shorthand="off"
os_arch="on"
uptime_shorthand="on"
memory_percent="on"
memory_unit="gib"
package_managers="on"
shell_path="off"
shell_version="on"
cpu_brand="on"
cpu_speed="on"
cpu_cores="logical"
gpu_brand="on"
gpu_type="all"
refresh_rate="on"
de_version="on"
color_blocks="off"

image_backend="ascii"
image_source="auto"
ascii_distro="auto"
# 202 es el naranja de 256 colores más cercano a #E95420: neofetch no acepta hex en el logo.
ascii_colors=(202 15)
ascii_bold="on"
gap=3
''' % u['display']['separator']

(D / 'neofetch').mkdir(exist_ok=True)
(D / 'neofetch/config.conf').write_text(CABECERA + '\n'.join(lineas) + '\n' + PIE)
