# Variables y funciones comunes. Uso: source comun.sh [ID]   (desde un repo git, salvo consultar.sh)
DIR_SCRIPTS=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
DIR_SKILL=$(dirname "$DIR_SCRIPTS")
CONFIG=${ORQ_CONFIG:-$HOME/.config/orquestar-codex/config}
[ -f "$CONFIG" ] && source "$CONFIG"

# Nombres viejos o cortos → adaptador en agentes/.
normalizar_agente() {
  case $1 in
    gemini|antigravity) echo agy ;;
    oc) echo opencode ;;
    gcli|gemini_cli) echo gemini-cli ;;
    qodercli|qoder-cli) echo qoder ;;
    minimax|minimax-code) echo mcode ;;
    *) echo "$1" ;;
  esac
}

cargar_agente() {  # <nombre>
  AGENTE=$(normalizar_agente "$1")
  local f="$DIR_SKILL/agentes/$AGENTE.sh"
  [ -f "$f" ] || { echo "Agente desconocido: $1. Disponibles: $(ls "$DIR_SKILL/agentes" | sed 's/\.sh$//' | tr '\n' ' ')"; return 2; }
  BIN=""; MODELO_DEF=""; ESCALA=""
  source "$f"
  [ -n "$BIN" ] && { [ -x "$BIN" ] || command -v "$BIN" >/dev/null; } || {
    echo "$AGENTE no está instalado. Instalar: $INSTALAR · Luego: $LOGIN"; return 3; }
}

# Los PID de fondo son nativos en Windows (Start-Process), y de bash en Unix.
fondo_vivo() {  # <ruta sin extensión>
  local pid
  pid=$(cat "$1.pid" 2>/dev/null) || return 1
  [[ "$pid" =~ ^[1-9][0-9]*$ ]] || return 1
  case $OSTYPE in
    msys*|cygwin*) ORQ_PID="$pid" powershell.exe -NoProfile -Command 'if (Get-Process -Id $env:ORQ_PID -ErrorAction SilentlyContinue) { exit 0 } else { exit 1 }' >/dev/null 2>&1 ;;
    *) kill -0 "$pid" 2>/dev/null ;;
  esac
}

# Siguiente modelo de la escala del agente (para "+").
siguiente_modelo() {  # <modelo actual>
  local m siguiente=0
  for m in $ESCALA; do
    [ $siguiente = 1 ] && { echo "$m"; return; }
    [ "$m" = "$1" ] && siguiente=1
  done
  [ $siguiente = 1 ] && echo "TOPE" || echo "${ESCALA%% *}"
}

if [ -n "${1:-}" ]; then
  ID=$1
  RAIZ=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null | sed 's#/\.git$##')
  [ -n "$RAIZ" ] || { echo "No estás en un repo git (para preguntas sin repo usa consultar.sh)"; exit 2; }
  REPO=$(basename "$RAIZ")
  MARCA="[orq-codex $REPO/$ID]"
  PADRE=$(dirname "$RAIZ")
  WT="$PADRE/wt-$REPO-$ID"
  LOG="$PADRE/$REPO-$ID"
  TAREA="docs/agentes/tareas/$ID.md"
  REPORTE="docs/agentes/reportes/$ID.md"
  [ -z "${SIN_META:-}" ] && [ -f "$LOG.meta" ] && source "$LOG.meta"
fi

# El modo guardado se conserva al reintentar; ORQ_MODO lo puede forzar.
determinar_modo() {
  MODO=${ORQ_MODO:-${MODO:-}}
  if [ -z "$MODO" ]; then
    MODO=escritura
    if [[ "$ID" = REV-* || "$ID" = INV-* ]] || grep -qxE '\*\*Modo:\*\* lectura[[:space:]]*' "$RAIZ/$TAREA"; then
      MODO=lectura
    fi
  fi
  case $MODO in lectura|escritura) export MODO ;;
    *) echo "Modo inválido: $MODO (usa lectura o escritura)."; return 2 ;;
  esac
}

# El agente no debe publicar nada: los remotos del worktree apuntan a una URL que no existe.
# (agy con --dangerously-skip-permissions ignora su lista deny; esto lo frena igual.)
bloquear_push() {
  git -C "$RAIZ" config extensions.worktreeConfig true
  local r
  for r in $(git -C "$WT" remote); do
    git -C "$WT" config --worktree "remote.$r.pushurl" "no-push://bloqueado-por-el-orquestador"
  done
}

