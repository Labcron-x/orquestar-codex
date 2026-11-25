# CX-2 — Documentación y plantillas para que Codex sea el orquestador

**Contexto:** este repo viene de `claude-orquestador`, donde **Claude Code** orquestaba. Ahora el orquestador es
**Codex** (CLI o app), que lee la skill desde `~/.codex/skills/orquestar-codex/SKILL.md`. Codex deja de ser trabajador:
los agentes son agy, OpenCode, Gemini CLI y Qwen. Ya se borraron `agentes/codex.sh`, `deploy/` y las skills de Claude
de `skills/`. Otra tarea (CX-1) cambia los scripts en paralelo según el contrato de abajo.
**Archivos permitidos:** `SKILL.md`, `ORQUESTACION.md`, `README.md`, `CONTRIBUIR.md`, `config.ejemplo`,
`plantillas/**`, `guias/**`, `skills/README.md`, `.github/pull_request_template.md`. Nada más (ni `scripts/`, ni
`instalar.sh`, ni `.github/workflows/`).
**Agente / modelo:** agy · gemini-3.8-flash-high

## Objetivo

Reescribir la documentación para Codex como orquestador. `SKILL.md` es lo más importante: es lo que Codex lee en cada
sesión. Mantén la estructura, el tono breve y las reglas del `SKILL.md` actual (lee primero el actual completo) y
cambia solo lo que depende de quién orquesta. No uses comandos de terminal: solo lee y edita archivos.

## Contrato (lo implementa CX-1; documéntalo tal cual)

- Skill `orquestar-codex`, instalada clonando el repo en `~/.codex/skills/orquestar-codex` (o `$CODEX_HOME/skills/...`).
  Solo se activa al escribir `$orquestar-codex <pedido>` (`agents/openai.yaml` con `allow_implicit_invocation: false`).
  No escribe ningún AGENTS.md global ni toca `~/.claude/`: convive con claude-orquestador en la misma PC.
- Config personal: `~/.config/orquestar-codex/config` (copia de `config.ejemplo`).
- Codex necesita acceso completo para crear worktrees fuera del repo y lanzar agentes con red:
  `codex --sandbox danger-full-access` (o "Acceso completo" en la app). Si un comando falla por el sandbox, Codex
  avisa al usuario en vez de insistir.
- Todos los scripts se llaman por la entrada única `scripts/orq.sh <comando> [args]`. En `SKILL.md` se abrevia como
  `orq <comando>` y se explica una vez cómo llamarla:
  - PowerShell (Windows; ahí `bash` suele ser el de WSL, no lo uses a secas):
    `& "$env:ProgramFiles\Git\bin\bash.exe" "$env:USERPROFILE/.codex/skills/orquestar-codex/scripts/orq.sh" <comando> ...`
  - bash (Linux, macOS, Git Bash): `bash ~/.codex/skills/orquestar-codex/scripts/orq.sh <comando> ...`
  - Comandos: `actualizar agentes lanzar reintentar resumen limpiar consultar fondo esperar-fondo esperar esperar-gh
    verificar nueva-skill instalar-skills` (mismos argumentos que los scripts actuales).
- Segundo plano (reemplaza `run_in_background` de Claude: Codex no recibe aviso al terminar un proceso):
  - `orq fondo lanzar <agente> <ID> [modelo|-] [rama-base]` · `orq fondo reintentar <ID> "<error>" [modelo|+|-] [agente]`
    · `orq fondo consultar <nombre> <agente> "<pregunta>" [modelo|-] [archivos...]`. Imprime
    `En segundo plano: <clave>` y vuelve al instante (clave `<repo>-<ID>` o `consulta-<nombre>`).
  - `orq esperar-fondo [clave...] [--max SEG] [--todas]`: espera sin gastar tokens hasta que termine alguna (o todas)
    o pasen `--max` s (defecto 540) e imprime el resumen de las terminadas. Códigos: 0 informó alguna, 124 plazo sin
    ninguna (volver a llamar), 2 nada pendiente. **Regla para Codex:** si la herramienta de comandos tiene plazo,
    dale al menos `--max` + 60 s; nunca hagas sondeo propio con `sleep` ni leas los registros.
  - Lanzar varias tareas independientes = varios `orq fondo lanzar` seguidos y luego `orq esperar-fondo`.
- Reparto sin Codex trabajador. Jerarquía: **Codex (orquestador) > agy / OpenCode / Gemini CLI / Qwen**.
  - Implementar código/UI y navegador: `agy` (`ORQ_IMPLEMENTA`); en paralelo, comandos, pruebas, docs: `opencode`
    (`ORQ_PARALELO`); revisión cruzada: `opencode` (`ORQ_REVISA`); consultas: `opencode` (`ORQ_CONSULTA`); cuota
    agotada u ocupados: `gemini-cli`, `qwen`.
  - Tareas complejas (algoritmos, concurrencia, seguridad, dinero, refactors grandes): `agy` con un modelo alto de su
    escala (`ORQ_COMPLEJO="agy"`); lo delicado lo revisa Codex a fondo y, si no sale, lo resuelve Codex.
  - Escalado en `reintentar`: mismo modelo (`-`) una vez → `+` → otro agente (4.º argumento, mismo worktree) → `agy`
    con el modelo más alto de su escala → Codex lo resuelve él mismo.
