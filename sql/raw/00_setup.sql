-- =====================================================================
-- FOOTBALL.RAW — Setup inicial (base de datos, schema, file format, stage)
-- Ejecutado originalmente a mano en Snowflake; se documenta aquí para
-- que el repositorio sea reproducible de principio a fin.
-- =====================================================================

CREATE DATABASE IF NOT EXISTS FOOTBALL;
CREATE SCHEMA IF NOT EXISTS RAW;

CREATE OR REPLACE FILE FORMAT RAW.FF_CSV
    TYPE = CSV
    FIELD_DELIMITER = ','
    SKIP_HEADER = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    EMPTY_FIELD_AS_NULL = TRUE
    NULL_IF = ('', 'NULL');

CREATE OR REPLACE STAGE RAW.STG_TRANSFERMARKT
    FILE_FORMAT = RAW.FF_CSV;

-- A continuación: subir los 5 CSV (players.csv, clubs.csv,
-- competitions.csv, player_valuations.csv, appearances.csv) al stage,
-- p.ej. desde SnowSQL:
--   PUT file://data/*.csv @RAW.STG_TRANSFERMARKT AUTO_COMPRESS=TRUE;
-- o subiéndolos manualmente desde Snowsight.
