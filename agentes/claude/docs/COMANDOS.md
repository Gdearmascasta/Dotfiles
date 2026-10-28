# Catálogo de comandos y subagentes NEPTUNO

Referencia completa que antes vivía en la sección 8 de `CLAUDE.md`. Claude Code ya lista las skills y los agentes con su descripción en cada sesión; este catálogo los agrupa por familia.

## Comandos de proceso
| Comando | Cuándo usarlo |
|---|---|
| `/fable-mode` | Activar el protocolo completo en modo estricto para una tarea difícil |
| `/optimize-prompt` | Reescribir un prompt del usuario para máxima calidad de resultado |
| `/optimize-tokens` | Auditar y comprimir el uso de contexto de la sesión |
| `/deep-plan` | Diseño de arquitectura antes de implementar |
| `/verify-work` | Verificación end-to-end de un cambio |
| `/debug` | Resolución sistemática de bugs: repro → hipótesis → causa raíz → fix + test |
| `/bug-hunt` | Caza proactiva de bugs latentes en un área, sin síntoma previo (pre-release, código heredado) |
| `/write-tests` | Escribir tests que detectan bugs de verdad (con prueba de mutación manual) |
| `/refactor` | Refactor seguro: red de tests previa, pasos en verde, equivalencia verificada |
| `/self-review` | Autocrítica estructurada del diff actual |
| `/context-prime` | Cargar un mapa eficiente del repo al iniciar sesión |
| `/handoff` | Generar nota de traspaso al acabar una sesión larga |
| `/parallel-split` | Descomponer una tarea grande en subagentes paralelos |
| `/hivemind` | Repartir una tarea entre las CLIs externas (opencode, antigravity, devin) y verificar el resultado |

## Comandos de calidad, documentación y lenguaje
| Comando | Cuándo usarlo |
|---|---|
| `/code-standards` | Auditar/aplicar buenas prácticas contra las convenciones reales del repo |
| `/document-code` | README, ADR, docstrings, runbooks — documentación derivada del código |
| `/diagram-mermaid` | Elegir el diagrama correcto y escribir Mermaid válido, renderizado antes de entregar |
| `/write-natural` | Prosa que no suena a IA: quita los tics delatores y ajusta registro |
| `/redactar` | Reglas de redacción académica (RAE, tono impersonal, sin señales de IA); automática en informes y papers |
| `/translate-localize` | Traducir/localizar texto o UI con variante, plurales, placeholders e i18n |
## Comandos full stack
| Comando | Cuándo usarlo |
|---|---|
| `/full-stack-feature` | Feature completa DB→API→UI con enfoque contract-first |
| `/api-contract` | Diseñar el contrato de una API antes de implementar |
| `/db-migration` | Cambios de esquema seguros (expand-contract, rollback) |
| `/sql-optimize` | Diagnóstico y optimización de queries con EXPLAIN |

## Comandos de datos
| Comando | Cuándo usarlo |
|---|---|
| `/eda` | Análisis exploratorio riguroso de un dataset nuevo |
| `/data-quality` | Auditoría de calidad con checks ejecutables |
| `/data-pipeline` | Construir ETL/ELT idempotente, validado y reanudable |
| `/ml-experiment` | Entrenar/evaluar modelos sin leakage y con baseline |

## Comandos de diseño y frontend
| Comando | Cuándo usarlo |
|---|---|
| `/frontend-design` | Dirección de arte obligatoria (paso 0) antes de escribir código de UI nueva |
| `/editorial-layout` | Retícula y tipografía editorial en vez de tarjetas/contenedores por defecto |
| `/theme-factory` | Elegir paleta + tipografía de un catálogo curado, sin adivinar hex al azar |
| `/motion-design` | Animaciones y microinteracciones con curvas de easing y duración con sistema |
| `/generative-art` | Fondos/elementos visuales generativos en Canvas/SVG/WebGL, sin imágenes stock |
| `/responsive-grid` | Escalado continuo (clamp, vmax, container queries) más allá de breakpoints fijos |
| `/figma-to-code` | Traducir un diseño/design system dado (Figma, capturas) a tokens y componentes |
| `/a11y-review` | Verificación final de contraste, teclado y semántica en cualquier UI |

