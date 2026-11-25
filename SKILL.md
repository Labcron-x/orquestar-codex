---
name: orquestar-codex
description: Codex orquesta y delega en agentes de CLI (Antigravity/agy, OpenCode, Gemini CLI, Qwen Code, Qoder, MiniMax Code) para ahorrar tokens y trabajar en paralelo. Usar en CUALQUIER proyecto o consulta con trabajo delegable, de código o no: implementar, probar en navegador, crear o revisar documentos (PDF, Word, Excel, PowerPoint), investigar, resumir, revisar código. Divide en tareas, elige agente y modelo (y los cambia o escala si falla), lanza en segundo plano en worktrees, valida con un resumen corto e integra. También al retomar con "$orquestar-codex Lee docs/agentes/ESTADO.md y continúa".
---

# Orquestar agentes con Codex

Codex **no hace** lo que un agente pueda hacer: decide, reparte, valida e integra. Los agentes trabajan y se
comunican por archivos, no por chat. Referencia (agentes, modelos, permisos, problemas): [ORQUESTACION.md](ORQUESTACION.md),
solo la sección que necesites.

Codex trabaja en modo seguro: `codex --sandbox workspace-write --ask-for-approval on-request` (o en la app, "Pedir
aprobación" / "Aprobar por mí"). `danger-full-access` queda como opción no recomendada. Codex lee todo y escribe dentro
del proyecto; `.git` es de solo lectura en el sandbox, por lo que Codex **nunca** corre `git add/commit/merge/push`
directo. Lo que sale del proyecto o toca `.git` (crear worktrees, lanzar agentes, commits, merges) va por `orq`, que
Codex corre **pidiendo permisos elevados** (fuera del sandbox) con una justificación corta. La primera vez el usuario
aprueba con "no volver a preguntar" y Codex guarda la regla en `~/.codex/rules/default.rules`. Leer, `git status`,
`git diff`, `git log` y editar tareas o `ESTADO.md` van dentro del sandbox.

Carpeta de la skill: `$S` = `~/.codex/skills/orquestar-codex` (o `$CODEX_HOME/skills/orquestar-codex`).
Entrada única: `orq <comando> [args]`. Escribe la ruta completa en cada llamada (las variables no persisten):
- **PowerShell** (Windows; `bash` a secas suele ser WSL, no lo uses):
  `& "$env:ProgramFiles\Git\bin\bash.exe" "$env:USERPROFILE/.codex/skills/orquestar-codex/scripts/orq.sh" <comando> ...`
- **bash** (Linux, macOS, Git Bash): `bash ~/.codex/skills/orquestar-codex/scripts/orq.sh <comando> ...`

Al empezar la sesión corre `orq actualizar` (git pull de la skill e instala MCP nuevos; avisa si pide reiniciar). Luego,
antes del primer reparto, corre `orq agentes`: muestra instalados, modelos y fortalezas. Si falta alguno, dile al
usuario el comando de instalación y el login que imprime (no los corras tú: piden cuenta). Para pruebas de navegador,
los agentes usan el MCP `chrome-devtools` (consola, red, rendimiento) y `playwright` (flujos).

## ¿Tarea en un repo o consulta suelta?

- **Consulta** (investigar, comparar, resumir o revisar un documento, responder una pregunta): sin repo ni worktree.
  - Directa: `orq consultar <agente> "<pregunta>" [modelo|-] [archivos...]` (imprime solo la respuesta).
  - En segundo plano: `orq fondo consultar <nombre> <agente> "<pregunta>" [modelo|-] [archivos...]` y luego
    `orq esperar-fondo` (permite lanzar varias a la vez).
- **Trabajo en un repo**: el ciclo de abajo.

## Al empezar en un repo

1. Si existe `docs/agentes/ESTADO.md`, léelo y sigue desde su "Siguiente paso". No leas chats anteriores.
2. Si no existe, prepara el repo **una vez**: copia `$S/plantillas/ESTADO.md` a `docs/agentes/ESTADO.md` y llena "Notas
   del proyecto" mirando solo `package.json`/README/AGENTS.md; si no hay `AGENTS.md`, créalo desde
   `$S/plantillas/AGENTS.md` con los comandos de verificación del proyecto; crea `docs/agentes/{tareas,reportes}/`; guarda
   con `orq guardar "preparar orquestación"`.

## Repartir

Jerarquía de inteligencia: **Codex (orquestador) > agy / OpenCode / Gemini CLI / Qwen / Qoder / MiniMax Code**.

| Función | Agente (config: `ORQ_*`) |
|---|---|
| **Tareas complejas**: algoritmos, concurrencia, seguridad, dinero, depuración difícil, refactors grandes, backend difícil, arquitectura | `agy` con modelo alto de su escala (`ORQ_COMPLEJO="agy"`); Codex revisa a fondo y, si no sale, lo resuelve Codex |
| Implementar código y UI, pruebas de navegador | `agy` (`ORQ_IMPLEMENTA`) |
| En paralelo: comandos libres, migraciones, pruebas, documentos, docs | `opencode` (`ORQ_PARALELO`) |
| Implementar en paralelo o sin cuota de agy/OpenCode | `qoder`, `mcode` (MiniMax Code: sin sandbox, no usar para lectura delicada) |
| Revisión cruzada del diff de otro agente (`REV-<ID>`, sin editar código) | `opencode` (`ORQ_REVISA`) |
| Consultas e investigación | `opencode` con Context7 (`ORQ_CONSULTA`) |
| Se acabó la cuota o están ocupados | `gemini-cli`, `qwen`, `qoder`, `mcode` |
| Imágenes (ilustraciones, fondos, maquetas) | `agy` (genera imágenes) |
| Sistemas web con la sesión del usuario (administradores, portales, formularios con login) | **Codex**, no se delega (ver abajo) |

- **Sistemas con la sesión del usuario:** los navegadores de los agentes son aislados y corren en segundo plano; nadie
  puede iniciar sesión ahí. Hazlo tú con el MCP `chrome-devtools`: abre la página, pide al usuario que inicie sesión
  en esa ventana y te avise, y nunca pidas ni escribas su contraseña. Delega en paralelo lo que no necesita sesión
  (comparar listas, armar los datos, revisar la página pública) y verifica al final en la página.
- **Marketing:** los agentes preparan piezas (imágenes con `agy`, textos, UTM) y analizan métricas. Publicar, crear
  campañas o gastar presupuesto lo haces tú (por API, MCP o el navegador con la sesión del usuario), solo con su
  aprobación explícita y con las campañas creadas en pausa. Los tokens van fuera del repo y de los prompts.
- Modo de tarea: **escritura** para implementar; **lectura** (`**Modo:** lectura` en la tarea, o prefijos `REV-`/`INV-`)
  para revisiones cruzadas, investigación y auditorías. En modo lectura el agente arranca en solo lectura real y no
  puede modificar el worktree.
- Codex define **antes** los contratos compartidos (tipos, API, esquema) y nunca deja dos tareas en paralelo tocando
  los mismos archivos. Lo delicado (dinero, auth, seguridad, datos personales, migraciones) lo revisa Codex a fondo.
- Modelo: el más barato que alcance (ORQUESTACION.md § 2). En la tarea puedes sugerir agente y modelo.
- Ahorro de tokens: si hay `graphify-out/`, úsalo para elegir archivos en vez de leer código; cada tarea lleva la
  escalera de Ponytail y, si aplica, la skill de agent-skills ([guias/skills-externas.md](guias/skills-externas.md)).

## Ciclo por tarea

1. **Tarea:** `docs/agentes/tareas/<ID>.md` desde `$S/plantillas/tarea.md`: objetivo, modo (`escritura` o `lectura`),
   archivos permitidos, contrato, criterios y verificación. Corta: el agente no ve esta conversación.
2. **Lanzar en segundo plano** (Codex no recibe aviso al terminar un proceso):
   ```bash
   orq fondo lanzar <agente> <ID> [modelo|-] [rama-base]
   ```
   Imprime `En segundo plano: <clave>` (`<repo>-<ID>`) y vuelve al instante. Hace commit de la tarea en la rama base,
   crea `../wt-<repo>-<ID>`, bloquea el push, instala dependencias (`SETUP="..."` lo cambia), lanza, hace commit y resume.
   Para varias tareas independientes, corre varios `orq fondo lanzar` seguidos.
3. **Esperar:**
   ```bash
   orq esperar-fondo [clave...] [--max SEG] [--todas]
   ```
   Espera sin gastar tokens hasta que termine alguna (o todas) o pasen `--max` s (defecto 540) e imprime el resumen.
   Códigos: 0 informó alguna, 124 plazo sin ninguna (volver a llamar), 2 nada pendiente. **Regla para Codex:** si tu
   herramienta de comandos tiene plazo, dale al menos `--max` + 60 s; nunca hagas sondeo con `sleep` ni leas registros.
   **Vigilante (sin tokens):** `lanzar` y `reintentar` revisan en bash cada 5 min (`ORQ_VIGILAR_SEG=300`) que el
   registro crezca. Si no crece en 2 revisiones (10 min) o hay bloqueo de créditos/cuota, detienen el agente, imprimen
   `ALERTA: agente colgado (...)` y salen con código 124. Al ver la ALERTA, reintenta con otro modelo/agente.
4. **Validar** con el resumen (no abras el registro): reporte, commits y `diff --stat` dentro de lo permitido,
   denegadas, **ALERTA** de push o de modo lectura violado (`ALERTA: modo lectura violado: <archivos>`), cambios sin
   commit. Corre **tú** la verificación en el worktree. Documentos: ORQUESTACION.md § 5.
5. **Si falla**, en segundo plano y esperar con `orq esperar-fondo`:
   ```bash
   orq fondo reintentar <ID> "<error concreto>" [modelo|+|-] [agente]
   ```
   Escalado en `reintentar`: mismo modelo (`-`) una vez → `+` (siguiente modelo de la escala) → otro agente
   (4.º argumento, mismo worktree) → `agy` con el modelo más alto de su escala → Codex lo resuelve él mismo.
6. **Integrar:** `orq integrar <ID>` (merge `--no-ff` de `agente/<ID>` en la rama base y limpieza; si hay conflicto
   aborta, lista los archivos y sale con 1). Actualiza el tablero de ESTADO.md. Para conservar el worktree, usa
   `orq integrar <ID> --sin-limpiar`.

## Esperas externas (CI, deploy, servidores)

Nunca esperes algo sin plazo. Corridas directas dándole a la herramienta un plazo mayor que el de la espera (no van por
`fondo`):

```bash
orq esperar-gh <owner/repo> <workflow.yml> <sha> [plazo_aparecer=600] [plazo_total=1800]
orq esperar "<qué se espera>" <plazo_seg> <comando de chequeo...>
```

- `esperar-gh` falla con **3** si la ejecución no aparece (el disparador no funcionó; avisa si el workflow tiene
  `workflow_dispatch`), con **124** si no termina a tiempo y con **1** si termina en fallo.
- Tras un merge que debe desplegar: espera el CI **y** el workflow de deploy. Si el deploy no aparece, no lo des por
  hecho: dile al usuario, lánzalo a mano con `gh workflow run` si está autorizado y anota que el disparador automático falla.
- Al terminar un deploy, verifica el resultado en el destino (p. ej. `orq esperar` con un chequeo del commit en el
  servidor o del HTTP de la app), no solo el verde del workflow.
- Si una espera no va a servir (filtro mal escrito, plazo absurdo), córtala y lanza otra; no confíes en un vigilante mudo.

## Entre tareas

- Corre `orq consumo` al cerrar un lote o si el usuario pregunta por gasto. Si un agente acumula fallos o Codex
  pasa del 80 % de su ventana, prefiere otros agentes.
- Al cerrar cada lote: ESTADO.md al día (tablero + siguiente paso concreto) y `orq guardar "<mensaje>"`, para que
  cualquier sesión retome desde ahí. Revisa `ls ..`: no deben quedar `wt-*` integrados.
- Encadena el siguiente paso sin preguntar, **salvo** si toca un servidor, producción o despliegue; si necesita una
  decisión del usuario; o si no está claro. Ahí te detienes y preguntas.
- Si el usuario quiere cortar: espera a los agentes en curso, deja ESTADO.md al día y dile que retome con:
  `$orquestar-codex Lee docs/agentes/ESTADO.md y continúa con el siguiente paso.`

**Nunca** hagas push sin pedido explícito (puede desplegar). Los agentes no pueden: sus worktrees tienen el push
bloqueado y sus CLI, reglas deny.
