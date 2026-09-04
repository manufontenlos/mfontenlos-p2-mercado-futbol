# SILVER

Capa de limpieza y tipado. Toma cada tabla RAW (todo STRING) y produce una versión con tipos de dato reales, valores nulos estandarizados y sin duplicados. Es la capa donde se responde a "¿por qué usaba esta función y no otra?".

## Decisiones de diseño (pendiente de implementar)

**`TRY_CAST` / `TRY_TO_DATE` / `TRY_TO_NUMBER` en vez de `CAST` / `TO_DATE` / `TO_NUMBER`.** La familia `TRY_*` devuelve `NULL` cuando el valor no se puede convertir, en vez de lanzar un error que aborta toda la carga. Como RAW puede contener cualquier cosa (viene sin validar), es la única forma segura de tipar sin que una fila mala tumbe el proceso completo.

**`NULLIF` + `TRIM` para estandarizar "vacíos".** Un mismo concepto de "sin valor" puede venir representado de formas distintas según el CSV (`''`, `'NA'`, `' '`, `'null'`). `TRIM` quita espacios sobrantes antes de comparar, y `NULLIF(columna, 'valor')` convierte esas representaciones en un `NULL` real y consistente, para que las consultas de GOLD no tengan que lidiar con cinco formas distintas de "no hay dato".

**`QUALIFY ROW_NUMBER() OVER (PARTITION BY ... ORDER BY ...)` para deduplicar, en vez de `DISTINCT`.** `DISTINCT` solo sirve si la fila duplicada es idéntica byte a byte. Aquí el caso real es distinto: pueden llegar varias cargas del mismo archivo (o el mismo registro con `_LOADED_AT` distinto) y queremos quedarnos con la versión más reciente por clave de negocio. `ROW_NUMBER() OVER (PARTITION BY <clave> ORDER BY _LOADED_AT DESC) = 1` en un `QUALIFY` expresa exactamente eso: "una fila por clave, la más nueva", cosa que `DISTINCT` no puede hacer.

**`MERGE` para cargas idempotentes.** En vez de truncar y recargar cada vez (caro y sin histórico) o solo insertar (duplica si se reprocesa el mismo archivo), `MERGE ... WHEN MATCHED THEN UPDATE ... WHEN NOT MATCHED THEN INSERT` hace que ejecutar la carga dos veces con los mismos datos no cambie el resultado. Esto es importante porque Snowpipe puede reintentar la entrega de un mismo archivo.

## Estructura prevista

Un archivo `sql/silver/<tabla>.sql` por tabla RAW, cada uno con: `SELECT` de limpieza/tipado sobre `RAW.<TABLA>` → `QUALIFY` de deduplicación → `MERGE INTO SILVER.<TABLA>`.

## Tablas previstas

Mismo alcance que RAW: `competitions`, `clubs`, `players`, `games`, `club_games`, `appearances`, `player_valuations`, `transfers`, `countries`.
