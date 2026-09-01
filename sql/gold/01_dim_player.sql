-- =====================================================================
-- FOOTBALL.GOLD — dim_player
-- Fuente: SILVER.DIM_PLAYER (paso directo, ya limpia y deduplicada).
-- Se excluyen url / image_url: no aportan a los KPIs/visuales pedidos.
-- =====================================================================

CREATE SCHEMA IF NOT EXISTS FOOTBALL.GOLD;
USE DATABASE FOOTBALL;
USE SCHEMA GOLD;

CREATE OR REPLACE TABLE GOLD.DIM_PLAYER AS
SELECT
    player_id,
    player_name,
    first_name,
    last_name,
    date_of_birth,
    position,
    sub_position,
    preferred_foot,
    height_in_cm,
    country_of_birth,
    city_of_birth,
    country_of_citizenship,
    current_club_id,
    current_competition_id,
    agent_name,
    contract_expiration_date,
    current_market_value_eur,
    highest_market_value_eur,
    international_caps,
    international_goals,
    last_season AS last_season_played
FROM SILVER.DIM_PLAYER;
