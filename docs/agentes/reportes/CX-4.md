# Reporte CX-4 — Documentar seguridad (sandbox y modo lectura), Qoder, MiniMax Code y documentos opcionales

## Resumen

Se actualizó la documentación del proyecto conforme al contrato de la tarea CX-4:
- Se documentó el funcionamiento de Codex en modo seguro (`--sandbox workspace-write --ask-for-approval on-request`), dejando `danger-full-access` como opción no recomendada y estipulando que Codex nunca ejecuta `git add/commit/merge/push` directo sino a través de `orq` (`orq guardar` y `orq integrar`) con permisos elevados.
- Se documentó el modo lectura de los agentes (`**Modo:** lectura` o prefijos `REV-`/`INV-`), los flags correspondientes por agente (`agy --mode plan`, `opencode plan`, `gemini/qwen --approval-mode plan`, `qoder --permission-mode plan`, aviso en `mcode`), y la alerta ante violaciones del modo lectura.
- Se incorporaron los nuevos agentes `qoder` (Qoder CLI) y `mcode` (MiniMax Code) con sus comandos de instalación, login, permisos, variables de configuración y consideraciones de contención (MiniMax sin sandbox).
- Se documentó la opción `--documentos` para la instalación opcional de dependencias de documentos y LibreOffice/pandoc en `instalar.sh`.
- Se actualizó la URL del repositorio a `https://github.com/Labcron-x/orquestar-codex.git` y se añadieron los créditos correspondientes a `delegate-skills`.
- Se actualizaron las plantillas y el archivo de configuración de ejemplo con las nuevas variables comentadas.

## Archivos tocados

- `SKILL.md`: arranque en modo seguro, eliminación de git commit/merge directo en favor de `orq guardar` y `orq integrar`, incorporación de `qoder`/`mcode` en la jerarquía y tabla de reparto, y especificación del modo lectura.
- `README.md`: URL real del repositorio, flags `--agentes` y `--documentos` en el instalador, CLI de Qoder y MiniMax en la lista y comandos de login, uso en modo seguro y sección de créditos a `delegate-skills`.
- `ORQUESTACION.md`: filas de `qoder` y `mcode` en § 1 con notas de permisos y contención, detalle del modo lectura por agente y alerta, notas de modelos en § 2, comandos `orq guardar` y `orq integrar` en § 3, modo lectura en § 4, notas sobre `--documentos` en § 5, y modo seguro en § 7.
- `config.ejemplo`: adición de `ORQ_MODO`, `QODER_MODELO`, `QODER_ESCALA`, `MCODE_MODELO`, `MCODE_ESFUERZO` y `QODER_PERMISOS` comentadas con una línea descriptiva.
- `plantillas/tarea.md`: línea `**Modo:** escritura` (o lectura) bajo "Agente / modelo".
- `plantillas/AGENTS.md`: encabezado actualizado para incluir Qoder y MiniMax Code.
- `docs/agentes/reportes/CX-4.md`: este reporte.

## Verificación (criterios repasados)

Siguiendo la instrucción de la tarea ("No corras comandos. Repasa los criterios y anótalos en el reporte"), se revisaron manualmente todos los criterios de aceptación:

- [x] **Ningún archivo pide `danger-full-access` como forma normal de uso**: Verificado en `SKILL.md`, `README.md` y `ORQUESTACION.md`. El modo seguro por defecto es `--sandbox workspace-write --ask-for-approval on-request`, y `danger-full-access` figura únicamente como opción no recomendada.
- [x] **SKILL.md no manda a Codex a correr `git commit`/`git merge` directo; usa `orq guardar` / `orq integrar`**: Verificado. La preparación del repo y el cierre de lotes usan `orq guardar "<mensaje>"`, y la integración de ramas usa `orq integrar <ID>`. Se prohíbe explícitamente a Codex correr comandos git de escritura directos.
- [x] **`qoder` y `mcode` aparecen en README, ORQUESTACION y config con los comandos del contrato**: Verificado. Incluye paquetes npm (`@qoder-ai/qodercli`, `@minimax-ai/code`), comandos de login, flags de permisos, alias y variables en `config.ejemplo`.
- [x] **README con la URL real y los créditos a delegate-skills**: Verificado. Se colocó `https://github.com/Labcron-x/orquestar-codex.git` y la sección de créditos reconociendo a `claude-orquestador` y a `delegate-skills` (MIT, Ahmed Mohammed).

## Dudas

Ninguna.
