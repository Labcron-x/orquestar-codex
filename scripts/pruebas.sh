#!/usr/bin/env bash
# Pruebas sin git, instalaciones ni agentes reales. Uso: bash scripts/pruebas.sh
set -eu
DIR_SKILL=$(cd "$(dirname "$0")/.." && pwd)
TMP_PRUEBA=$(mktemp -d)
export DIR_SKILL TMP_PRUEBA
trap 'rm -f "$TMP_PRUEBA/args" "$TMP_PRUEBA/stdin" "$TMP_PRUEBA/registro" "$TMP_PRUEBA/tarea" "$TMP_PRUEBA/config" "$TMP_PRUEBA/instalacion"; rmdir "$TMP_PRUEBA"' EXIT

capturar() {
  printf '%s\n' "$@" > "$TMP_PRUEBA/args"
  cat > "$TMP_PRUEBA/stdin"
}
agy() { capturar "$@"; }
opencode() { capturar "$@"; }
gemini() { capturar "$@"; }
qwen() { capturar "$@"; }
qodercli() { capturar "$@"; }
mcode() { capturar "$@"; }
export -f capturar agy opencode gemini qwen qodercli mcode

for a in agy opencode gemini-cli qwen qoder mcode; do
  (
    export AGY=agy MCODE_CLI=mcode AGY_FLAGS=--inseguro OPENCODE_FLAGS=--inseguro
    export GEMINI_CLI_APROBACION=yolo QWEN_APROBACION=yolo QODER_PERMISOS=auto MCODE_ESFUERZO=high
    source "$DIR_SKILL/agentes/$a.sh"
    for MODO in lectura escritura; do
      export MODO
      for funcion in agente_lanzar agente_reintentar; do
        "$funcion" 'prompt con espacios' 'minimax/modelo' 'sesion de prueba'
        node - "$a" "$MODO" "$funcion" "$TMP_PRUEBA" "$DIR_SKILL" <<'NODE'
const fs = require('fs'), assert = require('assert');
const [a, modo, funcion, tmp, skill] = process.argv.slice(2);
const args = fs.readFileSync(tmp + '/args', 'utf8').trimEnd().split('\n');
const stdin = fs.readFileSync(tmp + '/stdin', 'utf8');
const lectura = modo === 'lectura';
const flag = {agy: '--mode', opencode: '--agent', 'gemini-cli': '--approval-mode', qwen: '--approval-mode', qoder: '--permission-mode', mcode: '--permission'}[a];
const defecto = {agy: 'accept-edits', opencode: 'build', 'gemini-cli': 'yolo', qwen: 'yolo', qoder: 'auto', mcode: 'smart'}[a];
assert.strictEqual(args[args.indexOf(flag) + 1], lectura && a !== 'mcode' ? 'plan' : defecto);
if (a === 'agy' || a === 'opencode') assert.strictEqual(args.includes('--inseguro'), !lectura);
if (a === 'mcode') {
  assert.strictEqual(stdin, 'prompt con espacios\n');
  assert.strictEqual(args.includes('--append-system-prompt-file'), lectura);
  if (lectura) assert.ok(args[args.indexOf('--append-system-prompt-file') + 1].endsWith('/agentes/solo-lectura.txt'));
  assert.strictEqual(args[args.indexOf('--effort') + 1], 'high');
} else {
  assert.strictEqual(stdin, '');
  assert(args.includes('prompt con espacios'));
}
if (funcion === 'agente_reintentar' && ['agy', 'opencode', 'qoder', 'mcode'].includes(a)) assert(args.includes('sesion de prueba'));
NODE
      done
    done
    echo "$a: lanzar/reintentar, lectura/escritura y stdin OK"
  )
done

(
  ORQ_CONFIG=/dev/null source "$DIR_SKILL/scripts/comun.sh" ""
  RAIZ=$TMP_PRUEBA TAREA=tarea
  for ID in REV-1 INV-1 CX-1; do
    : > "$RAIZ/$TAREA"
    unset MODO ORQ_MODO
    determinar_modo
    if [ "$ID" = CX-1 ]; then [ "$MODO" = escritura ]; else [ "$MODO" = lectura ]; fi
  done
  printf '**Modo:** lectura\r\n' > "$RAIZ/$TAREA"
  unset MODO
  determinar_modo; [ "$MODO" = lectura ]
  ORQ_MODO=escritura determinar_modo; [ "$MODO" = escritura ]
  ORQ_MODO=lectura determinar_modo; [ "$MODO" = lectura ]
  : > "$RAIZ/$TAREA"
  determinar_modo; [ "$MODO" = lectura ] # Conserva el modo guardado aunque cambie la tarea.
  [ "$(normalizar_agente qodercli)" = qoder ] && [ "$(normalizar_agente qoder-cli)" = qoder ]
  [ "$(normalizar_agente minimax)" = mcode ] && [ "$(normalizar_agente minimax-code)" = mcode ]
  if ORQ_MODO=invalido determinar_modo >/dev/null; then exit 1; fi
  echo 'Detección, prioridad, persistencia de modo y alias OK'
)

