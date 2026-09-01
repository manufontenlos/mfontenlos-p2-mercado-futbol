-- =====================================================================
-- FOOTBALL.RAW — Creación de tablas RAW
-- Fuente: Kaggle "player-scores" (transfermarkt-datasets)
-- Requiere: FOOTBALL.RAW.FF_CSV (file format) y FOOTBALL.RAW.STG_TRANSFERMARKT (stage)
--
-- Nota: el dataset actualmente disponible en data/ no incluye un CSV
-- "player_scores" independiente (el .md del proyecto lo menciona, pero
-- las columnas de rendimiento por partido viven en appearances.csv).
-- Se crean tablas RAW para los 5 CSV realmente presentes:
--   players, clubs, competitions, player_valuations, appearances
--
-- Tipado: se tipan de forma nativa (NUMBER/DATE) las columnas cuyo
-- formato en el CSV es limpio y consistente (fechas ISO YYYY-MM-DD,
-- enteros, decimales), y se dejan como VARCHAR los campos de texto
-- libre o con formato "sucio" (p.ej. net_transfer_record mezcla
-- símbolos de moneda y signo: '+€5.90m', '€-25.00m', '+-0').
-- La limpieza/casting definitivo y las reglas de duplicados se
-- resuelven en SILVER (solo SQL), tal como pide el enunciado.
-- =====================================================================

USE DATABASE FOOTBALL;
USE SCHEMA RAW;

-- ---------------------------------------------------------------------
-- RAW.PLAYERS  (players.csv — 50.149 filas, 26 columnas)
-- ---------------------------------------------------------------------
CREATE OR REPLACE TABLE RAW.PLAYERS (
    player_id                            NUMBER(38,0),
    first_name                           VARCHAR(100),
    last_name                            VARCHAR(100),
    name                                  VARCHAR(150),
    last_season                          NUMBER(4,0),
    current_club_id                      NUMBER(38,0),
    player_code                          VARCHAR(60),
    country_of_birth                     VARCHAR(100),
    city_of_birth                        VARCHAR(150),
    country_of_citizenship               VARCHAR(100),
    date_of_birth                        DATE,
    sub_position                         VARCHAR(50),
    position                             VARCHAR(50),
    foot                                  VARCHAR(10),
    height_in_cm                         NUMBER(5,1),
    contract_expiration_date             DATE,
    agent_name                           VARCHAR(150),
    image_url                            VARCHAR(500),
    international_caps                   NUMBER(6,0),
    international_goals                  NUMBER(6,0),
    current_national_team_id             NUMBER(38,0),
    url                                   VARCHAR(500),
    current_club_domestic_competition_id VARCHAR(10),
    current_club_name                    VARCHAR(150),
    market_value_in_eur                  NUMBER(15,2),
    highest_market_value_in_eur          NUMBER(15,2)
);

-- ---------------------------------------------------------------------
-- RAW.CLUBS  (clubs.csv — 796 filas, 17 columnas)
-- ---------------------------------------------------------------------
CREATE OR REPLACE TABLE RAW.CLUBS (
    club_id                    NUMBER(38,0),
    club_code                  VARCHAR(60),
    name                        VARCHAR(150),
    domestic_competition_id    VARCHAR(10),
    total_market_value         NUMBER(15,2),   -- siempre NULL en el CSV actual; se mantiene por completitud de esquema
    squad_size                 NUMBER(4,0),
    average_age                NUMBER(4,1),
    foreigners_number          NUMBER(4,0),
    foreigners_percentage      NUMBER(5,2),
    national_team_players      NUMBER(4,0),
    stadium_name                VARCHAR(150),
    stadium_seats               NUMBER(10,0),
    net_transfer_record         VARCHAR(30),    -- formato mixto ('+€5.90m', '€-25.00m', '+-0'); se parsea en SILVER si se necesita
    coach_name                  VARCHAR(150),
    last_season                 NUMBER(4,0),
    filename                    VARCHAR(200),
    url                          VARCHAR(500)
);

-- ---------------------------------------------------------------------
-- RAW.COMPETITIONS  (competitions.csv — 65 filas, 11 columnas)
-- ---------------------------------------------------------------------
CREATE OR REPLACE TABLE RAW.COMPETITIONS (
    competition_id          VARCHAR(10),
    competition_code        VARCHAR(60),
    name                      VARCHAR(100),
    sub_type                 VARCHAR(60),
    type                      VARCHAR(40),
    country_id               NUMBER(10,0),      -- -1 = competición sin país (p.ej. internacional)
    country_name             VARCHAR(100),
    domestic_league_code     VARCHAR(10),
    confederation             VARCHAR(20),
    total_clubs               NUMBER(4,0),
    url                        VARCHAR(500)
);

-- ---------------------------------------------------------------------
-- RAW.PLAYER_VALUATIONS  (player_valuations.csv — 656.301 filas, 6 columnas)
-- ---------------------------------------------------------------------
CREATE OR REPLACE TABLE RAW.PLAYER_VALUATIONS (
    player_id                             NUMBER(38,0),
    date                                    DATE,
    market_value_in_eur                    NUMBER(15,2),
    current_club_name                      VARCHAR(150),
    current_club_id                        NUMBER(38,0),
    player_club_domestic_competition_id    VARCHAR(10)
);

-- ---------------------------------------------------------------------
-- RAW.APPEARANCES  (appearances.csv — 1.894.350 filas, 13 columnas)
-- ---------------------------------------------------------------------
CREATE OR REPLACE TABLE RAW.APPEARANCES (
    appearance_id             VARCHAR(30),   -- formato "{game_id}_{player_id}"
    game_id                    NUMBER(38,0),
    player_id                  NUMBER(38,0),
    player_club_id             NUMBER(38,0),
    player_current_club_id     NUMBER(38,0), -- puede ser -1
    date                        DATE,
    player_name                 VARCHAR(150),
    competition_id               VARCHAR(10),
    yellow_cards                 NUMBER(2,0),
    red_cards                    NUMBER(2,0),
    goals                        NUMBER(3,0),
    assists                      NUMBER(3,0),
    minutes_played               NUMBER(4,0)
);
