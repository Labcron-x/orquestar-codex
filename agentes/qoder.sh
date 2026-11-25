# Qoder CLI; el modelo vacío usa el de Qoder.
BIN=$(command -v qodercli)
MODELO_DEF=${QODER_MODELO:-}
ESCALA=${QODER_ESCALA:-}
INSTALAR="npm i -g @qoder-ai/qodercli"
LOGIN="qodercli login (o QODER_PERSONAL_ACCESS_TOKEN)"
FUERTE="código y revisión con el modo plan de Qoder"

agente_lanzar() {
  local modo=${QODER_PERMISOS:-auto}
  [ "${MODO:-escritura}" != lectura ] || modo=plan
  qodercli --output-format stream-json --permission-mode "$modo" ${2:+--model "$2"} -p "$1" < /dev/null
}
agente_reintentar() {
  local modo=${QODER_PERMISOS:-auto}
  [ "${MODO:-escritura}" != lectura ] || modo=plan
  qodercli --output-format stream-json --permission-mode "$modo" ${2:+--model "$2"} ${3:+--resume "$3"} -p "$1" < /dev/null
}
agente_modelos() { qodercli --list-models < /dev/null; }
