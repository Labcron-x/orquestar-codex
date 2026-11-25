# Instrucciones para agentes

Trabajas en un worktree de git, en la rama `agente/<ID>`. Tu tarea está en `docs/agentes/tareas/<ID>.md`.

Este repo es una skill de **Codex CLI** (`orquestar-codex`): Codex orquesta y delega en agentes de CLI (agy, OpenCode,
Gemini CLI, Qwen). Es un derivado de `claude-orquestador` (donde orquestaba Claude Code) y debe poder convivir en la
misma PC con esa versión sin tocar nada de ella: nada en `~/.claude/`, ni `~/.config/orquestar-agentes/`.

## Reglas

- Toca **solo** los archivos que la tarea permite. Si necesitas cambiar otro, no lo hagas: anótalo en "Dudas" del
  reporte.
- No cambies el contrato que fija la tarea (nombres de comandos, rutas, variables).
- Escribe en español, en el mismo tono breve y directo de los archivos que ya existen.
- Prohibido: `git push`, `merge`, `rebase`, `reset --hard`, `git worktree`, `rm -rf`, publicar y subir secretos.
- Nada de abstracciones que la tarea no pida.

## Verificación

- `bash scripts/verificar.sh` (sintaxis bash y Node, ShellCheck si está, carga de los adaptadores)
- `bash scripts/pruebas.sh` (pruebas sin git ni agentes reales: adaptadores, extraer.js, instalador)

## Al terminar

1. Escribe `docs/agentes/reportes/<ID>.md` con: resumen, archivos tocados, salida de la verificación (las últimas
   líneas) y dudas.
2. No corras `git add` ni `git commit`: tus cambios se guardan en la rama al terminar.
