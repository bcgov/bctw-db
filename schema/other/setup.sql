SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

CREATE SCHEMA bctw;
ALTER SCHEMA bctw OWNER TO bctw;

CREATE SCHEMA bctw_dapi_v1;
ALTER SCHEMA bctw_dapi_v1 OWNER TO bctw;
COMMENT ON SCHEMA bctw_dapi_v1 IS 'a schema containing API facing views and routines for interfacing with the BCTW schema.';

CREATE SCHEMA crypto;
ALTER SCHEMA crypto OWNER TO bctw;

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA crypto;
COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';

CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA public;
COMMENT ON EXTENSION postgis IS 'PostGIS geometry, geography, and raster spatial types and functions';

SET default_tablespace = '';

SET default_table_access_method = heap;
