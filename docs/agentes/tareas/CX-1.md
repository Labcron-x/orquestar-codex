# CX-1 — Scripts, instalador y CI para que Codex sea el orquestador

**Contexto:** este repo viene de `claude-orquestador` (Claude Code orquestaba con `run_in_background` y avisos). Ahora
el orquestador es **Codex CLI / app de Codex**, que lee la skill desde `~/.codex/skills/orquestar-codex`. Ya se
borraron `agentes/codex.sh` (Codex deja de ser trabajador), `deploy/` y las skills de Claude en `skills/`.
**Archivos permitidos:** `instalar.sh`, `scripts/*.sh`, `scripts/*.js`, `agents/openai.yaml` (nuevo),
`.github/workflows/ci.yml`, `.gitignore`, `agentes/*.sh` (solo si hace falta). NO toques `SKILL.md`, `*.md` de la raíz,
`plantillas/`, `guias/`, `skills/`, `config.ejemplo` (los hace otra tarea en paralelo).
**Agente / modelo:** codex · @high

## Objetivo

Que los scripts funcionen con Codex como orquestador, en Windows (Git Bash llamado desde PowerShell) y en Linux/macOS,
**sin tocar nada de la instalación de Claude** que convive en la misma PC (`~/.claude/`, `~/.claude.json`,
`~/.config/orquestar-agentes/`, comando `claude`).

## Contrato (no cambiarlo: la documentación de otra tarea lo describe tal cual)

1. **Nombres y rutas**
   - Skill `orquestar-codex`; se instala clonando el repo en `${CODEX_HOME:-$HOME/.codex}/skills/orquestar-codex`.
   - Config personal: `${ORQ_CONFIG:-$HOME/.config/orquestar-codex/config}` (antes `.../orquestar-agentes/config`).
   - `agents/openai.yaml` (nuevo, metadatos de Codex):
     ```yaml
     interface:
       display_name: "Orquestar agentes"
       short_description: "Codex reparte el trabajo entre agentes de CLI y valida"
       default_prompt: "Usa $orquestar-codex para repartir esta tarea entre los agentes de CLI."
     policy:
       allow_implicit_invocation: false
     ```
     (`false` = solo se activa con `$orquestar-codex`; así un Codex lanzado como trabajador por otra herramienta
     nunca la carga.)
2. **Entrada única** `scripts/orq.sh <comando> [args...]`: ejecuta `scripts/<comando>.sh` con los mismos argumentos y
   devuelve su código. Comandos: `actualizar agentes lanzar reintentar resumen limpiar consultar fondo
   esperar-fondo esperar esperar-gh verificar nueva-skill instalar-skills`. Sin comando o desconocido: imprime el uso
   con esa lista y sale con 2. Se llama así (PowerShell en Windows, donde `bash` suele ser el de WSL):
   `& "$env:ProgramFiles\Git\bin\bash.exe" "$env:USERPROFILE/.codex/skills/orquestar-codex/scripts/orq.sh" <comando> ...`
   y en bash: `bash ~/.codex/skills/orquestar-codex/scripts/orq.sh <comando> ...`
3. **Segundo plano** (Codex no avisa cuando termina un proceso: se lanza separado y se espera con un script que no
   gasta tokens):
   - `scripts/fondo.sh lanzar <agente> <ID> [modelo|-] [rama-base]` (desde el repo) → clave `<repo>-<ID>`
   - `scripts/fondo.sh reintentar <ID> "<error>" [modelo|+|-] [agente]` (desde el repo) → clave `<repo>-<ID>`
   - `scripts/fondo.sh consultar <nombre> <agente> "<pregunta>" [modelo|-] [archivos...]` → clave `consulta-<nombre>`
   - Estado en `${ORQ_FONDO:-$HOME/.cache/orquestar-codex/fondo}/`: `<clave>.salida` (stdout+stderr del script),
     `<clave>.pid`, `<clave>.inicio` (epoch), `<clave>.fin` (código de salida, se escribe al terminar). `<repo>` es el
     nombre de la carpeta raíz del repo (como `REPO` en `comun.sh`). Pasa las variables de entorno (`SETUP`, etc.).
   - Si la clave ya está corriendo: error y código 2. Al lanzar imprime una línea:
     `En segundo plano: <clave>. Espera con: orq esperar-fondo <clave>` y sale con 0 al instante.
   - El proceso debe sobrevivir a que termine el comando que lo lanzó (`nohup`/`setsid`/`disown`, stdin de
     `/dev/null`). En Windows, si `nohup` no basta para salir del árbol de procesos del que lo lanzó, usa
     `powershell.exe Start-Process` con Git Bash; documenta en el comentario del script qué elegiste y por qué.
   - `scripts/esperar-fondo.sh [clave...] [--max SEG] [--todas]`: sin claves = todas las pendientes de informar.
     Espera en silencio (sondeo cada 5 s) hasta que termine al menos una (o todas con `--todas`) o pasen `--max`
     segundos (defecto 540). Por cada terminada imprime `== <clave> terminó · código N · M min` y las últimas 150
     líneas de su `.salida`, y la marca como informada (no vuelve a salir sin pedir esa clave). Por cada una que
     sigue: `… <clave> sigue (M min)`. Proceso muerto sin `.fin` → se informa como terminada con código 125.
     Sale con 0 si informó alguna, 124 si se acabó el plazo sin ninguna, 2 si no hay nada pendiente o la clave no
     existe.
