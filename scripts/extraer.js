// Lee el registro de cualquier agente (agy, OpenCode, Gemini CLI, Qwen, Qoder, MiniMax Code, Codex).
// Uso: node extraer.js <registro> [--sesion | --respuesta | --uso [--desde <bytes>]]
const fs = require("fs");
const [, , ruta, modo] = process.argv;
let texto = "";
if (fs.existsSync(ruta)) {
  const desde = modo === "--uso" && process.argv.includes("--desde")
    ? Number(process.argv[process.argv.indexOf("--desde") + 1]) : 0;
  if (!Number.isSafeInteger(desde) || desde < 0) throw new Error("Byte inicial inválido");
  const fd = fs.openSync(ruta, "r");
  try {
    const buffer = Buffer.alloc(Math.max(0, fs.fstatSync(fd).size - desde));
    const leidos = fs.readSync(fd, buffer, 0, buffer.length, desde);
    texto = buffer.toString("utf8", 0, leidos);
  } finally { fs.closeSync(fd); }
}

const numero = n => typeof n === "number" && Number.isFinite(n) && n >= 0 ? n : 0;
const costo = n => typeof n === "number" && Number.isFinite(n) && n >= 0 ? n : null;
const usos = new Map();
let modelo = null, incrementales = [], totales = [];
function cerrarUso() {
  for (const u of totales.length ? totales : incrementales) {
    const previo = usos.get(u.modelo);
    if (!previo) usos.set(u.modelo, {...u});
    else {
      for (const k of ["entrada", "cache", "salida", "razonamiento"]) previo[k] += u[k];
      if (u.costo !== null) previo.costo = (previo.costo || 0) + u.costo;
    }
  }
  incrementales = []; totales = []; modelo = null;
}
function uso(e) {
  if (!e || typeof e !== "object") return;
  if (Array.isArray(e)) return e.forEach(uso);
  const vigente = e.event === "init" && e.init ? e.init.model
    : e.type === "init" || (e.type === "system" && e.subtype === "init") ? e.model
    : e.type === "assistant" && e.message ? e.message.model : null;
  if (typeof vigente === "string" && vigente) modelo = vigente;
  const m = e.model || e.modelID || (e.part && (e.part.model || e.part.modelID)) || modelo;
  const agregar = (lista, u, mod = m, extra = 0, cache = u.cache_read_input_tokens, coste = null) => lista.push({
    modelo: typeof mod === "string" ? mod : null,
    entrada: numero(u.input_tokens) + extra, cache: numero(cache), salida: numero(u.output_tokens),
    razonamiento: numero(u.reasoning_output_tokens ?? u.thinking_tokens), costo: costo(coste)
  });
  if (e.type === "step_finish" && e.part && e.part.tokens) {
    const t = e.part.tokens, c = t.cache || {};
    agregar(incrementales, {input_tokens: t.input, output_tokens: t.output, reasoning_output_tokens: t.reasoning},
      m, numero(c.read) + numero(c.write), c.read, e.part.cost);
  } else if (e.event === "result" && e.result && e.result.usage) {
    agregar(totales, e.result.usage, m, 0, e.result.usage.cache_read_tokens);
  } else if (e.type === "result" && e.stats) {
    const modelos = e.stats.models;
    for (const [nombre, u] of modelos && Object.keys(modelos).length ? Object.entries(modelos) : [[m, e.stats]])
      agregar(totales, u, nombre, 0, u.cached);
  } else if (e.type === "result" && e.usage) {
    const u = e.usage;
    agregar(totales, u, m, numero(u.cache_read_input_tokens) + numero(u.cache_creation_input_tokens),
      u.cache_read_input_tokens, e.total_cost_usd);
  } else if (e.type === "turn.completed" && e.usage) {
    agregar(incrementales, e.usage, m, 0, e.usage.cached_input_tokens);
  } else if (e.type === "exec.completed") {
    const u = e.usage || (e.result && e.result.usage);
    if (u) agregar(totales, u, m, numero(u.cache_read_input_tokens) + numero(u.cache_creation_input_tokens),
      u.cached_input_tokens ?? u.cache_read_tokens ?? u.cache_read_input_tokens,
      e.total_cost_usd ?? (e.result && e.result.total_cost_usd));
  }
}
for (const linea of texto.split(/\r?\n/)) {
  if (linea.startsWith("----- cambio de agente")) {
    // En --uso manda el tramo de bytes; el resumen conserva los intentos de cada agente.
    if (modo !== "--uso") cerrarUso();
  }
  else { try { uso(JSON.parse(linea)); } catch {} }
}
cerrarUso();
if (modo === "--uso") { console.log(JSON.stringify([...usos.values()])); process.exit(0); }

let respuesta = "", sesion = "";
const denegadas = [], errores = [], comandos = [];

