# OpenCode con modelos gratis de OpenCode Zen.
BIN=$(command -v opencode)
MODELO_DEF=${OPENCODE_MODELO:-opencode/big-pickle}
ESCALA=${OPENCODE_ESCALA:-"opencode/big-pickle opencode/deepseek-v4.1-flash-free opencode/glm-5.3-flash-free opencode/nemotron-3-ultra-free"}
INSTALAR="npm i -g opencode-ai"
LOGIN="opencode auth login (opcional: los modelos opencode/* gratis no lo piden)"
FUERTE="comandos libres (instalar, generar, migraciones), pruebas, docs, investigación (Tavily/Context7), revisión"

# --agent build trabaja directo; el agente orchestrator subdelega en modelos de pago y falla.
agente_lanzar() {
  local tipo=build flags=()
  if [ "${MODO:-escritura}" = lectura ]; then tipo=plan
  else read -r -a flags <<< "${OPENCODE_FLAGS:-}"; fi
  opencode run "${flags[@]}" --agent "$tipo" -m "$2" --format json "$1" < /dev/null
}
agente_reintentar() {
  local tipo=build flags=()
  if [ "${MODO:-escritura}" = lectura ]; then tipo=plan
  else read -r -a flags <<< "${OPENCODE_FLAGS:-}"; fi
  opencode run "${flags[@]}" --agent "$tipo" -m "$2" ${3:+-s "$3"} --format json "$1" < /dev/null
}
agente_modelos() { opencode models opencode; }
