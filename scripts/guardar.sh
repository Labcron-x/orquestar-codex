#!/usr/bin/env bash
# Uso: guardar.sh "<mensaje>" [rutas...]   Desde el repo.
set -eu
source "$(dirname "$0")/comun.sh" ""
MENSAJE=${1:?Uso: guardar.sh "<mensaje>" [rutas...]}
shift
cd "$(git rev-parse --show-toplevel)" || exit 2
if [ $# -eq 0 ]; then
  for ruta in docs/agentes AGENTS.md; do
    [ ! -e "$ruta" ] || set -- "$@" "$ruta"
  done
fi
[ $# -eq 0 ] || git add -- "$@"
if git diff --cached --quiet; then
  echo "Nada que guardar."
  if git rev-parse --verify HEAD >/dev/null 2>&1; then git log -1 --oneline; fi
  exit 0
fi
git commit -m "$MENSAJE"
git log -1 --oneline
