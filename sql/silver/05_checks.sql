-- =====================================================================
-- FOOTBALL.SILVER — controles de calidad post-transformación
-- =====================================================================

USE DATABASE FOOTBALL;
USE SCHEMA SILVER;

-- 1) Conteo de filas por tabla
SELECT 'dim_player' AS tabla, COUNT(*) AS filas FROM SILVER.DIM_PLAYER
UNION ALL
SELECT 'dim_club', COUNT(*) FROM SILVER.DIM_CLUB
UNION ALL
SELECT 'dim_competition', COUNT(*) FROM SILVER.DIM_COMPETITION
UNION ALL
SELECT 'fct_player_season', COUNT(*) FROM SILVER.FCT_PLAYER_SEASON;

-- 2) Unicidad de las claves de dimensión (debe devolver 0 filas)
SELECT player_id, COUNT(*) FROM SILVER.DIM_PLAYER GROUP BY player_id HAVING COUNT(*) > 1;
SELECT club_id, COUNT(*) FROM SILVER.DIM_CLUB GROUP BY club_id HAVING COUNT(*) > 1;
SELECT competition_id, COUNT(*) FROM SILVER.DIM_COMPETITION GROUP BY competition_id HAVING COUNT(*) > 1;

-- 3) Grano de la fact: un jugador-temporada-club-competición no debe repetirse
--    (debe devolver 0 filas)
SELECT player_id, season, club_id, competition_id, COUNT(*)
FROM SILVER.FCT_PLAYER_SEASON
GROUP BY player_id, season, club_id, competition_id
HAVING COUNT(*) > 1;

-- 4) Integridad referencial fact -> dimensiones
--    player_id debe dar 0 filas (dim_player cubre todo raw.players).
--    club_id / competition_id: decisión de negocio tomada = NO filtrar
--    ni reasignar las claves huérfanas (ver comentario en
--    04_fct_player_season.sql). Es esperable ver aquí ~11.062 filas de
--    club_id y ~14.200 filas de competition_id sin dimensión asociada
--    (~1,3% del total); esta query sirve para monitorizar que el
--    volumen no crezca de forma anómala en cargas futuras, no para
--    exigir 0 filas.
SELECT f.player_id
FROM SILVER.FCT_PLAYER_SEASON f
LEFT JOIN SILVER.DIM_PLAYER d ON f.player_id = d.player_id
WHERE d.player_id IS NULL;

SELECT COUNT(*) AS filas_sin_club
FROM SILVER.FCT_PLAYER_SEASON f
LEFT JOIN SILVER.DIM_CLUB d ON f.club_id = d.club_id
WHERE d.club_id IS NULL;

SELECT COUNT(*) AS filas_sin_competicion
FROM SILVER.FCT_PLAYER_SEASON f
LEFT JOIN SILVER.DIM_COMPETITION d ON f.competition_id = d.competition_id
WHERE d.competition_id IS NULL;

-- 5) Cobertura de valor de mercado por temporada (informativo: cuántas
--    filas de la fact no tienen valoración asociada en esa temporada)
SELECT
    season,
    COUNT(*)                                                   AS filas,
    SUM(IFF(market_value_eur_season_end IS NULL, 1, 0))        AS sin_valoracion
FROM SILVER.FCT_PLAYER_SEASON
GROUP BY season
ORDER BY season;
