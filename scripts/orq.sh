#!/usr/bin/env bash
# Entrada única de la skill. Conserva los argumentos y el código del comando.
DIR_SCRIPTS=$(cd "$(dirname "$0")" && pwd)
case ${1:-} in
  actualizar|agentes|guardar|integrar|lanzar|reintentar|resumen|limpiar|consultar|fondo|esperar-fondo|esperar|esperar-gh|verificar|nueva-skill|instalar-skills)
    comando=$1; shift
    exec bash "$DIR_SCRIPTS/$comando.sh" "$@"
    ;;
  *) echo 'Uso: orq <comando> [args...]'
     echo 'Comandos: actualizar agentes guardar integrar lanzar reintentar resumen limpiar consultar fondo esperar-fondo esperar esperar-gh verificar nueva-skill instalar-skills'
     exit 2 ;;
esac
