#!/usr/bin/env bash
# Pruebas sin git, instalaciones ni agentes reales. Uso: bash scripts/probar-cx3.sh
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
  if (lectura) assert.strictEqual(args[args.indexOf('--append-system-prompt-file') + 1], skill + '/agentes/solo-lectura.txt');
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
for opciones in '' '--documentos' '--documentos --sin-programas'; do
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
const documentos = opciones.includes('--documentos');
assert(log.includes('npm i -g @qoder-ai/qodercli'));
assert(log.includes('npm i -g @minimax-ai/code'));
assert.strictEqual(log.includes('-m pip install'), documentos);
assert.strictEqual(log.includes('winget'), documentos && !opciones.includes('--sin-programas'));
const config = log.split('\n').find(l => l.includes('configurar-agentes.js'));
assert(config);
assert.strictEqual(config.includes('--documentos'), documentos);
NODE
done
echo 'Instalador: documentos opcionales y --sin-programas OK (sin instalaciones reales)'
echo 'Pruebas CX-3 sin git OK'
