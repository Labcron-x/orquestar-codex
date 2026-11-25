#!/usr/bin/env bash
# Uso: fondo.sh lanzar <agente> <ID> [modelo|-] [rama-base]
#      fondo.sh reintentar <ID> "<error>" [modelo|+|-] [agente]
#      fondo.sh consultar <nombre> <agente> "<pregunta>" [modelo|-] [archivos...]
set -u
source "$(dirname "$0")/comun.sh" ""
FONDO=${ORQ_FONDO:-$HOME/.cache/orquestar-codex/fondo}

# Entrada interna: el lanzador conserva su PID hasta que este proceso escribe .fin.
if [ "${1:-}" = --ejecutar ]; then
  clave=$2; shift 2
  registro=$FONDO/$clave
  trap 'estado=$?; printf "%s\n" "$estado" > "$registro.fin.tmp"; mv -f "$registro.fin.tmp" "$registro.fin"' EXIT
  trap 'exit 125' HUP INT TERM
  bash "$DIR_SCRIPTS/$1.sh" "${@:2}"
  exit $?
fi

comando=${1:-}
case $comando in
  lanzar|reintentar)
    [ $# -ge 3 ] || { echo "Uso: fondo.sh $comando $([ "$comando" = lanzar ] && echo '<agente> <ID>' || echo '<ID> "<error>"') [modelo] [agente o rama-base]"; exit 2; }
    if [ "$comando" = lanzar ]; then id=$3; else id=$2; fi
    SIN_META=1 source "$DIR_SCRIPTS/comun.sh" "$id"
    clave=$REPO-$id
    shift
    ;;
  consultar)
    [ $# -ge 4 ] || { echo 'Uso: fondo.sh consultar <nombre> <agente> "<pregunta>" [modelo|-] [archivos...]'; exit 2; }
    clave=consulta-$2
    export ORQ_CONSULTA_NOMBRE=$2
    shift 2
    ;;
  *) echo 'Uso: fondo.sh lanzar|reintentar|consultar [args...]'; exit 2 ;;
esac
[[ "$clave" != */* && "$clave" != *\\* && "$clave" != .* ]] || { echo "Clave inválida: $clave"; exit 2; }
mkdir -p "$FONDO" || exit 2
FONDO=$(cd "$FONDO" && pwd) || exit 2
export ORQ_FONDO=$FONDO
registro=$FONDO/$clave
bloqueo=$registro.lock
mkdir "$bloqueo" 2>/dev/null || { echo "La clave $clave ya se está lanzando."; exit 2; }
trap 'rmdir "$bloqueo" 2>/dev/null' EXIT
if [ ! -f "$registro.fin" ] && fondo_vivo "$registro"; then
  echo "La clave $clave ya está corriendo."
  exit 2
fi
rm -f "$registro.fin" "$registro.fin.tmp" "$registro.informada" "$registro.pid" || exit 2
date +%s > "$registro.inicio" || exit 2
: > "$registro.salida" || exit 2
# %q conserva espacios, comillas, saltos de línea y argumentos vacíos sin evaluarlos.
{
  printf 'exec </dev/null >%q 2>&1\n' "$registro.salida"
  printf 'cd -- %q || exit 2\n' "$PWD"
  printf 'bash %q --ejecutar %q %q' "$DIR_SCRIPTS/fondo.sh" "$clave" "$comando"
  printf ' %q' "$@"
  printf '\nexit $?\n'
} > "$registro.ejecutar.sh" || exit 2

case $OSTYPE in
  msys*|cygwin*)
    # nohup no sale del árbol de procesos de Codex en Windows. Start-Process abre
    # otro Git Bash, oculto, con el entorno heredado; el lanzador cierra stdin.
    ORQ_BASH=$(cygpath -w "$(command -v bash)") \
    ORQ_ARRANQUE=$(cygpath -w "$registro.ejecutar.sh") \
    ORQ_PID_ARCHIVO=$(cygpath -w "$registro.pid") \
    ORQ_DIRECTORIO=$(cygpath -w "$PWD") \
      powershell.exe -NoProfile -Command '$ErrorActionPreference = "Stop"; $p = Start-Process -FilePath $env:ORQ_BASH -ArgumentList @("--noprofile", "--norc", ("`"" + $env:ORQ_ARRANQUE + "`"")) -WorkingDirectory $env:ORQ_DIRECTORIO -WindowStyle Hidden -PassThru; [IO.File]::WriteAllText($env:ORQ_PID_ARCHIVO, [string]$p.Id)' || { echo 125 > "$registro.fin"; exit 2; }
    ;;
  *)
    nohup bash "$registro.ejecutar.sh" </dev/null > "$registro.salida" 2>&1 &
    printf '%s\n' "$!" > "$registro.pid"
    disown 2>/dev/null || true
    ;;
esac
echo "En segundo plano: $clave. Espera con: orq esperar-fondo $clave"