# Commit de lo que el agente dejó sin commit.
commit_pendiente() {
  if [ "${MODO:-escritura}" = lectura ]; then
    local cambios cabeza archivos
    cambios=$(git -C "$WT" status --porcelain) || return 1
    cabeza=$(git -C "$WT" rev-parse HEAD) || return 1
    if [ "$cabeza" != "$LECTURA_HEAD" ]; then
      archivos=$(git -C "$WT" diff --name-only "$LECTURA_HEAD" "$cabeza") || return 1
      cambios="${cambios}${cambios:+$'\n'}commits: ${archivos:-sin cambios de archivos} (HEAD cambió: $LECTURA_HEAD → $cabeza)"
    fi
    if [ -n "$cambios" ]; then
      printf 'ALERTA: modo lectura violado: %s\n' "${cambios//$'\n'/; }" | tee -a "$LOG.jsonl"
    fi
    mkdir -p "$WT/$(dirname "$REPORTE")" || return 1
    node "$DIR_SCRIPTS/extraer.js" "$LOG.jsonl" --respuesta > "$WT/$REPORTE" || return 1
    git -C "$WT" add -- "$REPORTE" || return 1
    if ! git -C "$WT" diff --cached --quiet -- "$REPORTE"; then
      git -C "$WT" commit -q -m "docs(agentes): $ID reporte de lectura" -- "$REPORTE" || return 1
    fi
    return 0
  fi
  [ -z "$(git -C "$WT" status --porcelain)" ] && return 0
  git -C "$WT" add -A
  git -C "$WT" commit -q -m "chore(agentes): $ID cambios de ${AGENTE:-agente} (${MODELO:-por defecto})" \
    && echo "Commit automático de lo pendiente." || echo "AVISO: falló el commit automático (¿hooks?)."
}

# Vigilante sin tokens: cada ORQ_VIGILAR_SEG (300 s) mira si el registro del agente creció.
# Si no crece en ORQ_VIGILAR_CICLOS revisiones seguidas (2 → 10 min), o el registro muestra un
# bloqueo conocido (sin créditos o cuota), corta el agente y deja ALERTA.
procesos_de_tarea() {  # <ID> → PIDs de Windows con la marca de este orquestador, repo y tarea.
  ORQ_MARCA="[orq-codex $REPO/$1]" powershell.exe -NoProfile -Command 'Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -match [regex]::Escape($env:ORQ_MARCA) -and $_.Name -ne "powershell.exe" } | ForEach-Object { $_.ProcessId }' 2>/dev/null | tr -d '\r'
}
detener_agente() {  # <pid de bash> [ID]: en Windows se busca el exe del agente por la marca.
  local wp
  if [ -n "${2:-}" ] && command -v powershell.exe >/dev/null; then
    for wp in $(procesos_de_tarea "$2"); do taskkill //F //T //PID "$wp" >/dev/null 2>&1; done
  fi
  wp=$(cat "/proc/$1/winpid" 2>/dev/null) && taskkill //F //T //PID "$wp" >/dev/null 2>&1
  pkill -P "$1" 2>/dev/null; kill "$1" 2>/dev/null
}
vigilar_agente() {  # <pid> <registro> [bytes previos: solo se revisa lo que escribe este intento]
  local pid=$1 log=$2 desde=$(( ${3:-0} + 1 )) seg=${ORQ_VIGILAR_SEG:-300} ciclos=${ORQ_VIGILAR_CICLOS:-2}
  local previo=-1 quietos=0 t=0 tam motivo="" patron
  # Por partes: leer este código no debe confundirse con un bloqueo real del agente.
  patron="out of ""credits|quota ""exceeded|quota ""reached|RESOURCE_""EXHAUSTED|insufficient_""quota|usage ""limit|limit_""exceeded"
  while kill -0 "$pid" 2>/dev/null; do
    sleep 15; t=$((t + 15))
    if tail -c +"$desde" "$log" 2>/dev/null | grep -qiE "$patron"; then
      motivo="bloqueo conocido: $(tail -c +"$desde" "$log" | grep -oiE "$patron" | head -1)"
    elif [ $t -ge "$seg" ]; then
      t=0; tam=$(wc -c < "$log" 2>/dev/null || echo 0)
      if [ "$tam" -eq "$previo" ]; then quietos=$((quietos + 1)); else quietos=0; fi
      previo=$tam
      [ $quietos -ge "$ciclos" ] && motivo="sin actividad en el registro por $((seg * ciclos)) s"
    fi
    if [ -n "$motivo" ]; then
      echo "ALERTA: agente colgado ($motivo). Detenido por el vigilante." | tee -a "$log"
      detener_agente "$pid" "${ID:-}"; return 1
    fi
  done
}

ejecutar_agente() {  # <lanzar|nuevo|reintentar> <prompt> <modelo> [sesión] → salida a "$LOG.jsonl"
  local inicio=$SECONDS pid estado previo=0        # nuevo = sesión nueva (otro agente) agregada al mismo registro
  if [ "${MODO:-escritura}" = lectura ] && [ -n "${WT:-}" ]; then
    LECTURA_HEAD=$(git -C "$WT" rev-parse HEAD) || return 1
  fi
  if [ "$1" != lanzar ] && [ -f "$LOG.jsonl" ]; then previo=$(wc -c < "$LOG.jsonl"); fi
  case $1 in
    lanzar) agente_lanzar "$2" "$3" > "$LOG.jsonl" 2>&1 & ;;
    nuevo) agente_lanzar "$2" "$3" >> "$LOG.jsonl" 2>&1 & ;;
    *) agente_reintentar "$2" "$3" "${4:-}" >> "$LOG.jsonl" 2>&1 & ;;
  esac
  pid=$!
  if vigilar_agente "$pid" "$LOG.jsonl" "$previo"; then wait "$pid"; estado=$?; else wait "$pid" 2>/dev/null; estado=124; fi
  echo "Código de salida: $estado · $(( (SECONDS - inicio) / 60 )) min"
}
