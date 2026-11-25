#!/usr/bin/env bash
# Verificación local mínima: sintaxis bash y Node, ShellCheck (solo errores) si está instalado, y que los agentes carguen.
# Uso: bash scripts/verificar.sh
set -u
cd "$(dirname "$0")/.." || exit 2
fallo=0
for f in instalar.sh scripts/*.sh agentes/*.sh; do bash -n "$f" || { echo "Sintaxis bash: $f"; fallo=1; }; done
for f in scripts/*.js; do node --check "$f" || { echo "Sintaxis Node: $f"; fallo=1; }; done
if command -v shellcheck >/dev/null 2>&1; then shellcheck -s bash -S error instalar.sh scripts/*.sh agentes/*.sh || fallo=1
else echo "(shellcheck no instalado: se omite)"; fi
ORQ_CONFIG=/dev/null bash scripts/agentes.sh >/dev/null || { echo "agentes.sh falló"; fallo=1; }
[ $fallo = 0 ] && echo "Verificación OK" || { echo "Verificación con errores"; exit 1; }
