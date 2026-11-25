# Estado de la orquestación

**Retomar:** `/orquestar-agentes Lee docs/agentes/ESTADO.md y continúa con el siguiente paso.`

## Notas del proyecto

- Skill `orquestar-codex` (Codex orquesta). Repo: https://github.com/Labcron-x/orquestar-codex
- Instalar en un worktree: nada (`SETUP=:`) · Verificar: `bash scripts/verificar.sh`
- Rama base: `main` · Integración: merge local; push solo a pedido del usuario
- `docs/agentes/` es solo para construir la skill: se quita antes de publicar

## Tablero

| ID | Tarea | Agente | Modelo | Estado |
|---|---|---|---|---|
| CX-1 | Scripts, instalador y CI para Codex orquestador | codex | @high | Hecha |
| CX-2 | Documentación y plantillas | agy | gemini-3.8-flash-medium | Hecha |
| CX-3 | Sandbox de Codex, modo lectura, Qoder/MiniMax, documentos opcionales (scripts) | codex | @high | En curso |
| CX-4 | Lo mismo en la documentación | agy | gemini-3.8-flash-medium | En curso |

## Siguiente paso

1. Validar CX-3 y CX-4, integrar, quitar docs/agentes y preguntar al usuario antes del push.
