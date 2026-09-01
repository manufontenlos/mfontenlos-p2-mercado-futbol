-- =====================================================================
-- FOOTBALL.RAW — Controles mínimos post-carga
-- (conteo de filas, duplicados por ID, sanity check de tipos)
-- =====================================================================

USE DATABASE FOOTBALL;
USE SCHEMA RAW;

-- ---------------------------------------------------------------------
-- 1) Conteo de filas por tabla (comparar contra el nº de filas del CSV
--    origen, sin contar la cabecera):
--      players.csv            -> 50.149
--      clubs.csv               -> 796
--      competitions.csv        -> 65
--      player_valuations.csv   -> 656.301
--      appearances.csv         -> 1.894.350
-- ---------------------------------------------------------------------
SELECT 'players' AS tabla, COUNT(*) AS filas FROM RAW.PLAYERS
UNION ALL
SELECT 'clubs', COUNT(*) FROM RAW.CLUBS
UNION ALL
SELECT 'competitions', COUNT(*) FROM RAW.COMPETITIONS
UNION ALL
SELECT 'player_valuations', COUNT(*) FROM RAW.PLAYER_VALUATIONS
UNION ALL
SELECT 'appearances', COUNT(*) FROM RAW.APPEARANCES;

-- ---------------------------------------------------------------------
-- 2) Duplicados básicos por clave
-- ---------------------------------------------------------------------

-- players: player_id debe ser único
SELECT player_id, COUNT(*) AS n
FROM RAW.PLAYERS
GROUP BY player_id
HAVING COUNT(*) > 1;

-- clubs: club_id debe ser único
SELECT club_id, COUNT(*) AS n
FROM RAW.CLUBS
GROUP BY club_id
HAVING COUNT(*) > 1;

-- competitions: competition_id debe ser único
SELECT competition_id, COUNT(*) AS n
FROM RAW.COMPETITIONS
GROUP BY competition_id
HAVING COUNT(*) > 1;

-- appearances: appearance_id (game_id + player_id) debe ser único
SELECT appearance_id, COUNT(*) AS n
FROM RAW.APPEARANCES
GROUP BY appearance_id
HAVING COUNT(*) > 1;

-- player_valuations: no tiene un ID propio; la clave natural es
-- (player_id, date) — una valoración por jugador y fecha de publicación
SELECT player_id, date, COUNT(*) AS n
FROM RAW.PLAYER_VALUATIONS
GROUP BY player_id, date
HAVING COUNT(*) > 1;

-- ---------------------------------------------------------------------
-- 3) Tipos de dato correctos (fechas y números ya vienen tipados desde
--    el COPY INTO; aquí se comprueba que no haya nulos inesperados en
--    columnas clave ni valores fuera de rango razonable)
-- ---------------------------------------------------------------------
SELECT
    SUM(IFF(player_id IS NULL, 1, 0))         AS player_id_nulls,
    SUM(IFF(date_of_birth IS NULL, 1, 0))     AS date_of_birth_nulls,
    MIN(date_of_birth)                         AS min_date_of_birth,
    MAX(date_of_birth)                         AS max_date_of_birth
FROM RAW.PLAYERS;

SELECT
    SUM(IFF(game_id IS NULL, 1, 0))    AS game_id_nulls,
    SUM(IFF(date IS NULL, 1, 0))       AS date_nulls,
    MIN(date)                           AS min_date,
    MAX(date)                           AS max_date,
    MIN(minutes_played)                 AS min_minutes,
    MAX(minutes_played)                 AS max_minutes
FROM RAW.APPEARANCES;

SELECT
    SUM(IFF(market_value_in_eur IS NULL, 1, 0)) AS value_nulls,
    MIN(market_value_in_eur)                     AS min_value,
    MAX(market_value_in_eur)                     AS max_value,
    MIN(date)                                     AS min_date,
    MAX(date)                                     AS max_date
FROM RAW.PLAYER_VALUATIONS;
