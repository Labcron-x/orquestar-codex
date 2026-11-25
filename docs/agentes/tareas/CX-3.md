# CX-3 — Seguridad (sandbox de Codex y modo lectura), agentes Qoder y MiniMax Code, documentos opcionales

**Contexto:** revisión de un compañero. (1) Codex orquestador no debe necesitar `danger-full-access`: trabaja en su
sandbox normal (`workspace-write` + aprobación) y todo lo que sale del proyecto o escribe en `.git` pasa por `orq`, que
Codex corre con permisos elevados (el usuario lo aprueba una vez). Por eso faltan `orq guardar` y `orq integrar`.
(2) Las tareas de revisión e investigación deben correr con un **modo de solo lectura real** del CLI, no solo por
prompt, con alarma si algo cambió (idea tomada de github.com/amElnagdy/delegate-skills, MIT). (3) Faltan los agentes
Qoder CLI y MiniMax Code. (4) LibreOffice/pandoc y librerías de documentos deben ser opcionales.
**Archivos permitidos:** `scripts/*.sh`, `scripts/*.js`, `agentes/*.sh`, `agentes/solo-lectura.txt` (nuevo),
`instalar.sh`, `.github/workflows/ci.yml`. NO toques `*.md`, `plantillas/`, `guias/`, `config.ejemplo` (otra tarea).
**Agente / modelo:** codex · @high

## Contrato (no cambiarlo: la documentación de otra tarea lo describe tal cual)

1. **`orq guardar "<mensaje>" [rutas...]`** (`scripts/guardar.sh`, desde el repo): `git add -- <rutas>` (por defecto
   las que existan de `docs/agentes` y `AGENTS.md`) y commit con el mensaje. Si no hay nada preparado: `Nada que
   guardar.` y código 0. Al terminar imprime `git log -1 --oneline`. Nunca agrega el repo entero salvo que la ruta
   pasada sea `.`.
2. **`orq integrar <ID> [--sin-limpiar]`** (`scripts/integrar.sh`, desde el repo): exige estar en la rama base de la
   tarea (`BASE` del `.meta`; si no hay meta, la actual) y sin cambios con seguimiento sin commit. Hace
   `git merge --no-ff agente/<ID> -m "Merge agente/<ID>: <título>"` (título = primera línea de la tarea sin
   `# <ID> — `). Si hay conflicto: lista los archivos en conflicto, `git merge --abort` y código 1. Si sale bien:
   `limpiar.sh <ID>` (salvo `--sin-limpiar`) y `git log -1 --oneline`. Agrégalos a `orq.sh`.
3. **Modo lectura**:
   - Se activa si la tarea tiene la línea `**Modo:** lectura`, o si el ID empieza con `REV-` o `INV-`, o con
     `ORQ_MODO=lectura` (y `ORQ_MODO=escritura` lo fuerza al revés). Se guarda en el `.meta` (`MODO=`) para que
     `reintentar` lo mantenga. Variable exportada `MODO` (`lectura`|`escritura`) que leen los adaptadores.
   - Flags por adaptador en lectura: agy `--mode plan` (en vez de `accept-edits`, y sin `AGY_FLAGS`); opencode
     `--agent plan` (en vez de `build`); gemini-cli `--approval-mode plan`; qwen `--approval-mode plan`; qoder
     `--permission-mode plan`; mcode: no tiene modo lectura → `--append-system-prompt-file
     <DIR_SKILL>/agentes/solo-lectura.txt` (texto corto: solo leer, no crear/editar/borrar archivos ni correr
     comandos que cambien algo).
   - Prompt en lectura (`lanzar` y `reintentar`): misma marca `[orq-codex <repo>/<ID>]`, aviso "MODO SOLO
     LECTURA: no modifiques, crees ni borres archivos", y "tu respuesta final es el reporte completo" (no escribe
     archivos).
   - Al terminar en lectura: **alarma**: si `git status --porcelain` del worktree no está vacío o hay commits nuevos,
     imprime `ALERTA: modo lectura violado: <archivos>` y NO hace commit de esos cambios (quedan para que el
     orquestador decida). Luego guarda la respuesta final (`extraer.js --respuesta`) en `$REPORTE` del worktree y
     hace commit solo de ese archivo. `resumen.sh` muestra `Modo: lectura|escritura` en su primera línea y la
     ALERTA si la hubo.
