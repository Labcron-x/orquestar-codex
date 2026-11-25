# Estado de la orquestación

**Retomar:** `/orquestar-agentes Lee docs/agentes/ESTADO.md y continúa con el siguiente paso.`

## Notas del proyecto

- Qué es: derivado de claude-orquestador para que **Codex** sea el orquestador (skill `orquestar-codex` en
  `~/.codex/skills/`). No debe chocar con la versión de Claude instalada en la misma PC.
- Instalar en un worktree: nada (`SETUP=:`)
- Verificar: `bash scripts/verificar.sh`
- Rama base de los lotes: `main` (repo local, aún sin remoto)
- Integración: merge directo en local; el usuario lo sube a su GitHub cuando lo pida
- Contrato común: `docs/agentes/tareas/CX-1.md` § Contrato (T2 lo documenta tal cual)

## Tablero

| ID | Tarea | Agente | Modelo | Estado |
|---|---|---|---|---|
| CX-1 | Scripts, instalador y CI para Codex orquestador | codex | @high | En curso |
| CX-2 | Documentación y plantillas para Codex orquestador | agy | gemini-3.8-flash-high | En curso |

Estados: Pendiente → En curso → En validación → Hecha / Devuelta (motivo).

## Siguiente paso

1. Validar CX-1 y CX-2, integrar, probar `fondo`/`esperar-fondo` desde una sesión real de Codex (que el proceso en
   segundo plano sobreviva al comando) y preguntar al usuario el nombre/URL de su repo de GitHub.