(
  ORQ_CONFIG=/dev/null source "$DIR_SKILL/scripts/comun.sh" ""
  printf '{"type":"exec.completed","result":{"status":"limit_%s"}}\n' exceeded > "$TMP_PRUEBA/registro"
  sleep() { :; }
  detener_agente() { :; }
  if vigilar_agente "$BASHPID" "$TMP_PRUEBA/registro"; then exit 1; fi
  grep -q '^ALERTA: agente colgado (bloqueo conocido:' "$TMP_PRUEBA/registro"
)

node - "$DIR_SKILL" "$TMP_PRUEBA" <<'NODE'
const fs = require('fs'), assert = require('assert'), {execFileSync} = require('child_process');
const [skill, tmp] = process.argv.slice(2), registro = tmp + '/registro';
const extraer = modo => execFileSync(process.execPath, [skill + '/scripts/extraer.js', registro, ...modo ? [modo] : []], {encoding: 'utf8'});
const escribir = eventos => fs.writeFileSync(registro, eventos.map(e => JSON.stringify(e)).join('\n') + '\n');
escribir([{type: 'result', session_id: 'qoder-1', result: 'Reporte Qoder completo'}]);
assert.strictEqual(extraer('--sesion'), 'qoder-1');
assert.strictEqual(extraer('--respuesta'), 'Reporte Qoder completo');
console.log('Qoder: sesión=qoder-1; respuesta=Reporte Qoder completo');
const mensaje = {type: 'item.completed', sessionId: 'mcode-1', item: {type: 'agent_message', content: 'Reporte MiniMax completo'}};
escribir([mensaje]);
assert.strictEqual(extraer('--respuesta'), 'Reporte MiniMax completo');
escribir([mensaje, {type: 'exec.completed', sessionId: 'mcode-1', result: {status: 'succeeded', output: 'Respuesta final MiniMax'}}]);
assert.strictEqual(extraer('--sesion'), 'mcode-1');
assert.strictEqual(extraer('--respuesta'), 'Respuesta final MiniMax');
assert(!extraer().includes('Errores:'));
console.log('MiniMax: sesión=mcode-1; item.content y result.output OK');
for (const status of ['failed', 'limit_exceeded', 'timeout']) {
  escribir([{type: 'exec.completed', sessionId: 'mcode-1', result: {status, error: 'detalle'}}]);
  assert(extraer().includes('MiniMax Code: ' + status + ': detalle'));
  assert(extraer('--respuesta').includes('ERROR del agente:'));
}
console.log('MiniMax: failed, limit_exceeded y timeout detectados como errores');
NODE

# El instalador se prueba con funciones exportadas: no instala ni configura nada real.
: > "$TMP_PRUEBA/config"
for opciones in '' '--documentos' '--libreoffice'; do
  : > "$TMP_PRUEBA/instalacion"
  "$BASH" -c '
    codex() { :; }; setx() { :; }
    command() {
      if [ "${1:-}" = -v ] && [ "${2:-}" = qodercli ]; then return 1; fi
      builtin command "$@"
    }
    npm() { echo "npm $*" >> "$TMP_PRUEBA/instalacion"; }
    python() { echo "python $*" >> "$TMP_PRUEBA/instalacion"; }
    winget() { echo "winget $*" >> "$TMP_PRUEBA/instalacion"; }
    node() { echo "node $*" >> "$TMP_PRUEBA/instalacion"; }
    bash() { :; }
    ORQ_CONFIG=$TMP_PRUEBA/config MCODE_CLI=orq-mcode-ausente source "$0" --agentes "qoder mcode" "$@"
  ' "$DIR_SKILL/instalar.sh" ${opciones} >/dev/null
  node - "$TMP_PRUEBA" "$opciones" <<'NODE'
