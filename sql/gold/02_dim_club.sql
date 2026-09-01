-- =====================================================================
-- FOOTBALL.GOLD — dim_club
-- Fuente: SILVER.DIM_CLUB (paso directo).
-- =====================================================================

USE DATABASE FOOTBALL;
USE SCHEMA GOLD;

CREATE OR REPLACE TABLE GOLD.DIM_CLUB AS
SELECT
    club_id,
    club_name,
    club_code,
    domestic_competition_id,
    stadium_name,
    stadium_seats,
    squad_size,
    average_age,
    foreigners_number,
    foreigners_percentage,
    national_team_players,
    coach_name,
    last_season,
    net_transfer_record_eur
FROM SILVER.DIM_CLUB;
