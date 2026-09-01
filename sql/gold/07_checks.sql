-- =====================================================================
-- FOOTBALL.GOLD — controles de calidad del modelo en estrella
-- =====================================================================

USE DATABASE FOOTBALL;
USE SCHEMA GOLD;

-- 1) Conteo de filas por tabla
SELECT 'dim_player' AS tabla, COUNT(*) AS filas FROM GOLD.DIM_PLAYER
UNION ALL
SELECT 'dim_club', COUNT(*) FROM GOLD.DIM_CLUB
UNION ALL
SELECT 'dim_competition', COUNT(*) FROM GOLD.DIM_COMPETITION
UNION ALL
SELECT 'dim_season', COUNT(*) FROM GOLD.DIM_SEASON
UNION ALL
SELECT 'dim_date', COUNT(*) FROM GOLD.DIM_DATE
UNION ALL
SELECT 'fact_player_season', COUNT(*) FROM GOLD.FACT_PLAYER_SEASON;

-- 2) Unicidad de claves en cada dimensión (deben devolver 0 filas)
SELECT player_id, COUNT(*) FROM GOLD.DIM_PLAYER GROUP BY player_id HAVING COUNT(*) > 1;
SELECT club_id, COUNT(*) FROM GOLD.DIM_CLUB GROUP BY club_id HAVING COUNT(*) > 1;
SELECT competition_id, COUNT(*) FROM GOLD.DIM_COMPETITION GROUP BY competition_id HAVING COUNT(*) > 1;
SELECT season, COUNT(*) FROM GOLD.DIM_SEASON GROUP BY season HAVING COUNT(*) > 1;
SELECT date_day, COUNT(*) FROM GOLD.DIM_DATE GROUP BY date_day HAVING COUNT(*) > 1;

-- 3) dim_date sin huecos (debe devolver 0 filas: comprueba que no
--    falte ningún día entre el mínimo y el máximo)
SELECT COUNT(*) AS dias_esperados,
       DATEDIFF(day, MIN(date_day), MAX(date_day)) + 1 AS dias_en_rango
FROM GOLD.DIM_DATE
HAVING dias_esperados <> dias_en_rango;

-- 4) Grano de la fact (debe devolver 0 filas)
SELECT player_id, season, club_id, competition_id, COUNT(*)
FROM GOLD.FACT_PLAYER_SEASON
GROUP BY player_id, season, club_id, competition_id
HAVING COUNT(*) > 1;

-- 5) Integridad referencial fact -> dimensiones
--    player_id y season deben dar 0 filas.
--    club_id / competition_id: se heredan las ~11.062 / ~14.200 filas
--    huérfanas ya documentadas y aceptadas en SILVER (ver README /
--    sql/silver/04_fct_player_season.sql) — no es un fallo de GOLD.
SELECT f.player_id
FROM GOLD.FACT_PLAYER_SEASON f
LEFT JOIN GOLD.DIM_PLAYER d ON f.player_id = d.player_id
WHERE d.player_id IS NULL;

SELECT f.season
FROM GOLD.FACT_PLAYER_SEASON f
LEFT JOIN GOLD.DIM_SEASON d ON f.season = d.season
WHERE d.season IS NULL;

SELECT COUNT(*) AS filas_sin_club
FROM GOLD.FACT_PLAYER_SEASON f
LEFT JOIN GOLD.DIM_CLUB d ON f.club_id = d.club_id
WHERE d.club_id IS NULL;

SELECT COUNT(*) AS filas_sin_competicion
FROM GOLD.FACT_PLAYER_SEASON f
LEFT JOIN GOLD.DIM_COMPETITION d ON f.competition_id = d.competition_id
WHERE d.competition_id IS NULL;

SELECT COUNT(*) AS filas_market_value_date_sin_dim_date
FROM GOLD.FACT_PLAYER_SEASON f
LEFT JOIN GOLD.DIM_DATE d ON f.market_value_as_of_date = d.date_day
WHERE f.market_value_as_of_date IS NOT NULL
  AND d.date_day IS NULL;

-- 6) Sanity check del KPI "performance_score" (Overview de Power BI)
--    filas_bajo_umbral = filas con minutes_played < 450 (por eso su
--    score es NULL a propósito, no es un fallo de cálculo).
SELECT
    COUNT(*)                                                          AS filas,
    SUM(IFF(performance_score IS NULL, 1, 0))                          AS filas_sin_score,
    SUM(IFF(minutes_played < 450, 1, 0))                                AS filas_bajo_umbral_450min,
    ROUND(AVG(performance_score), 2)                                   AS score_medio,
    MIN(performance_score)                                              AS score_min,
    MAX(performance_score)                                              AS score_max
FROM GOLD.FACT_PLAYER_SEASON;

-- Top 10 jugadores por score en la última temporada disponible
SELECT
    p.player_name,
    f.season,
    f.performance_score,
    f.goals,
    f.assists,
    f.minutes_played,
    f.market_value_eur_season_end
FROM GOLD.FACT_PLAYER_SEASON f
JOIN GOLD.DIM_PLAYER p ON f.player_id = p.player_id
WHERE f.season = (SELECT MAX(season) FROM GOLD.DIM_SEASON)
  AND f.performance_score IS NOT NULL
ORDER BY f.performance_score DESC
LIMIT 10;
