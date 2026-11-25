#!/usr/bin/env bash
# Uso: orq consumo [días|todo]. Por defecto, los últimos 7 días.
source "$(dirname "$0")/comun.sh" ""
export ORQ_CONSUMO CODEX_HOME
exec node "$DIR_SCRIPTS/consumo.js" "$@"
