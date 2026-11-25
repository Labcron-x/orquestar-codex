# Reporte CX-3

## Resumen

- Agregados `orq guardar` e `orq integrar`, con rutas acotadas, comprobación de rama base, aborto de conflictos y limpieza opcional.
- Modo lectura por tarea, prefijos `REV-`/`INV-` u `ORQ_MODO`; se exporta y conserva en `.meta`. Los adaptadores usan plan; MiniMax recibe la instrucción adicional porque no tiene sandbox.
- En lectura se detectan cambios y cambios de HEAD, se registra la alerta y el orquestador guarda solo el reporte extraído de la respuesta final. El resumen muestra el modo y las alertas.
- Agregados Qoder y MiniMax Code, sus alias, extracción de sesiones/respuestas/errores y detección de límites en el vigilante.
- Documentos opcionales con `--documentos`; `--sin-programas` omite LibreOffice/pandoc. Sin documentos tampoco se exige Python ni se registra markitdown. El instalador indica cómo abrir Codex con sandbox y aprobación.
- Agregadas pruebas sin git y su ejecución en CI. No se instalaron agentes ni herramientas reales.

Omitido por mínimo código: dependencias nuevas y configuración específica de MCP para los dos CLI nuevos, que la tarea no pide.

## Archivos tocados

- `scripts/guardar.sh` (nuevo)
- `scripts/integrar.sh` (nuevo)
- `scripts/orq.sh`
- `scripts/comun.sh`
- `scripts/lanzar.sh`
- `scripts/reintentar.sh`
- `scripts/resumen.sh`
- `scripts/extraer.js`
- `scripts/configurar-agentes.js`
- `scripts/probar-cx3.sh` (nuevo)
- `agentes/agy.sh`
- `agentes/opencode.sh`
- `agentes/gemini-cli.sh`
- `agentes/qwen.sh`
- `agentes/qoder.sh` (nuevo)
- `agentes/mcode.sh` (nuevo)
- `agentes/solo-lectura.txt` (nuevo)
- `instalar.sh`
- `.github/workflows/ci.yml`
- `docs/agentes/reportes/CX-3.md` (este reporte)

## Verificación

`bash scripts/verificar.sh` — código 0, últimas líneas:

```text
(shellcheck no instalado: se omite)
Verificación OK
```

`bash scripts/orq.sh agentes` — código 0. Extracto con los agentes nuevos:

```text
■ mcode — NO: mcode no está instalado. Instalar: npm i -g @minimax-ai/code · Luego: mcode login (o mcode login --region global)
  por defecto: el del CLI · escala (+): sin definir
  fuerte en: código con MiniMax; sin sandbox, smart aprueba escrituras y borrados sin preguntar
■ qoder — NO: qoder no está instalado. Instalar: npm i -g @qoder-ai/qodercli · Luego: qodercli login (o QODER_PERSONAL_ACCESS_TOKEN)
  por defecto: el del CLI · escala (+): sin definir
  fuerte en: código y revisión con el modo plan de Qoder
```

Últimas líneas del listado:

```text
Config personal: /c/Users/Equipo/.config/orquestar-codex/config (no existe: ver config.ejemplo)
FALTA codex: npm i -g @openai/codex
```

## Pruebas

`bash scripts/probar-cx3.sh` — código 0:

```text
agy: lanzar/reintentar, lectura/escritura y stdin OK
opencode: lanzar/reintentar, lectura/escritura y stdin OK
gemini-cli: lanzar/reintentar, lectura/escritura y stdin OK
qwen: lanzar/reintentar, lectura/escritura y stdin OK
qoder: lanzar/reintentar, lectura/escritura y stdin OK
mcode: lanzar/reintentar, lectura/escritura y stdin OK
Detección, prioridad, persistencia de modo y alias OK
ALERTA: agente colgado (bloqueo conocido: limit_exceeded). Detenido por el vigilante.
Qoder: sesión=qoder-1; respuesta=Reporte Qoder completo
MiniMax: sesión=mcode-1; item.content y result.output OK
MiniMax: failed, limit_exceeded y timeout detectados como errores
Instalador: documentos opcionales y --sin-programas OK (sin instalaciones reales)
Pruebas CX-3 sin git OK
```

Los CLI son funciones simuladas. Se comprueban los argumentos de lanzamiento y reintento, sesiones con espacios, flags adicionales omitidos en lectura para agy/OpenCode, stdin cerrado o propio, y el archivo de instrucciones de MiniMax. La prueba del vigilante usa un registro simulado y no detiene procesos reales.

El instalador se ejecuta con npm, Python, gestores de programas y configuración simulados: se comprueban los paquetes nuevos, la ausencia de documentos por defecto, `--documentos` y `--documentos --sin-programas`.

Registros JSON escritos a mano para `extraer.js`:

```json
{"type":"result","session_id":"qoder-1","result":"Reporte Qoder completo"}
```

```json
{"type":"item.completed","sessionId":"mcode-1","item":{"type":"agent_message","content":"Reporte MiniMax completo"}}
{"type":"exec.completed","sessionId":"mcode-1","result":{"status":"succeeded","output":"Respuesta final MiniMax"}}
```

Además se prueban `failed`, `limit_exceeded` y `timeout` como errores, y `item.content` sin un evento final.

## Dudas y pendientes

- No se ejecutó ningún comando de git, por la instrucción explícita del usuario. Quedan pendientes las pruebas en repositorios temporales de `guardar` sin cambios, integración con limpieza, conflicto con aborto y lanzamiento `REV-1` con modificación indebida, alarma y commit exclusivo del reporte. Los resultados anteriores no sustituyen esas pruebas de integración.
- ShellCheck no está instalado aquí; CI conserva su comprobación de errores.
- Qoder y MiniMax no están instalados: sus llamadas se validaron con simulaciones y los contratos de la tarea.
- No fue necesario modificar archivos fuera de los permitidos; el único Markdown escrito es este reporte solicitado.
