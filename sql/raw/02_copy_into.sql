-- =====================================================================
-- FOOTBALL.RAW — Carga de datos desde el stage a las tablas RAW
-- Requiere que los 5 CSV ya estén subidos a @RAW.STG_TRANSFERMARKT
-- (p.ej. vía PUT desde SnowSQL/Snowsight) con esos nombres de fichero.
-- =====================================================================

USE DATABASE FOOTBALL;
USE SCHEMA RAW;

COPY INTO RAW.PLAYERS
    FROM @RAW.STG_TRANSFERMARKT/players.csv
    FILE_FORMAT = (FORMAT_NAME = RAW.FF_CSV)
    ON_ERROR = 'ABORT_STATEMENT';

COPY INTO RAW.CLUBS
    FROM @RAW.STG_TRANSFERMARKT/clubs.csv
    FILE_FORMAT = (FORMAT_NAME = RAW.FF_CSV)
    ON_ERROR = 'ABORT_STATEMENT';

COPY INTO RAW.COMPETITIONS
    FROM @RAW.STG_TRANSFERMARKT/competitions.csv
    FILE_FORMAT = (FORMAT_NAME = RAW.FF_CSV)
    ON_ERROR = 'ABORT_STATEMENT';

COPY INTO RAW.PLAYER_VALUATIONS
    FROM @RAW.STG_TRANSFERMARKT/player_valuations.csv
    FILE_FORMAT = (FORMAT_NAME = RAW.FF_CSV)
    ON_ERROR = 'ABORT_STATEMENT';

COPY INTO RAW.APPEARANCES
    FROM @RAW.STG_TRANSFERMARKT/appearances.csv
    FILE_FORMAT = (FORMAT_NAME = RAW.FF_CSV)
    ON_ERROR = 'ABORT_STATEMENT';

-- Si algún fichero falla por un registro puntual mal formado, cambia
-- ON_ERROR a 'CONTINUE' y revisa los rechazos con:
-- SELECT * FROM TABLE(VALIDATE(RAW.<tabla>, JOB_ID => '_last'));
