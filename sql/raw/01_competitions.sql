-- =====================================================================
-- RAW · 01_competitions.sql
-- Tabla: competitions.csv (11 columnas)
-- =====================================================================

-- 1. Descubrir columnas reales (nombres y orden)
SELECT *
FROM TABLE(
  INFER_SCHEMA(
    LOCATION => '@stage_raw_blob/landing/2026/09/04/player-scores/',
    FILE_FORMAT => 'FOOTBALL.RAW.FF_CSV_INFER',
    FILES => 'competitions.csv'
  )
);

-- 2. Tabla RAW generada desde el propio INFER_SCHEMA (todo STRING)
CREATE OR REPLACE TABLE FOOTBALL.RAW.COMPETITIONS
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
        FILES => 'competitions.csv'
      )
    )
  );

-- Columnas de metadatos, añadidas al final (mismo orden que usa el pipe)
ALTER TABLE FOOTBALL.RAW.COMPETITIONS
  ADD COLUMN _SOURCE_FILE STRING,
             _LOADED_AT   TIMESTAMP_NTZ;

-- 3. Pipe: ingesta automática vía Snowpipe + Event Grid.
-- Sin lista explícita de columnas: el SELECT produce 13 valores (11 del
-- CSV + 2 de metadatos) en el mismo orden que las 13 columnas de la
-- tabla, así que Snowflake las inserta posicionalmente sin ambigüedad.
CREATE OR REPLACE PIPE FOOTBALL.RAW.PIPE_COMPETITIONS
  AUTO_INGEST = TRUE
  INTEGRATION = 'NI_AZURE_BLOB_EVENTS'
AS
COPY INTO FOOTBALL.RAW.COMPETITIONS
FROM (
    SELECT $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,
           METADATA$FILENAME,
           CURRENT_TIMESTAMP()
    FROM @stage_raw_blob
)
PATTERN = '.*competitions\\.csv'
FILE_FORMAT = (FORMAT_NAME = 'FOOTBALL.RAW.FF_CSV_STANDARD');

-- 4. Backfill: el archivo que ya estaba en Blob antes de crear el pipe
-- no dispara un evento nuevo. REFRESH le dice al pipe que revise el
-- stage y encole también lo que ya estaba ahí.
ALTER PIPE FOOTBALL.RAW.PIPE_COMPETITIONS REFRESH;

-- Validación:
-- SELECT * FROM FOOTBALL.RAW.COMPETITIONS;
-- SELECT SYSTEM$PIPE_STATUS('FOOTBALL.RAW.PIPE_COMPETITIONS');
