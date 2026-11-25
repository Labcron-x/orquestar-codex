# CX-4 — Consumo por proveedor y modelo

## Resumen

- `extraer.js --uso [--desde <bytes>]` reconoce los formatos pedidos, suma los pasos y prioriza los totales.
  `resumen` muestra consumo por modelo antes de la respuesta final.
- Cada intento y consulta registra JSONL con tokens, costo informado, estado y duración. La escritura es
  silenciosa ante errores y se desactiva con `ORQ_CONSUMO=off`.
- `orq consumo [días|todo]` agrupa por agente y modelo, agrega totales por agente y lee los incrementos de las
  sesiones locales de Codex, con cambios de modelo y los límites de ChatGPT más recientes.
- Documentación y configuración actualizadas. Pruebas con registros y sesiones ficticios; no se leyeron sesiones
  reales ni se ejecutó git.
- Omitido: dependencias nuevas, precios estimados, filtros y opciones adicionales al contrato.

## Correcciones de revisión

- Tablas alineadas con espacios; columnas numéricas a la derecha.
- Las secciones sin filas muestran un aviso en lugar de una tabla vacía. Si no hay ningún dato, se conserva
  el mensaje general de ausencia de registros.
- Los totales por agente cuentan ejecuciones, fallos y tiempo una vez por clave `fecha+repo+id+tipo`.
  Los tokens y costos siguen sumando todos los modelos de la ejecución.
- Codex filtra por el timestamp de cada `token_count`. Los eventos anteriores al periodo actualizan el acumulado
  de referencia sin sumarse; la fecha del archivo queda como respaldo si falta el timestamp.
- El modelo de `init`, `system/init` y `assistant.message.model` se conserva para los eventos siguientes,
  incluido el resultado de Gemini sin desglose por modelo.
- Pruebas añadidas para los puntos 2, 3, 4 y 5, además de la alineación de columnas.
  Esta revisión solo tocó `scripts/consumo.js`, `scripts/extraer.js`, `scripts/pruebas.sh` y este reporte.

## Archivos tocados

- `scripts/extraer.js`
- `scripts/comun.sh`
- `scripts/orq.sh`
- `scripts/consumo.sh` (nuevo)
- `scripts/consumo.js` (nuevo)
- `scripts/pruebas.sh`
- `SKILL.md`
- `README.md`
- `ORQUESTACION.md`
- `config.ejemplo`
- `docs/agentes/reportes/CX-4.md` (nuevo)

## Verificación

`bash scripts/verificar.sh` — código 0:

```text
(shellcheck no instalado: se omite)
Verificación OK
```

`bash scripts/pruebas.sh` — código 0, últimas líneas:

```text
Instalador: --documentos sin LibreOffice y --libreoffice aparte OK (sin instalaciones reales)
Consumo: modelos de inicio y assistant conservados hasta result OK
Consumo: formatos, totales, caché, costos, bytes y resumen OK
Consumo: columnas alineadas y totales por ejecución sin duplicar modelos OK
Consumo: secciones vacías, timestamps por evento y límites de Codex OK
Registro: JSON válido, consulta, modelo, sin datos, off y errores silenciosos OK
Pruebas sin git OK
```

## Dudas

Ninguna. MiniMax registra consumo solo si el evento incluye `usage`, conforme al contrato.
