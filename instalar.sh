#!/usr/bin/env bash
# Instala la skill orquestar-codex para una persona del equipo. Se corre en su propia terminal (bash / Git Bash):
#
#   git clone <url> ~/.codex/skills/orquestar-codex
#   bash ~/.codex/skills/orquestar-codex/instalar.sh [--agentes "agy opencode gemini-cli qwen"] [--sin-programas]
# Si defines CODEX_HOME, clona en "$CODEX_HOME/skills/orquestar-codex".
#
# Hace: instala los CLI de agentes que falten, las librerías de documentos (Python) y LibreOffice/pandoc,
# configura en cada CLI los MCP (Playwright, Chrome DevTools, markitdown, Context7), las reglas deny y la skill de documentos,
# y crea tu config personal. Respalda cada archivo que toca como *.bak-orq. Se puede correr varias veces.
set -u
DIR_SKILL=$(cd "$(dirname "$0")" && pwd)
AGENTES="opencode gemini-cli"
PROGRAMAS=1
while [ $# -gt 0 ]; do
  case $1 in
    --agentes) [ $# -ge 2 ] || { echo 'Falta el valor de --agentes'; exit 2; }; AGENTES=$2; shift 2 ;;
    --sin-programas) PROGRAMAS=0; shift ;;
    *) echo "Opción desconocida: $1"; exit 2 ;;
  esac
done
for a in $AGENTES; do
  case $a in agy|opencode|gemini-cli|qwen) ;;
    *) echo "Agente desconocido: $a. Disponibles: agy opencode gemini-cli qwen"; exit 2 ;;
  esac
done
paso() { printf '\n\033[1m▸ %s\033[0m\n' "$1"; }
falta() { ! command -v "$1" >/dev/null 2>&1; }

paso "Requisitos"
for c in git node npm; do falta $c && { echo "Falta $c: instálalo y vuelve a correr."; exit 2; }; done
PY=$(command -v python || command -v python3) || { echo "Falta Python 3: instálalo y vuelve a correr."; exit 2; }
echo "git, node, npm y $("$PY" --version) listos."

ESPERADO=${CODEX_HOME:-$HOME/.codex}/skills/orquestar-codex
if [ "$(cd "$ESPERADO" 2>/dev/null && pwd)" != "$DIR_SKILL" ]; then
  echo "AVISO: la skill debe quedar en $ESPERADO (está en $DIR_SKILL)."
fi

paso "Orquestador: Codex CLI"
if falta codex; then
  echo "FALTA codex: npm i -g @openai/codex"
  npm i -g @openai/codex || exit 3
fi

paso "CLI de agentes: $AGENTES"
for a in $AGENTES; do
  case $a in
    opencode)   falta opencode && npm i -g opencode-ai ;;
    gemini-cli) falta gemini && npm i -g @google/gemini-cli ;;
    qwen)       falta qwen && npm i -g @qwen-code/qwen-code ;;
    agy)        falta agy && falta agy.exe && echo "agy: instala Antigravity CLI desde la web de Google Antigravity (no va por npm)." ;;
  esac
done

paso "Librerías de documentos (Python)"
"$PY" -m pip install -q pypdf pdfplumber reportlab python-docx openpyxl pandas python-pptx \
  "markitdown[all]" markitdown-mcp && echo "Listas."

if [ $PROGRAMAS = 1 ]; then
  paso "LibreOffice y pandoc"
  if command -v winget >/dev/null; then
    for id in TheDocumentFoundation.LibreOffice JohnMacFarlane.Pandoc; do
      winget list --id $id -e >/dev/null 2>&1 || winget install --id $id -e --silent --accept-package-agreements --accept-source-agreements
    done
  elif command -v brew >/dev/null; then
    falta soffice && brew install --cask libreoffice; falta pandoc && brew install pandoc
  else
    echo "Instálalos con tu gestor de paquetes (p. ej. sudo apt install libreoffice pandoc poppler-utils)."
  fi
fi

paso "Configurar los agentes (MCP, reglas deny, skill de documentos)"
node "$DIR_SKILL/scripts/configurar-agentes.js" "$DIR_SKILL"

paso "Config personal"
CONFIG=${ORQ_CONFIG:-$HOME/.config/orquestar-codex/config}
if [ -f "$CONFIG" ]; then echo "Ya existe: $CONFIG"
else mkdir -p "$(dirname "$CONFIG")" && cp "$DIR_SKILL/config.ejemplo" "$CONFIG" && echo "Creada: $CONFIG (revisa la sección de permisos)"; fi
command -v setx >/dev/null && setx PYTHONUTF8 1 >/dev/null 2>&1

paso "Skills del equipo (skills/*)"
bash "$DIR_SKILL/scripts/instalar-skills.sh"

paso "Estado"
bash "$DIR_SKILL/scripts/agentes.sh"
cat <<'EOF'

Falta solo iniciar sesión una vez en cada CLI que vayas a usar (en tu terminal):
  opencode auth login   (opcional: los modelos opencode/* gratis no lo piden)
  gemini                (en la carpeta que contiene tus repos: Login with Google + Trust parent folder)
  qwen                  (opcional y de pago: QwenCloud o Third-party con API key)
  codex login           (cuenta de ChatGPT)
  agy                   (cuenta de Google)
Después abre Codex con acceso completo:
  codex --sandbox danger-full-access
  o selecciona "Acceso completo" en la app.
Escribe: $orquestar-codex <lo que quieres hacer>
EOF