const fs = require('fs'), assert = require('assert');
const [tmp, opciones] = process.argv.slice(2), log = fs.readFileSync(tmp + '/instalacion', 'utf8');
const documentos = opciones !== '';
assert(log.includes('npm i -g @qoder-ai/qodercli'));
assert(log.includes('npm i -g @minimax-ai/code'));
assert.strictEqual(log.includes('-m pip install'), documentos);
assert.strictEqual(log.includes('JohnMacFarlane.Pandoc'), documentos);
assert.strictEqual(log.includes('TheDocumentFoundation.LibreOffice'), opciones === '--libreoffice');
const config = log.split('\n').find(l => l.includes('configurar-agentes.js'));
assert(config);
assert.strictEqual(config.includes('--documentos'), documentos);
NODE
done
echo 'Instalador: --documentos sin LibreOffice y --libreoffice aparte OK (sin instalaciones reales)'
node - "$DIR_SKILL" "$TMP_PRUEBA" <<'NODE'
const fs = require('fs'), assert = require('assert'), path = require('path'), {execFileSync} = require('child_process');
const [skill, tmp] = process.argv.slice(2), registro = path.join(tmp, 'registro');
const ejecutar = (script, args = [], env = process.env) => execFileSync(process.execPath,
  [path.join(skill, 'scripts', script), ...args], {encoding: 'utf8', env});
const escribir = eventos => fs.writeFileSync(registro, eventos.map(e => JSON.stringify(e)).join('\n') + '\n');
const extraer = (...args) => JSON.parse(ejecutar('extraer.js', [registro, '--uso', ...args]));
const fila = (modelo, entrada, cache, salida, razonamiento = 0, costo = null) => ({modelo, entrada, cache, salida, razonamiento, costo});
const paso = {type: 'step_finish', model: 'oc', part: {tokens: {input: 100, output: 20, reasoning: 3, cache: {read: 40, write: 10}}, cost: 0.125}};
escribir([paso, paso]);
assert.deepStrictEqual(extraer(), [fila('oc', 300, 80, 40, 6, 0.25)]);
const agy = [{event: 'init', init: {model: 'gemini-3.8-flash-medium'}},
  {event: 'step_update', step_update: {usage: {input_tokens: 999}}},
  {event: 'result', result: {usage: {input_tokens: 120, output_tokens: 12, thinking_tokens: 8, cache_read_tokens: 50, total_tokens: 140}}}];
escribir([paso, ...agy]);
assert.deepStrictEqual(extraer(), [fila('gemini-3.8-flash-medium', 120, 50, 12, 8)]);
fs.writeFileSync(registro, JSON.stringify(paso) + '\n----- cambio de agente\n' + agy.map(e => JSON.stringify(e)).join('\n') + '\n');
assert.deepStrictEqual(extraer(), [fila('gemini-3.8-flash-medium', 120, 50, 12, 8)]);
const resumenMixto = ejecutar('extraer.js', [registro]);
assert(resumenMixto.includes('Consumo: oc: 150 entrada'));
assert(resumenMixto.includes('Consumo: gemini-3.8-flash-medium: 120 entrada'));
const stats = {input_tokens: 100, cached: 30, output_tokens: 10, input: 70, total_tokens: 110};
escribir([{type: 'result', stats: {...stats, models: {uno: stats, dos: {...stats, input_tokens: 200}}}}]);
assert.deepStrictEqual(extraer(), [fila('uno', 100, 30, 10), fila('dos', 200, 30, 10)]);
escribir([{type: 'result', stats}]);
assert.deepStrictEqual(extraer(), [fila(null, 100, 30, 10)]);
const claude = {type: 'result', usage: {input_tokens: 80, output_tokens: 20, cache_read_input_tokens: 30, cache_creation_input_tokens: 10}};
escribir([claude]);
assert.deepStrictEqual(extraer(), [fila(null, 120, 30, 20)]);
escribir([{...claude, model: 'qoder', total_cost_usd: 0.0123}]);
assert.deepStrictEqual(extraer(), [fila('qoder', 120, 30, 20, 0, 0.0123)]);
const turno = {type: 'turn.completed', usage: {input_tokens: 100, cached_input_tokens: 40, output_tokens: 10, reasoning_output_tokens: 5}};
escribir([turno, turno]);
assert.deepStrictEqual(extraer(), [fila(null, 200, 80, 20, 10)]);
for (const evento of [{type: 'exec.completed', usage: turno.usage},
  {type: 'exec.completed', result: {status: 'succeeded', usage: turno.usage}}]) {
  escribir([evento]); assert.deepStrictEqual(extraer(), [fila(null, 100, 40, 10, 5)]);
}
escribir([{type: 'exec.completed', result: {status: 'succeeded'}}]);
assert.deepStrictEqual(extraer(), []);
escribir([{response: 'á漢'}, paso]);
const desde = fs.statSync(registro).size;
fs.appendFileSync(registro, '----- cambio de agente\n' + JSON.stringify(turno) + '\nrota\n');
assert.deepStrictEqual(extraer('--desde', String(desde)), [fila(null, 100, 40, 10, 5)]);
assert.deepStrictEqual(extraer(), [fila('oc', 150, 40, 20, 3, 0.125), fila(null, 100, 40, 10, 5)]);
const resumen = ejecutar('extraer.js', [registro]);
assert(resumen.indexOf('Consumo: oc:') < resumen.indexOf('Respuesta final:'));
escribir([]); assert(ejecutar('extraer.js', [registro]).includes('Consumo: sin datos'));
console.log('Consumo: formatos, totales, caché, costos, bytes y resumen OK');