- Para retomar: `$orquestar-codex Lee docs/agentes/ESTADO.md y continúa con el siguiente paso.`
- El layout por repo no cambia (`docs/agentes/ESTADO.md`, `tareas/`, `reportes/`, `../wt-<repo>-<ID>`, rama
  `agente/<ID>`): un proyecto empezado con la versión de Claude se puede continuar con esta y al revés.
- CI: GitHub Actions con `ubuntu-latest` (ya no hay runner propio ni `deploy/runner`).

## Cambios por archivo

- `SKILL.md`: frontmatter `name: orquestar-codex` y `description` en español que diga que Codex orquesta y delega en
  agy, OpenCode, Gemini CLI y Qwen, y cuándo usarla. Cuerpo: "Codex **no hace** lo que un agente pueda hacer";
  cómo llamar a `orq` (contrato); al empezar: `orq actualizar` y `orq agentes`; acceso completo; consulta vs repo;
  preparar el repo (sin `CLAUDE.md`: mirar `package.json`/README/AGENTS.md); tabla de reparto nueva; ciclo por tarea
  con `orq fondo` + `orq esperar-fondo` (el vigilante y la ALERTA siguen igual: código 124 de `lanzar`); validar,
  reintentar con el escalado nuevo, integrar, limpiar; esperas externas con `orq esperar` / `orq esperar-gh`,
  corridas directas dándole a la herramienta un plazo mayor que el de la espera (no van por `fondo`); entre tareas;
  nunca push sin pedido. Ninguna mención a herramientas de Claude (`Bash`, `run_in_background`, `Read`, skills de
  Anthropic). Largo parecido al actual (~120 líneas).
- `ORQUESTACION.md`: quitar la fila de codex de § 1 (y el texto de `extraer.js` puede seguir citando formatos);
  § 2 sin columna/filas de codex como trabajador (el último recurso es Codex orquestador); § 3 agrega `orq`, `fondo`,
  `esperar-fondo`, `verificar`; § 5 "Codex valida" (markitdown y sus propios plugins de documentos; sin skills de
  Anthropic); § 6 agrega: en Windows `bash` en PowerShell suele ser WSL, por eso `orq` va con la ruta de Git Bash;
  § 7 ruta `~/.codex/skills/orquestar-codex`, config `~/.config/orquestar-codex/config`, convivencia con la versión
  de Claude (no se pisan; la vieja `.claude/skills/...` por proyecto no aplica); § 8 skills en `~/.codex/skills/`.
- `README.md`: título `codex-orquestador`; una línea "derivado de claude-orquestador; aquí orquesta Codex"; instalar
  con `git clone <URL de tu repo> ~/.codex/skills/orquestar-codex` y `bash .../instalar.sh` (opción
  `--agentes "agy opencode gemini-cli qwen"`); qué hace el instalador (sin pasos de Claude); "Convive con
  claude-orquestador" (qué no toca); usar: `codex --sandbox danger-full-access` y `$orquestar-codex ...`; estructura
  (agrega `agents/openai.yaml`, `scripts/orq.sh`); la tabla de skills del equipo queda vacía con una línea de cómo
  crear una.
- `CONTRIBUIR.md`: rutas nuevas; CI en `ubuntu-latest`; quitar la sección del runner del servidor; la actualización
  automática la corre Codex con `orq actualizar`.
- `config.ejemplo`: sin `CODEX_*` ni codex como trabajador; `ORQ_COMPLEJO="agy"` (con un modelo alto de su escala; si
  falla, lo resuelve Codex); comentarios "lo lee Codex al repartir"; ruta `~/.config/orquestar-codex/config`.
- `plantillas/AGENTS.md`, `plantillas/tarea.md`, `plantillas/ESTADO.md`, `plantillas/skill/SKILL.md`: "Claude" →
  "Codex" donde es el orquestador; línea de retomar con `$orquestar-codex`; en la plantilla de skill,
  `$S = ~/.codex/skills/orquestar-codex` y llamadas con `orq`.
- `guias/skills-externas.md`: quitar los comandos `claude plugin ...` y rutas `~/.claude/...`; dejar Graphify
  (`graphify-out/` si el repo lo tiene) y la escalera de Ponytail como prácticas; agent-skills como opcional "si
  está instalada" sin instrucciones de Claude. `guias/documentos.md`: solo si menciona a Claude.
- `skills/README.md`: las skills del equipo se instalan en `~/.codex/skills/` con `orq instalar-skills`; se crean con
  `orq nueva-skill`; por ahora no hay ninguna.
- `.github/pull_request_template.md`: config `~/.config/orquestar-codex/config`; probar con `orq agentes`.

## Criterios de aceptación

- [ ] Ningún archivo permitido dice que Claude orquesta ni usa rutas `~/.claude` (salvo al explicar la convivencia
      con claude-orquestador o en nombres de modelos como `claude-opus-5-5-high`).
- [ ] `SKILL.md` empieza con frontmatter válido (`---`, `name: orquestar-codex`, `description: ...`, `---`).
- [ ] Todos los comandos citados coinciden con el contrato (`orq fondo lanzar`, `orq esperar-fondo`, etc.).
- [ ] Sin codex como agente trabajador en tablas, escalados ni config.

## Verificación

No corras comandos (Codex verifica al integrar). Repasa los criterios y anótalos en el reporte.

## Reporte

`docs/agentes/reportes/CX-2.md`: resumen, archivos tocados, criterios repasados, dudas.