## Comandos Android (sin abrir Android Studio)
| Comando | Cuándo usarlo |
|---|---|
| `/apk-build` | Compilar/rebuildear una APK o AAB con diagnóstico de errores de Gradle |
| `/apk-release` | Release firmado (keystore, versionCode, minify, verificación de firma) |
| `/android-run` | Instalar y ejecutar en emulador/dispositivo con logcat filtrado |
| `/android-doctor` | Diagnosticar y reparar el entorno (JDK, SDK, licencias, adb, emulador) |

## Comandos React Native / Expo
| Comando | Cuándo usarlo |
|---|---|
| `/expo-build` | Build de desarrollo/preview (local Android, EAS Build en la nube para iOS) |
| `/expo-release` | Build de producción + submit a tiendas (EAS Build + EAS Submit) |
| `/expo-run` | Instalar y ejecutar en emulador/simulador/dispositivo con Metro y logs filtrados |
| `/expo-doctor` | Diagnosticar el entorno Expo/RN (Node, Expo CLI, EAS CLI, SDK Android reutilizado) |

## Comandos Capacitor / Ionic
| Comando | Cuándo usarlo |
|---|---|
| `/capacitor-build` | Build de la capa web + sync nativo (Android local vía Gradle, iOS vía CI) |
| `/capacitor-release` | Release firmado Android (reutiliza `/apk-release`); camino de iOS documentado |
| `/capacitor-run` | Instalar y ejecutar en emulador/dispositivo Android con logcat filtrado |
| `/capacitor-doctor` | Diagnosticar el entorno Capacitor (versiones core/cli/android desalineadas) |

## Comandos de apps de escritorio (Electron / Tauri)
| Comando | Cuándo usarlo |
|---|---|
| `/desktop-build` | Compilar la app de escritorio, autodetectando Electron o Tauri |
| `/desktop-release` | Instalador empaquetado/firmado con versionado |
| `/desktop-run` | Arrancar en modo desarrollo y verificar que inició sin errores |
| `/desktop-doctor` | Diagnosticar el entorno (Node, toolchain Rust para Tauri, WebView2) |

## Comandos GitHub (con el `gh` del usuario — sin colaboradores ni bots)
| Comando | Cuándo usarlo |
|---|---|
| `/pr` | Crear un PR de calidad: rama, commits atómicos, descripción desde el diff real |
| `/pr-merge` | Merge seguro: checks + reviews + conflictos en verde, estrategia del repo |
| `/pr-stack` | Stacked PRs estilo Graphite: cadena de PRs pequeños, restack, aterrizaje en orden |
| `/release` | Versión semver desde commits, changelog, tag y GitHub release con artefactos |

## Subagentes (Agent tool — corren en paralelo, cada uno con su propio contexto)
| Agente | Modelo | Cuándo usarlo |
|---|---|---|
| `scout` | haiku | Búsquedas amplias y baratas por el código |
| `architect` | opus | Decisiones de diseño y planes de implementación |
| `implementer` | sonnet | Implementación de un plan ya definido |
| `verifier` | sonnet | Verificación independiente de un cambio |
| `critic` | opus | Revisión adversarial antes de entregar |
| `debugger` | opus | Causa raíz de bugs difíciles con reproducción y evidencia |
| `backend` | sonnet | Capa servidor de una feature (API, lógica, datos) |
| `frontend` | sonnet | Capa cliente de una feature (UI, estado, consumo API) |
| `data-engineer` | sonnet | Pipelines, SQL pesado, modelado de tablas |
| `data-scientist` | sonnet | Análisis, EDA, features y modelos con rigor |
| `android` | sonnet | Builds de Gradle, adb/emulador y releases firmadas sin quemar contexto con logs |
| `react-native` | sonnet | Builds EAS, Metro bundler, emulador/dispositivo Expo/RN sin quemar contexto |
| `capacitor` | sonnet | Compilar capa web, sincronizar y ejecutar apps Capacitor/Ionic en Android |
| `desktop` | sonnet | Builds Electron/Tauri, empaquetado e instaladores de escritorio en Windows |
| `delegate` | sonnet | Despachar encargos a la flota externa absorbiendo sus logs fuera del contexto principal |
