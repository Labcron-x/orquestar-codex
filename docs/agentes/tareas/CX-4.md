# CX-4 — Documentar seguridad (sandbox y modo lectura), Qoder, MiniMax Code y documentos opcionales

**Contexto:** revisión de un compañero sobre `codex-orquestador`. Otra tarea (CX-3) cambia los scripts en paralelo
según el contrato de abajo; tú actualizas la documentación. Las ideas de seguridad y los adaptadores de Qoder/MiniMax
vienen de github.com/amElnagdy/delegate-skills (licencia MIT): hay que darle crédito.
**Archivos permitidos:** `SKILL.md`, `README.md`, `ORQUESTACION.md`, `CONTRIBUIR.md`, `config.ejemplo`,
`plantillas/**`, `.github/pull_request_template.md`. Nada más.
**Agente / modelo:** agy · gemini-3.8-flash-medium

## Objetivo

Lee primero `SKILL.md` y `README.md` completos. Cambia solo lo necesario para describir el contrato; mantén el tono
breve y la estructura. `SKILL.md` es lo que Codex lee en cada sesión: que quede claro y sin contradicciones. No corras
comandos: solo lee y edita archivos.

## Contrato (lo implementa CX-3)

1. **Codex trabaja con sandbox (ya no hace falta acceso completo).**
   - Abrir Codex en modo seguro: `codex --sandbox workspace-write --ask-for-approval on-request` (es el modo normal de
     Codex) o, en la app, "Pedir aprobación" ("Aprobar por mí" también sirve: un revisor automático aprueba lo
     rutinario). `danger-full-access` queda como opción no recomendada.
   - Codex lee todo y escribe solo dentro del proyecto. `.git` es de solo lectura en el sandbox: Codex **nunca** corre
     `git add/commit/merge/push` directo. Lo que sale del proyecto o toca `.git` va por `orq`, que Codex corre
     **pidiendo permisos elevados** (fuera del sandbox) con una justificación corta. La primera vez el usuario aprueba
     con "no volver a preguntar" y Codex guarda la regla en `~/.codex/rules/default.rules`. Leer, `git status`,
     `git diff`, `git log` y editar tareas o ESTADO.md van dentro del sandbox.
   - Comandos nuevos: `orq guardar "<mensaje>" [rutas...]` (commit de `docs/agentes` y `AGENTS.md` por defecto) y
     `orq integrar <ID> [--sin-limpiar]` (merge `--no-ff` de `agente/<ID>` en la rama base y limpieza; si hay
     conflicto aborta, lista los archivos y sale con 1). Reemplazan el `git merge` y el `orq limpiar` manuales del
     ciclo y el "haz commit" de preparar el repo y de "Entre tareas".
2. **Modo lectura de los agentes.** Una tarea con la línea `**Modo:** lectura` (o con ID `REV-<...>` o `INV-<...>`)
   lanza al agente en su modo de solo lectura real: agy `--mode plan`, OpenCode agente `plan`, Gemini CLI y Qwen
   `--approval-mode plan`, Qoder `--permission-mode plan`; MiniMax Code no tiene, así que recibe un aviso de solo
   lectura y queda la alarma. Al terminar, si cambió algo en el worktree sale `ALERTA: modo lectura violado:
   <archivos>` y esos cambios no se guardan. El reporte es la respuesta final del agente (lo escribe el script).
   Usar lectura para revisiones cruzadas, investigación y auditorías; escritura para implementar.
3. **Agentes nuevos.**
   - `qoder` — Qoder CLI (`qodercli`): `npm i -g @qoder-ai/qodercli`, login `qodercli login` (o
     `QODER_PERSONAL_ACCESS_TOKEN`); permisos `auto` (`QODER_PERMISOS`); modelos con `qodercli --list-models`
     (`QODER_MODELO`, `QODER_ESCALA`).
   - `mcode` — MiniMax Code: `npm i -g @minimax-ai/code`, login `mcode login` (o `--region global`); modelos
     `minimax/<modelo>` (`MCODE_MODELO`, `MCODE_ESFUERZO`). **Sin sandbox**: su permiso `smart` aprueba escrituras y
     borrados sin preguntar; el worktree aislado y el push bloqueado son la contención. No usarlo para tareas en modo
     lectura delicadas.
   - Alias: `qodercli`/`qoder-cli` → `qoder`; `minimax`/`minimax-code` → `mcode`.
   - En el reparto: ambos son implementadores adicionales para trabajo en paralelo o cuando agy/OpenCode no tienen
     cuota (no cambian la jerarquía: Codex orquesta).
4. **Instalador.** `--agentes "agy opencode gemini-cli qwen qoder mcode"`. Librerías de documentos y
   LibreOffice/pandoc solo con `--documentos` (por defecto no se instalan). Mensaje final con logins y el modo seguro.
5. **README.** URL real del repo: `https://github.com/Labcron-x/orquestar-codex.git` (reemplaza `<URL de tu repo>`).
   Sección corta "Créditos": derivado de claude-orquestador; modo lectura, revisión y adaptadores de Qoder/MiniMax
   inspirados en [delegate-skills](https://github.com/amElnagdy/delegate-skills) (MIT, Ahmed Mohammed).

## Cambios por archivo

- `SKILL.md`: arranque (modo seguro + regla de `orq` con permisos elevados y nunca git directo), preparar el repo con
  `orq guardar`, tabla de reparto con `qoder` y `mcode`, tipo de tarea en lectura, ciclo (validar mira la ALERTA de
  lectura; integrar con `orq integrar <ID>`), "Entre tareas" con `orq guardar`.
- `README.md`: URL real, instalar con `--agentes` y `--documentos`, uso en modo seguro, créditos.
- `ORQUESTACION.md`: § 1 filas de `qoder` y `mcode` y nota de modo lectura por agente; § 3 `guardar` e `integrar`;
  § 4 REV/INV en modo lectura; § 5 documentos requieren `instalar.sh --documentos`; § 6/§ 7 modo seguro de Codex.
- `config.ejemplo`: `QODER_MODELO`, `QODER_ESCALA`, `QODER_PERMISOS`, `MCODE_MODELO`, `MCODE_ESFUERZO`, `ORQ_MODO`
  (comentados, con una línea de explicación cada uno).
- `plantillas/tarea.md`: línea `**Modo:** escritura` (o `lectura` para revisión/investigación) bajo "Agente / modelo".
- `CONTRIBUIR.md` y `.github/pull_request_template.md`: solo si mencionan el acceso completo o el merge manual.

## Criterios de aceptación

- [ ] Ningún archivo pide `danger-full-access` como forma normal de uso.
- [ ] SKILL.md no manda a Codex a correr `git commit`/`git merge` directo; usa `orq guardar` / `orq integrar`.
- [ ] `qoder` y `mcode` aparecen en README, ORQUESTACION y config con los comandos del contrato.
- [ ] README con la URL real y los créditos a delegate-skills.

## Verificación

No corras comandos. Repasa los criterios y anótalos en el reporte.

## Reporte

`docs/agentes/reportes/CX-4.md`: resumen, archivos tocados, criterios repasados, dudas.
