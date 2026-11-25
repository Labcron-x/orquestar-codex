# Skills externas para ahorrar tokens

Prácticas y paquetes de terceros que complementan el orquestador.

| Herramienta / Práctica | Dónde vive | Qué aporta al orquestador |
|---|---|---|
| **Graphify** | `graphify-out/` si el repo lo tiene | Mapa del repo para no releer archivos |
| **Ponytail** (DietrichGebert/ponytail) | Práctica en cada tarea | Reutilizar antes de escribir: menos código y diffs más cortos |
| **Agent Skills** (addyosmani/agent-skills) | Opcional si está instalada | Flujos de ingeniería (spec, plan, TDD, revisión, ship) |

## Cómo se usan en el ciclo

- **Antes de repartir (Codex):** si el repo tiene `graphify-out/`, consulta el grafo para elegir los archivos
  permitidos de cada tarea en vez de leer el código. Si no existe y el repo es grande, se puede generar una vez y
  hacer commit de `graphify-out/` solo si el proyecto lo quiere versionado.
- **En cada tarea:** la plantilla ya trae la escalera de Ponytail ("Mínimo código"). No la quites.
- **Agent Skills por tipo de tarea (si está instalada):** nombra en la tarea la skill que aplica, en una línea, y
  si el agente no puede leer fuera del worktree copia a la tarea solo las 3–5 reglas que importan (no el archivo
  entero).

| Tarea | Skill de agent-skills |
|---|---|
| Partir un pedido grande en tareas | `planning-and-task-breakdown`, `spec-driven-development` |
| Lógica nueva con pruebas | `test-driven-development`, `incremental-implementation` |
| Bug | `debugging-and-error-recovery` |
| UI | `frontend-ui-engineering`, `browser-testing-with-devtools` |
| Revisión cruzada (`REV-<ID>`) | `code-review-and-quality`, `code-simplification` |
| Auth, pagos, datos personales | `security-and-hardening` |
| Migraciones o cambios de API | `deprecation-and-migration`, `api-and-interface-design` |
| Antes de desplegar | `shipping-and-launch` |

## Cambio de modelo al agotar cuota

El orquestador ya lo hace sin proxy: `orq fondo reintentar <ID> "<error>" + [agente]` sube de modelo o cambia de agente.
**OmniRoute** (diegosouzapw/OmniRoute) no es una skill sino un proxy local que guarda las claves de todos los
proveedores y ve cada prompt; no se instala por defecto. Si el usuario lo quiere, que lo instale y configure él.
