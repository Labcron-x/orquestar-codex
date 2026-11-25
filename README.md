# orquestar-codex

Skill de Codex derivada de claude-orquestador: aquí el que orquesta es Codex. Codex reparte el trabajo pesado y paralelo
entre agentes de CLI: Antigravity (`agy`), OpenCode, Gemini CLI, Qwen Code, Qoder y MiniMax Code (`mcode`), o cualquier
otro que agregues. Sirve para cualquier proyecto (código, pruebas de navegador, documentos) y para consultas sueltas
(investigar, resumir, revisar archivos).

## Instalar (cada persona del equipo)

Requisitos: git, Node.js y bash (en Windows, Git Bash). Python 3 solo si vas a usar `--documentos` o `--libreoffice`.

```bash
git clone https://github.com/Labcron-x/orquestar-codex.git ~/.codex/skills/orquestar-codex
bash ~/.codex/skills/orquestar-codex/instalar.sh
```

### Qué instala sin opciones

- Codex CLI, si falta.
- Dos agentes, si faltan: OpenCode y Gemini CLI. Los demás se eligen con `--agentes` (abajo).
- En cada CLI de agente: los MCP Playwright, Chrome DevTools y Context7, y las reglas que bloquean push, borrados,
  publicación y despliegues.
- La guía de documentos como skill de agy y OpenCode. Es un archivo de texto: no instala ningún programa.
- Las skills del equipo (`skills/`) en `~/.codex/skills/`, y tu config personal en `~/.config/orquestar-codex/config`.

**No instala nada de documentos:** ni librerías de Python, ni pandoc, ni LibreOffice.

### Opciones

| Opción | Qué agrega | Espacio aprox. |
|---|---|---|
| `--agentes "..."` | Elige los agentes en lugar de los dos por defecto: `agy opencode gemini-cli qwen qoder mcode`. `agy` no se instala por npm: el instalador avisa que lo bajes de la web de Antigravity | según el agente |
| `--documentos` | Librerías de Python (pypdf, python-docx, openpyxl, python-pptx, pandas, markitdown), pandoc y el MCP markitdown. Con eso los agentes leen y crean PDF, Word, Excel y PowerPoint | ~500 MB |
| `--libreoffice` | Todo lo de `--documentos` más LibreOffice. Solo hace falta para pasar documentos a PDF y recalcular fórmulas de Excel; sin él, el agente entrega el archivo y anota en su reporte lo que no pudo convertir | ~500 MB + ~800 MB |

Ejemplos:

```bash
bash ~/.codex/skills/orquestar-codex/instalar.sh --agentes "agy opencode gemini-cli qoder"   # solo programar
bash ~/.codex/skills/orquestar-codex/instalar.sh --documentos                                # además, documentos
```

Se puede correr varias veces (por ejemplo, para sumar una opción después): solo agrega lo que falta y respalda cada
archivo que toca como `*.bak-orq`.

Después inicia sesión una vez en cada CLI que instalaste: `codex login`, `gemini`, `agy`, `qodercli login`,
`mcode login` (`qwen` solo con API key de pago). OpenCode con modelos `opencode/*` no lo pide.

### Convive con claude-orquestador

No toca nada de `claude-orquestador`: nada en `~/.claude/`, ni `~/.config/orquestar-agentes/`. Ambos pueden coexistir
en la misma máquina sin interferir entre sí:

- la skill solo se activa al escribir `$orquestar-codex` (`agents/openai.yaml`), así que un Codex que Claude lance como
  trabajador nunca la carga;
- los dos instaladores configuran igual los CLI de agentes (mismos MCP y reglas; solo agregan lo que falta);
- los prompts llevan la marca `[orq-codex <repo>/<ID>]`, así el vigilante de uno no detiene agentes del otro.

## Usar

En Codex (CLI o app en modo seguro):

```bash
codex --sandbox workspace-write --ask-for-approval on-request
```

O en la app, elige "Pedir aprobación" ("Aprobar por mí" también sirve). `danger-full-access` queda solo como opción
no recomendada. Codex lee todo y escribe dentro del proyecto; todo lo que sale del proyecto o toca `.git` (crear
worktrees, lanzar agentes, commits, merges) va por `orq`, pidiendo permisos elevados fuera del sandbox con justificación
corta (la primera vez apruebas con "no volver a preguntar").

Dentro de Codex:

```
$orquestar-codex <lo que quieres hacer>
$orquestar-codex Lee docs/agentes/ESTADO.md y continúa con el siguiente paso.
```

## Consumo

`orq consumo [días|todo]` muestra tokens, caché, fallos, tiempo y costo por agente y modelo (7 días por defecto).
También suma todas las sesiones de Codex de esta PC y muestra el porcentaje usado del límite de ChatGPT.
`orq resumen <ID>` incluye el consumo de la tarea.

El registro queda en `~/.local/share/orquestar-codex/consumo.jsonl`. Puedes cambiar la ruta con `ORQ_CONSUMO`
o desactivarlo con `ORQ_CONSUMO=off` en tu config. El costo solo aparece si el CLI lo informa; no se estima.

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
| `agentes/*.sh` | Un adaptador por CLI (`agy`, `opencode`, `gemini-cli`, `qwen`, `qoder`, `mcode`) |
| `scripts/` | `orq.sh`, scripts de agentes, fondo, esperar, resumen, limpiar y configuración |
| `plantillas/` | `AGENTS.md`, `ESTADO.md` y tarea para cada repo |
| `guias/documentos.md` | Guía de PDF/Word/Excel/PowerPoint para los agentes |

## Créditos

Derivado de `claude-orquestador` (donde orquestaba Claude Code).
El modo lectura, el esquema de revisión y los adaptadores de Qoder y MiniMax Code están inspirados en
[delegate-skills](https://github.com/amElnagdy/delegate-skills) (MIT, Ahmed Mohammed).

## Contribuir

Todo cambio entra por PR a `main` y lo valida CI en GitHub Actions. Ver [CONTRIBUIR.md](CONTRIBUIR.md).
