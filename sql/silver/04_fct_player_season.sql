-- =====================================================================
-- FOOTBALL.SILVER — fct_player_season
-- Grano: jugador · temporada · club · competición
-- Fuentes: RAW.APPEARANCES (rendimiento) + RAW.PLAYER_VALUATIONS (valor)
--
-- ⚠️ El .md del proyecto menciona raw.player_scores como fuente, pero
-- ese CSV no existe en este dataset (ver checks de RAW). Las métricas
-- de rendimiento por partido viven en appearances, así que esta tabla
-- se construye únicamente a partir de appearances + player_valuations.
--
-- Criterios de agregación (documentados tal como pide el enunciado):
--   - Temporada: convención Transfermarkt — una temporada "Y" cubre de
--     julio del año Y a junio del año Y+1 (p.ej. season=2012 significa
--     2012/2013). Se deriva de la fecha del partido / de la valoración
--     con: MONTH >= 7 -> YEAR ; MONTH < 7 -> YEAR - 1.
--   - Métricas de rendimiento (goles, asistencias, tarjetas, minutos):
--     SUMA de todas las apariciones del jugador en esa
--     temporada-club-competición.
--   - Valor de mercado: se toma la ÚLTIMA valoración registrada dentro
--     de la temporada del jugador (no la media), porque Transfermarkt
--     actualiza el valor de forma puntual e irregular, así que el
--     último valor conocido es el más representativo del cierre de
--     temporada. Esta valoración no está desglosada por club/competición
--     en la fuente, por lo que se repite para todas las combinaciones
--     club-competición de ese jugador en esa temporada.
--
-- ⚠️ Claves huérfanas (decisión tomada): ~686 club_id (11.062 filas,
-- 0,58%) y 4 competition_id (14.200 filas, 0,75%) presentes en
-- appearances no existen en dim_club / dim_competition (equipos de
-- categorías inferiores y competiciones menores no catalogados en el
-- dataset origen). Se decide MANTENERLAS tal cual, sin filtrarlas ni
-- reasignarlas a un miembro "Desconocido": se prioriza no perder
-- histórico de rendimiento. Consecuencia esperada y documentada: en
-- Power BI, esas ~1,3% de filas aparecerán como (en blanco) al
-- relacionar con dim_club/dim_competition. Ver sql/silver/05_checks.sql
-- punto 4 para monitorizar el volumen exacto tras cada carga.
-- =====================================================================

USE DATABASE FOOTBALL;
USE SCHEMA SILVER;

CREATE OR REPLACE TABLE SILVER.FCT_PLAYER_SEASON AS
WITH appearances_dedup AS (
    SELECT *
    FROM RAW.APPEARANCES
    WHERE player_id IS NOT NULL
      AND date IS NOT NULL
    QUALIFY ROW_NUMBER() OVER (PARTITION BY appearance_id ORDER BY appearance_id) = 1
),
appearances_season AS (
    SELECT
        *,
        CASE WHEN MONTH(date) >= 7 THEN YEAR(date) ELSE YEAR(date) - 1 END AS season
    FROM appearances_dedup
),
perf AS (
    SELECT
        player_id,
        season,
        player_club_id      AS club_id,
        competition_id,
        COUNT(*)            AS games_played,
        SUM(goals)          AS goals,
        SUM(assists)        AS assists,
        SUM(yellow_cards)   AS yellow_cards,
        SUM(red_cards)      AS red_cards,
        SUM(minutes_played) AS minutes_played
    FROM appearances_season
    GROUP BY player_id, season, player_club_id, competition_id
),
valuations_ranked AS (
    SELECT
        player_id,
        CASE WHEN MONTH(date) >= 7 THEN YEAR(date) ELSE YEAR(date) - 1 END AS season,
        date                 AS valuation_date,
        market_value_in_eur,
        ROW_NUMBER() OVER (
            PARTITION BY player_id, CASE WHEN MONTH(date) >= 7 THEN YEAR(date) ELSE YEAR(date) - 1 END
            ORDER BY date DESC
        ) AS rn
    FROM RAW.PLAYER_VALUATIONS
    WHERE player_id IS NOT NULL
      AND date IS NOT NULL
),
valuations_season AS (
    SELECT player_id, season, market_value_in_eur, valuation_date
    FROM valuations_ranked
    WHERE rn = 1
)
SELECT
    p.player_id,
    p.season,
    p.club_id,
    p.competition_id,
    p.games_played,
    p.goals,
    p.assists,
    p.yellow_cards,
    p.red_cards,
    p.minutes_played,
    v.market_value_in_eur AS market_value_eur_season_end,
    v.valuation_date       AS market_value_as_of_date
FROM perf p
LEFT JOIN valuations_season v
    ON p.player_id = v.player_id
   AND p.season    = v.season;