4. **Vigilante sin choques entre orquestadores:** el prompt de cada agente empieza con la marca
   `[orq-codex <repo>/<ID>]` y NO contiene el texto literal `tareas/<ID>.md` (p. ej. "la tarea <ID> (archivo <ID>.md
   en docs/agentes/tareas)"). `procesos_de_tarea` busca esa marca (regex escapada) en vez de `tareas/<ID>.md`. Así
   el vigilante de este orquestador no mata agentes de la versión de Claude ni de otro repo con el mismo ID, y al
   revés. Ajusta igual los prompts de `reintentar.sh` y `consultar.sh` (en consultas la marca es
   `[orq-codex consulta/<nombre o carpeta>]`).
5. **Sin Codex trabajador:** el escalado termina en el orquestador. El mensaje de tope de `reintentar.sh` dice
   "...cambia de agente o resuélvelo tú (Codex, el orquestador)". Ningún script menciona Claude como orquestador.

## Cambios por archivo

- `scripts/comun.sh`: config nueva, marca y `procesos_de_tarea` (punto 4).
- `scripts/actualizar.sh`: quitar todo lo de Claude (`claude mcp add`, `~/.claude.json`). Hacer `git pull --ff-only`
  solo si está en `main`, limpio **y** `main` tiene upstream configurado (si no, no hace nada ni avisa). Luego
  `configurar-agentes.js` como ahora.
- `scripts/agentes.sh`: quitar el aviso del MCP de Claude; agregar al final una línea del orquestador:
  `Orquestador: codex <versión> · skill en <ruta de DIR_SKILL>` (o `FALTA codex: npm i -g @openai/codex` si no está).
- `scripts/configurar-agentes.js`: igual para agy, OpenCode, Gemini CLI y Qwen (no cambies lo que escribe: debe dar
  el mismo resultado que la versión de Claude para no pelear con ella). La sección de Codex queda para el
  orquestador: agrega los MCP faltantes a `${CODEX_HOME:-~/.codex}/config.toml` (respeta `CODEX_HOME`).
- `scripts/lanzar.sh`, `reintentar.sh`, `consultar.sh`: prompts con la marca (punto 4); comentarios de uso sin
  `run_in_background` (ahora: "Para no bloquear, usa fondo.sh"). `lanzar.sh` lista de agentes sin codex.
- `scripts/orq.sh`, `scripts/fondo.sh`, `scripts/esperar-fondo.sh`: nuevos (puntos 2 y 3).
- `scripts/instalar-skills.sh`: destino `${CODEX_HOME:-$HOME/.codex}/skills`, marca `.origen-orquestar-codex`, mensaje
  "Abre una sesión nueva de Codex para que las vea". `scripts/nueva-skill.sh`: rutas de los comentarios.
- `instalar.sh`: uso `git clone <url> ~/.codex/skills/orquestar-codex`; requisito y aviso si falta `codex`
  (`npm i -g @openai/codex`), instalarlo si falta; `--agentes` por defecto `"opencode gemini-cli"`, admite
  `agy opencode gemini-cli qwen` (quitar la rama de codex); aviso si no está en `.../skills/orquestar-codex`; quitar
  el paso "MCP de Claude Code" y el paso que escribe `~/.claude/CLAUDE.md` (no escribe ningún AGENTS.md global:
  la skill se invoca explícitamente); config en `~/.config/orquestar-codex/config` desde `config.ejemplo`; skills del
  equipo con `instalar-skills.sh`. Mensaje final: logins (`codex login`, `gemini`, `agy`, `opencode auth login`
  opcional, `qwen` opcional) y cómo usar: abrir Codex con acceso completo (`codex --sandbox danger-full-access`, o
  "Acceso completo" en la app) y escribir `$orquestar-codex <lo que quieres hacer>`.
- `.github/workflows/ci.yml`: `runs-on: ubuntu-latest` en todos los jobs (no hay runner propio); quitar el paso de
  limpiar `/tmp/gitleaks.tmp` y los comentarios del servidor OCI; frontmatter `name: orquestar-codex`; nuevo paso
  que comprueba `allow_implicit_invocation: false` en `agents/openai.yaml`; el resto igual.
- `.gitignore`: sin cambios salvo que haga falta.

## Mínimo código (Ponytail)

Toma la primera opción que funcione completa: ¿hace falta? → ¿ya existe en el repo? → librería estándar → una línea
clara → el mínimo código. Nada de opciones no pedidas; nunca recortes manejo de errores. En el reporte, una línea con
lo que omitiste.

## Criterios de aceptación

- [ ] `bash scripts/verificar.sh` en verde.
- [ ] `grep -rn "claude" instalar.sh scripts/ .github/` solo devuelve nombres de modelo (`claude-sonnet...`) o el
      origen del proyecto en un comentario; nada escribe ni lee en `~/.claude*` ni `~/.config/orquestar-agentes`.
- [ ] Prueba de `fondo.sh`/`esperar-fondo.sh` sin agentes reales: con `ORQ_FONDO` en una carpeta temporal, un
      "comando" de prueba (puedes agregar a `fondo.sh` un modo oculto o usar `consultar` con un agente falso
      instalado en un `ORQ_CONFIG` temporal; elige lo más simple) que termina en ~10 s: `esperar-fondo --max 3` da
      124, luego `esperar-fondo` da 0 con su salida, y de nuevo da 2. Pega la salida en el reporte.
- [ ] `bash scripts/orq.sh` sin argumentos imprime el uso y sale con 2; `bash scripts/orq.sh agentes` funciona.

## Verificación (córrela y pega las últimas líneas en el reporte)

```bash
bash scripts/verificar.sh
bash scripts/orq.sh agentes
```

## Reporte

`docs/agentes/reportes/CX-1.md`: resumen, archivos tocados, salida de la verificación y de la prueba de segundo
plano, cómo resolviste el desacople en Windows, dudas.