4. **Agentes nuevos** (mismo formato que los demás adaptadores: `BIN`, `MODELO_DEF`, `ESCALA`, `INSTALAR`, `LOGIN`,
   `FUERTE`, `agente_lanzar`, `agente_reintentar`, `agente_modelos`; todos con `< /dev/null` o stdin propio):
   - `agentes/qoder.sh` — binario `qodercli`; `INSTALAR="npm i -g @qoder-ai/qodercli"`; `LOGIN="qodercli login (o
     QODER_PERSONAL_ACCESS_TOKEN)"`; modelo `${QODER_MODELO:-}` (vacío = el de Qoder), escala `${QODER_ESCALA:-}`.
     Lanzar: `qodercli --output-format stream-json --permission-mode "${QODER_PERMISOS:-auto}" [--model M] -p
     "<prompt>"`. Reintentar: agrega `--resume <sesión>`. Modelos: `qodercli --list-models`. Salida tipo
     stream-json de Claude (`type: result`, `session_id`).
   - `agentes/mcode.sh` — MiniMax Code, binario `mcode` (o `$MCODE_CLI`, o `~/.minimax-code/bin/mcode` si no está en
     PATH); `INSTALAR="npm i -g @minimax-ai/code"`; `LOGIN="mcode login (o mcode login --region global)"`; modelo
     `${MCODE_MODELO:-}` con forma `minimax/<modelo>`, esfuerzo opcional `${MCODE_ESFUERZO:-}` → `--effort`.
     Lanzar: el prompt por stdin: `mcode exec --input - --output-format stream-json --permission smart [--model M]
     [--effort E]`. Reintentar: agrega `--session <sesión>`. No tiene sandbox: `smart` aprueba escrituras y borrados
     sin preguntar (dilo en `FUERTE` o en un comentario). Eventos: cada uno trae `sessionId`; `item.completed` con
     `item.type == "agent_message"` trae el texto en `item.content`; termina con `exec.completed` cuyo `result` tiene
     `status` (succeeded|failed|limit_exceeded|timeout), `output` y `error`.
   - `scripts/extraer.js`: sesión también desde `sessionId`; respuesta desde `item.content` (mcode) y desde
     `exec.completed`.`result.output`; `result.status` distinto de `succeeded` → error. El vigilante cuenta
     `limit_exceeded` como bloqueo conocido (por fragmentos, como los demás).
   - `comun.sh` `normalizar_agente`: `qodercli|qoder-cli` → `qoder`; `minimax|minimax-code` → `mcode`.
5. **`instalar.sh`**: `--agentes` acepta `agy opencode gemini-cli qwen qoder mcode` (instala con npm los que falten;
   agy sigue con su aviso). **Documentos opcionales:** las librerías de Python de documentos y LibreOffice/pandoc
   solo con `--documentos` (por defecto no se instalan; `--sin-programas` sigue funcionando: con `--documentos`
   instala solo las librerías). El mensaje final agrega los logins de `qodercli` y `mcode` y dice cómo abrir Codex en
   modo seguro: `codex --sandbox workspace-write --ask-for-approval on-request` (o "Pedir aprobación" en la app), y
   que la primera vez aprueben `orq` con "no volver a preguntar".

## Mínimo código (Ponytail)

¿Hace falta? → ¿ya existe en el repo? → librería estándar → una línea clara → el mínimo código. Nunca recortes
manejo de errores. En el reporte, una línea con lo que omitiste.

## Criterios de aceptación

- [ ] `bash scripts/verificar.sh` en verde; `bash scripts/orq.sh agentes` lista `qoder` y `mcode` (no instalados aquí).
- [ ] Prueba en un repo git temporal (con agentes falsos en `PATH` y `ORQ_CONFIG` temporal, como en CX-1): `guardar`
      sin cambios da 0 con "Nada que guardar"; `integrar` de una rama limpia hace el merge y limpia; con conflicto
      aborta y da 1; una tarea `REV-1` lanza el agente falso con el flag de plan y, si el agente falso modifica un
      archivo, sale `ALERTA: modo lectura violado` y ese cambio no queda en el commit; el reporte se escribe desde la
      respuesta final. Pega las salidas en el reporte.
- [ ] `extraer.js` entiende un registro de ejemplo de mcode y uno de qoder (prueba con líneas JSON escritas a mano).

## Verificación (córrela y pega las últimas líneas en el reporte)

```bash
bash scripts/verificar.sh
bash scripts/orq.sh agentes
```

## Reporte

`docs/agentes/reportes/CX-3.md`: resumen, archivos tocados, salidas de verificación y pruebas, dudas.
