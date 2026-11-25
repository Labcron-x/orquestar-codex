#!/usr/bin/env bash
# Espera sin tokens y muestra una sola vez cada resultado, salvo si se pide su clave.
# Uso: esperar-fondo.sh [clave...] [--max SEG] [--todas]
set -u
source "$(dirname "$0")/comun.sh" ""
FONDO=${ORQ_FONDO:-$HOME/.cache/orquestar-codex/fondo}
max=540; todas=0; claves=()
while [ $# -gt 0 ]; do
  case $1 in
    --max)
      [ $# -ge 2 ] && [[ "$2" =~ ^[0-9]+$ ]] || { echo 'Uso: --max SEG (entero no negativo)'; exit 2; }
      max=$((10#$2)); shift 2 ;;
    --todas) todas=1; shift ;;
    --*) echo "Opción desconocida: $1"; exit 2 ;;
    *)
      [[ -n "$1" && "$1" != */* && "$1" != *\\* && "$1" != .* ]] || { echo "Clave inválida: $1"; exit 2; }
      # No repite una clave pasada dos veces.
      repetida=0
      for clave in "${claves[@]}"; do [ "$clave" = "$1" ] && repetida=1; done
      [ "$repetida" = 1 ] || claves+=("$1")
      shift ;;
  esac
done
if [ ${#claves[@]} -eq 0 ]; then
  for archivo in "$FONDO"/*.inicio; do
    [ -f "$archivo" ] || continue
    registro=${archivo%.inicio}
    [ -f "$registro.informada" ] || claves+=("$(basename "$registro")")
  done
fi
[ ${#claves[@]} -gt 0 ] || { echo 'No hay nada pendiente.'; exit 2; }
for clave in "${claves[@]}"; do
  [ -f "$FONDO/$clave.inicio" ] || { echo "No existe la clave: $clave"; exit 2; }
done

inicio=$SECONDS
while :; do
  terminadas=0; pendientes=0
  for clave in "${claves[@]}"; do
    registro=$FONDO/$clave
    if [ ! -f "$registro.fin" ] && ! fondo_vivo "$registro"; then
      echo 125 > "$registro.fin"
    fi
    if [ -f "$registro.fin" ]; then terminadas=$((terminadas + 1)); else pendientes=$((pendientes + 1)); fi
  done
  [ "$todas" = 0 ] && [ "$terminadas" -gt 0 ] && break
  [ "$pendientes" = 0 ] && break
  restante=$((max - (SECONDS - inicio)))
  [ "$restante" -gt 0 ] || break
  [ "$restante" -gt 5 ] && restante=5
  sleep "$restante"
done

ahora=$(date +%s)
for clave in "${claves[@]}"; do
  registro=$FONDO/$clave
  desde=$(cat "$registro.inicio")
  [[ "$desde" =~ ^[0-9]+$ ]] || desde=$ahora
  minutos=$(( (ahora - desde) / 60 ))
  if [ -f "$registro.fin" ]; then
    estado=$(cat "$registro.fin")
    [[ "$estado" =~ ^[0-9]+$ ]] || estado=125
    echo "== $clave terminó · código $estado · $minutos min"
    tail -n 150 "$registro.salida"
    touch "$registro.informada" || exit 2
  else
    echo "… $clave sigue ($minutos min)"
  fi
done
[ "$terminadas" -gt 0 ] && exit 0
exit 124
