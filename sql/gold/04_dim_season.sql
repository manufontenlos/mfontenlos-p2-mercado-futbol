-- =====================================================================
-- FOOTBALL.GOLD — dim_season
-- Construida a partir de las temporadas realmente presentes en
-- SILVER.FCT_PLAYER_SEASON (no es un rango arbitrario).
-- Convención Transfermarkt: season=2012 representa la temporada 2012/2013.
-- =====================================================================

USE DATABASE FOOTBALL;
USE SCHEMA GOLD;

CREATE OR REPLACE TABLE GOLD.DIM_SEASON AS
SELECT DISTINCT
    season,
    TO_VARCHAR(season) || '/' || TO_VARCHAR(season + 1)  AS season_label,
    season                                                 AS season_start_year,
    season + 1                                             AS season_end_year
FROM SILVER.FCT_PLAYER_SEASON
WHERE season IS NOT NULL
ORDER BY season;