function visitar(e) {
  if (!e || typeof e !== "object") return;
  if (Array.isArray(e)) return e.forEach(visitar);
  // Sesión: agy conversation_id, OpenCode sessionID, MiniMax sessionId, Gemini/Qwen/Qoder session_id, Codex thread_id.
  for (const k of ["conversation_id", "sessionID", "sessionId", "session_id", "thread_id"])
    if (typeof e[k] === "string" && e[k]) sesion = e[k];
  // Respuesta final.
  if (e.event === "result" && e.result) {
    if (e.result.response) respuesta = e.result.response;
    (e.result.denied_actions || []).forEach(d => denegadas.push(d.display_name || d.action));
  }
  if (e.type === "text" && e.part && e.part.text) respuesta = e.part.text;              // OpenCode
  if (typeof e.response === "string" && e.response) respuesta = e.response;            // Gemini CLI / Qwen
  if (e.type === "result" && typeof e.result === "string") respuesta = e.result;        // resultado stream-json
  if (e.item && e.item.type === "agent_message" && e.item.text) respuesta = e.item.text; // Codex
  if (e.type === "item.completed" && e.item && e.item.type === "agent_message" && typeof e.item.content === "string")
    respuesta = e.item.content; // MiniMax Code
  if (e.type === "exec.completed" && e.result) {
    if (typeof e.result.output === "string" && e.result.output) respuesta = e.result.output;
    if (e.result.status !== "succeeded")
      errores.push("MiniMax Code: " + (e.result.status || "sin estado") + (e.result.error ? ": " + (typeof e.result.error === "string" ? e.result.error : JSON.stringify(e.result.error)) : ""));
  }
  if (e.type === "assistant" && e.message && Array.isArray(e.message.content))
    e.message.content.forEach(c => c.type === "text" && c.text && (respuesta = c.text));
  // Comandos y errores.
  const cmd = (e.tool_info && e.tool_info.parameters && e.tool_info.parameters.CommandLine)
    || (e.part && e.part.state && e.part.state.input && e.part.state.input.command)
    || (e.item && e.item.type === "command_execution" && e.item.command);
  if (cmd) comandos.push(String(cmd));
  if (e.part && e.part.state && e.part.state.status === "error") errores.push(String(e.part.state.error));
  if (e.type === "error" && e.message) errores.push(String(e.message));
  if (e.error && typeof e.error === "object" && e.error.message) errores.push(String(e.error.message));
}

const lineas = texto.split(/\r?\n/);
let algunJson = false;
for (const l of lineas) {
  const t = l.trim();
  if (!t) continue;
  if (t.startsWith("----- cambio de agente")) {  // solo cuenta el último agente; los comandos (push) se conservan
    respuesta = ""; sesion = ""; denegadas.length = 0; errores.length = 0; continue;
  }
  if (t.startsWith("{") || t.startsWith("[")) {
    try { visitar(JSON.parse(t)); algunJson = true; continue; } catch {}
  }
  if (/error|denied|timeout|quota|rate.?limit|unauthori[sz]ed|login/i.test(t)) errores.push(t);
}
if (!algunJson) { try { visitar(JSON.parse(texto)); algunJson = true; } catch {} }
if (!respuesta && !algunJson) respuesta = texto.trim().slice(-1500);

if (modo === "--sesion") { process.stdout.write(sesion); process.exit(0); }
if (modo === "--respuesta") {
  const errs = [...new Set(errores)].slice(-3);
  process.stdout.write((respuesta || "").trim() || (errs.length ? "ERROR del agente:\n" + errs.join("\n") : "(sin respuesta)"));
  process.exit(0);
}

const pushes = [...new Set(comandos.filter(c => /\bgit\s+push\b/.test(c)))];
console.log("Sesión: " + (sesion || "?"));
console.log("Denegadas: " + (denegadas.length ? denegadas.join(", ") : "ninguna"));
if (pushes.length) console.log("ALERTA: el agente intentó publicar: " + pushes.join(" | "));
const unicos = [...new Set(errores.map(x => x.slice(0, 300)))];
if (unicos.length) console.log("Errores:\n  " + unicos.slice(-5).join("\n  "));
const corto = n => n >= 1e6 ? (n / 1e6).toFixed(1) + "M" : n >= 1e3 ? (n / 1e3).toFixed(1) + "k" : String(n);
if (!usos.size) console.log("Consumo: sin datos");
for (const u of usos.values()) console.log(`Consumo: ${u.modelo || "?"}: ${corto(u.entrada)} entrada (${corto(u.cache)} caché) · ${corto(u.salida)} salida · ${corto(u.razonamiento)} razonamiento${u.costo === null ? "" : " · US$" + u.costo.toFixed(4)}`);
console.log("Respuesta final:\n  " + ((respuesta || "(vacía)").trim().slice(-1500).replace(/\n/g, "\n  ")));