const home = path.join(tmp, 'codex'), sesiones = path.join(home, 'sessions', '2026', '11');
fs.mkdirSync(sesiones, {recursive: true});
const evento = (input, cache, output, razonamiento) => ({type: 'event_msg', payload: {type: 'token_count', info: {
  total_token_usage: {input_tokens: input, cached_input_tokens: cache, output_tokens: output, reasoning_output_tokens: razonamiento},
  last_token_usage: {input_tokens: 99999}}}});
const limite = {type: 'event_msg', timestamp: new Date().toISOString(), payload: {type: 'token_count', info: null,
  rate_limits: {plan_type: 'team', primary: {used_percent: 13, window_minutes: 300, resets_at: 1796051100},
    secondary: {used_percent: 6, window_minutes: 10080, resets_at: 1796051100}}}};
const eventos = [{type: 'turn_context', payload: {model: 'gpt-uno'}}, evento(1000, 400, 100, 50),
  {type: 'turn_context', payload: {model: 'gpt-dos'}}, evento(1500, 600, 160, 70), evento(1500, 600, 160, 70), limite];
const sesion = path.join(sesiones, 'rollout-prueba.jsonl');
fs.writeFileSync(sesion, eventos.map(e => JSON.stringify(e)).join('\n') + '\nrota\nnull\n');
const log = path.join(tmp, 'consumo.jsonl'), env = {...process.env, CODEX_HOME: home, ORQ_CONSUMO: log};
const fecha = new Date().toISOString();
const entradas = [{fecha, agente: 'agy', modelo: 'flash', codigo: 0, seg: 60, ...fila('flash', 1234, 1000, 100)},
  {fecha, agente: 'agy', codigo: 17, seg: 30, ...fila('flash', 266, 100, 30)},
  {fecha, agente: 'agy', codigo: 0, seg: 30, ...fila('otro', 100, 0, 10, 0, 0.0123)},
  {fecha: '2000-01-01', agente: 'antiguo', codigo: 0, seg: 0, ...fila('viejo', 10, 0, 0)}];
fs.writeFileSync(log, entradas.map(e => JSON.stringify(e)).join('\n') + '\nrota\n');
const salida = ejecutar('consumo.js', [], env);
assert(salida.includes('agy | flash | 2 | 1 | 1.5k | 1.1k | 130 | 0 | — | 1.5'));
assert(salida.includes('agy | TOTAL | 3 | 1 | 1.6k | 1.1k | 140 | 0 | 0.0123 | 2.0'));
assert(salida.includes('gpt-uno | 1 | 1.0k | 400 | 100 | 50'));
assert(salida.includes('gpt-dos | 1 | 500 | 200 | 60 | 20'));
assert(salida.includes('Límite de ChatGPT (plan team): 13 % de la ventana de 5 h (se renueva '));
assert(salida.includes('6 % semanal (se renueva '));
assert(salida.includes('todas las sesiones de Codex de esta PC'));
assert(!salida.includes('antiguo'));
assert(ejecutar('consumo.js', ['todo'], env).includes('antiguo | viejo'));
assert(ejecutar('consumo.js', ['todo'], env).includes('gpt-dos | 1 | 500'));
fs.utimesSync(sesion, new Date('2000-01-01'), new Date('2000-01-01'));
assert(!ejecutar('consumo.js', ['1'], env).includes('gpt-uno | 1'));
assert.strictEqual(ejecutar('consumo.js', [], {...env, ORQ_CONSUMO: 'off'}).trim(), 'Sin registros de consumo en este periodo.');
assert.strictEqual(ejecutar('consumo.js', [], {...env, CODEX_HOME: path.join(tmp, 'ausente'), ORQ_CONSUMO: path.join(tmp, 'ausente.jsonl')}).trim(),
  'Sin registros de consumo en este periodo.');
