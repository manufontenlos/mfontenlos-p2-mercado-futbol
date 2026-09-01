-- =====================================================================
-- FOOTBALL.GOLD — dim_date
-- Calendario continuo (sin huecos) construido en SQL a partir del rango
-- de fechas realmente presentes en los datos: se toma el MIN/MAX de
-- appearances.date y player_valuations.date (las dos columnas de fecha
-- que alimentan la capa SILVER/GOLD) y se genera un día por cada fecha
-- del rango con TABLE(GENERATOR(...)). Un calendario continuo (en vez
-- de solo las fechas que aparecen sueltas) es necesario para que las
-- funciones de time intelligence de Power BI (acumulados, YoY, etc.)
-- funcionen correctamente.
--
-- Uso previsto: relacionar con
-- gold.fact_player_season.market_value_as_of_date (fecha de la última
-- valoración de mercado usada en cada fila de la fact). El eje temporal
-- principal del análisis sigue siendo gold.dim_season, ya que la fact
-- está a grano temporada, no a grano día.
-- =====================================================================

USE DATABASE FOOTBALL;
USE SCHEMA GOLD;

CREATE OR REPLACE TABLE GOLD.DIM_DATE AS
WITH bounds AS (
    SELECT
        MIN(d) AS min_date,
        MAX(d) AS max_date
    FROM (
        SELECT date AS d FROM RAW.APPEARANCES
        UNION ALL
        SELECT date AS d FROM RAW.PLAYER_VALUATIONS
    )
),
spine AS (
    SELECT DATEADD(DAY, SEQ4(), (SELECT min_date FROM bounds)) AS date_day
    FROM TABLE(GENERATOR(ROWCOUNT => 20000))  -- ~54 años, margen de sobra sobre el rango real
)
SELECT
    s.date_day,
    YEAR(s.date_day)                                                              AS year,
    QUARTER(s.date_day)                                                           AS quarter,
    MONTH(s.date_day)                                                             AS month,
    MONTHNAME(s.date_day)                                                         AS month_name,
    DAY(s.date_day)                                                               AS day,
    DAYOFWEEKISO(s.date_day)                                                      AS day_of_week,
    DAYNAME(s.date_day)                                                           AS day_name,
    WEEKOFYEAR(s.date_day)                                                        AS week_of_year,
    CASE WHEN MONTH(s.date_day) >= 7 THEN YEAR(s.date_day) ELSE YEAR(s.date_day) - 1 END AS season
FROM spine s
CROSS JOIN bounds b
WHERE s.date_day <= b.max_date;
