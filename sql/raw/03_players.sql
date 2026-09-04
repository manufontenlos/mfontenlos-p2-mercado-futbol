-- =====================================================================
-- RAW · 03_players.sql
-- Tabla: players.csv
--
-- TODO antes de ejecutar: sustituye <N> por el número real de columnas
-- del CSV (lo ves en el resultado del paso 1, es el ORDER_ID máximo + 1)
-- y añade esa misma cantidad de posiciones $1..$N en el paso 3.
-- =====================================================================

-- 1. Descubrir columnas reales (nombres y orden)
SELECT *
FROM TABLE(
  INFER_SCHEMA(
    LOCATION => '@stage_raw_blob/landing/2026/09/04/player-scores/',
    FILE_FORMAT => 'FOOTBALL.RAW.FF_CSV_INFER',
    FILES => 'players.csv'
  )
);

-- 2. Tabla RAW generada desde el propio INFER_SCHEMA (todo STRING)
CREATE OR REPLACE TABLE FOOTBALL.RAW.PLAYERS
  USING TEMPLATE (
    SELECT ARRAY_AGG(
             OBJECT_CONSTRUCT(
               'COLUMN_NAME', UPPER(COLUMN_NAME),
               'TYPE', 'TEXT',
               'NULLABLE', TRUE
             )
           ) WITHIN GROUP (ORDER BY ORDER_ID)
    FROM TABLE(
      INFER_SCHEMA(
        LOCATION => '@stage_raw_blob/landing/2026/09/04/player-scores/',
        FILE_FORMAT => 'FOOTBALL.RAW.FF_CSV_INFER',
        FILES => 'players.csv'
      )
    )
  );

-- Columnas de metadatos, añadidas al final (mismo orden que usa el pipe)
ALTER TABLE FOOTBALL.RAW.PLAYERS
  ADD COLUMN _SOURCE_FILE STRING,
             _LOADED_AT   TIMESTAMP_NTZ;

-- 3. Pipe: ingesta automática vía Snowpipe + Event Grid.
-- Sin lista explícita de columnas: el SELECT debe producir <N>+2 valores
-- (<N> del CSV + 2 de metadatos) en el mismo orden que las columnas de
-- la tabla, para que Snowflake las inserte posicionalmente.
CREATE OR REPLACE PIPE FOOTBALL.RAW.PIPE_PLAYERS
  AUTO_INGEST = TRUE
  INTEGRATION = 'NI_AZURE_BLOB_EVENTS'
AS
COPY INTO FOOTBALL.RAW.PLAYERS
FROM (
    SELECT $1,$2,$3,  -- <-- ajustar a $1..$<N> según el resultado del paso 1
           METADATA$FILENAME,
           CURRENT_TIMESTAMP()
    FROM @stage_raw_blob
)
PATTERN = '.*players\\.csv'
FILE_FORMAT = (FORMAT_NAME = 'FOOTBALL.RAW.FF_CSV_STANDARD');

-- 4. Backfill del histórico ya subido antes de crear el pipe
ALTER PIPE FOOTBALL.RAW.PIPE_PLAYERS REFRESH;

-- Validación:
-- SELECT * FROM FOOTBALL.RAW.PLAYERS;
-- SELECT SYSTEM$PIPE_STATUS('FOOTBALL.RAW.PIPE_PLAYERS');
