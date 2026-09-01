-- =====================================================================
-- FOOTBALL.SILVER — dim_competition
-- Fuente: RAW.COMPETITIONS
-- Limpieza aplicada:
--   - Deduplicación defensiva por competition_id.
--   - TRIM de campos de texto.
--   - country_id = -1 (competiciones sin país, p.ej. internacionales)
--     se convierte a NULL para no tratarlo como un país real.
-- =====================================================================

USE DATABASE FOOTBALL;
USE SCHEMA SILVER;

CREATE OR REPLACE TABLE SILVER.DIM_COMPETITION AS
SELECT
    competition_id,
    TRIM(competition_code)         AS competition_code,
    TRIM(name)                     AS competition_name,
    TRIM(sub_type)                 AS sub_type,
    TRIM(type)                     AS competition_type,
    NULLIF(country_id, -1)         AS country_id,
    TRIM(country_name)             AS country_name,
    TRIM(domestic_league_code)     AS domestic_league_code,
    TRIM(confederation)            AS confederation,
    total_clubs
FROM RAW.COMPETITIONS
WHERE competition_id IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY competition_id ORDER BY competition_id) = 1;
