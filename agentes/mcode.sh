# MiniMax Code. No tiene sandbox: smart aprueba escrituras y borrados sin preguntar.
BIN=${MCODE_CLI:-$(command -v mcode || echo "$HOME/.minimax-code/bin/mcode")}
MODELO_DEF=${MCODE_MODELO:-}
ESCALA=""
INSTALAR="npm i -g @minimax-ai/code"
LOGIN="mcode login (o mcode login --region global)"
FUERTE="código con MiniMax; sin sandbox, smart aprueba escrituras y borrados sin preguntar"

agente_lanzar() {
  local lectura=()
  [ "${MODO:-escritura}" != lectura ] || lectura=(--append-system-prompt-file "$DIR_SKILL/agentes/solo-lectura.txt")
  "$BIN" exec --input - --output-format stream-json --permission smart ${2:+--model "$2"} \
    ${MCODE_ESFUERZO:+--effort "$MCODE_ESFUERZO"} "${lectura[@]}" <<< "$1"
}
agente_reintentar() {
  local lectura=()
  [ "${MODO:-escritura}" != lectura ] || lectura=(--append-system-prompt-file "$DIR_SKILL/agentes/solo-lectura.txt")
  "$BIN" exec --input - --output-format stream-json --permission smart ${2:+--model "$2"} \
    ${MCODE_ESFUERZO:+--effort "$MCODE_ESFUERZO"} ${3:+--session "$3"} "${lectura[@]}" <<< "$1"
}
agente_modelos() { echo 'MiniMax Code: usa --model minimax/<modelo> de tu cuenta.'; }
