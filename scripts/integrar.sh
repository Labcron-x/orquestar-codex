#!/usr/bin/env bash
# Uso: integrar.sh <ID> [--sin-limpiar]   Desde la rama base.
set -eu
source "$(dirname "$0")/comun.sh" "${1:?Uso: integrar.sh <ID> [--sin-limpiar]}"
[ $# -le 2 ] && [ "${2:---sin-limpiar}" = --sin-limpiar ] || { echo 'Uso: integrar.sh <ID> [--sin-limpiar]'; exit 2; }
ACTUAL=$(git -C "$RAIZ" symbolic-ref --short HEAD) || exit 2
if [ -f "$LOG.meta" ]; then BASE=${BASE:-$ACTUAL}; else BASE=$ACTUAL; fi
[ "$ACTUAL" = "$BASE" ] || { echo "Debes estar en la rama base: $BASE (actual: $ACTUAL)."; exit 2; }
git -C "$RAIZ" diff --quiet && git -C "$RAIZ" diff --cached --quiet || {
  echo "Hay cambios con seguimiento sin commit. Guárdalos antes de integrar."; exit 2;
}
[ -f "$RAIZ/$TAREA" ] || { echo "Falta $TAREA"; exit 2; }
TITULO=$(head -1 "$RAIZ/$TAREA")
TITULO=${TITULO%$'\r'}
TITULO=${TITULO#"# $ID — "}
if ! git -C "$RAIZ" merge --no-ff "agente/$ID" -m "Merge agente/$ID: $TITULO"; then
  echo "No se pudo integrar $ID. Archivos en conflicto:"
  git -C "$RAIZ" diff --name-only --diff-filter=U
  if git -C "$RAIZ" rev-parse -q --verify MERGE_HEAD >/dev/null; then
    git -C "$RAIZ" merge --abort || { echo "No se pudo abortar el merge."; exit 1; }
  fi
  exit 1
fi
[ "${2:-}" = --sin-limpiar ] || bash "$DIR_SCRIPTS/limpiar.sh" "$ID"
git -C "$RAIZ" log -1 --oneline
