-- =====================================================================
-- FOOTBALL.SILVER — dim_club
-- Fuente: RAW.CLUBS
-- Limpieza aplicada:
--   - Deduplicación defensiva por club_id.
--   - TRIM de campos de texto.
--   - net_transfer_record llega como texto con formato mixto
--     ('+€5.90m', '€-25.00m', '+-0', '+€900k', '€-180k'); se conserva
--     el valor original (net_transfer_record_raw) y se añade una
--     versión numérica en EUR (net_transfer_record_eur) parseando
--     signo + magnitud + unidad ('m' = millones, 'k' = miles).
--   - total_market_value se descarta: llega siempre NULL en origen
--     (comprobado en el perfilado del CSV).
-- =====================================================================

USE DATABASE FOOTBALL;
USE SCHEMA SILVER;

CREATE OR REPLACE TABLE SILVER.DIM_CLUB AS
WITH cleaned AS (
    SELECT
        club_id,
        TRIM(club_code)                AS club_code,
        TRIM(name)                     AS club_name,
        TRIM(domestic_competition_id)  AS domestic_competition_id,
        squad_size,
        average_age,
        foreigners_number,
        foreigners_percentage,
        national_team_players,
        TRIM(stadium_name)             AS stadium_name,
        stadium_seats,
        net_transfer_record,
        TRIM(coach_name)               AS coach_name,
        last_season
    FROM RAW.CLUBS
    WHERE club_id IS NOT NULL
    QUALIFY ROW_NUMBER() OVER (PARTITION BY club_id ORDER BY club_id) = 1
)
SELECT
    club_id,
    club_code,
    club_name,
    domestic_competition_id,
    squad_size,
    average_age,
    foreigners_number,
    foreigners_percentage,
    national_team_players,
    stadium_name,
    stadium_seats,
    coach_name,
    last_season,
    net_transfer_record                                              AS net_transfer_record_raw,
    CASE
        WHEN net_transfer_record IS NULL THEN NULL
        WHEN net_transfer_record = '+-0' THEN 0
        ELSE TRY_TO_DECIMAL(
                 REGEXP_SUBSTR(REPLACE(net_transfer_record, '€', ''), '-?[0-9]+(\\.[0-9]+)?'),
                 18, 2
             )
             * CASE
                 WHEN net_transfer_record ILIKE '%m' THEN 1000000
                 WHEN net_transfer_record ILIKE '%k' THEN 1000
                 ELSE 1
               END
    END                                                               AS net_transfer_record_eur
FROM cleaned;
