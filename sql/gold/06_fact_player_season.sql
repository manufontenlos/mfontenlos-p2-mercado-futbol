-- =====================================================================
-- FOOTBALL.GOLD — fact_player_season
-- Grano: jugador · temporada · club · competición (idéntico a SILVER).
--
-- performance_score: fórmula acordada = "contribución de gol por 90
-- minutos" = (goles*2 + asistencias) / (minutos_jugados / 90).
-- Normalizado por minutos jugados para comparar de forma justa a
-- titulares y suplentes.
--
-- ⚠️ Umbral mínimo de minutos (MIN_MINUTES_FOR_SCORE = 450, ≈ 5
-- partidos completos): con muestras muy pequeñas la tasa por 90' se
-- dispara y deja de ser significativa (ejemplo real detectado: un
-- jugador con 1 gol en 1 minuto jugado da un score de 180, el más alto
-- de toda la temporada, sin ser un rendimiento real). Por debajo del
-- umbral, performance_score queda en NULL — así ni distorsiona el
-- "score medio" del Overview ni contamina el "top jugadores por
-- score". Es el criterio estándar en estadística deportiva para
-- evitar rankings dominados por apariciones testimoniales.
-- =====================================================================

USE DATABASE FOOTBALL;
USE SCHEMA GOLD;

CREATE OR REPLACE TABLE GOLD.FACT_PLAYER_SEASON AS
SELECT
    player_id,
    season,
    club_id,
    competition_id,
    games_played,
    goals,
    assists,
    yellow_cards,
    red_cards,
    minutes_played,
    goals + assists AS goal_contributions,
    CASE
        WHEN minutes_played >= 450  -- MIN_MINUTES_FOR_SCORE
        THEN ROUND((goals * 2 + assists) / (minutes_played / 90.0), 2)
    END AS performance_score,
    market_value_eur_season_end,
    market_value_as_of_date
FROM SILVER.FCT_PLAYER_SEASON;
