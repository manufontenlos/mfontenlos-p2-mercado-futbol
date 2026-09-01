-- =====================================================================
-- FOOTBALL.SILVER — dim_player
-- Fuente: RAW.PLAYERS
-- Limpieza aplicada:
--   - Deduplicación defensiva por player_id (por si una recarga de RAW
--     introdujera duplicados; hoy player_id ya es único en origen).
--   - TRIM de campos de texto.
--   - date_of_birth se mantiene tal cual (49 nulos conocidos en origen,
--     ver controles de RAW): no se imputa, para no distorsionar edad.
--   - international_caps / international_goals: NULL -> 0 (un jugador
--     sin apariciones internacionales registradas equivale a 0, no a
--     "desconocido").
-- =====================================================================

CREATE SCHEMA IF NOT EXISTS FOOTBALL.SILVER;
USE DATABASE FOOTBALL;
USE SCHEMA SILVER;

CREATE OR REPLACE TABLE SILVER.DIM_PLAYER AS
SELECT
    player_id,
    TRIM(name)                                    AS player_name,
    TRIM(first_name)                               AS first_name,
    TRIM(last_name)                                AS last_name,
    date_of_birth,
    TRIM(position)                                 AS position,
    TRIM(sub_position)                             AS sub_position,
    TRIM(foot)                                     AS preferred_foot,
    height_in_cm,
    TRIM(country_of_birth)                         AS country_of_birth,
    TRIM(city_of_birth)                            AS city_of_birth,
    TRIM(country_of_citizenship)                   AS country_of_citizenship,
    current_club_id,
    TRIM(current_club_domestic_competition_id)     AS current_competition_id,
    TRIM(agent_name)                               AS agent_name,
    contract_expiration_date,
    market_value_in_eur                            AS current_market_value_eur,
    highest_market_value_in_eur                    AS highest_market_value_eur,
    NVL(international_caps, 0)                     AS international_caps,
    NVL(international_goals, 0)                    AS international_goals,
    last_season,
    url,
    image_url
FROM RAW.PLAYERS
WHERE player_id IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY player_id ORDER BY player_id) = 1;
