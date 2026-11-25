# codex-orquestador

Skill de Codex: derivado de claude-orquestador; aquí orquesta Codex. Codex delega en agentes de CLI para hacer el trabajo
pesado y paralelo. Los agentes son Antigravity (`agy`), OpenCode, Gemini CLI y Qwen Code (o cualquier otro que agregues).
Sirve para cualquier proyecto (código, pruebas de navegador, documentos) y para consultas sueltas (investigar, resumir,
revisar archivos).

## Instalar (cada persona del equipo)

Requisitos: git, Node.js, Python 3 y bash (en Windows, Git Bash).

```bash
git clone <URL de tu repo> ~/.codex/skills/orquestar-codex
bash ~/.codex/skills/orquestar-codex/instalar.sh
# opciones: --agentes "agy opencode gemini-cli qwen"   --sin-programas
```

El instalador hace esto:

- instala los CLI que falten (`agy`, `opencode`, `gemini`, `qwen`);
- instala las librerías de documentos y LibreOffice/pandoc;
- agrega a cada CLI los MCP: Playwright, Chrome DevTools, markitdown y Context7;
- agrega las reglas que bloquean push, borrados, publicación y despliegues en los agentes;
- instala la skill de documentos;
- crea tu config personal en `~/.config/orquestar-codex/config`;
- configura los metadatos de la skill en `~/.codex/skills/orquestar-codex`.

Respalda cada archivo que toca como `*.bak-orq` y se puede correr varias veces.

Después inicia sesión una vez en cada CLI (`gemini`, `agy`; `qwen` solo con API key de pago). OpenCode con modelos
`opencode/*` no lo pide.

### Convive con claude-orquestador

No toca nada de `claude-orquestador`: nada en `~/.claude/`, ni `~/.config/orquestar-agentes/`. Ambos pueden coexistir
en la misma máquina sin interferir entre sí.

## Usar

En Codex (CLI o app con acceso completo):

```bash
codex --sandbox danger-full-access
```

Dentro de Codex:

```
$orquestar-codex <lo que quieres hacer>
$orquestar-codex Lee docs/agentes/ESTADO.md y continúa con el siguiente paso.
```

## Personalizar

Tu config personal está en `~/.config/orquestar-codex/config` (ver `config.ejemplo`). Ahí defines:

- **qué agente** hace cada función;
- **los modelos** por defecto y la escala para subir de modelo;
- **los permisos:** cuánto pueden hacer los agentes sin preguntar. Es tu decisión, y el push queda bloqueado siempre.

Para sumar otro agente, crea `agentes/<nombre>.sh` (ORQUESTACION.md § 1).

## Más skills del equipo

El repo también permite alojar otras skills del equipo en `skills/`, siguiendo la misma lógica (Codex decide y valida,
los agentes trabajan). `orq instalar-skills` las copia a `~/.codex/skills/`. Detalle: [skills/README.md](skills/README.md).

Por ahora no hay skills adicionales en el equipo. Para crear una: `orq nueva-skill <nombre> "<cuándo usarla>"` y luego
`orq instalar-skills`.

## Estructura

| Ruta | Qué es |
|---|---|
| `SKILL.md` | Lo que lee Codex al invocar la skill |
| `agents/openai.yaml` | Metadatos de invocación para Codex CLI/app (`allow_implicit_invocation: false`) |
| `scripts/orq.sh` | Entrada única para todos los comandos del orquestador (`orq`) |
| `skills/<nombre>/` | Otras skills del equipo (se instalan con `orq instalar-skills`) |
| `plantillas/skill/` | Esqueleto de una skill nueva (`orq nueva-skill`) |
| `ORQUESTACION.md` | Referencia: agentes, modelos, scripts, tipos de tarea, documentos, problemas |
| `agentes/*.sh` | Un adaptador por CLI (`agy`, `opencode`, `gemini-cli`, `qwen`) |
| `scripts/` | `orq.sh`, scripts de agentes, fondo, esperar, resumen, limpiar y configuración |
| `plantillas/` | `AGENTS.md`, `ESTADO.md` y tarea para cada repo |
| `guias/documentos.md` | Guía de PDF/Word/Excel/PowerPoint para los agentes |

## Contribuir

Todo cambio entra por PR a `main` y lo valida CI en GitHub Actions. Ver [CONTRIBUIR.md](CONTRIBUIR.md).
