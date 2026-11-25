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

## Consumo (telemetría)

Cada vez que un agente trabaja (tarea, reintento o consulta), el orquestador anota cuántos tokens gastó, con qué
modelo, si falló y cuánto tardó. Para verlo:

- dentro de Codex: pregunta "¿cuánto llevo consumido?" (Codex corre `orq consumo`);
- en tu terminal: `bash ~/.codex/skills/orquestar-codex/scripts/orq.sh consumo [días|todo]` (7 días por defecto).

```
Agentes
Agente      Modelo                 Ejec.  Fallos (codigo≠0)  Entrada  Caché  Salida  Razon.  Costo US$  Tiempo (min)
gemini-cli  gemini-3.8-flash           1                  0    12.0k   3.0k     800       0          —           2.0
gemini-cli  TOTAL                      1                  0    12.0k   3.0k     800       0          —           2.0
opencode    opencode/big-pickle        2                  1   121.3k  84.5k     974    3.8k     0.0000          11.6
opencode    TOTAL                      2                  1   121.3k  84.5k     974    3.8k     0.0000          11.6

Codex (orquestador): todas las sesiones de Codex de esta PC con tokens en el periodo.
Modelo       Sesiones  Entrada  Caché  Salida  Razon.
gpt-6.1-sol         5     5.0M   4.7M   78.0k   28.0k
Límite de ChatGPT (plan team): 24 % de la ventana de 5 h (se renueva 14:58) · 7 % semanal (se renueva 27/11 16:40)
```

| Columna | Qué es |
|---|---|
| Ejec. / Fallos | Veces que se usó ese agente y modelo, y cuántas terminaron con error o detenidas por el vigilante |
| Entrada / Caché | Tokens que leyó el modelo; Caché es la parte que salió de caché (más barata o gratis) |
| Salida / Razon. | Tokens que escribió y tokens de razonamiento interno |
| Costo US$ | Solo si el CLI lo informa (OpenCode sí; Qwen y Qoder si lo dan). `—` = el CLI no lo informa. No se estiman precios |
| Codex | Tokens por modelo de todas las sesiones de Codex de esta PC (también otros proyectos) y % usado del límite de ChatGPT |

- `orq resumen <ID>` muestra además el consumo de esa tarea.
- Codex revisa el consumo al cerrar cada lote: si un agente acumula fallos o Codex pasa del 80 % de su ventana,
  reparte a otros agentes.
- El registro queda en `~/.local/share/orquestar-codex/consumo.jsonl` (un JSON por ejecución). En tu config puedes
  cambiar la ruta con `ORQ_CONSUMO="<ruta>"` o apagarlo con `ORQ_CONSUMO="off"`.

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
| `scripts/` | `orq.sh`, scripts de agentes, fondo, esperar, resumen, consumo, limpiar y configuración |
| `plantillas/` | `AGENTS.md`, `ESTADO.md` y tarea para cada repo |
| `guias/documentos.md` | Guía de PDF/Word/Excel/PowerPoint para los agentes |

## Créditos

Derivado de `claude-orquestador` (donde orquestaba Claude Code).
El modo lectura, el esquema de revisión y los adaptadores de Qoder y MiniMax Code están inspirados en
[delegate-skills](https://github.com/amElnagdy/delegate-skills) (MIT, Ahmed Mohammed).

## Contribuir

Todo cambio entra por PR a `main` y lo valida CI en GitHub Actions. Ver [CONTRIBUIR.md](CONTRIBUIR.md).
