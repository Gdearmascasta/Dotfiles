#!/usr/bin/env python3
# Filtro "clean" de git: quita datos personales de lo que entra al repo sin tocar el archivo de la app.
# Uso (lo configura configurar_filtro en lib.sh): python3 -I filtros/privado.py <ruta>, con el contenido por stdin.
import json
import re
import sys

ruta = sys.argv[1]
texto = sys.stdin.read()


def limpiar_json(quitar):
    try:
        datos = json.loads(texto)
    except json.JSONDecodeError as error:
        # Mejor parar el commit que publicar el archivo sin limpiar.
        sys.exit(f'privado.py: {ruta} no es JSON válido ({error}); quizá la app lo está guardando.'
                 ' Ciérrala o espera y vuelve a hacer el commit.')
    if isinstance(datos, dict):
        quitar(datos)
    # Sale con sangría de 2 espacios: el formato del repo puede no ser el de la app.
    return json.dumps(datos, ensure_ascii=False, indent=2) + '\n'


def vaciar(clave):
    def quitar(datos):
        if clave in datos:
            datos[clave] = []
    return quitar


def sin_tokens(nodo):
    if isinstance(nodo, dict):
        nodo.pop('RestoreToken', None)
        for valor in nodo.values():
            sin_tokens(valor)
    elif isinstance(nodo, list):
        for valor in nodo:
            sin_tokens(valor)


if ruta.endswith('ui.json'):
    # Documentos abiertos hace poco (Deckcraft, Wordcraft, Gridcraft).
    texto = limpiar_json(vaciar('recent'))
elif ruta.startswith('spotifast/') and ruta.endswith('settings.json'):
    texto = limpiar_json(vaciar('search_history'))
elif ruta.startswith('obs-studio/'):
    # Token del portal de captura: solo vale en este equipo.
    texto = limpiar_json(sin_tokens)
elif ruta.endswith('.ini'):
    # Historial de reproducción de las extensiones de música.
    texto = re.sub(r'^playback-history=.*(\n|\Z)', '', texto, flags=re.M)

sys.stdout.write(texto)