// Solo se quitan los archivos ficticios creados por esta prueba, dentro del temporal.
fs.unlinkSync(sesion);
for (const dir of [sesiones, path.dirname(sesiones), path.join(home, 'sessions'), home]) fs.rmdirSync(dir);
fs.unlinkSync(log);
console.log('Consumo: agrupación, periodo, diferencias por modelo y límites de Codex OK');
NODE

(
  ORQ_CONFIG=/dev/null source "$DIR_SKILL/scripts/comun.sh" ""
  LOG="$TMP_PRUEBA/registro" AGENTE=prueba MODELO_DEF=defecto MODO=escritura
  unset ID REPO WT
  ORQ_CONSULTA_NOMBRE='consulta "con comillas"'
  ORQ_CONSUMO="$TMP_PRUEBA/consumo.jsonl"
  printf '%s\n' '{"type":"turn.completed","usage":{"input_tokens":100,"output_tokens":10}}' > "$LOG.jsonl"
  registrar_consumo lanzar '' 17 60 0
  registrar_consumo nuevo pedido 0 30 0
  registrar_consumo reintentar pedido 0 5 "$(wc -c < "$LOG.jsonl")"
  node - "$ORQ_CONSUMO" <<'NODE'
const fs = require('fs'), assert = require('assert');
const filas = fs.readFileSync(process.argv[2], 'utf8').trim().split('\n').map(JSON.parse);
assert.strictEqual(filas.length, 3);
assert.strictEqual(filas[0].modelo, 'defecto');
assert.strictEqual(filas[0].id, 'consulta "con comillas"');
assert.strictEqual(filas[0].repo, 'consulta');
assert.strictEqual(filas[0].codigo, 17);
assert.strictEqual(filas[0].seg, 60);
assert.strictEqual(filas[1].modelo, 'pedido');
assert.strictEqual(filas[2].sin_datos, true);
assert.strictEqual(filas[2].entrada, 0);
assert(Number.isFinite(Date.parse(filas[0].fecha)));
NODE
  agente_lanzar() { printf '%s\n' '{"type":"turn.completed","usage":{"input_tokens":7,"output_tokens":2}}'; return 17; }
  vigilar_agente() { return 0; }
  ORQ_CONSUMO=off
  if salida=$(ejecutar_agente lanzar prueba ''); then :; else exit 1; fi
  [[ "$salida" = 'Código de salida: 17 · '* ]]
  ORQ_CONSUMO="$TMP_PRUEBA/consumo.jsonl/no-es-carpeta"
  if fallida=$(ejecutar_agente lanzar prueba ''); then :; else exit 1; fi
  [ "$salida" = "$fallida" ]
  node - "$TMP_PRUEBA/consumo.jsonl" <<'NODE'
const fs = require('fs'), assert = require('assert');
assert.strictEqual(fs.readFileSync(process.argv[2], 'utf8').trim().split('\n').length, 3);
NODE
  ORQ_CONSUMO="$TMP_PRUEBA/consumo.jsonl"
  if salida=$(ejecutar_agente lanzar prueba ''); then :; else exit 1; fi
  node - "$ORQ_CONSUMO" <<'NODE'
const fs = require('fs'), assert = require('assert');
const filas = fs.readFileSync(process.argv[2], 'utf8').trim().split('\n').map(JSON.parse);
assert.strictEqual(filas.length, 4);
assert.strictEqual(filas[3].codigo, 17);
assert.strictEqual(filas[3].entrada, 7);
NODE
  unset ORQ_CONSULTA_NOMBRE
  MODELO_DEF=''
  printf '%s\n' '{"type":"result","stats":{"models":{"uno":{"input_tokens":1},"dos":{"input_tokens":2}}}}' > "$LOG.jsonl"
  registrar_consumo nuevo pedido 0 1 0
  : > "$LOG.jsonl"
  registrar_consumo lanzar '' 0 1 0
  node - "$ORQ_CONSUMO" "$TMP_PRUEBA" <<'NODE'
const fs = require('fs'), path = require('path'), assert = require('assert');
const filas = fs.readFileSync(process.argv[2], 'utf8').trim().split('\n').map(JSON.parse);
assert.deepStrictEqual(filas.slice(4, 6).map(u => u.modelo), ['uno', 'dos']);
assert.strictEqual(filas[6].modelo, 'predeterminado');
assert.strictEqual(filas[6].id, path.basename(process.argv[3]));
NODE
  rm -f "$TMP_PRUEBA/consumo.jsonl" "$LOG.jsonl"
  echo 'Registro: JSON válido, consulta, modelo, sin datos, off y errores silenciosos OK'
)
echo 'Pruebas sin git OK'
