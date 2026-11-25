#!/usr/bin/env bash
# Al empezar cada sesión: trae la skill de main y agrega los MCP y reglas que falten.
# Uso: bash ~/.codex/skills/orquestar-codex/scripts/actualizar.sh
DIR_SKILL=$(cd "$(dirname "$0")/.." && pwd)

# Solo actualiza una copia limpia en main: no pisa cambios locales ni ramas de trabajo.
if [ "$(git -C "$DIR_SKILL" branch --show-current 2>/dev/null)" = main ] \
  && [ -z "$(git -C "$DIR_SKILL" status --porcelain)" ] \
  && git -C "$DIR_SKILL" rev-parse --verify 'main@{upstream}' >/dev/null 2>&1; then
  antes=$(git -C "$DIR_SKILL" rev-parse HEAD)
  git -C "$DIR_SKILL" pull -q --ff-only 2>/dev/null || echo "AVISO: no se pudo hacer git pull de la skill."
  [ "$antes" != "$(git -C "$DIR_SKILL" rev-parse HEAD)" ] && echo "Skill actualizada: $(git -C "$DIR_SKILL" log -1 --format=%s)"
fi

# MCP y reglas de los agentes del CLI: idempotente, solo agrega lo que falte.
command -v node >/dev/null 2>&1 && node "$DIR_SKILL/scripts/configurar-agentes.js" "$DIR_SKILL" >/dev/null
