# Contribuir y desplegar

La skill se "despliega" cuando un cambio llega a `main`: cada persona la actualiza con `git pull` (o `orq actualizar`)
y, si el cambio lo pide, vuelve a correr `instalar.sh`. Por eso **todo entra por PR** y `main` nunca recibe push directo.

## Flujo de un cambio

1. Rama desde `main` al día:
   ```bash
   cd ~/.codex/skills/orquestar-codex
   git switch main && git pull
   git switch -c <tipo>/<tema>        # feat/..., fix/..., docs/...
   ```
2. Cambios con commits en formato `tipo(alcance): descripción` (como el historial).
3. Prueba local mínima:
   ```bash
   bash scripts/orq.sh agentes
   for f in instalar.sh scripts/*.sh agentes/*.sh; do bash -n "$f"; done
   ```
4. `git push -u origin <rama>` y abre el PR hacia `main` (la plantilla pide cómo lo probaste).
5. El pipeline **Validación del orquestador** corre en GitHub Actions (`ubuntu-latest`): Gitleaks, sintaxis y ShellCheck
   de los scripts, sintaxis de Node y estructura de la skill (frontmatter y adaptadores). Debe quedar en verde.
6. Una persona distinta al autor revisa y aprueba.
7. **Squash and merge**. Ese merge es el despliegue.
8. Avisa al equipo si hay que correr `instalar.sh` o tocar `~/.config/orquestar-codex/config` (la plantilla del PR
   lo pregunta). Cada persona: `git switch main && git pull` (o `orq actualizar`).

**Actualización automática:** al empezar cada sesión, Codex corre `orq actualizar`: hace `git pull` (solo si la
copia está en `main` y limpia) y vuelve a correr `configurar-agentes.js` para los MCP de los agentes. Un MCP nuevo para
todos se agrega en los scripts correspondientes.

Para volver atrás: `git revert` del merge en un PR nuevo, por el mismo flujo.

## Protección de `main` (una vez, el dueño del repo)

GitHub → repo → Settings → Branches → *Add branch ruleset* (o *branch protection rule*) para `main`:

- Require a pull request before merging, con 1 aprobación.
- Require status checks to pass: `Gitleaks (Secret Scanning)`, `Scripts (bash, ShellCheck, Node)`,
  `Estructura de la skill` (aparecen después de la primera corrida).
- Block force pushes y restrict deletions.
