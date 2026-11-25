# Referencia de orquestación

## 1. Agentes

Cada agente es un adaptador en `agentes/<nombre>.sh`; `orq agentes` muestra cuáles están instalados.

| Agente | CLI | Cuenta | Fuerte en | Permisos sin interfaz (por defecto → config) |
|---|---|---|---|---|
| `agy` | Antigravity CLI | Google | código, UI, navegador | edita; comandos solo exactos de su lista → `AGY_FLAGS="--dangerously-skip-permissions"` (ignora su deny) |
| `opencode` | `opencode` | ninguna (modelos `opencode/*` gratis) | comandos libres, pruebas, docs, investigación | todo salvo deny; `OPENCODE_FLAGS="--auto"` evita preguntas |
| `gemini-cli` | `gemini` | Google (gratis) | contexto largo, reemplazo de agy | `auto_edit` → `GEMINI_CLI_APROBACION=yolo` |
| `qwen` | `qwen` | API key de pago (la cuota gratis terminó en 2026-04) | código en paralelo | `auto` (clasificador) → `QWEN_APROBACION=yolo` |

Alias aceptados: `gemini`/`antigravity` → `agy`, `oc` → `opencode`, `gcli` → `gemini-cli`.

**Agregar otro agente** (Aider, Cursor CLI, Crush, Goose...): crea `agentes/<nombre>.sh` copiando uno existente.
Define `BIN`, `MODELO_DEF`, `ESCALA`, `INSTALAR`, `LOGIN`, `FUERTE` y las funciones `agente_lanzar <prompt> <modelo>`,
`agente_reintentar <prompt> <modelo> <sesión>` y `agente_modelos`. La salida va a un registro; `extraer.js` ya entiende
JSON de agy, OpenCode, Gemini CLI, Qwen, Codex y el `stream-json` de Claude (si no, toma el texto final).

**Seguridad:** `lanzar` deja el `pushurl` de cada remoto del worktree en `no-push://...`, así que un push falla
aunque el agente corra cualquier comando, y `resumen` marca **ALERTA** si lo intentó. Las reglas deny (git push,
merge, rebase, reset --hard, clean, worktree, rm -rf, publish, prisma reset, ssh, scp, vercel, gh) están en agy y
OpenCode; **agy con `--dangerously-skip-permissions` no las respeta** (probado), por eso existe el bloqueo de push.

**agy sin el flag:** en modo `-p` solo acepta el **comando exacto** de su lista: `command(npm test)` deja pasar
`npm test`, no `npm test src`. Un comando sin regla corta toda la ejecución. `instalar.sh` agrega los comandos de
verificación habituales.

## 2. Elegir y cambiar modelo

| Tarea | agy | opencode | otros |
|---|---|---|---|
| Mecánica: renombrar, docs, pruebas simples | `gemini-3.8-flash-low` | `opencode/big-pickle` | defecto |
| Un módulo con pruebas, UI normal | `gemini-3.8-flash-medium` | `opencode/big-pickle` | defecto |
| Difícil: algoritmos, concurrencia, seguridad, refactor grande | `claude-sonnet-5-5-high` (o modelo alto de agy) | `opencode/nemotron-3-ultra-free` | alternar agente |
| Falló dos veces | `claude-opus-5-5-high` | `opencode/nemotron-3-ultra-free` | alternar agente |
| Último recurso | — | — | **Codex lo resuelve él mismo** |

- Modelo al lanzar: 3.er argumento de `lanzar` (`-` = el de por defecto).
- Al reintentar: `+` sube al siguiente de `ESCALA`, un nombre lo fija, `-` repite. Con un 4.º argumento cambia de
  agente y el nuevo retoma el mismo worktree.
- Por defecto y escalas, por persona: `~/.config/orquestar-codex/config` (`AGY_MODELO`, `AGY_ESCALA`, ...).
- Los nombres cambian: `orq agentes <agente>` lista los disponibles.

## 3. Scripts

Todos los scripts se invocan mediante la entrada única `scripts/orq.sh <comando> [args]` (abreviado `orq <comando>`).
Desde el repo. En `..` quedan `wt-<repo>-<ID>/` y `<repo>-<ID>.{jsonl,meta,setup.log}`.

