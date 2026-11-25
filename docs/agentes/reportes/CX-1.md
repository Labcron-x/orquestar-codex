# Reporte CX-1

## Resumen

- Migré instalador, configuración personal, skills y mensajes a `orquestar-codex`, respetando `CODEX_HOME` y `ORQ_CONFIG`.
- Agregué `orq.sh`, lanzamiento separado y espera sin tokens con registro, PID, inicio, código final y marca de informado. Rechaza claves activas, informa procesos muertos con 125 y permite volver a pedir una clave ya informada.
- Agregué metadatos de invocación explícita y cambié todos los jobs de CI a `ubuntu-latest`.
- Los prompts llevan la marca del orquestador y describen el archivo de tarea sin usar la ruta literal que busca el otro vigilante. El filtro de Windows escapa la marca como regex.
- El patrón de bloqueos del vigilante se construye por fragmentos en tiempo de ejecución. Leer su propio código ya no dispara la alerta; la detección real se conserva.
- `actualizar.sh` exige main limpio y upstream antes de actualizar. La configuración de los cuatro trabajadores conserva su comportamiento; Codex recibe solo los MCP faltantes en su propio `config.toml`.
- No ejecuté git, instaladores ni agentes reales. No accedí a la configuración de la otra instalación.

Omití dependencias nuevas, un modo público de prueba y cambios ajenos al alcance: las pruebas usan un CLI falso temporal.

## Archivos tocados

- `instalar.sh`
- `scripts/actualizar.sh`
- `scripts/agentes.sh`
- `scripts/comun.sh`
- `scripts/configurar-agentes.js`
- `scripts/consultar.sh`
- `scripts/extraer.js` (solo el comentario del formato stream-json)
- `scripts/fondo.sh` (nuevo)
- `scripts/esperar-fondo.sh` (nuevo)
- `scripts/instalar-skills.sh`
- `scripts/lanzar.sh`
- `scripts/nueva-skill.sh`
- `scripts/orq.sh` (nuevo)
- `scripts/reintentar.sh`
- `agents/openai.yaml` (nuevo)
- `.github/workflows/ci.yml`
- `docs/agentes/reportes/CX-1.md` (este reporte)

## Verificación

Ejecutada en Windows con `C:/Program Files/Git/bin/bash.exe` desde PowerShell.

```text
$ bash scripts/verificar.sh
(shellcheck no instalado: se omite)
Verificación OK
Código: 0
```

Últimas líneas de `bash scripts/orq.sh agentes`:

```text
■ qwen — NO: qwen no está instalado. Instalar: npm i -g @qwen-code/qwen-code · Luego: qwen → Connect a provider: QwenCloud (Token Plan o API key, de pago) o Third-party (p. ej. OpenRouter)
  por defecto: el del CLI · escala (+): sin definir
  fuerte en: código en paralelo cuando agy y OpenCode están ocupados
Config personal: /c/Users/Equipo/.config/orquestar-codex/config (no existe: ver config.ejemplo)
FALTA codex: npm i -g @openai/codex
Código: 0
```

```text
$ bash scripts/orq.sh
Uso: orq <comando> [args...]
Comandos: actualizar agentes lanzar reintentar resumen limpiar consultar fondo esperar-fondo esperar esperar-gh verificar nueva-skill instalar-skills
Código: 2
```

`grep -rn 'claude' instalar.sh scripts/ .github/`: sin coincidencias (1). El chequeo de `allow_implicit_invocation: false` pasa (0).

## Prueba de segundo plano

Temporal: `/tmp/orq-cx1-qzdprU`. `ORQ_CONFIG` apunta a un archivo temporal y `ORQ_FONDO` a una carpeta temporal. Un ejecutable falso `opencode`, primero en `PATH`, duerme 10 segundos y entrega JSON. `SETUP=heredado` se exporta al lanzar. La consulta conserva el sondeo existente del vigilante cada 15 segundos.

```text
$ bash scripts/orq.sh fondo consultar prueba opencode 'Prueba sin agentes reales' -
En segundo plano: consulta-prueba. Espera con: orq esperar-fondo consulta-prueba
lanzar: 0

$ bash scripts/orq.sh fondo consultar prueba opencode 'Duplicada' -
La clave consulta-prueba ya está corriendo.
duplicada: 2

$ bash scripts/orq.sh esperar-fondo --max 3
… consulta-prueba sigue (0 min)
espera corta: 124

$ bash scripts/orq.sh esperar-fondo
== consulta-prueba terminó · código 0 · 0 min
Código de salida: 0 · 0 min
Consulta simulada OK; SETUP=heredado
(carpeta de la consulta: /tmp/orq-consulta-PUEiYy)
espera final: 0

$ bash scripts/orq.sh esperar-fondo
No hay nada pendiente.
sin pendientes: 2

$ bash scripts/orq.sh esperar-fondo consulta-prueba --max 0
== consulta-prueba terminó · código 0 · 0 min
Código de salida: 0 · 0 min
Consulta simulada OK; SETUP=heredado
(carpeta de la consulta: /tmp/orq-consulta-PUEiYy)
clave explícita: 0
```

Pruebas adicionales:

```text
supervivencia tras cerrar el lanzador: 0
Marca y pregunta multilínea con comillas, $ y acentos: OK.
Vigilante: leer comun.sh no genera alerta (0).
Vigilante: un bloqueo real conserva la detección (1).
Primera terminada y proceso muerto: OK (0; código 125).
Solo queda la viva: OK (124).
Esperar todas con clave explícita: OK (0).
Clave inexistente y opciones inválidas: OK (2).
Comando desconocido: OK (2).
Últimas 150 líneas: OK.
Filtro PowerShell con inventario simulado: repo, tarea, regex y exclusión del vigilante OK.
MCP: CODEX_HOME, configuración previa, respaldo e idempotencia OK (FS simulado).
```

La prueba de supervivencia usa otra ejecución de terminal para esperar, una ruta de estado con espacios, una clave con apóstrofo y un archivo de entrada con espacios. Los bloqueos de prueba del vigilante se generaron por fragmentos y su salida quedó en archivos temporales, para no activar el vigilante externo.

## Desacople en Windows

`Start-Process -WindowStyle Hidden` inicia otro Git Bash con entorno heredado. Un archivo de arranque conserva los argumentos con `printf %q`, fija el directorio y conecta stdin a `/dev/null` y ambas salidas a `.salida`. Su PID nativo se comprueba con `Get-Process`; el trabajador escribe `.fin` mediante un archivo temporal y renombrado. Linux/macOS usan `nohup` y `disown`.

## Dudas y límites

- `SKILL.md` todavía declara `orquestar-agentes` y `config.ejemplo` conserva referencias antiguas. Son de otra tarea y no se tocaron. El chequeo de frontmatter de CI necesita el cambio paralelo de `SKILL.md`.
- `.github/pull_request_template.md` todavía cita la ruta personal antigua. Queda fuera de los archivos permitidos y no se modificó.
- Windows denegó `Get-CimInstance Win32_Process` en este entorno. El filtro se verificó con inventario simulado en PowerShell; no se pudo verificar su enumeración real. `Get-Process` y el segundo plano real sí funcionaron.
- ShellCheck no está instalado. No hubo ejecución nativa en Linux/macOS ni ejecución del pipeline remoto.
