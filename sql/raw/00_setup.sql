-- =====================================================================
-- FOOTBALL.RAW — Setup inicial (base de datos, schema, file format, stage)
-- Ejecutado originalmente a mano en Snowflake; se documenta aquí para
-- que el repositorio sea reproducible de principio a fin.
-- =====================================================================

CREATE DATABASE IF NOT EXISTS FOOTBALL;
CREATE SCHEMA IF NOT EXISTS RAW;

CREATE OR REPLACE STORAGE INTEGRATION integration_azure_blob_raw
  TYPE = EXTERNAL_STAGE
  STORAGE_PROVIDER = 'AZURE'
  ENABLED = TRUE
  AZURE_TENANT_ID = '35cd5c67-eb9c-4930-a44c-845061d6b9c3'
  STORAGE_ALLOWED_LOCATIONS = ('azure://stp2futbolmfontenlos.blob.core.windows.net/raw/');

Desc integration integration_azure_blob_raw;

CREATE OR REPLACE STAGE stage_raw_blob
  URL = 'azure://stp2futbolmfontenlos.blob.core.windows.net/raw/'
  STORAGE_INTEGRATION = integration_azure_blob_raw;

LIST @stage_raw_blob;

CREATE DATABASE IF NOT EXISTS FOOTBALL;
CREATE SCHEMA IF NOT EXISTS FOOTBALL.RAW;

CREATE OR REPLACE FILE FORMAT FOOTBALL.RAW.FF_CSV_INFER
  TYPE = CSV
  FIELD_DELIMITER = ','
  PARSE_HEADER = TRUE
  FIELD_OPTIONALLY_ENCLOSED_BY = '"'
  NULL_IF = ('', 'NA', 'null')
  EMPTY_FIELD_AS_NULL = TRUE
  ENCODING = 'UTF8';


SELECT *
FROM TABLE(
  INFER_SCHEMA(
    LOCATION => '@stage_raw_blob/landing/2026/09/04/player-scores/',
    FILE_FORMAT => 'FOOTBALL.RAW.FF_CSV_INFER',
    FILES => 'competitions.csv'
  )
);

CREATE OR REPLACE NOTIFICATION INTEGRATION ni_azure_blob_events
  TYPE = QUEUE
  NOTIFICATION_PROVIDER = AZURE_STORAGE_QUEUE
  ENABLED = TRUE
  AZURE_STORAGE_QUEUE_PRIMARY_URI = 'https://stp2futbolmfontenlos.queue.core.windows.net/snowpipe-landing-queue'
  AZURE_TENANT_ID = '35cd5c67-eb9c-4930-a44c-845061d6b9c3';

DESC NOTIFICATION INTEGRATION ni_azure_blob_events;
