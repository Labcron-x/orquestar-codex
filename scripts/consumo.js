// Consumo registrado por los agentes y por todas las sesiones locales de Codex.
const fs = require('fs'), path = require('path'), os = require('os');
const periodo = process.argv[2] || '7';
if (process.argv.length > 3 || (periodo !== 'todo' && !/^[1-9]\d*$/.test(periodo))) {
  console.error('Uso: orq consumo [días|todo]'); process.exit(2);
}
const desde = periodo === 'todo' ? -Infinity : Date.now() - Number(periodo) * 86400000;
const corto = n => n >= 1e6 ? (n / 1e6).toFixed(1) + 'M' : n >= 1e3 ? (n / 1e3).toFixed(1) + 'k' : String(n);
const numero = n => typeof n === 'number' && Number.isFinite(n) && n >= 0 ? n : 0;
const claves = ['entrada', 'cache', 'salida', 'razonamiento'];
const vacio = () => ({entrada: 0, cache: 0, salida: 0, razonamiento: 0, costo: null, ejec: 0, fallos: 0, seg: 0});
function sumar(total, u) {
  for (const k of [...claves, 'ejec', 'fallos', 'seg']) total[k] += numero(u[k]);
  if (typeof u.costo === 'number' && Number.isFinite(u.costo)) total.costo = (total.costo || 0) + u.costo;
}
function leer(ruta) {
  try { return fs.readFileSync(ruta, 'utf8').split(/\r?\n/).flatMap(l => {
    try { const e = JSON.parse(l); return e && typeof e === 'object' ? [e] : []; } catch { return []; }
  }); } catch { return []; }
}
const agentes = new Map();
const registro = process.env.ORQ_CONSUMO || path.join(os.homedir(), '.local/share/orquestar-codex/consumo.jsonl');
if (registro !== 'off') for (const u of leer(registro)) {
  const fecha = Date.parse(u.fecha);
  if (!Number.isFinite(fecha) || fecha < desde || typeof u.agente !== 'string') continue;
  if (!agentes.has(u.agente)) agentes.set(u.agente, new Map());
  const modelos = agentes.get(u.agente), modelo = u.modelo || 'predeterminado';
  if (!modelos.has(modelo)) modelos.set(modelo, vacio());
  sumar(modelos.get(modelo), {...u, ejec: 1, fallos: Number(u.codigo !== 0)});
}

const codex = new Map();
let limites = null, fechaLimites = -Infinity;
const home = process.env.CODEX_HOME || path.join(os.homedir(), '.codex');
function sesiones(dir) {
  let archivos;
  try { archivos = fs.readdirSync(dir, {withFileTypes: true}); } catch { return; }
  for (const archivo of archivos) {
    const ruta = path.join(dir, archivo.name);
    if (archivo.isDirectory()) { sesiones(ruta); continue; }
    if (!archivo.isFile() || !/^rollout-.*\.jsonl$/.test(archivo.name)) continue;
    let fecha;
    try { fecha = fs.statSync(ruta).mtimeMs; } catch { continue; }
    if (fecha < desde) continue;
    let modelo = '?', anterior = {};
    for (const e of leer(ruta)) {
      const p = e.payload;
      if (!p || typeof p !== 'object') continue;
      if (e.type === 'turn_context') { modelo = p.model || '?'; continue; }
      if (e.type !== 'event_msg' || p.type !== 'token_count') continue;
      const instante = Number.isFinite(Date.parse(e.timestamp)) ? Date.parse(e.timestamp) : fecha;
      if (p.rate_limits && (p.rate_limits.primary || p.rate_limits.secondary) && instante >= fechaLimites) {
        limites = p.rate_limits; fechaLimites = instante;
      }
      const uso = p.info && p.info.total_token_usage;
      if (!uso) continue;
      const u = {};
      for (const [k, origen] of Object.entries({entrada: 'input_tokens', cache: 'cached_input_tokens',
        salida: 'output_tokens', razonamiento: 'reasoning_output_tokens'}))
        u[k] = Math.max(0, numero(uso[origen]) - numero(anterior[origen]));
      anterior = uso;
      if (!claves.some(k => u[k])) continue;
      if (!codex.has(modelo)) codex.set(modelo, {...vacio(), sesiones: new Set()});
      sumar(codex.get(modelo), u); codex.get(modelo).sesiones.add(ruta);
    }
  }
}
sesiones(path.join(home, 'sessions'));

if (!agentes.size && !codex.size && !limites) {
  console.log('Sin registros de consumo en este periodo.'); process.exit(0);
}
console.log('Agentes');
console.log('Agente | Modelo | Ejec. | Fallos (codigo≠0) | Entrada | Caché | Salida | Razon. | Costo US$ | Tiempo (min)');
function fila(agente, modelo, u) {
  console.log([agente, modelo, u.ejec, u.fallos, ...claves.map(k => corto(u[k])),
    u.costo === null ? '—' : u.costo.toFixed(4), (u.seg / 60).toFixed(1)].join(' | '));
}
for (const [agente, modelos] of [...agentes].sort(([a], [b]) => a.localeCompare(b))) {
  const total = vacio();
  for (const [modelo, u] of [...modelos].sort((a, b) => b[1].entrada - a[1].entrada || a[0].localeCompare(b[0]))) {
    fila(agente, modelo, u); sumar(total, u);
  }
  fila(agente, 'TOTAL', total);
}
console.log('\nCodex (orquestador): todas las sesiones de Codex de esta PC modificadas en el periodo.');
console.log('Modelo | Sesiones | Entrada | Caché | Salida | Razon.');
for (const [modelo, u] of [...codex].sort((a, b) => b[1].entrada - a[1].entrada))
  console.log([modelo, u.sesiones.size, ...claves.map(k => corto(u[k]))].join(' | '));
if (limites) {
  const ventanas = ['primary', 'secondary'].flatMap(k => {
    const l = limites[k];
    if (!l || typeof l.used_percent !== 'number') return [];
    const ventana = l.window_minutes === 10080 ? 'semanal' : 'de la ventana de ' +
      (l.window_minutes % 60 === 0 ? l.window_minutes / 60 + ' h' : l.window_minutes + ' min');
    const fecha = new Date(l.resets_at * 1000), dos = n => String(n).padStart(2, '0');
    const hora = Number.isFinite(fecha.getTime()) ? (l.window_minutes >= 1440 ?
      dos(fecha.getDate()) + '/' + dos(fecha.getMonth() + 1) + ' ' : '') +
      dos(fecha.getHours()) + ':' + dos(fecha.getMinutes()) : '?';
    return [`${l.used_percent} % ${ventana} (se renueva ${hora})`];
  });
  if (ventanas.length) console.log(`Límite de ChatGPT (plan ${limites.plan_type || '?'}): ${ventanas.join(' · ')}`);
}
