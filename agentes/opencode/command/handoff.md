---
description: Genera una nota de traspaso con el estado exacto del trabajo para continuar en otra sesión (o tras /clear) sin perder contexto. Úsalo al final de sesiones largas o antes de limpiar el contexto.
---

# Handoff — traspaso de sesión sin pérdida

**Si el trabajo en curso tiene documento ODD** (`odd/tasks/<feature>.md`, de gentle-ai), ese documento es la fuente de verdad: no crees `HANDOFF.md`. Actualízalo en su sitio — estado de cada tarea en `## Tasks` y una entrada nueva al final de `## Log` con lo que pide la plantilla de abajo (estado, decisiones, hechos aprendidos, archivos calientes, cómo verificar) — y refresca su copia en Engram (topic `odd/<feature>/tasks`). Después sigue con la nota ANDROMEDA y el cierre de memoria.

**Si no hay documento ODD**, escribe el estado del trabajo actual en `HANDOFF.md` en la raíz del workspace (sobrescribe el anterior si existe). La próxima sesión debe poder continuar leyendo SOLO ese archivo.

## Contenido obligatorio

```
# Handoff — <fecha> <hora>

## Objetivo en curso
<qué se está construyendo/arreglando y para qué, 2-3 frases>

## Estado
- HECHO: <lista de lo completado Y VERIFICADO>
- HECHO SIN VERIFICAR: <completado pero no probado, si hay>
- EN CURSO: <qué está a medias y exactamente en qué punto>
- PENDIENTE: <siguientes pasos en orden>

## Decisiones tomadas (y por qué)
<decisiones de diseño que la próxima sesión NO debe re-litigar, con su motivo en una línea>

## Hechos aprendidos con esfuerzo
<cosas no obvias descubiertas: APIs con comportamiento raro, gotchas del entorno,
comandos exactos que funcionan, causas raíz diagnosticadas>

## Archivos calientes
<rutas de los archivos centrales del trabajo, con una nota de qué hay en cada uno>

## Cómo verificar
<comando(s) exacto(s) para comprobar que el estado actual funciona>
```

## Sincronizar la bóveda ANDROMEDA (si existe `~/ANDROMEDA`)

Tras escribir `HANDOFF.md` (o el documento ODD), actualiza la nota del proyecto en `~/ANDROMEDA\01-Proyectos\<proyecto>.md` (créala con `Plantillas\Proyecto.md` si no existe, con `ruta:` apuntando a la raíz real del proyecto). Es lo que el hook `andromeda-context` inyectará en la próxima sesión de cualquier terminal, así que debe ser un **mapa denso, no un diario**:

- Frontmatter: `ultima_modificacion:` a hoy; `estado:` si cambió (activo/pausado/archivado).
- Cuerpo: descripción de una línea, stack y comandos clave (build/test/run), y una sección `## Estado` de 3-6 líneas con lo esencial del handoff (en curso + siguiente paso + gotcha principal). Máximo ~40 líneas totales: el hook trunca a 2.500 caracteres.
- El detalle fino vive en `HANDOFF.md` o en el documento ODD; la nota es el resumen estable. No dupliques el handoff entero.

## Cerrar la memoria del proyecto

Último paso del cierre, después de HANDOFF.md (o el documento ODD) y de la nota ANDROMEDA: `mem_session_summary` de Engram con el objetivo, lo logrado, los descubrimientos y el siguiente paso. No hace falta volcar nada a Obsidian a mano: el hook `engram-obsidian` lo hace al cerrar la sesión. Si `mem_session_summary` falla, dilo en el cierre en vez de dar la memoria por guardada.

## Reglas

- Datos concretos, no vaguedades: "falta el caso de token expirado en `auth/session.ts:142`" y no "falta pulir auth".
- Incluye los callejones sin salida ya explorados para que nadie los repita.
- Convierte referencias relativas ("lo de ayer", "el bug de antes") en absolutas (fechas, rutas, mensajes de error literales).
- Tras escribirlo, confirma al usuario en una línea dónde quedó y qué contiene (y si la nota ANDROMEDA y el grafo quedaron sincronizados).
