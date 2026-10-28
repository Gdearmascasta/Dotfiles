---
name: verify-work
description: Verifica end-to-end que un cambio hace lo que debe, ejercitando el flujo real y no solo los tests. Úsalo al terminar cualquier cambio no trivial o cuando el usuario pida comprobar que algo funciona.
argument-hint: [cambio a verificar (opcional: por defecto el diff actual)]
---

# Verificación end-to-end

Verifica el cambio actual (el diff del working tree, o lo que indiquen los argumentos). El entregable es un veredicto con evidencia, no una opinión.

## Proceso

1. **Delimita qué cambió**: `git diff --stat` (o los archivos recién editados si no hay git). Lista qué comportamiento observable debería haber cambiado.
2. **Verificación estática rápida**: compila/typecheck/lint según el stack del repo. Si falla, para aquí y reporta.
3. **Tests**: ejecuta los tests relacionados con los archivos tocados (no siempre la suite entera; usa el filtro del runner). Tests nuevos deben fallar si reviertes mentalmente el cambio — si pasarían igual sin el cambio, no verifican nada.
4. **Ejercita el flujo real** — esta es la parte que casi todos se saltan:
   - CLI → ejecútala con los argumentos del caso de uso.
   - API/servidor → arráncalo y haz la petición real (`curl`/`Invoke-RestMethod`).
   - Librería → escribe un script mínimo en el scratchpad que la use como lo haría un consumidor y ejecútalo.
   - Frontend → si hay forma de renderizar/servir, hazlo; usa el MCP `chrome-devtools` (si está disponible) para navegar el flujo real, capturar pantalla y leer la consola/red en busca de errores — no te quedes en "el build pasa". Si no hay forma de servirlo, decláralo como no verificado.
5. **Caso hostil**: prueba al menos un input límite (vacío, nulo, muy grande, malformado, concurrente — el que aplique al cambio).
6. **Veredicto** en este formato:

```
## Veredicto: VERIFICADO | PARCIAL | FALLA
- Probado: <comando → resultado observado> (una línea por prueba)
- No probado: <qué y por qué>
- Hallazgos: <bugs o sorpresas, si las hay>
```

7. **Registra lo aprendido**: si la verificación destapó un callejón sin salida o corrigió una suposición, `mem_save` en Engram (tipo `bugfix` o `discovery`, con qué se creía y qué resultó cierto). Es lo que convierte un callejón sin salida de hoy en una advertencia escrita dentro de un mes, y lo que la vista de grafo de Obsidian enlaza con el resto de la memoria del proyecto.

## Reglas
- Nada de "debería funcionar": cada afirmación del veredicto lleva el comando y el output que la respalda.
- Si no puedes ejecutar algo (falta entorno, credenciales), el veredicto máximo es PARCIAL y lo dices.
- Si encuentras un bug, repórtalo con reproducción exacta; no lo arregles en silencio salvo que el usuario haya pedido arreglar.
