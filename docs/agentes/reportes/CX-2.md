# Reporte CX-2 — Documentación y plantillas para que Codex sea el orquestador

## Resumen

Se completó la reescritura de toda la documentación y plantillas para que Codex (CLI o app) sea el orquestador y delegue en agy, OpenCode, Gemini CLI y Qwen Code, dejando de actuar como agente trabajador. Se adaptaron todos los comandos a la interfaz única `orq` (`scripts/orq.sh`), se documentaron las primitivas de segundo plano (`orq fondo`, `orq esperar-fondo`), y se eliminaron las referencias a rutas (`~/.claude/`), herramientas y configuraciones de Claude Code. Se mantuvieron las rutas explícitas a plantillas y se aclaró la convivencia independiente de ambos orquestadores en la misma máquina.

## Archivos tocados

- `SKILL.md`: Frontmatter `name: orquestar-codex`, definición de carpeta de skill `$S = ~/.codex/skills/orquestar-codex`, invocación de `orq`, sandbox `danger-full-access`, tabla de reparto con Codex como orquestador, ciclo de segundo plano con `orq fondo` y `orq esperar-fondo`, rutas exactas a `$S/plantillas/ESTADO.md`, `$S/plantillas/AGENTS.md` y `$S/plantillas/tarea.md`, y reactivación mediante `$orquestar-codex`.
- `ORQUESTACION.md`: Eliminado Codex de la tabla de trabajadores y escalados; agregadas entradas para `orq`, `fondo`, `esperar-fondo` y `verificar`; documentada validación con herramientas de Codex y markitdown; nota sobre PowerShell/Git Bash; sección de equipo actualizada a `~/.codex/skills/orquestar-codex` y convivencia con claude-orquestador.
- `README.md`: Título `codex-orquestador`, aclaración de derivación, instalación en `~/.codex/skills/orquestar-codex`, agentes soportados (`agy opencode gemini-cli qwen`), sección de convivencia, invocación con `codex --sandbox danger-full-access` y `$orquestar-codex`, y estructura con `agents/openai.yaml` y `scripts/orq.sh`.
- `CONTRIBUIR.md`: Rutas a `~/.codex/skills/orquestar-codex` y `~/.config/orquestar-codex/config`, CI en `ubuntu-latest`, eliminación de la sección runner self-hosted, y actualización mediante `orq actualizar`.
- `config.ejemplo`: Configuración personal en `~/.config/orquestar-codex/config`, `ORQ_COMPLEJO="agy"`, eliminación de directivas `CODEX_*` como trabajador y notas dirigidas a Codex.
- `plantillas/AGENTS.md`: Adaptada referencia del orquestador a Codex.
- `plantillas/tarea.md`: Referencias de orquestador a Codex para elección de agente/modelo y verificación de comandos.
- `plantillas/ESTADO.md`: Comando para retomar actualizado a `$orquestar-codex Lee docs/agentes/ESTADO.md y continúa con el siguiente paso.`
- `plantillas/skill/SKILL.md`: Actualizada plantilla a `orquestar-codex`, `$S = ~/.codex/skills/orquestar-codex`, llamadas con `orq` y roles asignados a Codex.
- `guias/skills-externas.md`: Eliminados comandos `claude plugin` y rutas `~/.claude/`; preservadas prácticas de Graphify y Ponytail; Agent Skills como opcional sin instrucciones de Claude; reintento con `orq fondo reintentar`.
- `skills/README.md`: Destino de instalación en `~/.codex/skills/`, creación con `orq nueva-skill` e instalación con `orq instalar-skills`.
- `.github/pull_request_template.md`: Comprobaciones con `orq agentes` y ruta de configuración en `~/.config/orquestar-codex/config`.

## Criterios de aceptación repasados

- [x] Ningún archivo permitido dice que Claude orquesta ni usa rutas `~/.claude` (salvo al explicar la convivencia con claude-orquestador o en nombres de modelos como `claude-opus-5-5-high` / `claude-sonnet-5-5-high` de agy).
- [x] `SKILL.md` empieza con frontmatter válido (`---`, `name: orquestar-codex`, `description: ...`, `---`).
- [x] Todos los comandos citados coinciden con el contrato (`orq fondo lanzar`, `orq esperar-fondo`, `orq reintentar`, `orq resumen`, etc.).
- [x] Sin codex como agente trabajador en tablas, escalados ni config.
- [x] En `SKILL.md`, rutas exactas a `$S/plantillas/ESTADO.md`, `$S/plantillas/AGENTS.md` y `$S/plantillas/tarea.md`, aclarando `$S = ~/.codex/skills/orquestar-codex` (o `$CODEX_HOME/skills/orquestar-codex`).

## Verificación

Tal como indica la tarea (`CX-2.md`), no se corrieron comandos de terminal ni git (Codex verifica al integrar). Todos los criterios fueron validados revisando el contenido de los archivos permitidos.

## Dudas

Ninguna.
