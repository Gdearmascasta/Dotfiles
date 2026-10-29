#!/usr/bin/env python3
# Filtro de git: quita datos personales de lo que entra al repo sin tocar el archivo de la app,
# y guarda la carpeta personal como @HOME@ para que cada equipo la recupere con la suya.
# Uso (lo configura configurar_filtro en lib.sh): python3 -I filtros/privado.py clean|smudge <ruta>,
# con el contenido por stdin.
import json
import os
import re
import sys

# Clones viejos llaman al filtro sin modo: "privado.py <ruta>" era el clean.
if sys.argv[1] in ('clean', 'smudge'):
    modo, ruta = sys.argv[1], sys.argv[2]
else:
    modo, ruta = 'clean', sys.argv[1]

datos = sys.stdin.buffer.read()
MARCA = b'@HOME@'
home = os.environ.get('HOME', '').rstrip('/').encode()
# Con un HOME vacío o "/" se reemplazaría media ruta del sistema.
home_valido = home.startswith(b'/') and len(home) > 1

if modo == 'smudge':
    sys.stdout.buffer.write(datos.replace(MARCA, home) if home_valido else datos)
    sys.exit()

if not home_valido:
    sys.exit(f'privado.py: HOME no es válido ({home!r}); no se puede limpiar {ruta}.')
# Solo la carpeta completa: /home/gcasta2 no es /home/gcasta.
datos = re.sub(re.escape(home) + rb'(?![A-Za-z0-9_.-])', MARCA, datos)


def limpiar_json(texto, quitar):
    try:
        contenido = json.loads(texto)
    except json.JSONDecodeError as error:
        # Mejor parar el commit que publicar el archivo sin limpiar.
        sys.exit(f'privado.py: {ruta} no es JSON válido ({error}); quizá la app lo está guardando.'
                 ' Ciérrala o espera y vuelve a hacer el commit.')
    if isinstance(contenido, dict):
        quitar(contenido)
    # Sale con sangría de 2 espacios: el formato del repo puede no ser el de la app.
    return json.dumps(contenido, ensure_ascii=False, indent=2) + '\n'


def vaciar(clave):
    def quitar(contenido):
        if clave in contenido:
            contenido[clave] = []
    return quitar


def sin_tokens(nodo):
    if isinstance(nodo, dict):
        nodo.pop('RestoreToken', None)
        for valor in nodo.values():
            sin_tokens(valor)
    elif isinstance(nodo, list):
        for valor in nodo:
            sin_tokens(valor)


texto = None
if ruta.endswith('ui.json'):
    # Documentos abiertos hace poco (Deckcraft, Wordcraft, Gridcraft).
    texto = limpiar_json(datos.decode(), vaciar('recent'))
elif ruta.startswith('spotifast/') and ruta.endswith('settings.json'):
    texto = limpiar_json(datos.decode(), vaciar('search_history'))
elif ruta.startswith('obs-studio/basic/scenes/') and ruta.endswith('.json'):
    # Token del portal de captura: solo vale en este equipo.
    texto = limpiar_json(datos.decode(), sin_tokens)
elif ruta.startswith('escritorio/dconf/') and ruta.endswith('.ini'):
    # Historial de reproducción de las extensiones de música.
    texto = re.sub(r'^playback-history=.*(\n|\Z)', '', datos.decode(), flags=re.M)

sys.stdout.buffer.write(texto.encode() if texto is not None else datos)
