# CX-4 — Telemetría: consumo por proveedor y modelo

**Contexto:** el equipo quiere ver cuánto consume cada proveedor (agente de CLI) y cada modelo, y cuánto gasta Codex.
**Archivos permitidos:** `scripts/extraer.js`, `scripts/comun.sh`, `scripts/orq.sh`, `scripts/consumo.sh` (nuevo),
`scripts/consumo.js` (nuevo), `scripts/pruebas.sh`, `SKILL.md`, `README.md`, `ORQUESTACION.md`, `config.ejemplo`,
`docs/agentes/reportes/CX-4.md` (nada fuera de aquí)
**Depende de:** nada
**Agente / modelo:** codex
**Modo:** escritura

## Objetivo

1. Cada ejecución de un agente (lanzar, reintentar, consulta) deja una línea JSONL con sus tokens y, si el CLI lo
   informa, su costo.
2. `orq consumo [días|todo]` resume ese registro por agente y modelo, y agrega el consumo de Codex (el orquestador)
   leído de sus sesiones, con el % usado del límite de ChatGPT.
3. `orq resumen <ID>` muestra una línea `Consumo:` de la tarea.

## Contrato (no cambiarlo)

### A. `node scripts/extraer.js <registro> --uso [--desde <bytes>]`

Lee el registro solo desde el byte `--desde` (por defecto 0) e imprime un arreglo JSON (`[]` si no hay datos):
`[{"modelo": string|null, "entrada": n, "cache": n, "salida": n, "razonamiento": n, "costo": n|null}]`.
`entrada` = tokens de entrada **incluida** la caché; `cache` = de esos, los leídos de caché. Las líneas
`----- cambio de agente` no reinician nada en `--uso` (el tramo lo fija `--desde`). Formatos reales (una línea JSON
por evento):

| CLI | Eventos | Cómo contar |
|---|---|---|
| OpenCode | varios `{"type":"step_finish","part":{"tokens":{"input","output","reasoning","cache":{"read","write"}},"cost":N}}` | **sumar** todos. entrada = input + cache.read + cache.write; cache = cache.read; costo = suma de `cost` |
| agy | `{"event":"init","init":{"model":"gemini-3.8-flash-medium"}}`; por paso `{"event":"step_update","step_update":{"usage":{...}}}`; al final `{"event":"result","result":{"usage":{"input_tokens","output_tokens","thinking_tokens","cache_read_tokens","total_tokens"}}}` | usar **solo** el total de `result` (no sumar `step_update`). entrada = input_tokens; cache = cache_read_tokens; razonamiento = thinking_tokens; modelo = `init.model` |
| Gemini CLI | `{"type":"result","stats":{"input_tokens","output_tokens","cached","input","total_tokens","models":{"<modelo>":{"input_tokens","output_tokens","cached","input","total_tokens"}}}}` | un elemento **por modelo** de `stats.models` (sin `models`: uno con modelo null). entrada = input_tokens; cache = cached |
| Qwen Code, Qoder (stream-json tipo Claude) | `{"type":"result","usage":{"input_tokens","output_tokens","cache_read_input_tokens","cache_creation_input_tokens"},"total_cost_usd"?:N}` | entrada = input_tokens + cache_read_input_tokens + cache_creation_input_tokens; cache = cache_read_input_tokens; costo = total_cost_usd si viene |
| Codex | `{"type":"turn.completed","usage":{"input_tokens","cached_input_tokens","output_tokens","reasoning_output_tokens"}}` | sumar. entrada = input_tokens; cache = cached_input_tokens |
| MiniMax Code | formato de consumo **no confirmado** | si `exec.completed` trae `usage` (en el evento o en `result`), leerlo con las claves de arriba; si no, `[]` |

Si en el tramo hay un total de ejecución (agy, Gemini, Qwen/Qoder, MiniMax), manda sobre lo incremental.
Además, el modo por defecto de `extraer.js` (el que usa `resumen.sh`) imprime antes de `Respuesta final:` una línea
`Consumo: <modelo o "?">: 12.3k entrada (8.1k caché) · 0.5k salida · 0.4k razonamiento[ · US$0.0123]` por modelo,
sumando todo el registro, o `Consumo: sin datos`.

### B. Registro (en `scripts/comun.sh`)

Al final de `ejecutar_agente`, con `estado` ya conocido y antes del `echo "Código de salida..."`, llama a
`registrar_consumo <tipo> <modelo pedido> <estado> <segundos> <previo>` (tipo = `$1` de ejecutar_agente:
lanzar|nuevo|reintentar; previo = bytes del registro antes del intento, que ya calcula). Agrega a
`${ORQ_CONSUMO:-$HOME/.local/share/orquestar-codex/consumo.jsonl}` (crea la carpeta) una línea por elemento de
`extraer.js "$LOG.jsonl" --uso --desde <previo>`, o una sola con ceros y `"sin_datos":true` si es `[]`:
`{"fecha":"<ISO UTC>","repo":"<REPO o consulta>","id":"<ID, o ORQ_CONSULTA_NOMBRE o nombre de la carpeta de la consulta>","tipo","agente":"<AGENTE>","modelo","codigo":n,"seg":n,"entrada","cache","salida","razonamiento","costo"}`.
- `modelo`: el del registro; si no trae, el pedido; si está vacío, `MODELO_DEF`; si también, `"predeterminado"`.
- Escribe el JSON con node (bien escapado), no armado a mano en bash.
- **Nunca** falla ni ensucia: cualquier error se ignora (stderr a /dev/null) y no cambia el código ni la salida de
  `ejecutar_agente`. Con `ORQ_CONSUMO=off` no registra.

