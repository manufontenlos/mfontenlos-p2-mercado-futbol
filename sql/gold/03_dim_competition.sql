-- =====================================================================
-- FOOTBALL.GOLD — dim_competition
-- Fuente: SILVER.DIM_COMPETITION (paso directo).
-- =====================================================================

USE DATABASE FOOTBALL;
USE SCHEMA GOLD;

CREATE OR REPLACE TABLE GOLD.DIM_COMPETITION AS
SELECT
    competition_id,
    competition_name,
    competition_code,
    competition_type,
    sub_type,
    country_id,
    country_name,
    domestic_league_code,
    confederation,
    total_clubs
FROM SILVER.DIM_COMPETITION;
