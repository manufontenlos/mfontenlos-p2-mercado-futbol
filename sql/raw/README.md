# RAW

Capa de aterrizaje de los datos tal cual llegan del CSV, sin limpiar ni tipar. Es una copia fiel del archivo fuente dentro de Snowflake.

## Decisiones de diseño

**Todas las columnas son STRING.** Aunque `INFER_SCHEMA` sugiere tipos (por ejemplo `NUMBER` para `country_id`), los ignoramos a propósito. El motivo es que RAW tiene que aceptar el archivo *siempre*, incluso si viene con un valor mal formado, un campo vacío o un texto donde se esperaba un número. Si tipáramos aquí, una sola fila rara podría tumbar toda la carga. Ese control de calidad y conversión de tipos se hace de forma segura en SILVER (con `TRY_CAST`, que convierte a `NULL` en vez de fallar).

**Columnas de metadatos (`_SOURCE_FILE`, `_LOADED_AT`).** No vienen del CSV, las añadimos nosotros en la carga. Dan trazabilidad: de qué archivo concreto y en qué momento llegó cada fila. Esto es necesario en cuanto la ingesta es automática (Snowpipe) y pueden llegar varias cargas de golpe sin que nadie lo esté mirando en directo.

**Dos file formats (`FF_CSV_INFER` y `FF_CSV_STANDARD`).** `PARSE_HEADER` (necesario para que `INFER_SCHEMA` lea los nombres reales de columna) y `SKIP_HEADER` (necesario para saltar la cabecera al cargar filas con `COPY INTO`) son mutuamente excluyentes en Snowflake, así que no se puede resolver con un único file format:

- `FF_CSV_INFER`: solo se usa una vez por tabla nueva, para descubrir el nombre y orden real de las columnas antes de escribir el `CREATE TABLE`.
- `FF_CSV_STANDARD`: es el que se usa en la carga real de datos (`COPY INTO` manual y, después, en el `COPY INTO` del pipe de Snowpipe).

**Storage Integration en vez de SAS token.** El acceso de Snowflake al contenedor de Azure Blob se hace vía Azure AD (Service Principal gestionado por Azure, con el rol RBAC "Storage Blob Data Reader"), no con un SAS token embebido en el `CREATE STAGE`. Un SAS token caduca y hay que rotarlo a mano; la integration es la vía recomendada por Snowflake para producción porque el control de acceso vive en Azure RBAC, de forma centralizada.

## Ingesta automática (Snowpipe + Event Grid)

Una vez que un archivo aterriza en Blob, ¿cómo llega a Snowflake sin que nadie ejecute un `COPY INTO` a mano? La cadena es la siguiente:

1. El pipeline de ADF descarga, descomprime y escribe los CSV en `landing/<fecha>/player-scores/` dentro del contenedor Blob.
2. En cuanto Azure Blob Storage termina de escribir un blob nuevo, emite un evento `Blob Created` — esto es una propiedad del propio servicio de almacenamiento, no algo que programemos nosotros.
3. Event Grid tiene una suscripción a ese tipo de evento (filtrada a `landing/*.csv`) y deposita el evento como un mensaje en una Storage Queue de Azure.
4. Snowflake, a través de una Notification Integration (`NOTIFICATION_PROVIDER = AZURE_STORAGE_QUEUE`), está permanentemente escuchando esa cola — esto es lo que activa `AUTO_INGEST = TRUE` en un pipe.
5. Cuando llega un mensaje cuya ruta de archivo coincide con el `PATTERN` de un pipe (por ejemplo, termina en `competitions.csv`), Snowflake dispara automáticamente el `COPY INTO` de ese pipe, solo para ese archivo.

El disparador es la llegada del archivo, no el horario del trigger de ADF ni ninguna consulta periódica desde Snowflake — por eso es "basado en eventos" y no en sondeo. El `PATTERN` del pipe apunta a la raíz del stage y filtra por nombre de archivo, no por carpeta de fecha: así, cualquier `competitions.csv` nuevo que llegue, en cualquier fecha, dispara su propia carga sin que haya que calcular ni mantener "cuál es la última carpeta".

Tres matices a tener en cuenta:

- **No es instantáneo.** Snowflake documenta un retraso típico de hasta 1-2 minutos entre que llega el evento y se ejecuta el `COPY INTO`. Es "casi en tiempo real", no tiempo real.
- **Es por archivo, no por tabla.** Cada pipe reacciona solo a los archivos que coinciden con su `PATTERN`. Cada tabla RAW necesita su propio pipe (`PIPE_COMPETITIONS`, `PIPE_CLUBS`...); si un archivo no tiene pipe, sigue necesitando `COPY INTO` manual.
- **No hace backfill de lo que ya estaba antes de crear el pipe**, salvo que se lo pidamos explícitamente con `ALTER PIPE ... REFRESH` (ver más abajo).

**Sin lista explícita de columnas en el `COPY INTO` del pipe.** El `SELECT` interno produce los valores en el mismo orden que las columnas de la tabla (las del CSV, en el orden de `INFER_SCHEMA`, seguidas de `_SOURCE_FILE` y `_LOADED_AT`, añadidas siempre al final). Como el orden y la cantidad coinciden, Snowflake inserta posicionalmente sin ambigüedad. Esto es justo lo que evita el error *"Insert value list does not match column list"*: si se declara una lista de columnas a mano y se olvida una, o no coincide con el número de valores del `SELECT`, revienta; quitando la lista explícita, la única fuente de verdad sobre "qué va en cada columna" es el orden de creación de la tabla, que ya generamos automáticamente con `USING TEMPLATE`.

**`ALTER PIPE ... REFRESH` en vez de un `COPY INTO` manual de validación.** Un pipe recién creado solo reacciona a eventos *nuevos*: el archivo que ya estaba en Blob antes de crear el pipe no se carga solo. En vez de mantener un `COPY INTO` manual aparte (que sería una segunda vía de carga, redundante con el pipe y fácil de desincronizar), usamos `REFRESH`, el mecanismo propio de Snowpipe para decirle "revisa el stage y encola también lo que ya estaba ahí". Así hay una única vía de carga (el pipe), tanto para el histórico como para lo nuevo.

## Estructura

- `00_setup.sql` — objetos compartidos por toda la capa: base de datos, schema, storage integration, stage, los dos file formats y la notification integration. Nada específico de una tabla concreta va aquí.
- `01_<tabla>.sql`, `02_<tabla>.sql`... — un archivo por tabla origen, cada uno de principio a fin: descubrir columnas (`INFER_SCHEMA`) → crear tabla (`CREATE TABLE ... USING TEMPLATE`) → añadir metadatos (`ALTER TABLE`) → crear el pipe → `REFRESH` para el histórico ya existente.

## Tablas

- `competitions` — hecha de principio a fin (tabla + pipe funcionando).
- `clubs`, `players`, `games`, `club_games`, `appearances`, `player_valuations`, `transfers`, `countries` — archivo generado con la misma plantilla, pendiente de rellenar: hay que ejecutar el paso 1 (`INFER_SCHEMA`) de cada uno, ver cuántas columnas tiene el CSV, y ajustar el número de `$1..$N` en el paso 3 (marcado con `-- TODO` en el propio archivo).