### C. `orq consumo [días|todo]` (`scripts/consumo.sh` → `node scripts/consumo.js`)

Por defecto 7 días. Agregar `consumo` al `case` y al texto de uso de `scripts/orq.sh`. Imprime:

1. **Agentes** (del registro B): tabla agrupada por agente + modelo, ordenada por agente y entrada descendente:
   `Agente | Modelo | Ejec. | Fallos (codigo≠0) | Entrada | Caché | Salida | Razon. | Costo US$ (— si todo es null) | Tiempo (min)`,
   y una línea de total por agente. Números cortos: 1234 → `1.2k`, 1500000 → `1.5M`.
2. **Codex (orquestador)**: lee `${CODEX_HOME:-~/.codex}/sessions/**/rollout-*.jsonl` modificados en el periodo.
   Formato real:
   - `{"type":"turn_context","payload":{"model":"gpt-...", ...}}` → modelo de los turnos siguientes;
   - `{"type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens","cached_input_tokens","output_tokens","reasoning_output_tokens","total_tokens"},"last_token_usage":{...}},"rate_limits":{"primary":{"used_percent":13.0,"window_minutes":300,"resets_at":<epoch s>},"secondary":{"used_percent":6.0,"window_minutes":10080,"resets_at":<epoch s>},"plan_type":"team"}}}`
     (`info` y `rate_limits` pueden ser null).
   `total_token_usage` es acumulado por sesión: suma la **diferencia** entre token_count consecutivos (no uses
   `last_token_usage`, se repite) y atribúyela al modelo del último `turn_context`. Tabla
   `Modelo | Sesiones | Entrada | Caché | Salida | Razon.` y una línea con los `rate_limits` más recientes:
   `Límite de ChatGPT (plan team): 13 % de la ventana de 5 h (se renueva 15:05) · 6 % semanal (se renueva 30/11 10:20)`
   (hora local). Aclara que son todas las sesiones de Codex de esta PC.
3. Sin datos: `Sin registros de consumo en este periodo.` y código 0. Una línea JSONL rota se salta.

### D. Documentación (corta, mismo tono)

- `SKILL.md`, en "Entre tareas": `orq consumo` al cerrar un lote o si el usuario pregunta por gasto; si un agente
  acumula fallos o Codex pasa del 80 % de su ventana, prefiere otros agentes.
- `README.md`: sección corta "Consumo" (qué mide, comando, dónde queda el registro).
- `ORQUESTACION.md` § 3 Scripts: `consumo`; y en § 7 o una nota: ruta del registro, `ORQ_CONSUMO`, y límites
  (el costo solo aparece si el CLI lo informa: OpenCode, Qwen/Qoder; MiniMax sin confirmar; no hay tabla de precios).
- `config.ejemplo`: `# ORQ_CONSUMO="off"   # o una ruta: dónde guardar el registro de consumo`.

## Mínimo código (Ponytail)

Toma la primera opción que funcione completa: ¿hace falta? → ¿ya existe en el repo? → librería estándar o de la
plataforma → dependencia ya instalada → una línea clara → el mínimo código. Nada de abstracciones ni opciones no
pedidas (nada de `--json`, filtros por repo ni tablas de precios); nunca recortes manejo de errores. Sin dependencias
nuevas (solo node y bash). En el reporte, una línea con lo que omitiste.

**Importante:** no escribas literalmente en ningún archivo las frases que detecta el vigilante de cuota (ver `patron=`
en `scripts/comun.sh`); si una prueba las necesita, ármalas por fragmentos como ya hace `pruebas.sh`. No leas
`~/.codex/sessions` reales: en las pruebas usa un `CODEX_HOME` temporal.

## Criterios de aceptación

- [ ] `extraer.js --uso` da valores exactos para cada formato de la tabla A, incluidos: OpenCode suma 2 pasos y su
  costo; agy no suma `step_update`; Gemini con 2 modelos da 2 elementos; `--desde` cuenta solo el segundo intento.
- [ ] `registrar_consumo` escribe JSONL válido en un `ORQ_CONSUMO` temporal, no cambia el código de salida si la ruta
  no se puede escribir y no escribe nada con `ORQ_CONSUMO=off`.
- [ ] `consumo.js` con un JSONL de ejemplo y un `CODEX_HOME` falso (2 token_count, cambio de modelo, rate_limits)
  imprime los totales correctos y la línea del límite.
- [ ] Las pruebas nuevas van en `scripts/pruebas.sh` (sin git ni agentes reales) y pasan junto con las existentes.
- [ ] `resumen` muestra `Consumo:`; nada de lo anterior cambia otras salidas ni códigos.

## Verificación (córrela y pega las últimas líneas en el reporte)

```bash
bash scripts/verificar.sh
bash scripts/pruebas.sh
```

## Reporte

`docs/agentes/reportes/CX-4.md`: resumen, archivos tocados, salida de la verificación, dudas.