| Comando / Script | Qué hace |
|---|---|
| `orq <comando> [args]` | Entrada única del orquestador en `scripts/orq.sh` |
| `orq agentes [agente]` | Instalados, modelo por defecto, escala, fortalezas; con agente, sus modelos |
| `orq lanzar <agente> <ID> [modelo\|-] [base]` | Worktree + rama `agente/<ID>`, push bloqueado, tarea, `AGENTS.md` y guías en `.agentes/`, dependencias según lockfile (`SETUP="cmd"` / `SETUP=:`), lanza, commit y resumen |
| `orq fondo <comando> [args]` | Lanza `lanzar`, `reintentar` o `consultar` en segundo plano desacoplado; imprime clave (`<repo>-<ID>` o `consulta-<nombre>`) y vuelve al instante |
| `orq esperar-fondo [clave...] [--max SEG] [--todas]` | Espera sin tokens hasta que termine alguna (o todas) de las tareas en segundo plano (0 informó alguna, 124 plazo sin ninguna, 2 nada pendiente) |
| `orq resumen <ID>` | Respuesta final, denegadas, ALERTA de push, errores, commits, diff, sin commit, reporte |
| `orq reintentar <ID> "<msg>" [modelo\|+\|-] [agente]` | Misma conversación (o agente nuevo en el mismo worktree), commit y resumen |
| `orq limpiar <ID>` | Quita worktree, rama y registros (`FORZAR=1` si no está integrada) |
| `orq consultar <agente> "<pregunta>" [modelo\|-] [archivos]` | Consulta sin repo en una carpeta temporal; imprime solo la respuesta |
| `orq esperar-gh <owner/repo> <workflow> <sha> [p1] [p2]` | Espera que termine un workflow de GitHub Actions (3 no apareció, 124 plazo, 1 fallo, 0 éxito) |
| `orq esperar "<qué>" <plazo_seg> <comando...>` | Espera con plazo hasta que un comando de chequeo dé 0 |
| `orq verificar` | Verificación local mínima de sintaxis y adaptadores |

## 4. Tipos de tarea

- **Implementar** (`<MOD>-<n>`): la normal.
- **Revisión cruzada** (`REV-<ID>`): revisa `git diff <base>..agente/<ID>` **sin editar código** y lista hallazgos
  con archivo:línea y gravedad. Codex comprueba solo los graves.
- **Navegador** (`E2E-<ID>`): levanta la app, la recorre con Playwright MCP y reporta (capturas en
  `docs/agentes/reportes/`). La tarea dice URL, usuario de prueba y pasos.
- **Documentos** (`DOC-<ID>`): genera o edita PDF/Word/Excel/PowerPoint según `.agentes/documentos.md`; la tarea
  dice ruta de salida y contenido.
- **Investigación** (`INV-<tema>`): mejor con `orq consultar` (o `orq fondo consultar`); reporte corto con fuentes.

## 5. Documentos (PDF, Word, Excel, PowerPoint)

- **Agentes:** guía `guias/documentos.md` (se copia a `.agentes/` de cada worktree o consulta, y como skill
  `documentos` en agy y OpenCode), MCP `markitdown` (convierte PDF/docx/xlsx/pptx a Markdown), librerías `pypdf`,
  `pdfplumber`, `reportlab`, `python-docx`, `openpyxl`, `pandas`, `python-pptx`, y LibreOffice + `pandoc`.
- **Codex valida** gastando poco: `python -m markitdown <archivo>` y leer solo lo necesario; Codex aprovecha sus
  propios plugins y herramientas de documentos; en Excel, recalcular con LibreOffice y buscar
  `#REF!`/`#DIV/0!`/`#VALUE!`/`#NAME?`. No se usan skills de Anthropic.

## 6. Problemas conocidos

- Windows: en PowerShell, invocar `bash` a secas suele llamar a WSL en lugar de Git Bash, lo cual falla con las rutas
  de Windows; por eso `orq` va con la ruta completa a Git Bash (`& "$env:ProgramFiles\Git\bin\bash.exe" ...`).
- Windows: `git worktree remove` no borra los `node_modules` de pnpm (`limpiar` usa `rmdir`). Si una carpeta
  queda, hay una terminal o un editor abierto dentro.
- Consola de Windows con acentos rotos: `PYTHONUTF8=1` (lo pone `instalar.sh`); los archivos están bien.
- Dos agentes con Playwright a la vez: solo con `--isolated` (ya configurado).
- Generación de código previa (p. ej. `prisma generate`): en `SETUP`.
- Ahorro: nunca leas el registro completo; si el resumen no basta, `tail -c 3000` del `.jsonl`.

## 7. Equipo

La skill es un repo git: cada persona la clona en `~/.codex/skills/orquestar-codex` y corre `bash instalar.sh`
(ver README.md). Lo personal (permisos, modelos, agente preferido) vive en `~/.config/orquestar-codex/config`, no en
el repo. Para actualizar: `orq actualizar` (o `git pull` y volver a correr `instalar.sh`).

**Convivencia con claude-orquestador:** no se pisan porque usan carpetas distintas (`~/.codex/skills/orquestar-codex`
vs `~/.claude/skills/orquestar-agentes` y `~/.config/orquestar-codex/` vs `~/.config/orquestar-agentes/`). Pueden
convivir en la misma máquina sin tocar nada de la otra. La vieja `.claude/skills/...` por proyecto no aplica.

## 8. Más skills

`skills/<nombre>/` guarda otras skills del equipo con la misma lógica de reparto. `orq instalar-skills` las copia
a `~/.codex/skills/` y marca cada copia con `.origen-orquestador`, para no pisar skills ajenas. Una skill nueva se crea
con `orq nueva-skill`, según la convención de `skills/README.md`: es genérica y lo propio del proyecto va en el
repo del proyecto. Su `SKILL.md` dice qué pasos delega en agentes y cuáles hace Codex.
