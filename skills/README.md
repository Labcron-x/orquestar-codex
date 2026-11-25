# Skills del equipo

Cada carpeta de `skills/` es una skill para Codex. `orq instalar-skills` las copia a `~/.codex/skills/<nombre>/`, donde
Codex las descubre. Todas siguen la misma lógica que `orquestar-codex`:
**Codex decide, reparte y valida; los agentes de CLI hacen lo delegable.**

Por ahora no hay skills del equipo en este repo.

## Agregar una skill

```bash
orq nueva-skill <nombre-en-kebab> "<cuándo usarla, en una frase>"
# edita skills/<nombre>/SKILL.md y sus referencias, y luego:
orq instalar-skills
```

## Convención

```
skills/<nombre>/
├── SKILL.md          # frontmatter name + description; lo que Codex lee (corto: flujo y reglas)
├── referencias/      # detalle que se lee solo cuando hace falta (recetas, tablas, ejemplos)
├── plantillas/       # archivos que se copian al proyecto (config del proyecto, tareas para agentes)
└── scripts/          # utilidades deterministas (python -I, node, bash)
```

- **En español**, con el mismo tono que `orquestar-codex`.
- **Genérica:** lo propio de cada proyecto (marca, cuentas, rutas) vive en el repo del proyecto, en un archivo que la
  skill pide crear desde su plantilla. La skill nunca guarda claves ni datos de un cliente.
- **Delegación explícita:** el `SKILL.md` dice qué pasos hacen los agentes (con `orq consultar` o una tarea) y cuáles
  hace Codex, porque requieren herramientas o una decisión.
- **`description` concreta:** cuándo usarla y con qué palabras la pediría el usuario. De eso depende que Codex la active.
- Para actualizar: `git pull` en `~/.codex/skills/orquestar-codex` y `orq instalar-skills`.
