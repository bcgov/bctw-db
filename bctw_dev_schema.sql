--
-- PostgreSQL database dump
--

-- Dumped from database version 12.5
-- Dumped by pg_dump version 13.4 (Ubuntu 13.4-1.pgdg18.04+1)

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

--
-- Name: bctw; Type: SCHEMA; Schema: -; Owner: bctw
--

CREATE SCHEMA bctw;


ALTER SCHEMA bctw OWNER TO bctw;

--
-- Name: bctw_dapi_v1; Type: SCHEMA; Schema: -; Owner: bctw
--

CREATE SCHEMA bctw_dapi_v1;


ALTER SCHEMA bctw_dapi_v1 OWNER TO bctw;

--
-- Name: SCHEMA bctw_dapi_v1; Type: COMMENT; Schema: -; Owner: bctw
--

COMMENT ON SCHEMA bctw_dapi_v1 IS 'a schema containing API facing views and routines for interfacing with the BCTW schema.';


--
-- Name: crypto; Type: SCHEMA; Schema: -; Owner: bctw
--

CREATE SCHEMA crypto;


ALTER SCHEMA crypto OWNER TO bctw;

--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA crypto;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: postgis; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA public;


--
-- Name: EXTENSION postgis; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION postgis IS 'PostGIS geometry, geography, and raster spatial types and functions';


--
-- Name: user_permission; Type: TYPE; Schema: bctw; Owner: bctw
--

CREATE TYPE bctw.user_permission AS ENUM (
    'admin',
    'editor',
    'none',
    'observer',
    'manager'
);


ALTER TYPE bctw.user_permission OWNER TO bctw;

--
-- Name: critter_permission_json; Type: TYPE; Schema: bctw; Owner: bctw
--

CREATE TYPE bctw.critter_permission_json AS (
	critter_id uuid,
	permission_type bctw.user_permission
);


ALTER TYPE bctw.critter_permission_json OWNER TO bctw;

--
-- Name: domain_type; Type: TYPE; Schema: bctw; Owner: bctw
--

CREATE TYPE bctw.domain_type AS ENUM (
    'bceid',
    'idir'
);


ALTER TYPE bctw.domain_type OWNER TO bctw;

--
-- Name: TYPE domain_type; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON TYPE bctw.domain_type IS 'Keycloak domain types, stored in the user and onboarding tables as column "domain"';


--
-- Name: onboarding_status; Type: TYPE; Schema: bctw; Owner: bctw
--

CREATE TYPE bctw.onboarding_status AS ENUM (
    'pending',
    'granted',
    'denied'
);


ALTER TYPE bctw.onboarding_status OWNER TO bctw;

--
-- Name: role_type; Type: TYPE; Schema: bctw; Owner: bctw
--

CREATE TYPE bctw.role_type AS ENUM (
    'administrator',
    'manager',
    'owner',
    'observer'
);


ALTER TYPE bctw.role_type OWNER TO bctw;

--
-- Name: TYPE role_type; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON TYPE bctw.role_type IS 'BCTW user role types. note: owner is deprecated';


--
-- Name: telemetry; Type: TYPE; Schema: bctw; Owner: bctw
--

CREATE TYPE bctw.telemetry AS (
	critter_id uuid,
	critter_transaction_id uuid,
	collar_id uuid,
	collar_transaction_id uuid,
	species text,
	wlh_id character varying(20),
	animal_id character varying(30),
	device_id integer,
	device_vendor text,
	frequency double precision,
	animal_status text,
	sex text,
	device_status text,
	population_unit text,
	collective_unit text,
	geom public.geometry,
	date_recorded timestamp with time zone,
	vendor_merge_id bigint,
	geojson jsonb,
	map_colour text
);


ALTER TYPE bctw.telemetry OWNER TO bctw;

--
-- Name: TYPE telemetry; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON TYPE bctw.telemetry IS 'returned in function that retrieves telemetry data to be displayed in the map. (get_user_telemetry)';


--
-- Name: telemetry_alert_type; Type: TYPE; Schema: bctw; Owner: bctw
--

CREATE TYPE bctw.telemetry_alert_type AS ENUM (
    'malfunction',
    'mortality',
    'missing_data',
    'battery'
);


ALTER TYPE bctw.telemetry_alert_type OWNER TO bctw;

--
-- Name: TYPE telemetry_alert_type; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON TYPE bctw.telemetry_alert_type IS 'user alert notifications. 
	malfunction: alert indicating telemetry has not been received from a device for more than 7 days.
	mortality: telemetry alert from vendor indicating the animal is a potential mortality.
	battery: alert from vendor indicating the device battery may be low. (net yet implemented).
	missing_data: deprecated.
';


--
-- Name: unattached_telemetry; Type: TYPE; Schema: bctw; Owner: bctw
--

CREATE TYPE bctw.unattached_telemetry AS (
	collar_id uuid,
	device_id integer,
	geom public.geometry,
	date_recorded timestamp with time zone,
	geojson jsonb
);


ALTER TYPE bctw.unattached_telemetry OWNER TO bctw;

--
-- Name: add_code(text, jsonb); Type: FUNCTION; Schema: bctw; Owner: bctw
--

CREATE FUNCTION bctw.add_code(stridir text, codejson jsonb) RETURNS json
    LANGUAGE plpgsql
    AS $$
declare 
	userid integer;
	j json;
	codes code[];
	i integer := 0;
	rec record;
	headerid integer;
	names text[];
begin
	-- given a code header by name, add codes (does not update)
	-- params: idir, code header name, array of codes
	userid := (select * from bctw.get_user_id(stridir));

	if userid is null then
		raise exception 'unable to find user with idir %', stridir;
	end if;

	CREATE TEMPORARY TABLE errors(
		rownum integer,
   		error text,
   		row json
	);
	
	for j in select jsonb_array_elements(codejson) loop
		i := i + 1;
		begin
			headerid := (
				select ch.code_header_id 
				from bctw.code_header ch
				where ch.code_header_name = j->>'code_header'
				and ch.code_category_id = 1
			);
			if headerid is null then
				insert into errors values (i, 'code header does not exist, please create it first', j);
			end if;
		
			if (select 1 from code c where c.code_name = j->>'code_name' and c.code_header_id = headerid) then
				 insert into errors values (i, format('code with name %s already exists.', j->>'code_name'), j);
			end if;
		
			codes := array_append(codes, (select jsonb_populate_record(null::bctw.code, j::jsonb)));
		
			exception when others then
				insert into errors values (i, sqlerrm, j);
		end;
	end loop;

	-- exit early if there are errors
	if exists (select 1 from errors) then
		return (select JSON_AGG(src) from ( select * from errors ) src );
	end if;
	drop table errors;
		
	-- perform the insert
	foreach rec in array codes
		loop
			names := array_append(names, (select upper(rec.code_name)::text));
			insert into bctw.code (
				code_header_id,
				code_name,
				code_description,
				code_description_long,
				code_sort_order,
				valid_from,
				valid_to,
				created_by_user_id
			)
			values (
				headerid,
				(select upper(rec.code_name)),
				rec.code_description,
				rec.code_description_long,
				rec.code_sort_order,
				coalesce (rec.valid_from, now()),
				rec.valid_to,
				userid
			);
	end loop;
	
	return (select json_agg(t) from (select * from bctw.code c 
	where c.code_header_id = headerid
	and c.code_name = any(names)) t);
END;
$$;


ALTER FUNCTION bctw.add_code(stridir text, codejson jsonb) OWNER TO bctw;

--
-- Name: FUNCTION add_code(stridir text, codejson jsonb); Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON FUNCTION bctw.add_code(stridir text, codejson jsonb) IS 'adds new codes from a json array. json objects within the array must contain the code_header.code_header_name under the property name "code_header".';


--
-- Name: add_code_header(text, jsonb); Type: FUNCTION; Schema: bctw; Owner: bctw
--

CREATE FUNCTION bctw.add_code_header(stridir text, headerjson jsonb) RETURNS json
    LANGUAGE plpgsql
    AS $$
declare 
uid integer;
code_cat integer;
rec record;
names text[];
begin
	-- adds code headers
	-- params: idir, array of code headers
	uid := (select * from bctw.get_user_id(stridir));
	code_cat := (select code_category_id from bctw.get_bctw_code_category());

if uid is null then
	raise exception 'unable to find user with idir %', stridir;
end if;
	
for rec in select * from jsonb_populate_recordset(null::bctw.code_header, headerjson)	
	loop
		names := array_append(names, rec.code_header_name::text);
		if (select 1 from code_header ch where ch.code_header_name = rec.code_header_name)
		then raise exception 'code type % already exists.', rec.code_header_name;
		end if;
		insert into bctw.code_header (
			code_category_id,
			code_header_name,
			code_header_title,
			code_header_description,
			valid_from,
			valid_to,
			created_by_user_id
		)
		values (
			code_cat,
			rec.code_header_name,
			rec.code_header_title,
			rec.code_header_description,
			coalesce (rec.valid_from, now()),
			rec.valid_to,
			uid
		);
	end loop;
	return (select json_agg(t) from (select * from code_header ch where ch.code_header_name = any(names)) t);
END;
$$;


ALTER FUNCTION bctw.add_code_header(stridir text, headerjson jsonb) OWNER TO bctw;

--
-- Name: FUNCTION add_code_header(stridir text, headerjson jsonb); Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON FUNCTION bctw.add_code_header(stridir text, headerjson jsonb) IS 'adds new code headers, will throw exception if the code header exists.';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: collar_vendor_api_credentials; Type: TABLE; Schema: bctw; Owner: bctw
--

CREATE TABLE bctw.collar_vendor_api_credentials (
    api_name character varying(100) NOT NULL,
    api_url character varying(100),
    api_username bytea,
    api_password bytea
);


ALTER TABLE bctw.collar_vendor_api_credentials OWNER TO bctw;

--
-- Name: TABLE collar_vendor_api_credentials; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON TABLE bctw.collar_vendor_api_credentials IS 'used by data-collector cronjobs to retrieve API credentials';


--
-- Name: COLUMN collar_vendor_api_credentials.api_name; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.collar_vendor_api_credentials.api_name IS 'a name given to the credential';


--
-- Name: COLUMN collar_vendor_api_credentials.api_url; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.collar_vendor_api_credentials.api_url IS 'URI the API is accessed from';


--
-- Name: COLUMN collar_vendor_api_credentials.api_username; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.collar_vendor_api_credentials.api_username IS 'encrypted username of the API credential';


--
-- Name: COLUMN collar_vendor_api_credentials.api_password; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.collar_vendor_api_credentials.api_password IS 'encrypted password of the API credential';


--
-- Name: add_collar_vendor_credential(text, text, text, text, text); Type: FUNCTION; Schema: bctw; Owner: bctw
--

CREATE FUNCTION bctw.add_collar_vendor_credential(apiname text, apiurl text, apiusername text, apipassword text, publickey text) RETURNS SETOF bctw.collar_vendor_api_credentials
    LANGUAGE plpgsql
    AS $$
declare
begin
	return query
		INSERT INTO bctw.collar_vendor_api_credentials (api_name, api_url, api_username, api_password)
		values (
			apiname,
			apiurl,
			crypto.pgp_pub_encrypt(apiusername, crypto.dearmor(publickey)),
			crypto.pgp_pub_encrypt(apipassword, crypto.dearmor(publickey))
		)
		returning *;
END;
$$;


ALTER FUNCTION bctw.add_collar_vendor_credential(apiname text, apiurl text, apiusername text, apipassword text, publickey text) OWNER TO bctw;

--
-- Name: FUNCTION add_collar_vendor_credential(apiname text, apiurl text, apiusername text, apipassword text, publickey text); Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON FUNCTION bctw.add_collar_vendor_credential(apiname text, apiurl text, apiusername text, apipassword text, publickey text) IS '
Encrypts the provided credentials and stores them in the bctw.collar_vendor_api_credentials table.
Not currently exposed to the API layer.
The data_collector cronjobs use the bctw_dapi_v1.get_collar_vendor_credentials function to retrieve these credentials.
	apiname - a name for the credential.
	apiurl - the URL of the vendor API (not encrypted)
	apiusername - the username of the account used to login to the API (will be encrypted)
	apipassword - the password of the account used to login to the API (will be encrypted)
	publickey - the public key string used to encrypt the credentials (see the crypto pgp_pub_encrypt function)';


--
-- Name: add_historical_telemetry(text, jsonb); Type: FUNCTION; Schema: bctw; Owner: bctw
--

CREATE FUNCTION bctw.add_historical_telemetry(stridir text, pointjson jsonb) RETURNS json
    LANGUAGE plpgsql
    AS $$
DECLARE
	userid integer := bctw.get_user_id(stridir);
  current_ts timestamp := now();
  j json;
  i integer := 0;
BEGIN
  IF userid IS NULL THEN 
    RAISE EXCEPTION 'unable to find user with identifier %', stridir;
  END IF;
 
  FOR j IN SELECT jsonb_array_elements(pointjson)
    LOOP
     i := i + 1;
     -- todo: check all json props exist
     INSERT INTO bctw.historical_telemetry 
     VALUES (
       concat(j->>'device_id', j->>'date_recorded'),
	     (j->>'device_id')::integer,
	     j->>'device_vendor',
	     (j->>'date_recorded')::timestamp,
	     st_setSrid(st_point((j->>'longitude')::double precision, (j->>'latitude')::double precision),4326),
	     current_ts,
	     userid,
	     coalesce((j->>'valid_from')::timestamp, current_ts),
	     coalesce((j->>'valid_to')::timestamp, NULL)
	   )
	   ON CONFLICT (time_id)
	   DO NOTHING;
	 END LOOP;
	RETURN (SELECT json_agg(t) FROM (
	  SELECT device_id, device_vendor, date_recorded, geom FROM bctw.historical_telemetry
	) t);
END;
$$;


ALTER FUNCTION bctw.add_historical_telemetry(stridir text, pointjson jsonb) OWNER TO bctw;

--
-- Name: FUNCTION add_historical_telemetry(stridir text, pointjson jsonb); Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON FUNCTION bctw.add_historical_telemetry(stridir text, pointjson jsonb) IS 'inserts historical telemetry points. 
todo: throw when missing json key/values
todo: update materialized view with data from this table
todo: frequency instead of device_id?
note: not currently in use';


--
-- Name: delete_animal(text, uuid[]); Type: FUNCTION; Schema: bctw; Owner: bctw
--

CREATE FUNCTION bctw.delete_animal(stridir text, ids uuid[]) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE
  userid integer := bctw.get_user_id(stridir);
  current_ts timestamp WITHOUT time ZONE;
  aid uuid;
  cur_permission bctw.user_permission;
BEGIN
  IF userid IS NULL THEN
    RAISE exception 'unable find user with idir %', stridir;
  END IF;
 
 current_ts = now();
 
 FOREACH aid IN ARRAY ids LOOP
 	
 -- check critter exists
 	IF NOT EXISTS (
 		SELECT 1 from bctw.animal WHERE critter_id = aid
 		AND bctw.is_valid(valid_to) 		
 	) THEN RAISE EXCEPTION 'critter % does not exist', aid;
 	END IF;
 
 	-- confirm user has higher than 'observer' permissions to this animal
  cur_permission := bctw.get_user_animal_permission(userid, aid);
  IF cur_permission IS NULL OR cur_permission = ANY('{none, observer}'::bctw.user_permission[]) THEN
  	RAISE EXCEPTION 'you do not have permission to delete animal %', aid;
 	END IF; 
 
 	-- expire the user/animal link
	 UPDATE bctw.user_animal_assignment SET
	 	updated_at = current_ts,
	 	updated_by_user_id = userid,
	 	valid_to = current_ts
	 WHERE critter_id = aid
	 AND bctw.is_valid(valid_to);
	
	-- remove any collars attached to this critter
	UPDATE bctw.collar_animal_assignment SET
		updated_at = current_ts,
		updated_by_user_id = userid,
		valid_to = current_ts
	WHERE critter_id = aid
	AND bctw.is_valid(valid_to);

	-- expire the animal record itself
	UPDATE bctw.animal SET
		updated_at = current_ts,
		updated_by_user_id = userid,
  		valid_to = current_ts
 	WHERE critter_id = aid
 	AND bctw.is_valid(valid_to);
 
 END LOOP;

 RETURN TRUE;
END;
$$;


ALTER FUNCTION bctw.delete_animal(stridir text, ids uuid[]) OWNER TO bctw;

--
-- Name: FUNCTION delete_animal(stridir text, ids uuid[]); Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON FUNCTION bctw.delete_animal(stridir text, ids uuid[]) IS 'Expires the list of critter IDs. If a collar is attached to any of the critters specified, they will be unattached. This function will also expire any user/animal permissions.';


--
-- Name: delete_collar(text, uuid[]); Type: FUNCTION; Schema: bctw; Owner: bctw
--

CREATE FUNCTION bctw.delete_collar(stridir text, ids uuid[]) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE
  userid integer := bctw.get_user_id(stridir);
  current_ts timestamp without time zone;
  cid uuid;
BEGIN
  IF userid IS NULL THEN
    RAISE exception 'unable find user with idir %', stridir;
  END IF;
  
 -- todo: collar access permission??
 current_ts = now();

 FOREACH cid IN ARRAY ids LOOP
 	-- check collar exists
 	IF NOT EXISTS (
 		SELECT 1 FROM bctw.collar WHERE collar_id = cid
 		AND bctw.is_valid(valid_to) 		
 	) THEN RAISE EXCEPTION 'collar % does not exist', cid;
 	END IF;
	
	-- if there is a critter attached to this collar, remove it
	update bctw.collar_animal_assignment set
		updated_at = current_ts,
		updated_by_user_id = userid,
		valid_to = current_ts
	where collar_id = cid
	and bctw.is_valid(valid_to);

  -- todo: expire/delete the user/device link

	-- expire the collar record
	update bctw.collar set
		updated_at = current_ts,
		updated_by_user_id = userid,
  		valid_to = current_ts
 	where collar_id = cid
 	and bctw.is_valid(valid_to);
 
 end loop;

 return true;
END;
$$;


ALTER FUNCTION bctw.delete_collar(stridir text, ids uuid[]) OWNER TO bctw;

--
-- Name: FUNCTION delete_collar(stridir text, ids uuid[]); Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON FUNCTION bctw.delete_collar(stridir text, ids uuid[]) IS 'Expires the list of collar IDs. If a critter is attached to the collar, it will be removed.
todo: expire/delete the user/device link';


--
-- Name: delete_user(text, integer); Type: FUNCTION; Schema: bctw; Owner: bctw
--

CREATE FUNCTION bctw.delete_user(stridir text, useridtodelete integer) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE
  userid integer := bctw.get_user_id (stridir);
  userrole bctw.role_type;
  current_ts timestamp without time ZONE := now();
BEGIN
  IF userid IS NULL THEN
    RAISE EXCEPTION 'unable find user %', stridir;
  END IF;
 
  userrole := bctw.get_user_role(stridir);
  IF userrole IS NULL OR userrole != 'administrator' THEN
    RAISE EXCEPTION 'you must be an administrator to perform this action';
  END IF;
 
 -- todo - should this be deleted? or add valid_from/to columns to user_role_xref table?
 DELETE FROM bctw.user_role_xref
 WHERE user_id = useridtodelete;

 -- expire the user's animal access: 
 UPDATE bctw.user_animal_assignment
 SET
   valid_to = current_ts,
   updated_at = current_ts,
   updated_by_user_id = userid
 WHERE user_id = useridtodelete
 AND is_valid(valid_to);

 UPDATE bctw.USER
 SET 
   valid_to = current_ts,
   updated_at = current_ts,
   updated_by_user_id = userid
 WHERE id = useridtodelete;
 
  RETURN TRUE;
END;
$$;


ALTER FUNCTION bctw.delete_user(stridir text, useridtodelete integer) OWNER TO bctw;

--
-- Name: FUNCTION delete_user(stridir text, useridtodelete integer); Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON FUNCTION bctw.delete_user(stridir text, useridtodelete integer) IS 'expires a user. also removes their user role and animal access. User performing the action must be of role type administrator.';


--
-- Name: execute_permission_request(text, integer, boolean, text); Type: FUNCTION; Schema: bctw; Owner: bctw
--

CREATE FUNCTION bctw.execute_permission_request(stridir text, requestid integer, isgrant boolean, denycomment text DEFAULT NULL::text) RETURNS SETOF jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
  userid integer := bctw.get_user_id(stridir);     -- the admin user granting the request
  current_ts timestamp without time ZONE := now();
  userrole bctw.role_type;											
  rr record;																			 -- the fetched request permission record
BEGIN
	
  IF userid IS NULL THEN
    RAISE EXCEPTION 'unable find user with identifier %', stridir;
  END IF;
 
 -- confirm this user is an admin
 userrole := get_user_role(stridir);
 IF userrole 
 	IS NULL OR userrole != 'administrator' THEN 
  	RAISE EXCEPTION 'you must be an administrator to execute a permission request';
 END IF;

 SELECT * FROM permission_request INTO rr WHERE request_id = requestid;

 IF rr IS NULL OR NOT is_valid(rr.valid_to) THEN 
 	RAISE EXCEPTION 'request % is missing or expired', requestid;
 END IF; 

 -- grant the permissions, note this is a separate function from the one exposed to the API 
 -- that accepts an additional userid to be used as the requestor
 IF isgrant THEN 
	 PERFORM bctw.grant_critter_to_user(
	 	 stridir,
	 	 -- use the requestor as the user performing the grant so it can be tracked
	   rr.requested_by_user_id, 
	   UNNEST(rr.user_id_list),
	   -- no longer an array, so convert it to one
	   jsonb_build_array(rr.critter_permission_list)
	 );
 END IF;
	
 -- expire the request
 UPDATE permission_request
 SET 
 	 status = CASE WHEN isgrant THEN 'granted'::onboarding_status ELSE 'denied'::onboarding_status END,
   was_denied_reason = CASE WHEN isgrant THEN NULL ELSE denycomment END,
   valid_to = current_ts
 WHERE request_id = rr.request_id;

 RETURN query SELECT to_jsonb(t) FROM (
 	SELECT * FROM bctw_dapi_v1.permission_requests_v WHERE request_id = requestid
 ) t;
  
END;
$$;


ALTER FUNCTION bctw.execute_permission_request(stridir text, requestid integer, isgrant boolean, denycomment text) OWNER TO bctw;

--
-- Name: FUNCTION execute_permission_request(stridir text, requestid integer, isgrant boolean, denycomment text); Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON FUNCTION bctw.execute_permission_request(stridir text, requestid integer, isgrant boolean, denycomment text) IS 'rejects or approves a user-critter permission request';


--
-- Name: get_animal_collar_assignment_history(text, uuid); Type: FUNCTION; Schema: bctw; Owner: bctw
--

CREATE FUNCTION bctw.get_animal_collar_assignment_history(stridir text, animalid uuid) RETURNS SETOF json
    LANGUAGE plpgsql
    AS $$
declare
userid integer := bctw.get_user_id(stridir);
begin
	-- returns collar assignment history for the animal id supplied
	if userid is null
		then raise exception 'unable to find user with idir %', stridir;
	end if;

	if not exists (select 1 from animal where critter_id = animalid)
		then raise exception 'animal with id % does not exist!', animalid;
	end if;

    return query
    with res as (
    	select 
    		ca.assignment_id,
    		ca.collar_id,
    		c.device_id,
    		(SELECT code.code_description FROM code WHERE code.code_id = c.device_make) AS device_make,
    		c.frequency,
    		ca.valid_from AS data_life_start,
    		ca.valid_to AS data_life_end,
    		ca.attachment_start,
    		ca.attachment_end
		from collar_animal_assignment ca
		join collar c on c.collar_id = ca.collar_id
		where ca.critter_id = animalid
		-- todo: verify this is correct record 
		and c.collar_transaction_id = bctw.get_closest_collar_record(ca.collar_id, ca.valid_from)
    ) select row_to_json(t) from (select * from res) t;
END;
$$;


ALTER FUNCTION bctw.get_animal_collar_assignment_history(stridir text, animalid uuid) OWNER TO bctw;

--
-- Name: FUNCTION get_animal_collar_assignment_history(stridir text, animalid uuid); Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON FUNCTION bctw.get_animal_collar_assignment_history(stridir text, animalid uuid) IS 'for a given critter_id, retrieve it''s collar assignment history from the bctw.collar_animal_assignment table';


--
-- Name: get_attached_critter_from_device(integer, text); Type: FUNCTION; Schema: bctw; Owner: bctw
--

CREATE FUNCTION bctw.get_attached_critter_from_device(deviceid integer, make text) RETURNS uuid
    LANGUAGE plpgsql
    AS $$
DECLARE
	collarid uuid;
	critterid uuid;
BEGIN
	collarid := (
		SELECT collar_id FROM collar
		WHERE device_id = deviceid
		AND device_make = bctw.get_code_id('device_make', make)
		AND is_valid(valid_to)
	);
	IF collarid IS NULL THEN 
		RETURN NULL;
	END IF;
	critterid := (SELECT critter_id FROM collar_animal_assignment WHERE valid_to IS NULL AND collar_id = collarid);
	RETURN critterid;
END;
$$;


ALTER FUNCTION bctw.get_attached_critter_from_device(deviceid integer, make text) OWNER TO bctw;

--
-- Name: get_closest_collar_record(uuid, timestamp with time zone); Type: FUNCTION; Schema: bctw; Owner: bctw
--

CREATE FUNCTION bctw.get_closest_collar_record(collarid uuid, t timestamp with time zone) RETURNS uuid
    LANGUAGE plpgsql
    AS $$
declare tid uuid;
begin
	-- returns the closest valid collar record from the param t 
	-- looks at the valid_from column
	select c.collar_transaction_id 
	into tid
	from bctw.collar c
	where c.collar_id = collarid
	order by abs(extract(epoch from (c.valid_from - t)))
	limit 1;

	return tid;
END;
$$;


ALTER FUNCTION bctw.get_closest_collar_record(collarid uuid, t timestamp with time zone) OWNER TO bctw;

--
-- Name: FUNCTION get_closest_collar_record(collarid uuid, t timestamp with time zone); Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON FUNCTION bctw.get_closest_collar_record(collarid uuid, t timestamp with time zone) IS 'retrieves the collar_transaction_id with the closest valid_from after the timestamp parameter t.';


--
-- Name: get_code_as_json(integer); Type: FUNCTION; Schema: bctw; Owner: bctw
--

CREATE FUNCTION bctw.get_code_as_json(codeid integer) RETURNS SETOF json
    LANGUAGE plpgsql
    AS $$
BEGIN 
	RETURN query SELECT row_to_json(t) FROM (
    	SELECT code_id AS id,
    	  code_name AS code,
    		code_description AS description
    	FROM bctw.code WHERE code.code_id = codeid
    	AND is_valid(valid_to)
  ) t;
END;
$$;


ALTER FUNCTION bctw.get_code_as_json(codeid integer) OWNER TO bctw;

--
-- Name: get_code_id(text, text); Type: FUNCTION; Schema: bctw; Owner: bctw
--

CREATE FUNCTION bctw.get_code_id(codeheader text, description text) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE code_id integer;
BEGIN
	IF description IS NULL
	  THEN RETURN NULL;
	END IF;

	code_id := (
	  SELECT c.code_id FROM bctw.code c
	  INNER JOIN bctw.code_header ch
	  ON c.code_header_id = ch.code_header_id
	  WHERE lower(ch.code_header_name) = lower(codeheader)
	  AND is_valid(c.valid_to)
	  AND (lower(c.code_description) = lower(description) or lower(c.code_name) = lower(description))
	  LIMIT 1
	);
	IF code_id IS NULL THEN
	  RETURN NULL;
	END IF;
	RETURN code_id;
END;
$$;


ALTER FUNCTION bctw.get_code_id(codeheader text, description text) OWNER TO bctw;

--
-- Name: FUNCTION get_code_id(codeheader text, description text); Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON FUNCTION bctw.get_code_id(codeheader text, description text) IS 'retrieve a code records ID (code.code_id) from a code_header.code_header_name and either code_name or code_description. Returns NULL if it cannot be found.';


--
-- Name: get_code_id_with_error(text, anyelement); Type: FUNCTION; Schema: bctw; Owner: bctw
--

CREATE FUNCTION bctw.get_code_id_with_error(codeheader text, val anyelement) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE code_id integer;
BEGIN
	IF val IS NULL
	  THEN RETURN NULL;
	END IF;

	code_id := bctw.get_code_id(codeheader, val);

	IF code_id IS NULL THEN
	  RAISE EXCEPTION 'unable to determine valid code. Code type "%" and value "%"', codeheader, val;
	END IF;
	RETURN code_id;
END;
$$;


ALTER FUNCTION bctw.get_code_id_with_error(codeheader text, val anyelement) OWNER TO bctw;

--
-- Name: FUNCTION get_code_id_with_error(codeheader text, val anyelement); Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON FUNCTION bctw.get_code_id_with_error(codeheader text, val anyelement) IS 'retrieve a code records ID (code.code_id) given a .code_header_name and either code_name or code_description. Throws an exception if it cannot be found.';


--
-- Name: get_code_id_with_error(text, text); Type: FUNCTION; Schema: bctw; Owner: bctw
--

CREATE FUNCTION bctw.get_code_id_with_error(codeheader text, description text) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE code_id integer;
BEGIN
	IF description IS NULL
	  THEN RETURN NULL;
	END IF;
	
	code_id := bctw.get_code_id(codeheader, description);

	IF code_id IS NULL THEN
	  RAISE EXCEPTION 'unable to determine valid code. Code type "%" and value "%"', codeheader, description;
	END IF;
	RETURN code_id;
END;
$$;


ALTER FUNCTION bctw.get_code_id_with_error(codeheader text, description text) OWNER TO bctw;

--
-- Name: FUNCTION get_code_id_with_error(codeheader text, description text); Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON FUNCTION bctw.get_code_id_with_error(codeheader text, description text) IS 'retrieve a code records ID (code.code_id) given a .code_header_name and either code_name or code_description. Throws an exception if it cannot be found.';


--
-- Name: get_code_value(text, text); Type: FUNCTION; Schema: bctw; Owner: bctw
--

CREATE FUNCTION bctw.get_code_value(codeheader text, description text) RETURNS text
    LANGUAGE plpgsql
    AS $$
declare code_val text;
begin
	if description is null
	  then return null;
	end if;

	code_val := (
	  select c.code_name::text from bctw.code c
	  inner join bctw.code_header ch
	  ON c.code_header_id = ch.code_header_id
	  where ch.code_header_name = codeheader
	  and (c.code_description = description or c.code_name = description)
	);
	if code_val is null then
--	  raise exception 'unable to retrieve valid code from header % and value %', codeheader, description;
	  return null;
	end if;
	return code_val;
END;
$$;


ALTER FUNCTION bctw.get_code_value(codeheader text, description text) OWNER TO bctw;

--
-- Name: FUNCTION get_code_value(codeheader text, description text); Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON FUNCTION bctw.get_code_value(codeheader text, description text) IS 'given a code description, attempts to retrieve the code (code.code_name). returns the original parameter if it does not exist.';


--
-- Name: get_last_device_transmission(uuid); Type: FUNCTION; Schema: bctw; Owner: bctw
--

CREATE FUNCTION bctw.get_last_device_transmission(collarid uuid) RETURNS TABLE(latest_transmission timestamp with time zone)
    LANGUAGE plpgsql
    AS $$
BEGIN
	RETURN query SELECT date_recorded FROM latest_transmissions WHERE collar_id = collarid;
end;
$$;


ALTER FUNCTION bctw.get_last_device_transmission(collarid uuid) OWNER TO bctw;

--
-- Name: get_species_id_with_error(text); Type: FUNCTION; Schema: bctw; Owner: bctw
--

CREATE FUNCTION bctw.get_species_id_with_error(commonname text) RETURNS character varying
    LANGUAGE plpgsql
    AS $$
DECLARE speciesid varchar;
BEGIN
	IF commonname IS NULL THEN 
		RETURN NULL;
	END IF;

	IF EXISTS (SELECT 1 FROM species WHERE upper(species_code) = upper(commonname)) THEN
		RETURN upper(commonname);
	END IF;

	speciesid := (
	  SELECT s.species_code
	  FROM bctw.species s
	  WHERE lower(s.species_eng_name) = lower(commonname)
	  LIMIT 1
	);

	IF speciesid IS NULL THEN 
	  RAISE EXCEPTION 'unable to find species code with common name "%"', commonname;
	END IF;
	RETURN speciesid; 
END;
$$;


ALTER FUNCTION bctw.get_species_id_with_error(commonname text) OWNER TO bctw;

--
-- Name: get_species_name(character varying); Type: FUNCTION; Schema: bctw; Owner: bctw
--

CREATE FUNCTION bctw.get_species_name(code character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $$
DECLARE
species varchar;
BEGIN
  	species := (
  		SELECT species_eng_name FROM bctw.species
  		WHERE species_code = code
	);
RETURN species;
END;
$$;


ALTER FUNCTION bctw.get_species_name(code character varying) OWNER TO bctw;

--
-- Name: get_telemetry(text, timestamp with time zone, timestamp with time zone); Type: FUNCTION; Schema: bctw; Owner: bctw
--

CREATE FUNCTION bctw.get_telemetry(stridir text, starttime timestamp with time zone, endtime timestamp with time zone) RETURNS TABLE(critter_id uuid, species character varying, population_unit character varying, geom public.geometry, date_recorded timestamp with time zone, vendor_merge_id bigint, geojson jsonb)
    LANGUAGE plpgsql
    AS $$
DECLARE
  userid integer := get_user_id(stridir);
BEGIN
  IF userid IS NULL THEN
    RAISE EXCEPTION 'unable find username %', stridir;
  END IF;
  RETURN QUERY
  SELECT
    a.critter_id,
--    a.critter_transaction_id,
--    c.collar_id,
--    c.collar_transaction_id,
    (SELECT species_eng_name FROM species WHERE species_code = a.species) AS species,
--    a.wlh_id,
--    a.animal_id,
--    vmv.device_id,
--    vmv.device_vendor,
--    c.frequency,
--    (SELECT code_description FROM code WHERE code.code_id = a.animal_status)::text AS animal_status,
--    (SELECT code_description FROM code WHERE code.code_id = a.sex)::text AS sex,
--    (SELECT code_description FROM code WHERE code.code_id = c.device_status)::text AS device_status,
    (SELECT code_description FROM code WHERE code.code_id = a.population_unit) AS population_unit,
--    a.collective_unit::text,
    vmv.geom,
    vmv.date_recorded,
    row_number() OVER (ORDER BY 1::integer) AS VENDOR_MERGE_ID,
	 	JSONB_BUILD_OBJECT('type', 'Feature', 'id', row_number() OVER (ORDER BY 1::integer), 'geometry', ST_ASGEOJSON (VMV.geom)::jsonb, 'properties', 
	 		JSONB_BUILD_OBJECT(
	 			'collar_id', 		c.collar_id,
	 			'critter_id', 		a.critter_id,
	 			'species', 			(SELECT species_eng_name FROM species WHERE species_code = a.species),
	 			'wlh_id', 			a.wlh_id,
	 			'animal_id', 		a.animal_id,
	 			'device_id', 		vmv.device_id,
	 			'device_vendor', 	vmv.device_vendor,
	 			'frequency', 		c.frequency,
	 			'frequency_unit', 	(SELECT code_description FROM code WHERE code.code_id = c.frequency_unit),
	 			'animal_status', 	(SELECT code_description FROM code WHERE code.code_id = a.animal_status),
	 			'mortality_date', 	a.mortality_date,
	 			'sex', 				(SELECT code_description FROM code WHERE code.code_id = a.sex),
	 			'device_status', 	(SELECT code_description FROM code WHERE code.code_id = c.device_status),
	 			'population_unit',  (SELECT code_description FROM code WHERE code.code_id = a.population_unit),
	 			'collective_unit', 	a.collective_unit,
	 			'date_recorded', 	vmv.date_recorded,
	 			'map_colour', 		(SELECT concat(code_name, ',', code_description_long) from bctw.code where code_id = a.map_colour),
	 			'capture_date', 	a.capture_date -- fixme (should be the oldest capture date for this particular device id assignment)
	 	 )
 	  ) AS geojson
-- 	  , (select code_name from bctw.code where code_id = a.map_colour)::text as map_colour
 	
  FROM bctw.vendor_merge_view_no_critter vmv
    JOIN bctw.collar c
      ON c.device_id = vmv.device_id and (SELECT code_description FROM code WHERE code.code_id = c.device_make) = vmv.device_vendor
      
    JOIN bctw.collar_animal_assignment caa 
      ON caa.collar_id = c.collar_id
      
	JOIN bctw.animal a
      ON a.critter_id = caa.critter_id
  WHERE
    vmv.date_recorded <@ tstzrange(starttime, endtime)
  -- find the closet animal record
    AND a.critter_transaction_id = (
  	  SELECT critter_transaction_id FROM animal a3 
	  WHERE a3.critter_id = a.critter_id 
	  ORDER BY abs(EXTRACT(epoch FROM (a3.valid_from - vmv.date_recorded)))
	  LIMIT 1
  	)
  -- find the closest device record
	AND c.collar_transaction_id = (
	  SELECT collar_transaction_id FROM collar c3
	  WHERE c3.collar_id = c.collar_id
	  ORDER BY abs(EXTRACT(epoch FROM (c3.valid_from - vmv.date_recorded)))
	  LIMIT 1
	) 
	-- check the user has at least 'observer' permission for the animal
    AND caa.critter_id IN (
	    SELECT a.critter_id 
	    FROM animal a
			INNER JOIN user_animal_assignment ua ON a.critter_id = ua.critter_id
			WHERE ua.user_id = userid
			AND is_valid(a.valid_to)
			AND is_valid(ua.valid_to)
			OR a.owned_by_user_id = userid
			AND is_valid(a.valid_to)
    );
--    AND bctw.is_valid(vmv.date_recorded::timestamp, caa.valid_from::timestamp, caa.valid_to::timestamp);
END;
$$;


ALTER FUNCTION bctw.get_telemetry(stridir text, starttime timestamp with time zone, endtime timestamp with time zone) OWNER TO bctw;

--
-- Name: get_udf(text, text); Type: FUNCTION; Schema: bctw; Owner: bctw
--

CREATE FUNCTION bctw.get_udf(username text, udf_type text) RETURNS SETOF jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
  userid integer := bctw.get_user_id(username);
 	u jsonb;
BEGIN
	IF userid IS NULL THEN
    RAISE exception 'couldn\t find user with username %', username;
	END IF;

	u := ( SELECT udf FROM user_defined_field WHERE user_id = userid AND is_valid(valid_to));
	RETURN query SELECT * FROM jsonb_array_elements(u) t WHERE t->>'type' = udf_type;

END;
$$;


ALTER FUNCTION bctw.get_udf(username text, udf_type text) OWNER TO bctw;

--
-- Name: get_unattached_telemetry(text, timestamp with time zone, timestamp with time zone); Type: FUNCTION; Schema: bctw; Owner: bctw
--

CREATE FUNCTION bctw.get_unattached_telemetry(useridentifier text, starttime timestamp with time zone, endtime timestamp with time zone) RETURNS SETOF bctw.unattached_telemetry
    LANGUAGE plpgsql
    AS $$
DECLARE
  USERID integer := BCTW.GET_USER_ID(useridentifier);
BEGIN
  IF USERID IS NULL THEN
    RAISE exception 'UNABLE FIND USER WITH IDIR %', useridentifier;
  END IF;
 
  RETURN QUERY
  select
  	c.collar_id,
  	c.device_id,
  	vmv.geom,
  	vmv.date_recorded,
 	JSONB_BUILD_OBJECT('type', 'Feature', 'id', 0 - row_number() OVER (ORDER BY 1::integer), 'geometry', ST_ASGEOJSON (VMV.geom)::jsonb, 'properties', 
 		JSONB_BUILD_OBJECT(
 			'collar_transaction_id', c.collar_transaction_id,
 			'collar_id', c.collar_id,
 			'device_id', vmv.device_id,
 			'device_vendor', vmv.device_vendor,
 			'frequency', c.frequency,
 			'frequency_unit', (SELECT code_description FROM code WHERE code.code_id = c.frequency_unit),
 			'device_status', (SELECT code_description FROM code WHERE code.code_id = c.device_status),
 			'date_recorded', vmv.date_recorded
 		)
 	) AS geojson
  FROM bctw.vendor_merge_view_no_critter vmv
    JOIN bctw.collar c
      ON c.device_id = VMV.device_id AND (SELECT code_description FROM code WHERE code.code_id = c.device_make) = vmv.device_vendor
  WHERE
    vmv.date_recorded <@ tstzrange(starttime, endtime)
    -- find the closest collar record to the telemetry point's recorded timestamp
	AND c.collar_transaction_id = (
	  SELECT collar_transaction_id FROM collar c3
	  WHERE c3.collar_id = c.collar_id
	  ORDER BY abs(EXTRACT(epoch FROM (c3.valid_from - vmv.date_recorded)))
	  LIMIT 1
	)
	-- only devices that:
	-- a) are unassigned
	-- b) that this user created, unless they are an admin.
	and c.collar_id = any(bctw.get_user_unassigned_collar_access(useridentifier))
	-- only non deleted collars
	and is_valid(c.valid_to);
END;
$$;


ALTER FUNCTION bctw.get_unattached_telemetry(useridentifier text, starttime timestamp with time zone, endtime timestamp with time zone) OWNER TO bctw;

--
-- Name: FUNCTION get_unattached_telemetry(useridentifier text, starttime timestamp with time zone, endtime timestamp with time zone); Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON FUNCTION bctw.get_unattached_telemetry(useridentifier text, starttime timestamp with time zone, endtime timestamp with time zone) IS 'what the 2D map uses to display data for animals with no devices attached.
todo remove is_valid for expired devices?';


--
-- Name: get_user_animal_permission(integer, uuid); Type: FUNCTION; Schema: bctw; Owner: bctw
--

CREATE FUNCTION bctw.get_user_animal_permission(userid integer, critterid uuid) RETURNS bctw.user_permission
    LANGUAGE plpgsql
    AS $$
DECLARE
  critter_permission bctw.user_permission;
BEGIN
	-- if the user is an administrator...give them 'change' permission?
	
	IF EXISTS (
	  SELECT urt.role_type
	  FROM user_role_type urt
	  JOIN bctw.user_role_xref rx on urt.role_id = rx.role_id
		JOIN bctw.user u on u.id = rx.user_id 
	  WHERE u.id = userid
	  AND urt.role_type = 'administrator'
	) THEN RETURN 'admin'::user_permission;
  END IF;
 
  IF EXISTS (
  	SELECT 1 FROM animal
  	WHERE critter_id = critterid
  	AND is_valid(valid_to)
  	AND owned_by_user_id = userid
  ) THEN RETURN 'manager'::user_permission;
  END IF;
 
	critter_permission := (
    SELECT permission_type 
    FROM user_animal_assignment uaa 
    WHERE user_id = userid 
    AND critter_id = critterid
    AND is_valid(valid_to)
  );
 
  RETURN critter_permission;
END;
$$;


ALTER FUNCTION bctw.get_user_animal_permission(userid integer, critterid uuid) OWNER TO bctw;

--
-- Name: FUNCTION get_user_animal_permission(userid integer, critterid uuid); Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON FUNCTION bctw.get_user_animal_permission(userid integer, critterid uuid) IS 'returns the "user_permission" type for a given user identifier and bctw.critter_id';


--
-- Name: get_user_animal_permission(text, uuid); Type: FUNCTION; Schema: bctw; Owner: bctw
--

CREATE FUNCTION bctw.get_user_animal_permission(stridir text, critterid uuid) RETURNS bctw.user_permission
    LANGUAGE plpgsql
    AS $$
DECLARE
  userid integer := bctw.get_user_id(stridir);
BEGIN
	IF userid IS NULL THEN 
		RAISE EXCEPTION 'could not find username %', stridir;
	END IF;
	RETURN bctw.get_user_animal_permission(userid, critterid);
END;
$$;


ALTER FUNCTION bctw.get_user_animal_permission(stridir text, critterid uuid) OWNER TO bctw;

--
-- Name: FUNCTION get_user_animal_permission(stridir text, critterid uuid); Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON FUNCTION bctw.get_user_animal_permission(stridir text, critterid uuid) IS 'overloaded instance of the function that takes the IDIR/BCEID instead of the user_id as a parameter.';


--
-- Name: get_user_collar_access(text); Type: FUNCTION; Schema: bctw; Owner: bctw
--

CREATE FUNCTION bctw.get_user_collar_access(stridir text) RETURNS uuid[]
    LANGUAGE plpgsql
    AS $$
declare
animalids uuid[];
user_id integer := bctw.get_user_id(stridir);
begin
	animalids = bctw.get_user_critter_access(stridir);
	RETURN (
		SELECT ARRAY(
		  SELECT collar_id
		  FROM bctw.collar_animal_assignment
			WHERE animal_id = ANY(animalids)
		UNION ALL
		  SELECT c.collar_id FROM collar c
		  WHERE is_valid(c.valid_to)
		  AND c.owned_by_user_id = user_id
		)
	);
	
END;
$$;


ALTER FUNCTION bctw.get_user_collar_access(stridir text) OWNER TO bctw;

--
-- Name: FUNCTION get_user_collar_access(stridir text); Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON FUNCTION bctw.get_user_collar_access(stridir text) IS 'retrieves a list of collars a user has view/change permission to, based on the user''s critter access (see get_user_critter_access function) or the collar''s owner_id';


--
-- Name: get_user_collar_permission(integer, uuid); Type: FUNCTION; Schema: bctw; Owner: bctw
--

CREATE FUNCTION bctw.get_user_collar_permission(userid integer, collarid uuid) RETURNS bctw.user_permission
    LANGUAGE plpgsql
    AS $$
DECLARE
  collar_permission bctw.user_permission;
  attached_critter uuid;
BEGIN
	-- if the device was created by this user, they are a 'manager'
	IF EXISTS (
		SELECT 1 FROM bctw.collar 
		WHERE collar_id = collarid
		AND owned_by_user_id = userid
	) THEN RETURN 'manager'::bctw.user_permission;
	END IF;

	attached_critter := (
		SELECT critter_id FROM collar_animal_assignment
		WHERE collar_id = collarid
		-- todo: should this just be the most recent attachment even if not active??
		AND is_valid(valid_to)
	);

	-- otherwise the permission is based on the the animal the device is attached to.
--	RETURN COALESCE(bctw.get_user_animal_permission(userid, attached_critter), 'none');
	RETURN get_user_animal_permission(userid, attached_critter);
END;
$$;


ALTER FUNCTION bctw.get_user_collar_permission(userid integer, collarid uuid) OWNER TO bctw;

--
-- Name: get_user_collar_permission(text, uuid); Type: FUNCTION; Schema: bctw; Owner: bctw
--

CREATE FUNCTION bctw.get_user_collar_permission(stridir text, collarid uuid) RETURNS bctw.user_permission
    LANGUAGE plpgsql
    AS $$
DECLARE
  userid integer := bctw.get_user_id(stridir);
BEGIN
	IF userid IS NULL THEN 
		RAISE EXCEPTION 'could not find user with idir %', stridir;
	END IF;
	RETURN bctw.get_user_collar_permission(userid, collarid);
END;
$$;


ALTER FUNCTION bctw.get_user_collar_permission(stridir text, collarid uuid) OWNER TO bctw;

--
-- Name: get_user_critter_access(text); Type: FUNCTION; Schema: bctw; Owner: bctw
--

CREATE FUNCTION bctw.get_user_critter_access(stridir text) RETURNS uuid[]
    LANGUAGE plpgsql
    AS $$
declare
	userid integer := bctw.get_user_id(stridir);
  ids uuid[];
begin
	-- returns a list of uuids (critter ids user has access to)
	if userid is null
		then raise exception 'unable to find user with idir %', stridir;
	end if;

  WITH 
  owner_ids AS (
    SELECT critter_id FROM animal
    WHERE is_valid(valid_to)
    AND owned_by_user_id = userid
  ),
  has_perm AS (
  	SELECT a.critter_id
		FROM animal a
		INNER JOIN user_animal_assignment ua ON a.critter_id = ua.critter_id
		WHERE ua.user_id = userid
		AND bctw.is_valid(a.valid_to)
		AND bctw.is_valid(ua.valid_to) -- remove this?
  ),
  all_p AS (SELECT * FROM owner_ids UNION SELECT * FROM has_perm GROUP BY critter_id)
  SELECT array_agg(critter_id) INTO ids FROM all_p;
 
 RETURN ids;

END;
$$;


ALTER FUNCTION bctw.get_user_critter_access(stridir text) OWNER TO bctw;

--
-- Name: FUNCTION get_user_critter_access(stridir text); Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON FUNCTION bctw.get_user_critter_access(stridir text) IS 'returns an array of critter IDs (bctw.animal.id column) that a user currently has view, change, manager, or editor permission to.';


--
-- Name: get_user_id(text); Type: FUNCTION; Schema: bctw; Owner: bctw
--

CREATE FUNCTION bctw.get_user_id(stridir text) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
  uid integer;
BEGIN
  uid := (
    SELECT
      u.id
    FROM
      bctw.user u
    WHERE
      u.idir = stridir
      OR u.bceid = stridir);
  RETURN uid;
END;
$$;


ALTER FUNCTION bctw.get_user_id(stridir text) OWNER TO bctw;

--
-- Name: FUNCTION get_user_id(stridir text); Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON FUNCTION bctw.get_user_id(stridir text) IS 'provided with an IDIR or BCEID, retrieve the user_id. Returns NULL if neither can be found.';


--
-- Name: get_user_id_with_domain(text, text); Type: FUNCTION; Schema: bctw; Owner: bctw
--

CREATE FUNCTION bctw.get_user_id_with_domain(domain_type text, identifier text) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE uid integer;
BEGIN
	uid := (
		CASE 
			WHEN lower(domain_type) = 'bceid' THEN (SELECT id FROM bctw.USER WHERE bceid = identifier AND is_valid(valid_to))
			WHEN lower(domain_type) = 'idir' THEN (SELECT id FROM bctw.USER WHERE idir = identifier AND is_valid(valid_to))
		END
	);
RETURN uid;
END;
$$;


ALTER FUNCTION bctw.get_user_id_with_domain(domain_type text, identifier text) OWNER TO bctw;

--
-- Name: get_user_role(text); Type: FUNCTION; Schema: bctw; Owner: bctw
--

CREATE FUNCTION bctw.get_user_role(stridir text) RETURNS text
    LANGUAGE plpgsql
    AS $$
declare
	user_role text;
	userid integer := bctw.get_user_id(stridir);
begin
	
	if userid is null 
	THEN RAISE EXCEPTION 'couldnt find user with IDIR %', strIdir;
	end if;
	-- fixme: user can have multiple roles, this will only return the first one
	select urt.role_type into user_role
	from bctw.user_role_type urt
	join bctw.user_role_xref rx on urt.role_id = rx.role_id
	join bctw.user u on u.id = rx.user_id 
	where u.id = userid;

	return user_role;
END;
$$;


ALTER FUNCTION bctw.get_user_role(stridir text) OWNER TO bctw;

--
-- Name: FUNCTION get_user_role(stridir text); Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON FUNCTION bctw.get_user_role(stridir text) IS 'for a given user, return their role in a string format.
todo: user can have multiple roles, this will only return the first one';


--
-- Name: get_user_unassigned_collar_access(text); Type: FUNCTION; Schema: bctw; Owner: bctw
--

CREATE FUNCTION bctw.get_user_unassigned_collar_access(useridentifier text) RETURNS uuid[]
    LANGUAGE plpgsql
    AS $$
declare
userid integer := bctw.get_user_id(useridentifier);
userrole text;
unassignedids uuid[];
begin
	userrole := bctw.get_user_role(useridentifier);
	unassignedids := (
		select array_agg(collar_id)
		from bctw.collar c where c.collar_id not in (
	      select collar_id 
          from collar_animal_assignment caa
	      where is_valid(caa.valid_to)
	    )
	);
	-- users with admin role have access to all unassigned devices
	if userrole = 'administrator'
    then return unassignedids;
	end if;
	-- non-admin users only have access to devices they created
	return (
		select array_agg(c.collar_id)
		from bctw.collar c
		where c.collar_id = any(unassignedids)
		and c.created_by_user_id = userid
	);
END;
$$;


ALTER FUNCTION bctw.get_user_unassigned_collar_access(useridentifier text) OWNER TO bctw;

--
-- Name: grant_critter_to_user(text, integer, jsonb); Type: FUNCTION; Schema: bctw; Owner: bctw
--

CREATE FUNCTION bctw.grant_critter_to_user(usergranting text, usergranted integer, animalpermission jsonb) RETURNS json
    LANGUAGE plpgsql
    AS $$
DECLARE
user_id_granting integer := bctw.get_user_id(usergranting);
user_granting_role TEXT;
uar record; -- user_animal_assignment row populated from animalpermission parameter json
new_id uuid;
assignment_ids uuid[];
current_ts timestamp WITHOUT time ZONE;
BEGIN
	-- animalpermission should be a json string containing an array of objects with two properties:
	-- { critter_id: string, permission_type: bctw.user_critter_permission }
	
	IF user_id_granting IS NULL
		THEN RAISE EXCEPTION 'unable to find the user % trying to grant permissions', usergranting;
	END IF;

	user_granting_role := (SELECT role_type FROM bctw_dapi_v1.user_v WHERE id = user_id_granting);
    IF user_granting_role != 'administrator' THEN 
  		RAISE EXCEPTION 'you do not have access to grant animal permissions with role % ', user_granting_role;
	END IF;

	IF NOT EXISTS (SELECT 1 FROM bctw.user WHERE id = usergranted)
		THEN RAISE EXCEPTION 'unable to find the user % receiving permissions', usergranted;
	END IF;

	current_ts = now();

	FOR uar IN SELECT * FROM jsonb_populate_recordset(NULL::bctw.critter_permission_json, animalpermission) LOOP
    
	  -- check critter exists
	  IF NOT EXISTS (SELECT 1 FROM bctw.animal WHERE critter_id = uar.critter_id)
		  THEN RAISE EXCEPTION 'animal with critter_id % does not exist', uar.critter_id;
	  END IF;
		
		-- do nothing if user already has the same permission to this critter
		IF EXISTS(
		 	SELECT 1 FROM bctw.user_animal_assignment
		 	WHERE user_id = usergranted
		 	AND critter_id = uar.critter_id
		 	AND is_valid(valid_to)
		 	AND permission_type = uar.permission_type
		)
			THEN CONTINUE;
		END IF;
		 
		-- delete the current record if it exists
		DELETE FROM bctw.user_animal_assignment
		WHERE user_id = usergranted AND critter_id = uar.critter_id;
	    
	  -- if permission_type is none, dont insert new record
	  IF uar.permission_type = 'none'
	    THEN CONTINUE;
	  END IF;
	    
	  new_id := crypto.gen_random_uuid();
	  assignment_ids := array_append(assignment_ids, new_id);
	    
	  INSERT INTO bctw.user_animal_assignment (assignment_id, user_id, critter_id, created_at, created_by_user_id, updated_at, updated_by_user_id, valid_from, permission_type)
		SELECT
		 	new_id,
		 	usergranted,
		 	uar.critter_id,
		 	current_ts,
		 	user_id_granting,
		 	current_ts,
		 	user_id_granting,
		 	current_ts,
		 	uar.permission_type;
     
  END LOOP;
	RETURN (SELECT json_agg(t) FROM (
		SELECT assignment_id, user_id, critter_id, valid_from, valid_to, permission_type
		FROM user_animal_assignment
		WHERE assignment_id = ANY(assignment_ids)
	) t);
	
END;
$$;


ALTER FUNCTION bctw.grant_critter_to_user(usergranting text, usergranted integer, animalpermission jsonb) OWNER TO bctw;

--
-- Name: FUNCTION grant_critter_to_user(usergranting text, usergranted integer, animalpermission jsonb); Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON FUNCTION bctw.grant_critter_to_user(usergranting text, usergranted integer, animalpermission jsonb) IS 'grants or removes permission to an animal record for the usergranted user_id parameter. When a user creates a new animal, they are automatically granted owner permission. This function is exposed in the user API to users with the administrator role.';


--
-- Name: grant_critter_to_user(text, integer, integer, jsonb); Type: FUNCTION; Schema: bctw; Owner: bctw
--

CREATE FUNCTION bctw.grant_critter_to_user(stridir text, usergranting integer, usergranted integer, animalpermission jsonb) RETURNS json
    LANGUAGE plpgsql
    AS $$
DECLARE
	userid integer := bctw.get_user_id(stridir); -- the user actually calling the function
	userrole text;						 					 				 -- role of the user calling the function
	uar record; 												 				 -- user_animal_assignment row populated from animalpermission parameter json
	new_id uuid;
	assignment_ids uuid[];
	current_ts timestamp WITHOUT time ZONE;
BEGIN
	-- animalpermission should be a json string containing an array of objects with two properties:
	-- { animal_id: string, permission_type: bctw.user_critter_permission }
	
	IF userid IS NULL
		THEN RAISE EXCEPTION 'unable to find the user % calling this function', usergranting;
	END IF;

	userrole := (SELECT role_type FROM bctw_dapi_v1.user_v WHERE id = userid);

  IF userrole != 'administrator' THEN 
  	RAISE EXCEPTION 'you must be an administrator to call this function - your role is: %', userrole;
	END IF;

	IF NOT EXISTS (SELECT 1 FROM bctw.user WHERE id = usergranting)
		THEN RAISE EXCEPTION 'unable to find user with ID % granting the permissions', usergranting;
	END IF;

	IF NOT EXISTS (SELECT 1 FROM bctw.user WHERE id = usergranted)
		THEN RAISE EXCEPTION 'unable to find the user with ID % receiving the permissions', usergranted;
	END IF;

	current_ts = now();

	FOR uar IN SELECT * FROM jsonb_populate_recordset(NULL::bctw.critter_permission_json, animalpermission) LOOP
    
	  -- check critter exists
	  IF NOT EXISTS (SELECT 1 FROM bctw.animal WHERE critter_id = uar.critter_id)
		  THEN RAISE EXCEPTION 'animal with ID % does not exist', uar.critter_id;
		END IF;
		
		-- do nothing if user already has the same permission to this critter
		IF EXISTS(
		 	SELECT 1 FROM bctw.user_animal_assignment
		 	WHERE user_id = usergranted
		 	AND critter_id = uar.critter_id
		 	AND is_valid(valid_to)
		 	AND permission_type = uar.permission_type
		)
		  THEN CONTINUE;
		END IF;
		 
		-- delete the current record if it exists
		DELETE FROM bctw.user_animal_assignment
		WHERE user_id = usergranted AND critter_id = uar.critter_id;
	    
	  -- if permission_type is none, dont insert new record
	  IF uar.permission_type = 'none'
	    THEN CONTINUE;
	  END IF;
	    
	  new_id := crypto.gen_random_uuid();
	  assignment_ids := array_append(assignment_ids, new_id);
	    
	  INSERT INTO bctw.user_animal_assignment (assignment_id, user_id, critter_id, created_at, created_by_user_id, updated_at, updated_by_user_id, valid_from, permission_type)
		SELECT
		 	new_id,
		 	usergranted,
		 	uar.critter_id,
		 	current_ts,
		 	usergranting,
		 	current_ts,
		 	usergranting,
		 	current_ts,
		 	uar.permission_type;
     
  END LOOP;
	RETURN (SELECT json_agg(t) FROM (
		SELECT assignment_id, user_id, critter_id, valid_from, valid_to, permission_type
		FROM user_animal_assignment
		WHERE assignment_id = ANY(assignment_ids)
	) t);
	
END;
$$;


ALTER FUNCTION bctw.grant_critter_to_user(stridir text, usergranting integer, usergranted integer, animalpermission jsonb) OWNER TO bctw;

--
-- Name: FUNCTION grant_critter_to_user(stridir text, usergranting integer, usergranted integer, animalpermission jsonb); Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON FUNCTION bctw.grant_critter_to_user(stridir text, usergranting integer, usergranted integer, animalpermission jsonb) IS 'grants or removes permission to an animal record for the usergranted user_id parameter. When a user creates a new animal, they are automatically granted change permission. This function is exposed in the user API to users with the administrator role. 
NOTE: different than the original as it takes an additional parameter that differentiates between the user calling the function (param #1 stridir), vs the (param #2) which is the user granting the permission.';


--
-- Name: handle_onboarding_request(text, integer, bctw.onboarding_status, bctw.role_type); Type: FUNCTION; Schema: bctw; Owner: bctw
--

CREATE FUNCTION bctw.handle_onboarding_request(identifier text, requestid integer, status bctw.onboarding_status, user_role bctw.role_type) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE
  userid integer := bctw.get_user_id(identifier);
  userrole bctw.role_type;
	current_ts timestamptz := now();
BEGIN
  IF userid IS NULL THEN
		RAISE EXCEPTION 'user with identifier % does not exist', identifier;
  END IF;
 
  -- must be an admin
  userrole := bctw.get_user_role(identifier);
 
  IF userrole IS NULL OR userrole != 'administrator' THEN
    RAISE EXCEPTION 'you must be an administrator to perform this action';
  END IF;

  -- check the request id is valid
  IF NOT EXISTS (SELECT 1 FROM onboarding WHERE onboarding_id = requestid)
	 THEN RAISE EXCEPTION 'onboarding request ID % does not exist', requestid;
  END IF ;

  IF NOT EXISTS (SELECT 1 FROM onboarding WHERE onboarding_id = requestid AND is_valid(valid_to) AND onboarding."access" = 'pending')
	 THEN RAISE EXCEPTION 'onboarding request ID % has already been handled. the result was: %', requestid, (SELECT ACCESS FROM onboarding WHERE onboarding_id = requestid);
  END IF ;
 
 -- update the onboarding status table
 UPDATE bctw.onboarding SET
	 "access" = status,
	 valid_to = current_ts,
	 updated_at = current_ts
 WHERE onboarding_id = requestid;

-- exit if the request was denied
 IF status = 'denied' THEN
	RETURN FALSE;
 END IF;

-- add the new user
WITH ins AS (
	INSERT INTO bctw.USER ("domain", username, firstname, lastname, email, phone, created_by_user_id)
	SELECT "domain", username, firstname, lastname, email, phone, userid  FROM onboarding
	WHERE onboarding_id = requestid
	RETURNING id
)
    INSERT INTO user_role_xref (user_id, role_id)
    VALUES ((SELECT id FROM ins), (SELECT role_id FROM user_role_type WHERE role_type = user_role::varchar));

	RETURN TRUE;
END;
$$;


ALTER FUNCTION bctw.handle_onboarding_request(identifier text, requestid integer, status bctw.onboarding_status, user_role bctw.role_type) OWNER TO bctw;

--
-- Name: is_valid(timestamp without time zone); Type: FUNCTION; Schema: bctw; Owner: bctw
--

CREATE FUNCTION bctw.is_valid(valid_to timestamp without time zone) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
begin
	return valid_to >= now() or valid_to is null;
END;
$$;


ALTER FUNCTION bctw.is_valid(valid_to timestamp without time zone) OWNER TO bctw;

--
-- Name: FUNCTION is_valid(valid_to timestamp without time zone); Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON FUNCTION bctw.is_valid(valid_to timestamp without time zone) IS 'returns true if the row''s valid_to column is considered valid - when the timestamp is now or in the future.';


--
-- Name: is_valid(timestamp with time zone); Type: FUNCTION; Schema: bctw; Owner: bctw
--

CREATE FUNCTION bctw.is_valid(valid_to timestamp with time zone) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
begin
	return valid_to >= now() or valid_to is null;
END;
$$;


ALTER FUNCTION bctw.is_valid(valid_to timestamp with time zone) OWNER TO bctw;

--
-- Name: FUNCTION is_valid(valid_to timestamp with time zone); Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON FUNCTION bctw.is_valid(valid_to timestamp with time zone) IS 'returns true if the row''s valid_to column is considered valid - when the timestamp (with timezone) is now or in the future.';


--
-- Name: is_valid(timestamp without time zone, timestamp without time zone, timestamp without time zone); Type: FUNCTION; Schema: bctw; Owner: bctw
--

CREATE FUNCTION bctw.is_valid(ts timestamp without time zone, tsstart timestamp without time zone, tsend timestamp without time zone) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
begin
	return ts >= tsstart and (ts <= tsend or tsend is null);
END;
$$;


ALTER FUNCTION bctw.is_valid(ts timestamp without time zone, tsstart timestamp without time zone, tsend timestamp without time zone) OWNER TO bctw;

--
-- Name: FUNCTION is_valid(ts timestamp without time zone, tsstart timestamp without time zone, tsend timestamp without time zone); Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON FUNCTION bctw.is_valid(ts timestamp without time zone, tsstart timestamp without time zone, tsend timestamp without time zone) IS 'returns true if ts is between tsstart and tsend';


--
-- Name: is_valid(timestamp with time zone, timestamp with time zone, timestamp with time zone); Type: FUNCTION; Schema: bctw; Owner: bctw
--

CREATE FUNCTION bctw.is_valid(ts timestamp with time zone, tsstart timestamp with time zone, tsend timestamp with time zone) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
begin
	return ts >= tsstart and (ts <= tsend or tsend is null);
END;
$$;


ALTER FUNCTION bctw.is_valid(ts timestamp with time zone, tsstart timestamp with time zone, tsend timestamp with time zone) OWNER TO bctw;

--
-- Name: get_random_colour_code_id(); Type: FUNCTION; Schema: bctw_dapi_v1; Owner: bctw
--

CREATE FUNCTION bctw_dapi_v1.get_random_colour_code_id() RETURNS integer
    LANGUAGE plpgsql
    AS $$
declare
  ch_id integer := (select code_header_id from bctw.code_header where code_header_name = 'map_colour');
  high integer; 
  low integer; 
  colour_hex text;
begin
	high := (select max(code_id) from bctw.code where code_header_id = ch_id);
	low := (select min(code_id) from bctw.code where code_header_id = ch_id);
	colour_hex := (
	  select code_id
	  from bctw.code
	  where code_header_id = ch_id
	  and code_id = (SELECT floor(random() * (high - low + 1) + low))::int); 
	 
	return colour_hex;
END;
$$;


ALTER FUNCTION bctw_dapi_v1.get_random_colour_code_id() OWNER TO bctw;

--
-- Name: FUNCTION get_random_colour_code_id(); Type: COMMENT; Schema: bctw_dapi_v1; Owner: bctw
--

COMMENT ON FUNCTION bctw_dapi_v1.get_random_colour_code_id() IS 'returns a random code_id for an animal colour (in map view). called when new animals are created.';


--
-- Name: animal; Type: TABLE; Schema: bctw; Owner: bctw
--

CREATE TABLE bctw.animal (
    critter_id uuid DEFAULT crypto.gen_random_uuid() NOT NULL,
    critter_transaction_id uuid DEFAULT crypto.gen_random_uuid() NOT NULL,
    animal_id character varying(30),
    animal_status integer,
    associated_animal_id character varying(30),
    associated_animal_relationship integer,
    capture_comment character varying(200),
    capture_date timestamp with time zone,
    capture_latitude double precision,
    capture_longitude double precision,
    capture_utm_easting integer,
    capture_utm_northing integer,
    capture_utm_zone integer,
    collective_unit character varying(60),
    animal_colouration character varying(20),
    ear_tag_left_colour character varying(20),
    ear_tag_right_colour character varying(20),
    estimated_age double precision,
    juvenile_at_heel integer,
    life_stage integer,
    map_colour integer DEFAULT bctw_dapi_v1.get_random_colour_code_id(),
    mortality_comment character varying(200),
    mortality_date timestamp with time zone,
    mortality_latitude double precision,
    mortality_longitude double precision,
    mortality_utm_easting integer,
    mortality_utm_northing integer,
    mortality_utm_zone integer,
    proximate_cause_of_death integer,
    ultimate_cause_of_death integer,
    population_unit integer,
    recapture boolean,
    region integer,
    release_comment character varying(200),
    release_date timestamp with time zone,
    release_latitude double precision,
    release_longitude double precision,
    release_utm_easting integer,
    release_utm_northing integer,
    release_utm_zone integer,
    sex integer,
    species character varying(20),
    translocation boolean,
    wlh_id character varying(20),
    animal_comment character varying(200),
    created_at timestamp without time zone DEFAULT now(),
    created_by_user_id integer,
    updated_at timestamp without time zone DEFAULT now(),
    updated_by_user_id integer,
    valid_from timestamp with time zone DEFAULT now(),
    valid_to timestamp with time zone,
    pcod_predator_species character varying(20),
    owned_by_user_id integer,
    ear_tag_left_id character varying(20),
    ear_tag_right_id character varying(20),
    juvenile_at_heel_count integer,
    predator_known boolean,
    captivity_status boolean,
    mortality_captivity_status boolean,
    ucod_predator_species character varying(20),
    pcod_confidence integer,
    ucod_confidence integer,
    mortality_report boolean,
    mortality_investigation integer,
    device_id integer
);


ALTER TABLE bctw.animal OWNER TO bctw;

--
-- Name: COLUMN animal.critter_id; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.animal.critter_id IS 'A uuid key that is preserved through changes to the critter';


--
-- Name: COLUMN animal.critter_transaction_id; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.animal.critter_transaction_id IS 'Primary key of the animal table. When a critter is modified a new row with the same id but new transaction_id is inserted';


--
-- Name: COLUMN animal.animal_id; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.animal.animal_id IS 'A unique identifier permanently assigned to an animal by the project coordinator, independent of possible changes in mark method used. This data is mandatory if there is telemetry or GPS data for the animal.  Field often contains text and numbers.';


--
-- Name: COLUMN animal.animal_status; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.animal.animal_status IS 'Status of animal that a tracking device has been deployed on.';


--
-- Name: COLUMN animal.associated_animal_id; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.animal.associated_animal_id IS 'another individual with which this animal is associated';


--
-- Name: COLUMN animal.associated_animal_relationship; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.animal.associated_animal_relationship IS 'describes the relationship between this animal and the individual named in "associated_animal_id"';


--
-- Name: COLUMN animal.capture_comment; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.animal.capture_comment IS 'comments from the capture event/workflow';


--
-- Name: COLUMN animal.capture_date; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.animal.capture_date IS 'The date of the start of a deployment (ie. date animal was captured).  A reliable format is dd-mmm-yyyy (e.g. ''7 Jun 2008'' or ''7-Jun-2008''). When entering the date into Excel ensure that Excel interprets it as correct date information.';


--
-- Name: COLUMN animal.capture_latitude; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.animal.capture_latitude IS 'The latitude of the observation, in decimal degrees. Coordinates must be recorded in WGS84. Do not enter Long-Lat coordinates if UTM coordinates are provided.';


--
-- Name: COLUMN animal.capture_longitude; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.animal.capture_longitude IS 'The longitude of the observation, in decimal degrees. Coordinates must be recorded in WGS84. Do not enter Long-Lat coordinates if UTM coordinates are provided.';


--
-- Name: COLUMN animal.capture_utm_easting; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.animal.capture_utm_easting IS 'The UTM east coordinate in metres. The value in this field must be a 6-digit number. UTM coordinates must be recorded using NAD 83 datum.';


--
-- Name: COLUMN animal.capture_utm_northing; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.animal.capture_utm_northing IS 'The UTM north coordinate in metres for the observation recorded. The value in this field must be a 7 digit number. UTM coordinates must be recorded using NAD 83 datum.';


--
-- Name: COLUMN animal.capture_utm_zone; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.animal.capture_utm_zone IS 'The UTM zone in which the observation occurs. The value is a 2 digit number.';


--
-- Name: COLUMN animal.collective_unit; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.animal.collective_unit IS 'used to represent herds or packs, distinct from population units';


--
-- Name: COLUMN animal.animal_colouration; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.animal.animal_colouration IS 'general appearance of an animal resulting from the reflection or emission of light from its surfaces';


--
-- Name: COLUMN animal.ear_tag_left_colour; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.animal.ear_tag_left_colour IS 'An ear tag colour on the left ear';


--
-- Name: COLUMN animal.ear_tag_right_colour; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.animal.ear_tag_right_colour IS 'An ear tag colour on the right ear';


--
-- Name: COLUMN animal.estimated_age; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.animal.estimated_age IS 'The estimated age, in years, of the organism. A decimal place is permitted.';


--
-- Name: COLUMN animal.juvenile_at_heel; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.animal.juvenile_at_heel IS 'Fledged birds before their first winter, mammals older than neonates but still requiring parental care, and reptiles and amphibians of adult form that are significantly smaller than adult size.';


--
-- Name: COLUMN animal.life_stage; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.animal.life_stage IS 'The life stage of the individual.';


--
-- Name: COLUMN animal.map_colour; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.animal.map_colour IS 'colour used to represent points on the 2D map of the animal';


--
-- Name: COLUMN animal.mortality_comment; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.animal.mortality_comment IS 'comments from the mortality event/workflow';


--
-- Name: COLUMN animal.mortality_date; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.animal.mortality_date IS 'Date animal died';


--
-- Name: COLUMN animal.mortality_latitude; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.animal.mortality_latitude IS 'Mortality Location in WGS85';


--
-- Name: COLUMN animal.mortality_longitude; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.animal.mortality_longitude IS 'Mortality Location in WGS85';


--
-- Name: COLUMN animal.mortality_utm_easting; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.animal.mortality_utm_easting IS 'Mortality location easting';


--
-- Name: COLUMN animal.mortality_utm_northing; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.animal.mortality_utm_northing IS 'Mortality location northing';


--
-- Name: COLUMN animal.mortality_utm_zone; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.animal.mortality_utm_zone IS 'Mortality location zone';


--
-- Name: COLUMN animal.proximate_cause_of_death; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.animal.proximate_cause_of_death IS 'probable cause of death';


--
-- Name: COLUMN animal.ultimate_cause_of_death; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.animal.ultimate_cause_of_death IS 'ultimate cause of death';


--
-- Name: COLUMN animal.population_unit; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.animal.population_unit IS 'A code indicating the species'' population unit (e.g., SnSa). Population unit is a generic term for a provincially defined, geographically discrete population of a species. E.g., for grizzly bear they are called ''population units''; for caribou they are called ''herds''; for moose they are called ''game-management zones''.';


--
-- Name: COLUMN animal.recapture; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.animal.recapture IS 'Identifies whether the animal is a recapture.';


--
-- Name: COLUMN animal.region; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.animal.region IS 'Region within province the animal inhabits. ex. Peace';


--
-- Name: COLUMN animal.release_comment; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.animal.release_comment IS 'comments from the release event/workflow';


--
-- Name: COLUMN animal.release_date; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.animal.release_date IS 'Date the animal was released following capture.';


--
-- Name: COLUMN animal.release_latitude; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.animal.release_latitude IS 'latitude of location where animal was released';


--
-- Name: COLUMN animal.release_longitude; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.animal.release_longitude IS 'longitude of location where animal was released';


--
-- Name: COLUMN animal.release_utm_easting; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.animal.release_utm_easting IS 'UTM easting of location where animal was released';


--
-- Name: COLUMN animal.release_utm_northing; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.animal.release_utm_northing IS 'UTM northing of location where animal was released';


--
-- Name: COLUMN animal.release_utm_zone; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.animal.release_utm_zone IS 'UTM zone compnent of location where animal was released';


--
-- Name: COLUMN animal.sex; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.animal.sex IS 'A code indicating the sex of the individual.';


--
-- Name: COLUMN animal.species; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.animal.species IS 'A code that identifies a species or subspecies of wildlife.';


--
-- Name: COLUMN animal.translocation; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.animal.translocation IS 'Identifies whether the animal is a translocation.';


--
-- Name: COLUMN animal.wlh_id; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.animal.wlh_id IS '"A unique identifier assigned to an individual by the B. C. Wildlife Health Program, independent of possible changes in mark method used, to assoicate health data to the indiviudal.

"';


--
-- Name: COLUMN animal.animal_comment; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.animal.animal_comment IS 'general comments about the animal (e.g. missing left ear, scar on neck, etc.)';


--
-- Name: COLUMN animal.created_at; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.animal.created_at IS 'time this record was created at';


--
-- Name: COLUMN animal.created_by_user_id; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.animal.created_by_user_id IS 'user ID of the user that created the animal';


--
-- Name: COLUMN animal.updated_at; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.animal.updated_at IS 'time this record was updated at';


--
-- Name: COLUMN animal.updated_by_user_id; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.animal.updated_by_user_id IS 'user ID of the user that changed the animal';


--
-- Name: COLUMN animal.valid_from; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.animal.valid_from IS 'timestamp of when this record begins being valid';


--
-- Name: COLUMN animal.valid_to; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.animal.valid_to IS 'is this record expired? (null) is valid';


--
-- Name: COLUMN animal.pcod_predator_species; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.animal.pcod_predator_species IS 'a common english name of the predator species or subspecies associated with the animal''s proximate cause of death';


--
-- Name: COLUMN animal.owned_by_user_id; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.animal.owned_by_user_id IS 'user ID of the user the ''owns'' the animal';


--
-- Name: COLUMN animal.ear_tag_left_id; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.animal.ear_tag_left_id IS 'numeric or alphanumeric identifier, if marked on left ear tag';


--
-- Name: COLUMN animal.ear_tag_right_id; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.animal.ear_tag_right_id IS 'numeric or alphanumeric identifier, if marked on right ear tag';


--
-- Name: COLUMN animal.juvenile_at_heel_count; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.animal.juvenile_at_heel_count IS 'how many juveniles ';


--
-- Name: COLUMN animal.predator_known; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.animal.predator_known IS ' indicating that species (or genus) of a predator that predated an animal is known or unknown.';


--
-- Name: COLUMN animal.captivity_status; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.animal.captivity_status IS 'indicating whether an animal is, or has been, in a captivity program (e.g., maternity pen, conservation breeeding program).';


--
-- Name: COLUMN animal.mortality_captivity_status; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.animal.mortality_captivity_status IS 'indicating the mortality event occurred when animal was occupying wild habitat (i.e, natural range) or in captivity (i.e.,  maternity pen, conservation breeding centre).';


--
-- Name: COLUMN animal.ucod_predator_species; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.animal.ucod_predator_species IS 'a common english name of the predator species or subspecies associated with the animal''s ultimate cause of death';


--
-- Name: COLUMN animal.pcod_confidence; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.animal.pcod_confidence IS 'describes qualitative confidence in the assignment of Proximate Cause of Death of an animal. ';


--
-- Name: COLUMN animal.ucod_confidence; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.animal.ucod_confidence IS 'a code that describes qualitative confidence in the assignment of Ultimate Cause of Death of an animal.';


--
-- Name: COLUMN animal.mortality_report; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.animal.mortality_report IS 'indicating that details of animal''s mortality investigation is recorded in a Wildlife Health Group mortality template.';


--
-- Name: COLUMN animal.mortality_investigation; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.animal.mortality_investigation IS 'a code indicating the method of investigation of the animal mortality.';


--
-- Name: COLUMN animal.device_id; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.animal.device_id IS 'temporary column added to assist with bulk loading animal/collar relationships';


--
-- Name: json_to_animal(jsonb); Type: FUNCTION; Schema: bctw; Owner: bctw
--

CREATE FUNCTION bctw.json_to_animal(animaljson jsonb) RETURNS SETOF bctw.animal
    LANGUAGE plpgsql
    AS $$
declare
 ret1 jsonb;
 ret2 jsonb;
 ar record;
begin
	-- to access the json values in dot notation, cast the json record to the view version of animal (all text values)
	ar := jsonb_populate_record(NULL::bctw.animal_v, jsonb_strip_nulls(animaljson));
	-- create a new json object, converting everything to the animal table specific values
	-- creates 2 json objects since there are apparently too many parameters being passed to jsonb_build_object
	ret1 := JSONB_BUILD_OBJECT(
	  'critter_id', ar.critter_id,
	  'critter_transaction_id', crypto.gen_random_uuid(),
	  'animal_id', ar.animal_id,
	  'animal_status', bctw.get_code_id_with_error('animal_status', ar.animal_status),
	  'associated_animal_id', ar.associated_animal_id,
	  'associated_animal_relationship', bctw.get_code_id_with_error('associated_animal_relationship', ar.associated_animal_relationship),
	  'capture_comment', ar.capture_comment,
	  'capture_date', ar.capture_date,
	  'capture_latitude', ar.capture_latitude,
	  'capture_longitude', ar.capture_longitude,
	  'capture_utm_easting', ar.capture_utm_easting,
	  'capture_utm_northing', ar.capture_utm_northing,
	  'capture_utm_zone', ar.capture_utm_zone,
	  'collective_unit', ar.collective_unit,
	  'animal_colouration', ar.animal_colouration,
	  'ear_tag_left_id', ar.ear_tag_left_id,
	  'ear_tag_right_id', ar.ear_tag_right_id,
	  'ear_tag_left_colour', ar.ear_tag_left_colour,
	  'ear_tag_right_colour', ar.ear_tag_right_colour,
	  'estimated_age', ar.estimated_age,
	  'juvenile_at_heel', bctw.get_code_id_with_error('juvenile_at_heel', ar.juvenile_at_heel),
	  'juvenile_at_heel_count', ar.juvenile_at_heel_count,
	  'life_stage', bctw.get_code_id_with_error('life_stage', ar.life_stage),
	  'map_colour', bctw.get_code_id_with_error('map_colour', ar.map_colour),
	  'mortality_comment', ar.mortality_comment,
	  'mortality_date', ar.mortality_date,
	  'mortality_latitude', ar.mortality_latitude,
	  'mortality_longitude', ar.mortality_longitude,
	  'mortality_utm_easting', ar.mortality_utm_easting,
	  'mortality_utm_northing', ar.mortality_utm_northing,
	  'mortality_utm_zone', ar.mortality_utm_zone,
	  'proximate_cause_of_death', bctw.get_code_id_with_error('proximate_cause_of_death', ar.proximate_cause_of_death),
	  'ultimate_cause_of_death', bctw.get_code_id_with_error('ultimate_cause_of_death', ar.ultimate_cause_of_death)
	  );
	 	
	  ret2 := JSONB_BUILD_OBJECT(
	  'population_unit', bctw.get_code_id_with_error('population_unit', ar.population_unit),
	  'recapture', ar.recapture,
	  'region', bctw.get_code_id_with_error('region', ar.region),
 	  'release_comment', ar.release_comment,
    'release_date', ar.release_date,
    'release_latitude', ar.release_latitude,
    'release_longitude', ar.release_longitude,
    'release_utm_easting', ar.release_utm_easting,
    'release_utm_northing', ar.release_utm_northing,
    'release_utm_zone', ar.release_utm_zone,
	  'sex', bctw.get_code_id_with_error('sex', ar.sex),
	  'species', bctw.get_species_id_with_error(ar.species),
	  'translocation', ar.translocation,
	  'wlh_id', ar.wlh_id,
	  'animal_comment', ar.animal_comment,
	  'predator_known', ar.predator_known,
	  'captivity_status', ar.captivity_status,
	  'mortality_captivity_status', ar.mortality_captivity_status,
	  'pcod_predator_species', ar.pcod_predator_species,
	  'ucod_predator_species', ar.ucod_predator_species,
	  'pcod_confidence', bctw.get_code_id_with_error('cod_confidence'::text, ar.pcod_confidence),
	  'ucod_confidence', bctw.get_code_id_with_error('cod_confidence', ar.ucod_confidence),
	  'mortality_report', ar.mortality_report,
	  'mortality_investigation', bctw.get_code_id_with_error('mortality_investigation', ar.mortality_investigation),
	  'created_at', ar.created_at,
	  'created_by_user_id', ar.created_by_user_id,
	  'updated_at', ar.created_at,
	  'updated_by_user_id', ar.created_by_user_id,
	  'valid_from', ar.valid_from,
	  'valid_to', ar.valid_to,
	  'owned_by_user_id', ar.owned_by_user_id
	);
	-- return animal record, passing in the two jsonb objects concatenated
	return query select * from jsonb_populate_record(null::bctw.animal, ret1 || ret2);
END;
$$;


ALTER FUNCTION bctw.json_to_animal(animaljson jsonb) OWNER TO bctw;

--
-- Name: FUNCTION json_to_animal(animaljson jsonb); Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON FUNCTION bctw.json_to_animal(animaljson jsonb) IS 'converts an animal json record, mapping codes to their integer form. fixme: how to handle ''historical'' records';


--
-- Name: collar; Type: TABLE; Schema: bctw; Owner: bctw
--

CREATE TABLE bctw.collar (
    collar_id uuid DEFAULT crypto.gen_random_uuid() NOT NULL,
    collar_transaction_id uuid DEFAULT crypto.gen_random_uuid() NOT NULL,
    camera_device_id integer,
    device_id integer,
    device_deployment_status integer,
    device_make integer,
    device_malfunction_type integer,
    device_model character varying(40),
    device_status integer,
    device_type integer,
    dropoff_device_id integer,
    dropoff_frequency double precision,
    dropoff_frequency_unit integer,
    fix_interval double precision,
    fix_interval_rate integer,
    frequency double precision,
    frequency_unit integer,
    malfunction_date timestamp with time zone,
    activation_comment character varying(200),
    first_activation_month integer,
    first_activation_year integer,
    retrieval_date timestamp with time zone,
    retrieved boolean DEFAULT false,
    satellite_network integer,
    device_comment character varying(200),
    activation_status boolean DEFAULT false,
    created_at timestamp without time zone DEFAULT now(),
    created_by_user_id integer,
    updated_at timestamp without time zone DEFAULT now(),
    updated_by_user_id integer,
    valid_from timestamp with time zone DEFAULT now(),
    valid_to timestamp with time zone,
    owned_by_user_id integer,
    offline_date timestamp with time zone,
    offline_type integer,
    device_condition integer,
    retrieval_comment character varying(200),
    malfunction_comment character varying(200),
    offline_comment character varying(200),
    mortality_mode boolean,
    mortality_period_hr smallint,
    dropoff_mechanism integer,
    implant_device_id integer
);


ALTER TABLE bctw.collar OWNER TO bctw;

--
-- Name: COLUMN collar.collar_id; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.collar.collar_id IS 'A uuid key that is preserved through changes to the device';


--
-- Name: COLUMN collar.collar_transaction_id; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.collar.collar_transaction_id IS 'Primary key of the collar table. When a device is modified a new row with the same id but new transaction_id is inserted';


--
-- Name: COLUMN collar.camera_device_id; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.collar.camera_device_id IS 'ID of the camera component';


--
-- Name: COLUMN collar.device_id; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.collar.device_id IS 'An identifying number or label (e.g. serial number) that the manufacturer of a device has applied to the device.';


--
-- Name: COLUMN collar.device_deployment_status; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.collar.device_deployment_status IS 'The deployment status of a device.';


--
-- Name: COLUMN collar.device_make; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.collar.device_make IS 'The manufacturer of a device';


--
-- Name: COLUMN collar.device_malfunction_type; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.collar.device_malfunction_type IS 'Type of device malfunction. ex: VHF signal of device has malfunctioned';


--
-- Name: COLUMN collar.device_model; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.collar.device_model IS 'The model of a device. Text and numerici field.';


--
-- Name: COLUMN collar.device_status; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.collar.device_status IS 'The functional status of a device';


--
-- Name: COLUMN collar.device_type; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.collar.device_type IS 'Type of tracking device';


--
-- Name: COLUMN collar.dropoff_device_id; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.collar.dropoff_device_id IS 'ID of the drop-off component';


--
-- Name: COLUMN collar.dropoff_frequency; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.collar.dropoff_frequency IS 'radio frequency of the device’s drop-off component';


--
-- Name: COLUMN collar.dropoff_frequency_unit; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.collar.dropoff_frequency_unit IS 'should always be MHz, but created to match the way VHF frequency is modelled';


--
-- Name: COLUMN collar.fix_interval; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.collar.fix_interval IS 'Number of gps fixes per unit of time (fixes per hour) the device is programmed to collect.  Some devices allow for fix rate to be modified remotely over the device life.';


--
-- Name: COLUMN collar.fix_interval_rate; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.collar.fix_interval_rate IS 'Fix success rate is quantified as the number of attempted gps fixes that were successful relative to the expected number of gps fixes.';


--
-- Name: COLUMN collar.frequency; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.collar.frequency IS 'The frequency of electromagnetic signal emitted by a tag or mark.';


--
-- Name: COLUMN collar.frequency_unit; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.collar.frequency_unit IS 'A code indicating the frequency-unit used when recording the Frequency of a tag or mark, e.g., kHz.';


--
-- Name: COLUMN collar.malfunction_date; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.collar.malfunction_date IS 'Malfunction date of the device';


--
-- Name: COLUMN collar.activation_comment; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.collar.activation_comment IS 'comments about the purchase (e.g. invoice number, funding agency, etc.)';


--
-- Name: COLUMN collar.first_activation_month; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.collar.first_activation_month IS 'month in which the device was first activated';


--
-- Name: COLUMN collar.first_activation_year; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.collar.first_activation_year IS 'year in which the device was first activated';


--
-- Name: COLUMN collar.retrieval_date; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.collar.retrieval_date IS 'The earliest date in which the 1) the device was removed from animal or 2) the device was retrieved from the field.';


--
-- Name: COLUMN collar.retrieved; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.collar.retrieved IS 'Device retrieved from animal (i.e., no longer deployed)';


--
-- Name: COLUMN collar.satellite_network; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.collar.satellite_network IS 'The satellite network of GPS collar';


--
-- Name: COLUMN collar.device_comment; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.collar.device_comment IS 'general comments about the device (e.g. expansion collar, previously repaired, etc.)';


--
-- Name: COLUMN collar.activation_status; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.collar.activation_status IS 'Device activation status by the manufacturer';


--
-- Name: COLUMN collar.created_at; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.collar.created_at IS 'timestamp the collar was created';


--
-- Name: COLUMN collar.created_by_user_id; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.collar.created_by_user_id IS 'user ID of the user that created the collar';


--
-- Name: COLUMN collar.updated_at; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.collar.updated_at IS 'timestamp that the collar was updated at';


--
-- Name: COLUMN collar.updated_by_user_id; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.collar.updated_by_user_id IS 'user ID of the user that updated the collar';


--
-- Name: COLUMN collar.valid_from; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.collar.valid_from IS 'timestamp of when this record begins being valid';


--
-- Name: COLUMN collar.valid_to; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.collar.valid_to IS 'is this record expired? (null) is valid';


--
-- Name: COLUMN collar.owned_by_user_id; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.collar.owned_by_user_id IS 'user ID of the user the ''owns'' the collar.';


--
-- Name: COLUMN collar.offline_date; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.collar.offline_date IS 'the date the malfunction occurred';


--
-- Name: COLUMN collar.offline_type; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.collar.offline_type IS 'TODO - assuming this is a code?';


--
-- Name: COLUMN collar.device_condition; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.collar.device_condition IS 'the condition of the device upon retrieval';


--
-- Name: COLUMN collar.retrieval_comment; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.collar.retrieval_comment IS 'informative comments or notes about retrieval event for this device.';


--
-- Name: COLUMN collar.malfunction_comment; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.collar.malfunction_comment IS 'informative comments or notes about malfunction event for this device.';


--
-- Name: COLUMN collar.offline_comment; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.collar.offline_comment IS 'informative comments or notes about offline event for this device.';


--
-- Name: COLUMN collar.mortality_mode; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.collar.mortality_mode IS 'indicates the device has a mortality sensor.  A device movement sensor detects no movement, after a pre-programmed period of time can change the VHF pulse rate to indicate a change in animal behaviour (e.g., stationary, resting); this can also trigger a GPS device to send notification of a mortlity signal.';


--
-- Name: COLUMN collar.mortality_period_hr; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.collar.mortality_period_hr IS 'the pre-programmed period of time (hours) of no movement detected, after which the device is programmed to trigger a mortality notification signal.';


--
-- Name: COLUMN collar.dropoff_mechanism; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.collar.dropoff_mechanism IS 'a code for the drop-off mechanism for the device (e.g., device released by radio or timer)';


--
-- Name: COLUMN collar.implant_device_id; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.collar.implant_device_id IS 'an identifying number or label (e.g. serial number) that the manufacturer of a device has applied to the implant module.';


--
-- Name: json_to_collar(jsonb); Type: FUNCTION; Schema: bctw; Owner: bctw
--

CREATE FUNCTION bctw.json_to_collar(collarjson jsonb) RETURNS SETOF bctw.collar
    LANGUAGE plpgsql
    AS $$
declare
 ret jsonb;
 cr record;
begin
	-- in order to access the json properties in a dot notation form, cast the json
	-- record to the view version of collar (all text instead of codes)
	cr := jsonb_populate_record(NULL::bctw.collar_v, jsonb_strip_nulls(collarjson));
	-- create a new json object, converting everything to the collar table specific values
	ret := JSONB_BUILD_OBJECT(
	  'collar_id', cr.collar_id,
	  'collar_transaction_id', crypto.gen_random_uuid(),
	  'camera_device_id', cr.camera_device_id,
	  'device_id', cr.device_id,
	  'device_deployment_status', bctw.get_code_id_with_error('device_deployment_status', cr.device_deployment_status),
	  'device_make', bctw.get_code_id_with_error('device_make', cr.device_make),
	  'device_malfunction_type', bctw.get_code_id_with_error('device_malfunction_type', cr.device_malfunction_type),
	  'device_model', cr.device_model,
	  'device_status', bctw.get_code_id_with_error('device_status', cr.device_status),
	  'device_type', bctw.get_code_id_with_error('device_type', cr.device_type),
	  'dropoff_device_id', cr.dropoff_device_id,
	  'dropoff_frequency', cr.dropoff_frequency,
	  'dropoff_frequency_unit', bctw.get_code_id_with_error('frequency_unit', cr.dropoff_frequency_unit),
	  'fix_interval', cr.fix_interval,
	  'fix_interval_rate', bctw.get_code_id_with_error('fix_unit', cr.fix_interval_rate),
	  'frequency', cr.frequency,
	  'frequency_unit', bctw.get_code_id_with_error('frequency_unit', cr.frequency_unit),
	  'activation_comment', cr.activation_comment,
	  'first_activation_month', cr.first_activation_month,
	  'first_activation_year', cr.first_activation_year,
	  'retrieval_date', cr.retrieval_date,
	  'retrieved', cr.retrieved,
	  'retrieval_comment', cr.retrieval_comment,
	  'satellite_network', bctw.get_code_id_with_error('satellite_network', cr.satellite_network),
	  'device_comment', cr.device_comment,
	  'activation_status', cr.activation_status,
	  'offline_date', cr.offline_date,
	  'offline_type', cr.offline_type,
	  'device_condition', bctw.get_code_id_with_error('device_condition', cr.device_condition),
	  'malfunction_comment', cr.malfunction_comment,
	  'offline_comment', cr.offline_comment,
	  'mortality_mode', cr.mortality_mode,
	  'mortality_period_hr', cr.mortality_period_hr,
	  'dropoff_mechanism', bctw.get_code_id_with_error('dropoff_mechanism', cr.dropoff_mechanism),
	  'implant_device_id', cr.implant_device_id,
	  'created_at', cr.created_at,
	  'created_by_user_id', cr.created_by_user_id,
	  'updated_at', cr.created_at,
	  'updated_by_user_id', cr.created_by_user_id,
	  'valid_from', cr.valid_from,
	  'valid_to', cr.valid_to,
	  'owned_by_user_id', cr.owned_by_user_id
	);
	-- return it as a collar table row
	return query select * from jsonb_populate_record(null::bctw.collar, ret);
END;
$$;


ALTER FUNCTION bctw.json_to_collar(collarjson jsonb) OWNER TO bctw;

--
-- Name: FUNCTION json_to_collar(collarjson jsonb); Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON FUNCTION bctw.json_to_collar(collarjson jsonb) IS 'converts a collar json record, mapping codes to their integer form';


--
-- Name: link_collar_to_animal(text, uuid, uuid, timestamp with time zone, timestamp with time zone, timestamp with time zone, timestamp with time zone); Type: FUNCTION; Schema: bctw; Owner: bctw
--

CREATE FUNCTION bctw.link_collar_to_animal(stridir text, collarid uuid, critterid uuid, actual_start timestamp with time zone, data_life_start timestamp with time zone, actual_end timestamp with time zone, data_life_end timestamp with time zone) RETURNS SETOF json
    LANGUAGE plpgsql
    AS $$
DECLARE
userid integer := bctw.get_user_id(stridir);
animal_assigned uuid;
collar_assigned uuid;
current_ts timestamptz := now();
err text := 'failed to attach device:';
cur_permission user_permission;
BEGIN
	-- check collar exists
	IF NOT EXISTS (SELECT 1 FROM bctw.collar WHERE collar_id = collarid) THEN 
		RAISE EXCEPTION '% device wth collar_id % does not exist', err, collarid;
	END IF; 

	-- check critter exists
	IF NOT EXISTS (SELECT 1 FROM bctw.animal WHERE critter_id = critterid) THEN
		RAISE EXCEPTION '% animal with critter_id % does not exist', err, critterid;
	END IF;

	--
	-- TODO: also add check the attachment_end range bound doesn't overlap?
	--
	-- is the device already assigned during this period?
	-- yes if the provided actual_start is between the attachment_start/end of another assignment
	animal_assigned := (
	  SELECT critter_id FROM bctw.collar_animal_assignment
	  WHERE collar_id = collarid
	  AND is_valid(actual_start, attachment_start, attachment_end)
	);
	IF animal_assigned IS NOT NULL THEN
	  IF critterid = animal_assigned THEN
	  -- the animal is already attached to this device
	    RAISE EXCEPTION '% device with ID % is already attached to this animal', err, (SELECT device_id FROM bctw.collar WHERE collar_id = collarid AND is_valid(valid_to));
	  -- the animal is attached to a difference device
	  ELSE RAISE EXCEPTION 'device with ID % is already attached to a different animal with critter_id %', 
	 	(SELECT device_id FROM bctw.collar WHERE collar_id = collarid AND is_valid(valid_to)),
	    (SELECT critter_id FROM collar_animal_assignment WHERE collar_id = collarid AND is_valid(valid_to));
	  END IF;
	END IF;

	-- confirm animal isnt already assigned
	collar_assigned := (
	  SELECT collar_id FROM bctw.collar_animal_assignment
	  WHERE critter_id = critterid
	  AND is_valid(actual_start, attachment_start, attachment_end)
	);
	IF collar_assigned IS NOT NULL THEN
    RAISE EXCEPTION 'animal is currently attached device with ID %', (SELECT device_id FROM collar WHERE collar_id = collarid AND is_valid(valid_to));
	END IF;

	-- confirm user has permission to perform the attachment - must be an admin role or have owner permission - a subowner cannot do this!
	cur_permission := bctw.get_user_animal_permission(userid, critterid);
	IF cur_permission IS NULL OR cur_permission = ANY('{"observer", "none", "editor"}'::user_permission[]) THEN
	  RAISE EXCEPTION 'you do not have required permission to attach this animal - your permission is: "%"', cur_permission::TEXT;
  END IF;
 
 	-- copied from bctw.updated_data_life to check for valid timestamps
	 IF data_life_start < actual_start THEN
		RAISE EXCEPTION 'data life start (%) must be after actual end timestamp of %', data_life_start, actual_start;
	END IF;

	IF data_life_end > actual_end THEN 
		RAISE EXCEPTION 'data life end (%) must be before the actual end timestamp of %', data_life_end, actual_end;
	END IF; 
	
	RETURN query
	WITH i AS (
		INSERT INTO collar_animal_assignment (collar_id, critter_id, created_by_user_id, valid_from, valid_to, attachment_start, attachment_end)
	 	 VALUES (collarid, critterid, userid, data_life_start, data_life_end, actual_start, actual_end)
	 	 RETURNING *
	 ) SELECT row_to_json(t) FROM (SELECT * FROM i) t;
END;
$$;


ALTER FUNCTION bctw.link_collar_to_animal(stridir text, collarid uuid, critterid uuid, actual_start timestamp with time zone, data_life_start timestamp with time zone, actual_end timestamp with time zone, data_life_end timestamp with time zone) OWNER TO bctw;

--
-- Name: link_collar_to_animal_bak(text, uuid, uuid, timestamp without time zone, timestamp without time zone); Type: FUNCTION; Schema: bctw; Owner: bctw
--

CREATE FUNCTION bctw.link_collar_to_animal_bak(stridir text, collarid uuid, critterid uuid, validfrom timestamp without time zone DEFAULT now(), validto timestamp without time zone DEFAULT NULL::timestamp without time zone) RETURNS SETOF json
    LANGUAGE plpgsql
    AS $$
DECLARE
userid integer := bctw.get_user_id(stridir);
animal_assigned uuid;
deviceid integer := (SELECT device_id FROM bctw.collar WHERE collar_id = collarid LIMIT 1);
existing_deviceid integer;
current_ts timestamptz := now();
err text := 'unable to attach device:';
cur_permission user_permission;
BEGIN
	-- check collar exists
	IF deviceid IS NULL THEN 
		RAISE EXCEPTION '% device ID % does not exist', err, deviceid;
	END IF; 

	-- check critter exists
	IF NOT EXISTS (SELECT 1 FROM bctw.animal WHERE critter_id = critterid) THEN
		RAISE EXCEPTION '% animal with ID % does not exist', err, critterid;
	END IF;

	-- is the device already assigned during this period?
	animal_assigned := (
	  select caa.critter_id from bctw.collar_animal_assignment caa
	  where caa.collar_id = collarid
	  and is_valid(validfrom, caa.valid_from::timestamp, caa.valid_to::timestamp)
	);
	if animal_assigned is not null then
	  if critterid = animal_assigned then
	    raise exception '% device with ID % is already attached to this animal', err, deviceid;
	  else raise exception '% device is currently attached to an animal with ID %', err, animal_assigned;
	  end if;
	end if;

	-- confirm animal isnt already assigned
	existing_deviceid := (
	  SELECT device_id
	  FROM bctw.collar_animal_assignment caa
	  JOIN bctw.collar c
	  ON caa.collar_id = c.collar_id
	  WHERE caa.critter_id = critterid AND is_valid(validfrom, caa.valid_from::timestamp, caa.valid_to::timestamp)
	);
	IF existing_deviceid IS NOT NULL THEN
    RAISE EXCEPTION '% animal is currently attached device with ID %', err, existing_deviceid;
	END IF;

	-- confirm user has permission to change this linkage - must be an admin role or have owner permission - subowner cannot link!
	cur_permission := bctw.get_user_animal_permission(userid, er.critter_id);
	IF cur_permission IS NULL OR cur_permission = ANY('{"observer", "none", "editor"}'::user_permission[]) THEN
	  RAISE EXCEPTION 'you do not have required permission to attach this animal - your permission is: "%"', cur_permission::TEXT;
  END IF;
	
	RETURN query
	WITH i AS (
		INSERT INTO collar_animal_assignment (collar_id, critter_id, created_by_user_id, created_at, valid_from, valid_to)
	 	 VALUES (collarid, critterid, userid, current_ts, validfrom, validto)
	 	 RETURNING critter_id, collar_id, created_at, valid_from, valid_to
	 ) SELECT row_to_json(t) FROM (SELECT * FROM i) t;
END;
$$;


ALTER FUNCTION bctw.link_collar_to_animal_bak(stridir text, collarid uuid, critterid uuid, validfrom timestamp without time zone, validto timestamp without time zone) OWNER TO bctw;

--
-- Name: proc_check_for_missing_telemetry(); Type: PROCEDURE; Schema: bctw; Owner: bctw
--

CREATE PROCEDURE bctw.proc_check_for_missing_telemetry()
    LANGUAGE plpgsql
    AS $$
	-- triggered manually in vendor-merge cronjob as triggers can't exist on materialized views
	-- this procedure iterates records in the last_transmissions view to determine if there
	-- are devices that have not transmitted data in >= 7 days. If new data
	-- has not been received, adds an alert to the telemetry_sensor_alert table
	DECLARE 
	 tr record; -- the latest_transmissions record
	 attached_critterid uuid;
	 j jsonb;
    BEGIN
	 -- only check rows where:
	 -- a) there is a collar_id - ie. latest_transmissions.collar_id isn't null
	 -- b) the collar is attached to an animal - ie has a valid record in the animal_collar_assignment table
	 -- c) the animal status is not mortality
	 -- d) the device deployment status is set to deployed
	 -- e) the device 'retrieved' flag is false? - disabled since d) should cover this
	 FOR tr IN SELECT * FROM bctw.latest_transmissions
	 	WHERE collar_id IS NOT NULL 
	 	AND collar_id IN (SELECT ca.collar_id FROM bctw.collar_animal_assignment ca WHERE is_valid(ca.valid_to))
		LIMIT 5

	 	LOOP
	 		IF now() - INTERVAL '7 days' <= tr."date_recorded" 
				 THEN CONTINUE;
	 		ELSE 
				-- don't add a new alert if there a matching alert 
				IF EXISTS (
					SELECT 1 FROM telemetry_sensor_alert
					WHERE device_make = tr.device_vendor
					AND device_id = tr.device_id
					AND alert_type = 'malfunction'::telemetry_alert_type 
					AND is_valid(valid_to)
					-- disabled to prevent excessive alert spam 
--					AND created_at >= now() - INTERVAL '3 days'
				) THEN 
--					RAISE EXCEPTION 'alert exists %', tr.device_id;
					CONTINUE;
				END IF;
			
				attached_critterid := (
					SELECT ca.critter_id FROM collar_animal_assignment ca
					WHERE is_valid(ca.valid_to)
					AND ca.collar_id = tr.collar_id
				);

				-- if the animal status is mortality, also skip
				IF EXISTS (
					SELECT 1 FROM animal 
					WHERE is_valid(valid_to)
					AND critter_id = attached_critterid
					AND animal_status = bctw.get_code_id('animal_status', 'mortality')
				) THEN CONTINUE;
				END IF;

				-- if the device deployment status is anything but 'deployed', also skip
				IF NOT EXISTS (
					SELECT 1 FROM collar c
					WHERE c.collar_id = tr.collar_id
					AND is_valid(c.valid_to)
					AND c.device_deployment_status = get_code_id('device_deployment_status', 'deployed')
				) THEN CONTINUE;
				END IF;

				-- otherwise, insert the alert
				INSERT INTO telemetry_sensor_alert (device_id, device_make, valid_from, alert_type)
				VALUES (tr.device_id, tr.device_vendor, tr.date_recorded, 'malfunction'::telemetry_alert_type);
			
				-- update the device_status to 'potential malfunction'
				-- maybe dont need to do this since the
				j := jsonb_build_array(
					JSONB_BUILD_OBJECT('collar_id', tr.collar_id, 'device_status', 'potential mortality')
					);
				PERFORM upsert_collar('system', j);
--				RAISE EXCEPTION 'json %', j;

		END IF;
	END LOOP;
	END;
$$;


ALTER PROCEDURE bctw.proc_check_for_missing_telemetry() OWNER TO bctw;

--
-- Name: proc_update_mortality_status(uuid, uuid); Type: PROCEDURE; Schema: bctw; Owner: bctw
--

CREATE PROCEDURE bctw.proc_update_mortality_status(collarid uuid, critterid uuid)
    LANGUAGE plpgsql
    AS $$
BEGIN 
		IF critterid IS NOT NULL AND EXISTS (SELECT 1 FROM animal WHERE critter_id = critterid) THEN 
		-- update the animal record's status to Potential Mortality, using the generic 'Admin' usr
			PERFORM upsert_animal('system', jsonb_build_array(
				JSONB_BUILD_OBJECT(
					'critter_id', critterid,
					'animal_status', 'Potential Mortality'
				)
				)
			);
		END IF;
	
		IF collarid IS NOT NULL AND EXISTS (SELECT 1 FROM collar WHERE collar_id = collarid) THEN 
			PERFORM upsert_collar('system', jsonb_build_array(
			JSONB_BUILD_OBJECT(
				'collar_id', collarid,
				'device_status', 'MORT'
			))
		);
	 END IF;
END
$$;


ALTER PROCEDURE bctw.proc_update_mortality_status(collarid uuid, critterid uuid) OWNER TO bctw;

--
-- Name: PROCEDURE proc_update_mortality_status(collarid uuid, critterid uuid); Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON PROCEDURE bctw.proc_update_mortality_status(collarid uuid, critterid uuid) IS 'called from mortality alert triggers to update device status to mortality and animal status to potential mortality';


--
-- Name: set_user_role(text, text); Type: FUNCTION; Schema: bctw; Owner: bctw
--

CREATE FUNCTION bctw.set_user_role(stridir text, roletype text) RETURNS text
    LANGUAGE plpgsql
    AS $$
declare
	roleid uuid := (SELECT urt.role_id FROM bctw.user_role_type urt WHERE urt.role_type = roletype);
	uid integer := get_user_id(stridir);
begin
	IF uid IS NULL THEN 
		RAISE EXCEPTION 'couldnt find user %', strIdir;
	END IF;

	IF roleid IS NULL THEN 
		RAISE EXCEPTION 'invalid user role %', roletype;
	END IF;

	IF EXISTS (SELECT 1 FROM user_role_xref WHERE user_id = uid) THEN
		UPDATE user_role_xref SET role_id = roleid WHERE user_id = uid;
	ELSE 
		INSERT INTO bctw.user_role_xref(user_id, role_id) VALUES (uid, roleid);
	END IF;

return roleid;
end;
$$;


ALTER FUNCTION bctw.set_user_role(stridir text, roletype text) OWNER TO bctw;

--
-- Name: FUNCTION set_user_role(stridir text, roletype text); Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON FUNCTION bctw.set_user_role(stridir text, roletype text) IS 'sets a user role. currently replaces the old user role if the user already has one. not exposed to api';


--
-- Name: submit_onboarding_request(json); Type: FUNCTION; Schema: bctw; Owner: bctw
--

CREATE FUNCTION bctw.submit_onboarding_request(userjson json) RETURNS SETOF json
    LANGUAGE plpgsql
    AS $$
DECLARE
  ur record;
  role_t bctw.role_type;
  uid TEXT;
BEGIN
 
	-- cannot submit a new request with a status other than pending
  IF (userjson->>'access')::bctw.onboarding_status != 'pending' THEN
  	RAISE EXCEPTION 'onboarding status must be pending for new users';
  END IF;
 
  -- will throw if the requested role type is not valid
  role_t := (userjson->>'role_type')::bctw.role_type;
  uid := (userjson->>'username');
  
  -- todo: update this when idir/bceid are removed from user table
  IF EXISTS (SELECT 1 FROM bctw.USER WHERE bceid = uid OR idir = uid) THEN 
  	RAISE EXCEPTION 'a user with username % already exists ', uid;
  END IF; 
 
 	-- denied requests can be resubmitted. leave it up to the frontend to determine how/when it can be resubmitted
 	-- todo: also check email?
  IF EXISTS (SELECT 1 FROM onboarding o WHERE o.username = uid AND o."access" = 'pending') THEN 
    RAISE EXCEPTION 'this request already exists for % username %. Status: %', userjson->>'domain', uid, (SELECT "access" FROM onboarding WHERE username = uid);
  END IF;

  ur := json_populate_record(NULL::bctw.onboarding, userjson);
 
  RETURN query
  WITH ins AS (
	INSERT INTO bctw.onboarding (domain, username, firstname, lastname, access, email, phone, role_type, reason, valid_from)
		VALUES (
			ur.domain,
			ur.username,
			ur.firstname,
			ur.lastname,
			ur.access,
			ur.email,
			ur.phone,
			role_t,
			ur.reason,
			now()
		) RETURNING *
	) SELECT row_to_json(t) FROM (SELECT * FROM ins) t; 
	
END;
$$;


ALTER FUNCTION bctw.submit_onboarding_request(userjson json) OWNER TO bctw;

--
-- Name: submit_permission_request(text, text[], jsonb, text); Type: FUNCTION; Schema: bctw; Owner: bctw
--

CREATE FUNCTION bctw.submit_permission_request(stridir text, user_emails text[], user_permissions jsonb, requestcomment text DEFAULT ''::text) RETURNS SETOF jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
  userid_granting integer := bctw.get_user_id(stridir); -- id OF the USER performing the reqeust (an owner)
  e TEXT;             -- this iteration of the email list
  user_ids integer[]; -- retrieved userids from the email list
  uid integer;			  -- this iteration OF the user_ids list
  curid integer;			-- user id fetched using the email address
  j json;						  -- json value at current iteration OF user_permissions array
  reqid integer;      -- inserted request record_id
  newids integer[]; 
BEGIN
  IF userid_granting IS NULL THEN
    RAISE EXCEPTION 'unable find user with identifier %', stridir;
  END IF;
 
 -- confirm this user is a manager
 IF NOT EXISTS (
 	SELECT 1 FROM bctw_dapi_v1.user_v WHERE id = userid_granting AND is_owner
 ) THEN RAISE EXCEPTION 'user performing permission request must be a manager';
 END IF;
 
 -- convert the email list to a list of user IDs
 FOREACH e IN ARRAY user_emails LOOP
  curid := (SELECT u.id FROM bctw.USER u WHERE u.email = e);
  IF curid IS NULL THEN
  	RAISE EXCEPTION 'cannot find a user with the email %', e;
  END IF;
  user_ids := array_append(user_ids, curid);
 END LOOP;

 
 FOR j IN SELECT * FROM jsonb_array_elements(user_permissions) LOOP
 	 -- validate the user_permission json objects before saving
   IF j->>'critter_id' IS NULL OR j->>'permission_type' IS NULL THEN 
 	 	 RAISE EXCEPTION 'invalid JSON supplied - record must contain critter_id and permission_type: %', j;
 	 END IF;
 	 
 	 FOREACH uid IN ARRAY user_ids LOOP
	 	 -- add the record to the permission_request table
	 	 INSERT INTO bctw.permission_request (user_id_list, critter_permission_list, request_comment, requested_by_user_id)
	   	SELECT 
	   		ARRAY[uid],
	   		j,
	   		requestcomment,
	   		userid_granting
	 		RETURNING request_id INTO reqid;
	 	 newids := array_append(newids, reqid);
	 	
 	END LOOP; 
 END LOOP; 
 
-- RETURN query SELECT row_to_json(t) FROM (SELECT * FROM bctw.permission_request WHERE request_id = ret) t;
-- RETURN query SELECT * FROM bctw.permission_request WHERE request_id = ANY(newids);
 RETURN query SELECT jsonb_agg(t) FROM (
	SELECT * FROM bctw_dapi_v1.permission_requests_v WHERE request_id = ANY(newids)
) t;
  
END;
$$;


ALTER FUNCTION bctw.submit_permission_request(stridir text, user_emails text[], user_permissions jsonb, requestcomment text) OWNER TO bctw;

--
-- Name: FUNCTION submit_permission_request(stridir text, user_emails text[], user_permissions jsonb, requestcomment text); Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON FUNCTION bctw.submit_permission_request(stridir text, user_emails text[], user_permissions jsonb, requestcomment text) IS 'persists an animal permission request from a manager.';


--
-- Name: trg_new_alert(); Type: FUNCTION; Schema: bctw; Owner: bctw
--

CREATE FUNCTION bctw.trg_new_alert() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
	-- on insert to the telemetry_sensor_alert table
	DECLARE 
	new_record record;
	collarid uuid;
	critterid uuid;
	sms_payload jsonb;
    BEGIN
	    SELECT * FROM new_table
		  INTO new_record;
	
			IF new_record IS NULL THEN 
				RETURN NULL;
			END IF;
	    
			collarid := (
				SELECT collar_id FROM collar
				WHERE device_id = new_record.device_id
				AND is_valid(valid_to)
				AND device_make = get_code_id('device_make', new_record.device_make)
			);

			IF collarid IS NULL THEN 
--				RAISE EXCEPTION 'null collar';
				RETURN NULL;
			END IF;
		
			critterid := (
				SELECT critter_id FROM collar_animal_assignment 
				WHERE is_valid(valid_to) AND collar_id = collarid
			);
		
			IF critterid IS NULL THEN 
--				RAISE EXCEPTION 'null critter';
				RETURN NULL;
			END IF; 
			
			sms_payload := (SELECT (SELECT json_agg(t) FROM (
			    SELECT DISTINCT u.id AS "user_id", u.phone, u.email, u.firstname,
			    	a.wlh_id, a.species, a.animal_id,
					new_record.valid_from AS "date_time",
					(SELECT frequency FROM bctw.collar WHERE collar_id = collarid AND valid_to IS NULL) AS "frequency",
					new_record.latitude, new_record.longitude, new_record.device_id
			    FROM user_animal_assignment uaa 
				JOIN bctw.USER u ON u.id = uaa.user_id
				JOIN animal_v a ON uaa.critter_id = a.critter_id
				WHERE uaa.valid_to IS NULL
				AND uaa.permission_type = ANY('{editor, manager}')
				AND uaa.critter_id = critterid
			  ) t));
			 
			 PERFORM pg_notify('TRIGGER_ALERT_SMS', sms_payload::text);

 			RETURN NULL;
    END;
$$;


ALTER FUNCTION bctw.trg_new_alert() OWNER TO bctw;

--
-- Name: trg_process_ats_insert(); Type: FUNCTION; Schema: bctw; Owner: bctw
--

CREATE FUNCTION bctw.trg_process_ats_insert() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
	-- triggered after insert of ats_collar_data, trigger name ats_insert_trg
	-- trigger occurs only when ats_collar_data.mortality is true
	DECLARE 
	 new_record record;
	 existing_collar_id uuid;
	 attached_critter_id uuid;
   devicevendor varchar := 'ATS';
    BEGIN
	  -- the ats_collar_data record
	  SELECT * FROM new_table INTO new_record;
	
		-- determine if there is already an existing alert for this device
		IF EXISTS (
			SELECT 1 FROM telemetry_sensor_alert tsa
			WHERE tsa.device_make = devicevendor
			AND tsa.device_id = new_record.collarserialnumber
			AND tsa.alert_type = 'mortality'::telemetry_alert_type 
			AND is_valid(tsa.valid_to)
		) THEN 
--			RAISE EXCEPTION 'theres already an alert!';
			RETURN NULL;
		END IF;

		-- get the existing device record
		existing_collar_id := (
			SELECT collar_id FROM collar 
			WHERE device_id = new_record.collarserialnumber 
			AND is_valid(valid_to) 
			AND device_make = get_code_id('device_make', devicevendor)
		);

		-- if the device doesn't exist in the collar table, no point in making an alert
		IF existing_collar_id IS NULL THEN
			RETURN NULL;
		END IF;

		-- insert the telemetry alert
		INSERT INTO telemetry_sensor_alert (device_id, device_make, valid_from, alert_type, latitude, longitude)
		VALUES (new_record.collarserialnumber, devicevendor, new_record."date", 'mortality'::telemetry_alert_type, new_record.latitude, new_record.longitude);

		-- find the animal attached to this collar, if it exists
		attached_critter_id = (
			SELECT critter_id 
			FROM collar_animal_assignment 
			WHERE is_valid(valid_to)
			AND collar_id = existing_collar_id
		);
	
		-- update the mortality status for the device/animal
		CALL proc_update_mortality_status(existing_collar_id, attached_critter_id);

		RETURN NULL; 

    END;
$$;


ALTER FUNCTION bctw.trg_process_ats_insert() OWNER TO bctw;

--
-- Name: FUNCTION trg_process_ats_insert(); Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON FUNCTION bctw.trg_process_ats_insert() IS 'triggered on set of records inserted to ats_collar_data, this function checks existing collar status for alert flags. If the flag is considered new, it inserts an alert and updates the collar record.';


--
-- Name: trg_process_lotek_insert(); Type: FUNCTION; Schema: bctw; Owner: bctw
--

CREATE FUNCTION bctw.trg_process_lotek_insert() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
	-- triggered from telemetry_sensor_alert -> lotek_alert_trg 
	-- Lotek alerts are a separate API, they are inserted directly to the telemetry_sensor_alert table.
	-- Unlike other vendors, this trigger handler occurs when alerts are inserted into the alert table
	-- This trigger only occurs after inserts with device_make 'Lotek'
	-- This trigger only updates the mortality status for the attached animal / device
	-- fixme: need to check/prevent multiple alerts being added to alert table in the api cronjob
	DECLARE 
	new_record record;
	collarid uuid;
	critterid uuid;
    BEGIN
	    -- get the alert record, specifying Lotek as the device vendor
	    SELECT * FROM new_table
		  INTO new_record;
	
			IF new_record IS NULL THEN 
				RETURN NULL;
			END IF;
	    
			collarid := (
				SELECT collar_id FROM collar
				WHERE device_id = new_record.device_id
				AND is_valid(valid_to)
				AND device_make = get_code_id('device_make', 'Lotek')
			);

			IF collarid IS NULL THEN 
				RETURN NULL;
			END IF;
		
			critterid := (
				SELECT critter_id FROM collar_animal_assignment 
				WHERE is_valid(valid_to) AND collar_id = collarid
			);
		
			CALL proc_update_mortality_status(collarid, critterid);

			-- result is ignored since this is an AFTER trigger
			RETURN NULL; 
    END;
$$;


ALTER FUNCTION bctw.trg_process_lotek_insert() OWNER TO bctw;

--
-- Name: FUNCTION trg_process_lotek_insert(); Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON FUNCTION bctw.trg_process_lotek_insert() IS 'triggered on the insert of a Lotek user alert to the telemetry_sensor_alert alert table, this function updates collar and critter metadata if the alert is determined to be valid.';


--
-- Name: trg_process_new_user(); Type: FUNCTION; Schema: bctw; Owner: bctw
--

CREATE FUNCTION bctw.trg_process_new_user() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE  
	 new_record record;
	BEGIN 
	   
	-- the new user as a record
	SELECT n.* FROM new_table n INTO new_record;

	IF new_record."domain" = 'idir' THEN 
		UPDATE bctw.USER SET idir = new_record.username
		WHERE id = new_record.id;
	ELSIF new_record."domain" = 'bceid' THEN 
		UPDATE bctw.USER SET bceid = new_record.username
		WHERE id = new_record.id;
	END IF;
	
	RETURN NULL; 
	END;
$$;


ALTER FUNCTION bctw.trg_process_new_user() OWNER TO bctw;

--
-- Name: FUNCTION trg_process_new_user(); Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON FUNCTION bctw.trg_process_new_user() IS 'when new rows are inserted to the user table, update the idir/bceid columns if not present';


--
-- Name: trg_process_vectronic_insert(); Type: FUNCTION; Schema: bctw; Owner: bctw
--

CREATE FUNCTION bctw.trg_process_vectronic_insert() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
-- trigger name vectronics_collar_data -> vectronic_alert_trg
-- trigger only occurs when the idmortalitystatus is 1 (a mortality is detected)
	DECLARE 
	 new_record record;
	 existing_collar_id uuid;
	 attached_critter_id uuid;
	 devicevendor varchar := 'Vectronic';
    BEGIN
	  -- the vectronic_collar_data record with mortality
	  SELECT * FROM new_table INTO new_record;
	
		-- determine if there is already an existing alert for this device
		IF EXISTS (
			SELECT 1 FROM telemetry_sensor_alert tsa
			WHERE tsa.device_make = devicevendor
			AND tsa.device_id = new_record.idcollar
			AND is_valid(tsa.valid_to)
		) THEN 
--			RAISE EXCEPTION 'theres already an alert!';
			RETURN NULL;
		END IF;

		-- get the existing device record
		existing_collar_id := (
			SELECT collar_id FROM collar 
			WHERE device_id = new_record.idcollar 
			-- fixme: is_valid RETURNING MORE than one row??
			AND valid_to IS NULL 
			AND device_make = get_code_id('device_make', devicevendor)
		);
	
		-- if the device doesn't exist in the collar table, no point in making an alert
		IF existing_collar_id IS NULL THEN
			RETURN NULL;
		END IF;

		-- insert the telemetry alert
		INSERT INTO telemetry_sensor_alert (device_id, device_make, valid_from, alert_type, latitude, longitude)
		VALUES (new_record.idcollar, devicevendor, new_record.acquisitiontime, 'mortality'::telemetry_alert_type, new_record.latitude, new_record.longitude);

		-- find the animal attached to this collar, if it exists
		attached_critter_id = (
			SELECT critter_id 
			FROM collar_animal_assignment 
			WHERE is_valid(valid_to)
			AND collar_id = existing_collar_id
		);
	
		-- update the mortality status for the device/animal
		CALL proc_update_mortality_status(existing_collar_id, attached_critter_id);

		RETURN NULL; 
    END;
$$;


ALTER FUNCTION bctw.trg_process_vectronic_insert() OWNER TO bctw;

--
-- Name: trg_update_animal_retroactively(); Type: FUNCTION; Schema: bctw; Owner: bctw
--

CREATE FUNCTION bctw.trg_update_animal_retroactively() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE	new_record record;
BEGIN
	SELECT * FROM inserted INTO new_record;
	
	-- if this animal has no history, don't need to do anything
	IF NOT EXISTS (SELECT 1 FROM animal WHERE critter_id = new_record.critter_id AND valid_to IS NOT NULL) THEN
--		RAISE EXCEPTION 'no history for this critter! %', new_record.critter_id;
		RETURN NULL;
	END IF; 

	-- handle each retroactive field.
	-- should only need to update historic records
	IF new_record.sex IS NOT NULL THEN
--		RAISE EXCEPTION 'animal sex field is present!';
		UPDATE animal SET sex = new_record.sex
		WHERE critter_id = new_record.critter_id
--		AND NOT is_valid(valid_to); -- this check does not seem to work!
		AND valid_to IS NOT NULL; -- AND valid_to < now();  -- doesnt work either
	
	END IF;
	RETURN NULL;
END;
$$;


ALTER FUNCTION bctw.trg_update_animal_retroactively() OWNER TO bctw;

--
-- Name: unlink_collar_to_animal(text, uuid, timestamp with time zone, timestamp with time zone); Type: FUNCTION; Schema: bctw; Owner: bctw
--

CREATE FUNCTION bctw.unlink_collar_to_animal(stridir text, assignmentid uuid, actual_end timestamp with time zone, data_life_end timestamp with time zone) RETURNS SETOF json
    LANGUAGE plpgsql
    AS $$
DECLARE
userid integer:= bctw.get_user_id(stridir);
critterid uuid := (SELECT critter_id FROM bctw.collar_animal_assignment WHERE assignment_id = assignmentid);
cur_permission user_permission;
err text := 'failed to remove device:';
current_ts timestamptz := now();
cur_data_life_start timestamptz;
BEGIN
	-- changed unattach to only take assignment_id
	-- FIX do animal/collar checks still need to be done??

	IF NOT EXISTS (SELECT 1 FROM bctw.collar_animal_assignment WHERE assignment_id = assignmentid) THEN
		RAISE EXCEPTION 'this device / animal attchment relationship does not exist';
	END IF;

	-- ensure end timestamps are after the data_life_start of the device attachment
	cur_data_life_start := (SELECT valid_from FROM collar_animal_assignment WHERE assignment_id = assignmentid);
	IF actual_end <= cur_data_life_start OR data_life_end <= cur_data_life_start THEN
		RAISE EXCEPTION 'end dates must be after the data_life_start %', cur_data_life_start;
	END IF;

	-- ensure data_life_end is before actual_end
	IF data_life_end > actual_end THEN
		RAISE EXCEPTION 'data life end must be before actual end';
	END IF;

	-- confirm user has permission to remove the device - must be an admin, owner, or subowner permission
	cur_permission := bctw.get_user_animal_permission(userid, critterid);
	IF cur_permission IS NULL OR cur_permission = ANY('{"observer", "none"}'::user_permission[]) THEN
	  RAISE EXCEPTION 'you do not have required permission to remove this device - your permission is: "%"', cur_permission::TEXT;
	END IF;

	RETURN query
		WITH upd AS (
			UPDATE collar_animal_assignment
			SET 
				attachment_end = actual_end,
				valid_to = data_life_end,
				updated_at = current_ts,
				updated_by_user_id = userid
			WHERE assignment_id = assignmentid
			RETURNING *
		) SELECT row_to_json(t) FROM (SELECT * FROM upd) t;
END;
$$;


ALTER FUNCTION bctw.unlink_collar_to_animal(stridir text, assignmentid uuid, actual_end timestamp with time zone, data_life_end timestamp with time zone) OWNER TO bctw;

--
-- Name: unlink_collar_to_animal_bak(text, uuid, uuid, timestamp with time zone); Type: FUNCTION; Schema: bctw; Owner: bctw
--

CREATE FUNCTION bctw.unlink_collar_to_animal_bak(stridir text, collarid uuid, critterid uuid, validto timestamp with time zone DEFAULT now()) RETURNS SETOF json
    LANGUAGE plpgsql
    AS $$
DECLARE
userid integer:= bctw.get_user_id(stridir);
cur_permission user_permission;
BEGIN
	IF validto IS NULL THEN
		RAISE EXCEPTION 'a data life end date must be provided to remove a device';
	END IF;
	-- check collar exists
	IF NOT EXISTS (SELECT 1 FROM bctw.collar WHERE collar_id = collarid)
		THEN RAISE EXCEPTION 'collar with id % does not exist', collarid;
	END IF;
	-- check critter exists
	IF NOT EXISTS(SELECT 1 FROM bctw.animal WHERE critter_id = critterid) 
		THEN RAISE EXCEPTION 'animal with id % does not exist', critterid;
	END IF;
	-- confirm this collar is assigned to the critterid provided
	IF NOT EXISTS (
		SELECT 1 FROM collar_animal_assignment
		WHERE collar_id = collarid
		AND critter_id = critterid
		AND (valid_to >= now() OR valid_to IS NULL)
	)
		THEN RAISE EXCEPTION 'invalid attempt to remove collar, perhaps collar_id % is attached to a different critter than the animal id provided', collarid;
	END IF;

	-- confirm user has permission to remove the device - must be an admin role or have owner/subowner permission
	cur_permission := bctw.get_user_animal_permission(userid, er.critter_id);
	IF cur_permission IS NULL OR cur_permission = ANY('{"observer", "none"}'::user_permission[]) THEN
	  RAISE EXCEPTION 'you do not have required permission to remove this device - your permission is: "%"', cur_permission::TEXT;
  END IF;

	RETURN query
		WITH upd AS (
			UPDATE collar_animal_assignment
			SET valid_to = validto,
				updated_at = now(),
				updated_by_user_id = userid
			WHERE collar_id = collarid AND critter_id = critterid
			AND (valid_to >= now() OR valid_to IS NULL)
			RETURNING collar_id, critter_id, valid_from, valid_to
		) SELECT row_to_json(t) FROM (SELECT * FROM upd) t;
END;
$$;


ALTER FUNCTION bctw.unlink_collar_to_animal_bak(stridir text, collarid uuid, critterid uuid, validto timestamp with time zone) OWNER TO bctw;

--
-- Name: update_attachment_data_life(text, uuid, timestamp with time zone, timestamp with time zone); Type: FUNCTION; Schema: bctw; Owner: bctw
--

CREATE FUNCTION bctw.update_attachment_data_life(stridir text, assignmentid uuid, data_life_start timestamp with time zone, data_life_end timestamp with time zone) RETURNS SETOF json
    LANGUAGE plpgsql
    AS $$
DECLARE
current_ts timestamptz := now();
userid integer:= bctw.get_user_id(stridir);
critterid uuid;
actual_start timestamptz;
actual_end timestamptz;
is_admin boolean;
bookend_start_was_changed boolean;
bookend_end_was_changed boolean;
BEGIN
	IF NOT EXISTS (SELECT 1 FROM bctw.collar_animal_assignment WHERE assignment_id = assignmentid) THEN
		RAISE EXCEPTION 'this device / animal attchment relationship does not exist';
	END IF;

	actual_start := (SELECT attachment_start FROM collar_animal_assignment WHERE assignment_id = assignmentid);
	actual_end := (SELECT attachment_end FROM collar_animal_assignment WHERE assignment_id = assignmentid);
	critterid := (SELECT critter_id FROM collar_animal_assignment WHERE assignment_id = assignmentid);

	is_admin := (SELECT bctw.get_user_animal_permission(userid, critterid) = 'admin'::user_permission);

	-- data_life start/end considered to changed if they dont match the actual_start/end timestamps
	-- note: DL start/end timestamps parameters have the seconds trimmed: ex. 2021-01-01 12:00, but the postgres datetime comparison can still consider them equal
	bookend_start_was_changed := (SELECT valid_from != attachment_start FROM bctw.collar_animal_assignment WHERE assignment_id = assignmentid);
	bookend_end_was_changed := (SELECT valid_to != attachment_end FROM bctw.collar_animal_assignment WHERE assignment_id = assignmentid);

	-- if data_life_was_updated was already set and user is not admin, throw exception
--	IF cur_permission = ANY('{"observer", "none", "editor", "manager"}'::user_permission[]) AND data_life_already_changed THEN
--	  RAISE EXCEPTION 'data life has already been changed for this device assignment';
--	END IF;

	IF NOT is_admin AND bookend_start_was_changed AND data_life_start IS NOT NULL THEN
		RAISE EXCEPTION 'data life start has been set to % and cannot be changed again', (SELECT valid_from FROM collar_animal_assignment WHERE assignment_id = assignmentid);
	END IF;

	IF NOT is_admin AND bookend_end_was_changed AND data_life_end IS NOT NULL THEN
		RAISE EXCEPTION 'data life end has been set to % and cannot be changed again', (SELECT valid_to FROM collar_animal_assignment WHERE assignment_id = assignmentid);
	END IF;

	IF data_life_start < actual_start THEN
		RAISE EXCEPTION 'data life start (%) must be after actual capture timestamp of %', data_life_start, actual_start;
	END IF;

	-- if updating date_life_end...this assignment must be historic/unattached?
	IF data_life_end IS NOT NULL AND is_valid(actual_end) THEN
		RAISE EXCEPTION 'to change the bookend end timestamp, the device must be unatttached';
	END IF;

	IF data_life_end >  actual_end THEN 
		RAISE EXCEPTION 'data life end (%) must be before the actual end timestamp of %', data_life_end, actual_end;
	END IF; 

	-- TODO: verify there is no overlap for previous assignments? animal/collar/both??

	RETURN query
		WITH 
		cur_assign AS (SELECT * FROM collar_animal_assignment WHERE assignment_id = assignmentid),
		upd AS (
			UPDATE collar_animal_assignment
			SET 
				valid_from = COALESCE(data_life_start, (SELECT valid_from FROM cur_assign)),
				valid_to = COALESCE(data_life_end, (SELECT valid_to FROM cur_assign)),
				updated_at = current_ts,
				updated_by_user_id = userid
				--,			data_life_was_updated = TRUE
			WHERE assignment_id = assignmentid
			RETURNING *
		) SELECT row_to_json(t) FROM (SELECT * FROM upd) t;
END;
$$;


ALTER FUNCTION bctw.update_attachment_data_life(stridir text, assignmentid uuid, data_life_start timestamp with time zone, data_life_end timestamp with time zone) OWNER TO bctw;

--
-- Name: update_user_telemetry_alert(text, jsonb); Type: FUNCTION; Schema: bctw; Owner: bctw
--

CREATE FUNCTION bctw.update_user_telemetry_alert(stridir text, alertjson jsonb) RETURNS SETOF json
    LANGUAGE plpgsql
    AS $$
DECLARE
  user_id integer := bctw.get_user_id(stridir);
  j json;
  ar record;
  alertid integer;
  i integer := 0;
  alert_records telemetry_sensor_alert[];
  current_ts timestamp without time zone;
BEGIN
  FOR j IN SELECT jsonb_array_elements(alertjson)
    LOOP
      i := i + 1;
      BEGIN
	   ar := jsonb_populate_record(NULL::telemetry_sensor_alert, j::jsonb);
	   alertid := (SELECT alert_id FROM telemetry_sensor_alert WHERE alert_id = ar.alert_id);
	   IF alertid IS NULL THEN
	   	 RAISE EXCEPTION 'telemetry alert with ID % not found', alertid;
	   END IF;
	  alert_records := array_append(alert_records, ar);
	 END;
  END LOOP;
   
  current_ts = now();
 
  FOREACH ar IN ARRAY alert_records LOOP
	  UPDATE bctw.telemetry_sensor_alert
	  SET valid_to = ar.valid_to,
	  		snoozed_to = ar.snoozed_to,
	  		snooze_count = ar.snooze_count,
	  		updated_at = current_ts
	  WHERE alert_id = ar.alert_id;
    END LOOP;
 
  RETURN query
  SELECT json_agg(t)
  FROM (
    SELECT * FROM telemetry_sensor_alert
    WHERE alert_id = ANY ((SELECT alert_id FROM unnest(alert_records)))
  ) t;

END;
$$;


ALTER FUNCTION bctw.update_user_telemetry_alert(stridir text, alertjson jsonb) OWNER TO bctw;

--
-- Name: FUNCTION update_user_telemetry_alert(stridir text, alertjson jsonb); Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON FUNCTION bctw.update_user_telemetry_alert(stridir text, alertjson jsonb) IS 'used to either expire (invalidate) the telemetry alert or update its snooze status';


--
-- Name: upsert_animal(text, jsonb); Type: FUNCTION; Schema: bctw; Owner: bctw
--

CREATE FUNCTION bctw.upsert_animal(stridir text, animaljson jsonb) RETURNS SETOF json
    LANGUAGE plpgsql
    AS $$
DECLARE
  userid integer := bctw.get_user_id(stridir);
  current_ts timestamptz := now();
  j jsonb; 								-- the current json record
  i integer := 0;					-- the loop index variable
  existing_critter jsonb; -- existing animal record as json
  ar record; 							-- animal table record created from merging the existing/new json
  critters animal[]; 			-- new animal records to be inserted
  ids uuid[]; 						-- stores the critter ids added
  new_props_json jsonb; 	-- json object created to add new properties
BEGIN
	IF userid IS NULL THEN
    RAISE exception 'user with idir % does not exist', stridir;
  END IF;
 
  FOR j IN SELECT jsonb_array_elements(animaljson) LOOP
     i := i + 1;
     BEGIN
	     -- generate history properties for the record
	     new_props_json := jsonb_build_object(
			 'updated_at', current_ts,
			 'updated_by', userid,
			 'valid_from', (SELECT (SELECT CASE WHEN j ? 'valid_from' THEN j->>'valid_from' ELSE current_ts::text END)::timestamptz),
			 'valid_to', (SELECT (SELECT CASE WHEN j ? 'valid_to' THEN j->>'valid_to' ELSE NULL END)::timestamptz)
	     );
		 -- merge the json objects, passing the new object as the second parameter preserve the updated/new column values
	     j := (SELECT j || new_props_json);
			 -- find the existing critter as json
			 existing_critter := CASE WHEN NOT EXISTS (SELECT 1 FROM animal WHERE critter_id = (j->>'critter_id')::uuid) THEN
				-- if this animal doesn't exist, generate a new critter_id and map colour for it
				 j || jsonb_build_object(
				 		'critter_id', crypto.gen_random_uuid(),
				 		-- while not using code again...want the map colour to be the code_value/desc
				 		'map_colour', (SELECT code_name FROM code WHERE code_id = bctw_dapi_v1.get_random_colour_code_id() AND is_valid(valid_to)),
				 		'owned_by_user_id', userid,
				 		'created_by_user_id', userid,
				 		'created_at', current_ts
				 )
				-- otherwise create a json row from the existing critter using the its record in the animal view
				ELSE (
					SELECT row_to_json(t)::jsonb FROM (
-- 						using the view version of the animal until frontend passes the code_id for codes. so the code props will be in their text/description format
--						SELECT * FROM animal WHERE critter_id = (j->>'critter_id')::uuid AND is_valid(valid_to)
						SELECT * FROM animal_v WHERE critter_id = (j->>'critter_id')::uuid AND valid_to IS NULL -- is_valid(valid_to)
					) t)
			END;
			 -- merge the new changes into the existing json record
--			 todo until frontend passes code_id for codes, call json_to_animal to convert the existing animal props from the merged json object to the int values for codes
--			 critters := array_append(critters, jsonb_populate_record(NULL::bctw.animal, (existing_critter || j)));
			 critters := array_append(critters,  json_to_animal(existing_critter || j));
		 END;
  END LOOP;
 
  FOREACH ar IN ARRAY critters LOOP

  		 IF NOT EXISTS (SELECT 1 from animal WHERE critter_id = ar.critter_id) THEN
  		 -- grant 'manager' permission for the new critter to this user
		 INSERT INTO bctw.user_animal_assignment (user_id, critter_id, created_by_user_id, permission_type)
			 VALUES (userid, ar.critter_id, userid, 'manager'::user_permission);
		 END IF;

		 ids := array_append(ids, ar.critter_id);

		-- expire the existing critter record
		UPDATE bctw.animal
			SET valid_to = current_ts, updated_at = current_ts, updated_by_user_id = userid
			WHERE bctw.is_valid(valid_to)
			AND critter_id = ar.critter_id;

		-- finally, insert the new record
	 	INSERT INTO bctw.animal SELECT ar.*;

 END LOOP;
 RETURN query SELECT json_strip_nulls(
   (SELECT json_agg(t) FROM (
		SELECT * FROM bctw.animal_v
		WHERE critter_id = ANY (ids)
		AND (valid_to > now() OR valid_to IS NULL)
  ) t));
END;
$$;


ALTER FUNCTION bctw.upsert_animal(stridir text, animaljson jsonb) OWNER TO bctw;

--
-- Name: upsert_bulk(text, text, jsonb); Type: FUNCTION; Schema: bctw; Owner: bctw
--

CREATE FUNCTION bctw.upsert_bulk(username text, upsert_type text, records jsonb) RETURNS SETOF json
    LANGUAGE plpgsql
    AS $$
DECLARE
  j json; 			-- current element of the json loop
  i integer := 0; 	-- current index of the json loop
  r record; 		-- the json converted to a table row
BEGIN
  IF upsert_type != ALL('{"animal", "device"}') THEN
 	RAISE EXCEPTION 'invalid bulk type provided: "%", must be either "animal" or "device"', upsert_type;
  END IF;

  CREATE TEMPORARY TABLE IF NOT EXISTS errors (
    rownum integer,
    error text,
    ROW json
  );
  -- since most bulk insertion errors will be converting the json to a record,
  -- use an exception handler inside the loop that can continue if one is caught
  FOR j IN SELECT jsonb_array_elements(records) LOOP
      i := i + 1;
      BEGIN
	      IF upsert_type = 'animal' THEN
	      	r := json_to_animal(j::jsonb);
	      ELSE 
	      	r :=  json_to_collar(j::jsonb);
	      END IF;
        EXCEPTION
        WHEN sqlstate '22007' THEN -- an invalid date was provided
          INSERT INTO errors
            VALUES (i, 'invalid date format, date must be in the format YYYY-MM-DD', j);
        WHEN OTHERS THEN
          INSERT INTO errors
            VALUES (i, SQLERRM, j);
        END;
  END LOOP;
   
  -- exit early if there were errors
  IF EXISTS (SELECT 1 FROM errors) THEN
    RETURN query SELECT JSON_AGG(src) FROM (SELECT * FROM errors) src;
  	RETURN;
	END IF;
  DROP TABLE errors;
 
 IF upsert_type ='animal' THEN RETURN query SELECT bctw.upsert_animal(username, records);
 ELSE RETURN query SELECT bctw.upsert_collar(username, records);
 END IF;

END;
$$;


ALTER FUNCTION bctw.upsert_bulk(username text, upsert_type text, records jsonb) OWNER TO bctw;

--
-- Name: upsert_collar(text, jsonb); Type: FUNCTION; Schema: bctw; Owner: bctw
--

CREATE FUNCTION bctw.upsert_collar(stridir text, collarjson jsonb) RETURNS SETOF json
    LANGUAGE plpgsql
    AS $$
DECLARE
  userid integer := bctw.get_user_id(stridir);
  current_ts timestamptz := now();
  j jsonb;                     -- current element of the collarjson loop
  i integer := 0;					-- the loop index variable
  existing_collar jsonb; -- existing animal record as json
  cr record; 									-- the collar json converted to a collar table ROW
  collars collar[];  -- collar records TO be updated
  ids uuid[];			            -- list of the updated/added collar_ids 
  new_props_json jsonb; 	-- json object created to add new properties
 
BEGIN
  IF userid IS NULL THEN
    RAISE exception 'user with idir % does not exist', stridir;
  END IF;

  FOR j IN SELECT jsonb_array_elements(collarjson) LOOP
     i := i + 1;
     BEGIN
	     -- generate history properties for the record
	     new_props_json := jsonb_build_object(
			 'updated_at', current_ts,
			 'updated_by', userid,
			 'valid_from', (SELECT (SELECT CASE WHEN j ? 'valid_from' THEN j->>'valid_from' ELSE current_ts::text END)::timestamptz),
			 'valid_to', (SELECT (SELECT CASE WHEN j ? 'valid_to' THEN j->>'valid_to' ELSE NULL END)::timestamptz)
	     );
		 -- merge the json objects, passing the new object as the second parameter preserve the updated/new column values
	     j := (SELECT j || new_props_json);
			 -- find the existing device as json
			 existing_collar := CASE WHEN NOT EXISTS (SELECT 1 FROM collar WHERE collar_id = (j->>'collar_id')::uuid LIMIT 1) THEN
				-- if this device doesn't exist, generate a new collar_id
				 j || jsonb_build_object('collar_id', crypto.gen_random_uuid(), 'owned_by_user_id', userid) 
				-- otherwise create a json row from the existing device using the its record in the collar view
				ELSE (
					SELECT row_to_json(t)::jsonb FROM (
-- 						using the view version of the device until frontend passes the code_id for codes. so the code props will be in their text/description format
--						SELECT * FROM collar WHERE collar_id = (j->>'collar_id')::uuid AND is_valid(valid_to)
						-- fixme: sometimes returning more than one row
						SELECT * FROM collar_v WHERE collar_id = (j->>'collar_id')::uuid AND valid_to IS NULL -- is_valid(valid_to) LIMIT 1
					) t)
			END;
--			RAISE EXCEPTION 'hi %', existing_collar;
			 -- merge the new changes into the existing json record
--			 todo until frontend passes code_id for codes, call json_to_animal to convert the existing animal props from the merged json object to the int values for codes
--			 collars := array_append(collars, jsonb_populate_record(NULL::bctw.collar, (existing_collar || j)));
			 collars := array_append(collars,  json_to_collar(existing_collar || j));
		 END;
  END LOOP;
 
  FOREACH cr IN ARRAY collars LOOP

		 ids := array_append(ids, cr.collar_id);

		-- expire the existing device record
		UPDATE bctw.collar
			SET valid_to = current_ts, updated_at = current_ts, updated_by_user_id = userid
			WHERE bctw.is_valid(valid_to)
			AND collar_id = cr.collar_id;

		-- finally, insert the new record	
	 	INSERT INTO bctw.collar SELECT cr.*;

 END LOOP;
 
RETURN query SELECT json_strip_nulls(
   (SELECT json_agg(t) FROM (
    SELECT * FROM collar_v
    WHERE collar_id = ANY (ids)
    AND (valid_to > now() OR valid_to IS NULL)
) t));

END;
$$;


ALTER FUNCTION bctw.upsert_collar(stridir text, collarjson jsonb) OWNER TO bctw;

--
-- Name: upsert_udf(text, jsonb); Type: FUNCTION; Schema: bctw; Owner: bctw
--

CREATE FUNCTION bctw.upsert_udf(username text, new_udf jsonb) RETURNS SETOF jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
  userid integer := bctw.get_user_id(username);
  elem_index integer;
 	u jsonb;
	idx integer;
  new_udf_array jsonb;
  udf_type text := jsonb_typeof(new_udf);
BEGIN
	IF userid IS NULL THEN
    RAISE exception 'couldn\t find user with username %', username;
	END IF;
   
	 -- if the there are no udfs for this user, and the new_udf json is an object, store it in an array
	IF (udf_type = 'object') THEN
		new_udf_array := jsonb_build_array(new_udf);
	ELSE IF (udf_type = 'array') THEN
		new_udf_array := new_udf;
	ELSE RAISE EXCEPTION 'invalid json, must be object';
	END IF; END IF;
    
	-- this user has no udfs
	IF NOT EXISTS(
		SELECT 1 FROM user_defined_field WHERE user_id = userid AND is_valid(valid_to)
	)
	THEN INSERT INTO user_defined_field (user_id, udf) VALUES (userid, new_udf_array);

	ELSE 
		FOR u IN SELECT * FROM jsonb_array_elements(new_udf_array) LOOP
			-- todo check u has key/type/value properties
			-- find the array index for the matching key and type
			idx := (
				SELECT pos - 1 FROM user_defined_field, jsonb_array_elements(udf) 
					WITH ORDINALITY arr(elem, pos) 
					WHERE user_id = userid AND is_valid(valid_to)
					AND elem->>'key' = u->>'key'
					AND elem->>'type' = u->>'type'
			);
			-- if it's a new udf, add it to the beginning of the udf array
			IF idx IS NULL THEN
				UPDATE user_defined_field SET udf = jsonb_insert(udf, array[0::text], u)
				WHERE user_id = userid AND is_valid(valid_to);
			ELSE 
		   -- otherwise, update it at the determined position of the array
				UPDATE user_defined_field SET udf = jsonb_set(udf, array[idx::text], u)
				WHERE user_id = userid AND is_valid(valid_to);
			END IF;
	  END LOOP;
	END IF;
  
	RETURN query SELECT udf FROM user_defined_field WHERE user_id = userid AND is_valid(valid_to);
END;
$$;


ALTER FUNCTION bctw.upsert_udf(username text, new_udf jsonb) OWNER TO bctw;

--
-- Name: FUNCTION upsert_udf(username text, new_udf jsonb); Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON FUNCTION bctw.upsert_udf(username text, new_udf jsonb) IS 'store user defined fields (currently custom animal groups and collective units).';


--
-- Name: upsert_user(text, json, text); Type: FUNCTION; Schema: bctw; Owner: bctw
--

CREATE FUNCTION bctw.upsert_user(stridir text, userjson json, roletype text) RETURNS SETOF json
    LANGUAGE plpgsql
    AS $$
DECLARE
  userid integer := bctw.get_user_id (stridir);
  userrole bctw.role_type := bctw.get_user_role(stridir);
  current_ts timestamp without time ZONE := now();
  ur record;
  roleid uuid := (SELECT role_id FROM user_role_type WHERE role_type = roletype);
  newuserid integer;
BEGIN
  IF userid IS NULL THEN
    RAISE EXCEPTION 'unable find user %', stridir;
  END IF;
 
  IF userjson->>'username' IS NULL THEN
  	RAISE EXCEPTION 'must provide username';
  END IF;
 
  IF userjson->>'domain' IS NULL THEN 
  	RAISE EXCEPTION 'must provide a valid domain (BCEID or IDIR)';
  END IF;
 
  -- new users must have a unique username
  IF EXISTS (SELECT 1 FROM bctw.USER WHERE username = userjson->>'username' AND userjson->>'id' IS NULL) THEN 
  	RAISE EXCEPTION 'this username already exists';
  END IF;
 
  -- must be an admin, unless the user is changing only themself
  IF userrole IS NULL OR userrole != 'administrator' THEN
  	IF userid::text != userjson->>'id' THEN 
		RAISE EXCEPTION 'you must be an administrator to update users';
	END IF;
  END IF;
 
  ur := json_populate_record(NULL::bctw.user, userjson);
 
  WITH ins AS (
	  INSERT INTO bctw.USER AS uu (id, username, "domain", phone, email, lastname, firstname, created_by_user_id)
	  VALUES (
	  	COALESCE(ur.id, nextval('user_id_seq1')),
	    ur.username,
	    ur."domain",
	    ur.phone,
	  	ur.email,
	  	ur.lastname,
	  	ur.firstname,
	  	userid
	  )
	  ON CONFLICT (id)
	  DO UPDATE SET 
	    idir = COALESCE(excluded.idir, uu.idir),
	    bceid = COALESCE(excluded.bceid, uu.bceid),
	    "domain" = COALESCE(excluded."domain", uu."domain"),
	    username = COALESCE(excluded.username, uu.username),
	    lastname = COALESCE(excluded.lastname, uu.lastname),
	    firstname = COALESCE(excluded.firstname, uu.firstname),
	    email = COALESCE(excluded.email, uu.email),
	    phone = COALESCE(excluded.phone, uu.phone),
	    updated_at = current_ts,
	    updated_by_user_id = userid
	  RETURNING id
  ) SELECT id FROM ins INTO newuserid;

 IF EXISTS (SELECT 1 FROM user_role_xref WHERE user_id = newuserid) THEN 
		UPDATE user_role_xref SET role_id = roleid WHERE user_id = newuserid;
 ELSE 
    INSERT INTO user_role_xref (user_id, role_id)
    VALUES (newuserid, roleid);
 END IF;

  RETURN query SELECT row_to_json(t) FROM (SELECT * FROM bctw.USER WHERE id = newuserid) t; 
END;
$$;


ALTER FUNCTION bctw.upsert_user(stridir text, userjson json, roletype text) OWNER TO bctw;

--
-- Name: upsert_vectronic_key(integer, text, text, text, integer); Type: FUNCTION; Schema: bctw; Owner: bctw
--

CREATE FUNCTION bctw.upsert_vectronic_key(id_collar integer, com_type text, id_com text, collar_key text, collar_type integer) RETURNS json
    LANGUAGE plpgsql
    AS $$
declare
begin
	
	if exists (select 1 from bctw.api_vectronics_collar_data where idcollar = id_collar)
		then raise exception 'upsert_vectronic_key - device registration failed, an entry for device ID % already exists', id_collar;
	end if;
	
    insert into bctw.api_vectronics_collar_data (idcollar, comtype, idcom, collarkey, collartype)
	values (id_collar, com_type, id_com, collar_key, collar_type);

	return (select row_to_json(t) from (select * from bctw.api_vectronics_collar_data where idcollar = id_collar) t);
END;
$$;


ALTER FUNCTION bctw.upsert_vectronic_key(id_collar integer, com_type text, id_com text, collar_key text, collar_type integer) OWNER TO bctw;

--
-- Name: FUNCTION upsert_vectronic_key(id_collar integer, com_type text, id_com text, collar_key text, collar_type integer); Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON FUNCTION bctw.upsert_vectronic_key(id_collar integer, com_type text, id_com text, collar_key text, collar_type integer) IS 'for the Vectronic data collector cronjob to work, a record needs to be added to the api_vectronics_collar_data when a new Vectronic device is registered. This is exposed in the API through a bulk .keyx import. Before the device is created in the collar table, this api_vectronics_collar_data should be created.';


--
-- Name: vendor_insert_raw_vectronic(jsonb); Type: FUNCTION; Schema: bctw; Owner: bctw
--

CREATE FUNCTION bctw.vendor_insert_raw_vectronic(rec jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
	vect_row record;
  j jsonb; 
BEGIN
	FOR j IN SELECT jsonb_array_elements(rec) LOOP
		vect_row := jsonb_populate_record(NULL::vectronics_collar_data, jsonb_strip_nulls(j));
		INSERT INTO vectronics_collar_data SELECT vect_row.*
		ON CONFLICT (idposition) DO NOTHING;
	END LOOP;
RETURN jsonb_build_object('device_id', vect_row.idcollar, 'records_found', jsonb_array_length(rec));
END
$$;


ALTER FUNCTION bctw.vendor_insert_raw_vectronic(rec jsonb) OWNER TO bctw;

--
-- Name: FUNCTION vendor_insert_raw_vectronic(rec jsonb); Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON FUNCTION bctw.vendor_insert_raw_vectronic(rec jsonb) IS 'inserts json rows of vectronic_collar_data type. ignores  insert of duplicate idposition. 
returns a json object of the device_id and number of records insertd. 
todo: include actual records inserted';


--
-- Name: get_animal_history(text, uuid, timestamp without time zone, timestamp without time zone); Type: FUNCTION; Schema: bctw_dapi_v1; Owner: bctw
--

CREATE FUNCTION bctw_dapi_v1.get_animal_history(stridir text, animalid uuid, startdate timestamp without time zone DEFAULT '1971-01-01 00:00:00'::timestamp without time zone, enddate timestamp without time zone DEFAULT now()) RETURNS SETOF json
    LANGUAGE plpgsql
    AS $$
declare
userid integer;
perm user_permission;
begin
	userid = bctw.get_user_id(stridir);
	IF userid IS NULL
		THEN RAISE EXCEPTION 'unable to find user with idir %', stridir;
	END IF;

	perm := bctw.get_user_animal_permission(userid, animalid);

	-- user must be at least an observer to view animal history
	IF perm IS NULL OR perm = 'none'::user_permission THEN
		RAISE EXCEPTION 'you do not have permission to view this animal''s history';
	END IF;
	
	RETURN query
	SELECT row_to_json(t) FROM (
		SELECT * FROM bctw_dapi_v1.animal_historic_v av 
		WHERE critter_id = animalid
		AND tsrange(startdate, enddate) && tsrange(valid_from::timestamp, valid_to::timestamp)
		ORDER BY valid_to DESC NULLS FIRST
	) t;
END;
$$;


ALTER FUNCTION bctw_dapi_v1.get_animal_history(stridir text, animalid uuid, startdate timestamp without time zone, enddate timestamp without time zone) OWNER TO bctw;

--
-- Name: FUNCTION get_animal_history(stridir text, animalid uuid, startdate timestamp without time zone, enddate timestamp without time zone); Type: COMMENT; Schema: bctw_dapi_v1; Owner: bctw
--

COMMENT ON FUNCTION bctw_dapi_v1.get_animal_history(stridir text, animalid uuid, startdate timestamp without time zone, enddate timestamp without time zone) IS 'retrieves a list of metadata changes to an animal given the critter_id';


--
-- Name: get_code(text, text, integer); Type: FUNCTION; Schema: bctw_dapi_v1; Owner: bctw
--

CREATE FUNCTION bctw_dapi_v1.get_code(stridir text, codeheader text, page integer) RETURNS json
    LANGUAGE plpgsql
    AS $$
DECLARE
  select_limit integer := 15;
  offset_calc integer;
BEGIN
  -- Get list of valid codes and values for a code_header(type)
  -- This will also sort first on code_sort_order and then on code_description, so either it shows in the defined order or alphabetically
  IF codeheader IS NULL THEN
    RAISE exception 'code header % not found', codeheader;
  END IF;
  offset_calc := select_limit * page - select_limit;
  -- species has been moved to it's own table due to additional required columns that the current code table does not support
  -- todo: improve this, case statement doesnt work when cause you  want true & false
  IF codeheader = 'species' THEN
	  RETURN (SELECT json_agg(t)
	  FROM (
	    SELECT 
	      'Species' AS code_header_title,
	      s.species_code AS id,
	      s.species_code AS code,
	      s.species_eng_name AS description,
	      s.species_scientific_name AS long_description,
		  s.predator_species
	    FROM bctw.species s
	    WHERE is_valid(s.valid_to)
	    ORDER BY s.species_eng_name
	  ) t);
   END IF; 
   IF codeheader = 'predator_species' THEN
	  RETURN (SELECT json_agg(t)
	  FROM (
	    SELECT 
	      'Species' AS code_header_title,
	      s.species_code AS id,
	      s.species_code AS code,
	      s.species_eng_name AS description,
	      s.species_scientific_name AS long_description,
		  s.predator_species
	    FROM bctw.species s
	    WHERE is_valid(s.valid_to)
	    AND s.predator_species IS TRUE
	    ORDER BY s.species_eng_name
	  ) t);
  END IF;
    
  RETURN (
    SELECT
      json_agg(t)
    FROM (
      SELECT
        ch.code_header_title,
        c.code_id AS id,
        c.code_name AS code, -- column that will be stored in other tables
        c.code_description AS description, -- column that will be displayed in ui
        c.code_description_long as long_description
      FROM
        bctw_dapi_v1.code_v c
        INNER JOIN bctw_dapi_v1.code_header_v ch
        ON c.code_header_id = ch.code_header_id
      WHERE
        ch.code_header_name::text = codeheader::text
      ORDER BY
        c.code_sort_order,
        c.code_description
      limit 
      (case 
     	when page <> 0 then select_limit 
        else 200
      end)
      offset
      (case
        when page <> 0 then offset_calc
        else 0
      end)
     ) t);
END;
$$;


ALTER FUNCTION bctw_dapi_v1.get_code(stridir text, codeheader text, page integer) OWNER TO bctw;

--
-- Name: FUNCTION get_code(stridir text, codeheader text, page integer); Type: COMMENT; Schema: bctw_dapi_v1; Owner: bctw
--

COMMENT ON FUNCTION bctw_dapi_v1.get_code(stridir text, codeheader text, page integer) IS 'retrieves codes for a provided codeheader (code_header_name). Note the special handling for species. Used in the main code select compoennt in the UI';


--
-- Name: get_code_description(text, integer); Type: FUNCTION; Schema: bctw_dapi_v1; Owner: bctw
--

CREATE FUNCTION bctw_dapi_v1.get_code_description(codeheader text, codeid integer) RETURNS text
    LANGUAGE plpgsql
    AS $$
declare
 code_desc text;
begin
	code_desc := (
	SELECT
      c.code_description
      FROM
        bctw_dapi_v1.code_v c
        INNER JOIN bctw_dapi_v1.code_header_v ch
        ON c.code_header_id = ch.code_header_id
      WHERE
        ch.code_header_name::text = codeheader::text
        and c.code_id = codeid
	);
return code_desc;
END;
$$;


ALTER FUNCTION bctw_dapi_v1.get_code_description(codeheader text, codeid integer) OWNER TO bctw;

--
-- Name: FUNCTION get_code_description(codeheader text, codeid integer); Type: COMMENT; Schema: bctw_dapi_v1; Owner: bctw
--

COMMENT ON FUNCTION bctw_dapi_v1.get_code_description(codeheader text, codeid integer) IS 'used in the schema to translate code ids to descriptions for views.';


--
-- Name: get_code_description(text, text); Type: FUNCTION; Schema: bctw_dapi_v1; Owner: bctw
--

CREATE FUNCTION bctw_dapi_v1.get_code_description(codeheader text, codename text) RETURNS text
    LANGUAGE plpgsql
    AS $$
declare
 code_desc text;
begin
	code_desc := (
	SELECT
      c.code_description
      FROM
        bctw_dapi_v1.code_v c
        INNER JOIN bctw_dapi_v1.code_header_v ch
        ON c.code_header_id = ch.code_header_id
      WHERE
        ch.code_header_name::text = codeheader::text
        and c.code_name = codename
	);
return code_desc;
END;
$$;


ALTER FUNCTION bctw_dapi_v1.get_code_description(codeheader text, codename text) OWNER TO bctw;

--
-- Name: FUNCTION get_code_description(codeheader text, codename text); Type: COMMENT; Schema: bctw_dapi_v1; Owner: bctw
--

COMMENT ON FUNCTION bctw_dapi_v1.get_code_description(codeheader text, codename text) IS 'given a code_header_name and code_name, return the code_description';


--
-- Name: get_collar_history(text, uuid); Type: FUNCTION; Schema: bctw_dapi_v1; Owner: bctw
--

CREATE FUNCTION bctw_dapi_v1.get_collar_history(stridir text, collarid uuid) RETURNS SETOF json
    LANGUAGE plpgsql
    AS $$
DECLARE
userid integer := bctw.get_user_id(stridir);
BEGIN
	-- returns a history of metadata changes made to a collar (not collar assignment history)
	IF userid IS NULL
		THEN RAISE EXCEPTION 'unable to find user with idir %', stridir;
	END IF;
	-- todo: confirm user has access to this collar
	 
--	if not exists (select 1 from bctw.get_user_collar_access_t(stridir) ids where collarid = any(ids))
--		then raise exception 'user does not have access to any animals with this collar attached';
--	end if;

	RETURN query
	SELECT row_to_json(t) FROM (
		SELECT * FROM bctw_dapi_v1.collar_historic_v
		WHERE collar_id = collarid
		ORDER BY valid_to DESC NULLS FIRST
	) t;
END;
$$;


ALTER FUNCTION bctw_dapi_v1.get_collar_history(stridir text, collarid uuid) OWNER TO bctw;

--
-- Name: FUNCTION get_collar_history(stridir text, collarid uuid); Type: COMMENT; Schema: bctw_dapi_v1; Owner: bctw
--

COMMENT ON FUNCTION bctw_dapi_v1.get_collar_history(stridir text, collarid uuid) IS 'retrieves a history of metadata changes to a device given the collar_id';


--
-- Name: get_collar_vendor_credentials(text, text); Type: FUNCTION; Schema: bctw_dapi_v1; Owner: bctw
--

CREATE FUNCTION bctw_dapi_v1.get_collar_vendor_credentials(apiname text, privatekey text) RETURNS TABLE(url character varying, username text, password text)
    LANGUAGE plpgsql
    AS $$
declare
begin
	return query
		select 
			cv.api_url,
			crypto.pgp_pub_decrypt(cv.api_username, crypto.dearmor(privatekey)) as "username",
			crypto.pgp_pub_decrypt(cv.api_password, crypto.dearmor(privatekey)) as "password" 
		from bctw.collar_vendor_api_credentials cv
		where cv.api_name = apiname;
END;
$$;


ALTER FUNCTION bctw_dapi_v1.get_collar_vendor_credentials(apiname text, privatekey text) OWNER TO bctw;

--
-- Name: FUNCTION get_collar_vendor_credentials(apiname text, privatekey text); Type: COMMENT; Schema: bctw_dapi_v1; Owner: bctw
--

COMMENT ON FUNCTION bctw_dapi_v1.get_collar_vendor_credentials(apiname text, privatekey text) IS 'securely retrieve collar credentials provided with the API name and private key. Function parameters:
a) the API credential name - or apiname column in the collar_vendor_api_credentials table
b) the private key';


--
-- Name: get_movement_history(text, uuid, timestamp without time zone, timestamp without time zone); Type: FUNCTION; Schema: bctw_dapi_v1; Owner: bctw
--

CREATE FUNCTION bctw_dapi_v1.get_movement_history(stridir text, collarid uuid, tsstart timestamp without time zone DEFAULT '1971-01-01 00:00:00'::timestamp without time zone, tsend timestamp without time zone DEFAULT now()) RETURNS SETOF json
    LANGUAGE plpgsql
    AS $$
DECLARE
userid integer := bctw.get_user_id(stridir);
vendor_code_id integer := (SELECT device_make FROM bctw.collar WHERE collar_id = collarid);
vendor_str TEXT;
BEGIN
	IF userid IS NULL 		
    THEN RAISE EXCEPTION 'unable to find user with idir %', stridir;
	END IF;
    
	IF collarid IS NULL 
	  THEN RAISE EXCEPTION 'must supply collar_id to retrieve movement history';
	END IF;

  IF vendor_code_id IS NULL 
    THEN RAISE EXCEPTION 'unable to determine device make from collar_id %', collarid;
  END IF;
 
  vendor_str := bctw_dapi_v1.get_code_description('device_make', vendor_code_id);
 
  IF vendor_str = 'Lotek' THEN
	  RETURN query SELECT row_to_json(t) FROM (
	    SELECT c.device_id, vendor_str AS "device_make", lcd.* FROM lotek_collar_data lcd
	    JOIN collar c ON c.device_id = lcd.deviceid 
	    WHERE c.device_make = vendor_code_id
	    AND c.collar_id = collarid
	    AND lcd.recdatetime <@ tsrange(tsstart, tsend)
	  ) t;

	ELSIF vendor_str = 'ATS' THEN
	 RETURN query SELECT row_to_json(t) FROM (
	    SELECT c.device_id, vendor_str AS "device_make", acd.* FROM ats_collar_data acd
	    JOIN collar c ON c.device_id = acd.collarserialnumber
	    WHERE c.device_make = vendor_code_id
	    AND c.collar_id = collarid
	    AND acd."date" <@ tstzrange(tsstart::timestamptz, tsend::timestamptz)
	  ) t;

  ELSIF vendor_str = 'Vectronic' THEN 
   RETURN query SELECT row_to_json(t) FROM (
	    SELECT c.device_id, vendor_str AS "device_make", vcd.* FROM vectronics_collar_data vcd 
	    JOIN collar c ON c.device_id = vcd.idcollar
	    WHERE c.device_make = vendor_code_id
	    AND c.collar_id = collarid
	    AND vcd.scts <@ tsrange(tsstart, tsend)
	  ) t;
	 
	ELSE 
    RAISE EXCEPTION 'wat do';
  END IF;

END;
$$;


ALTER FUNCTION bctw_dapi_v1.get_movement_history(stridir text, collarid uuid, tsstart timestamp without time zone, tsend timestamp without time zone) OWNER TO bctw;

--
-- Name: FUNCTION get_movement_history(stridir text, collarid uuid, tsstart timestamp without time zone, tsend timestamp without time zone); Type: COMMENT; Schema: bctw_dapi_v1; Owner: bctw
--

COMMENT ON FUNCTION bctw_dapi_v1.get_movement_history(stridir text, collarid uuid, tsstart timestamp without time zone, tsend timestamp without time zone) IS 'for a given collar_id retrieves movement history from the raw vendor tables. results currently different for each vendor. used in map export
todo: historical telemetry?';


--
-- Name: get_user(text); Type: FUNCTION; Schema: bctw_dapi_v1; Owner: bctw
--

CREATE FUNCTION bctw_dapi_v1.get_user(stridir text) RETURNS SETOF json
    LANGUAGE plpgsql
    AS $$
DECLARE
	userid integer := bctw.get_user_id(stridir);
BEGIN
	
	IF userid IS NULL 
		THEN RAISE EXCEPTION 'couldnt find user with IDIR %', strIdir;
	END IF;
	
	RETURN query SELECT row_to_json(t) FROM (
		SELECT * FROM bctw_dapi_v1.user_v
		WHERE id = userid 
	) t;
END;
$$;


ALTER FUNCTION bctw_dapi_v1.get_user(stridir text) OWNER TO bctw;

--
-- Name: FUNCTION get_user(stridir text); Type: COMMENT; Schema: bctw_dapi_v1; Owner: bctw
--

COMMENT ON FUNCTION bctw_dapi_v1.get_user(stridir text) IS 'retrieves user and role data for a provided user identifier.';


--
-- Name: get_user_critter_access(text, bctw.user_permission[]); Type: FUNCTION; Schema: bctw_dapi_v1; Owner: bctw
--

CREATE FUNCTION bctw_dapi_v1.get_user_critter_access(stridir text, permission_filter bctw.user_permission[] DEFAULT '{admin,observer,manager,editor}'::bctw.user_permission[]) RETURNS TABLE(critter_id uuid, animal_id character varying, wlh_id character varying, species character varying, permission_type bctw.user_permission, device_id integer, device_make character varying, device_type character varying, frequency double precision)
    LANGUAGE plpgsql
    AS $$
DECLARE
	userid integer := bctw.get_user_id(stridir);
BEGIN
	IF userid IS NULL
		THEN RAISE EXCEPTION 'unable to find user with idir %', stridir;
	END IF;

	RETURN query SELECT * FROM (
	
		WITH 
		is_owner AS (
		  SELECT a3.critter_id, a3.animal_id, a3.wlh_id, bctw.get_species_name(a3.species) AS species, 'manager'::bctw.user_permission AS "permission_type"
			FROM animal a3
			WHERE is_valid(a3.valid_to)
			AND a3.owned_by_user_id = userid
		),
		
		has_permission AS (
		  SELECT a.critter_id, a.animal_id, a.wlh_id, bctw.get_species_name(a.species) AS species, ua.permission_type
		  FROM bctw.animal a
		    INNER JOIN bctw.user_animal_assignment ua 
		    ON a.critter_id = ua.critter_id
		  WHERE
		    ua.user_id = userid
		    AND is_valid(a.valid_to)
		    AND a.critter_id NOT IN (SELECT io.critter_id FROM is_owner io)
		),
		
		no_permission AS (
		  SELECT a2.critter_id, a2.animal_id, a2.wlh_id, bctw.get_species_name(a2.species) AS species, 'none'::bctw.user_permission AS "permission_type"
		  FROM animal a2 
		  WHERE a2.critter_id NOT IN (SELECT hp.critter_id FROM has_permission hp)
		  AND a2.critter_id NOT IN (SELECT io2.critter_id FROM is_owner io2)		    
		  AND is_valid(a2.valid_to)
		),
		
		all_permissions AS (
		  SELECT * FROM has_permission
		  UNION ALL SELECT * FROM no_permission
		  UNION ALL SELECT * FROM is_owner
		)

		SELECT
		  ap.*,
		  c.device_id,
		  c.device_make,
		  c.device_type,
		  c.frequency
		FROM
		  all_permissions ap
		  -- fixme: joining on non-currently attached collars
		  LEFT JOIN bctw_dapi_v1.currently_attached_collars_v caa
		  	ON caa.critter_id = ap.critter_id
		  LEFT JOIN bctw_dapi_v1.collar_v c 
		  	ON caa.collar_id = c.collar_id
	  WHERE ap.permission_type = ANY(permission_filter)
	 ) t;
END;
$$;


ALTER FUNCTION bctw_dapi_v1.get_user_critter_access(stridir text, permission_filter bctw.user_permission[]) OWNER TO bctw;

--
-- Name: FUNCTION get_user_critter_access(stridir text, permission_filter bctw.user_permission[]); Type: COMMENT; Schema: bctw_dapi_v1; Owner: bctw
--

COMMENT ON FUNCTION bctw_dapi_v1.get_user_critter_access(stridir text, permission_filter bctw.user_permission[]) IS 'returns a list of critters a user has access to. Includes some device properties if the critter is attached to a collar. the filter parameter permission_filter defaults to all permissions except "none". so to include "none" you would pass "{none,view, change, owner, subowner}"';


--
-- Name: get_user_id(text); Type: FUNCTION; Schema: bctw_dapi_v1; Owner: bctw
--

CREATE FUNCTION bctw_dapi_v1.get_user_id(stridir text) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
  uid integer;
BEGIN
  uid := (
    SELECT
      u.id
    FROM
      bctw_dapi_v1.user_v u
    WHERE
      u.idir = stridir
      OR u.bceid = stridir);
  RETURN uid;
END;
$$;


ALTER FUNCTION bctw_dapi_v1.get_user_id(stridir text) OWNER TO bctw;

--
-- Name: FUNCTION get_user_id(stridir text); Type: COMMENT; Schema: bctw_dapi_v1; Owner: bctw
--

COMMENT ON FUNCTION bctw_dapi_v1.get_user_id(stridir text) IS 'provided with an IDIR or BCEID, retrieve the user_id. Returns NULL if neither can be found.';


--
-- Name: get_user_telemetry_alerts(text); Type: FUNCTION; Schema: bctw_dapi_v1; Owner: bctw
--

CREATE FUNCTION bctw_dapi_v1.get_user_telemetry_alerts(stridir text) RETURNS SETOF json
    LANGUAGE plpgsql
    AS $$
DECLARE
  critter_access uuid[] := (
 		SELECT ARRAY(SELECT critter_id FROM bctw_dapi_v1.get_user_critter_access(stridir, '{admin,manager,editor}'::user_permission[]))
 	);
BEGIN
  RETURN query
  SELECT json_agg(t) FROM (
		SELECT * FROM bctw_dapi_v1.alert_v
		WHERE critter_id = ANY(critter_access)
		ORDER BY valid_from DESC
  ) t;
END;
$$;


ALTER FUNCTION bctw_dapi_v1.get_user_telemetry_alerts(stridir text) OWNER TO bctw;

--
-- Name: FUNCTION get_user_telemetry_alerts(stridir text); Type: COMMENT; Schema: bctw_dapi_v1; Owner: bctw
--

COMMENT ON FUNCTION bctw_dapi_v1.get_user_telemetry_alerts(stridir text) IS 'retrives telemetry alerts for a provided user identifier. The user must have admin, manager, or editor permission to the animal';


--
-- Name: get_users(text); Type: FUNCTION; Schema: bctw_dapi_v1; Owner: bctw
--

CREATE FUNCTION bctw_dapi_v1.get_users(stridir text) RETURNS json
    LANGUAGE plpgsql
    AS $$
declare
userid integer := bctw.get_user_id(stridir);
isAdmin boolean;
begin
	if userid is null
		then raise exception 'unable find user with idir %', stridir;
	end if;

	isAdmin := (select (select (select * from bctw.get_user_role(stridir)) = 'administrator')::boolean);
  IF isAdmin THEN 
		RETURN (SELECT json_agg(t) FROM (SELECT * FROM bctw_dapi_v1.user_v)	t);
  ELSE
  	RAISE EXCEPTION 'you must be an administrator or owner to perform this action';
  END IF; 
 
END;
$$;


ALTER FUNCTION bctw_dapi_v1.get_users(stridir text) OWNER TO bctw;

--
-- Name: FUNCTION get_users(stridir text); Type: COMMENT; Schema: bctw_dapi_v1; Owner: bctw
--

COMMENT ON FUNCTION bctw_dapi_v1.get_users(stridir text) IS 'returns a list of user data, must have the admin type role';


--
-- Name: code; Type: TABLE; Schema: bctw; Owner: bctw
--

CREATE TABLE bctw.code (
    code_id integer NOT NULL,
    code_header_id integer NOT NULL,
    code_name character varying(30) NOT NULL,
    code_description character varying(300) NOT NULL,
    code_sort_order smallint,
    valid_from timestamp without time zone DEFAULT now() NOT NULL,
    valid_to timestamp without time zone,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now(),
    created_by_user_id integer,
    updated_by_user_id integer,
    code_description_long character varying(300),
    custom_1 jsonb
);


ALTER TABLE bctw.code OWNER TO bctw;

--
-- Name: TABLE code; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON TABLE bctw.code IS 'This is the generic code table containing all codes.';


--
-- Name: COLUMN code.valid_from; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.code.valid_from IS 'Validity of this code from date.';


--
-- Name: COLUMN code.valid_to; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.code.valid_to IS 'Validity of this code until this date';


--
-- Name: COLUMN code.custom_1; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.code.custom_1 IS 'user defined json column';


--
-- Name: animal_v; Type: VIEW; Schema: bctw; Owner: bctw
--

CREATE VIEW bctw.animal_v AS
 SELECT a.critter_id,
    a.critter_transaction_id,
    a.animal_id,
    ( SELECT code.code_description
           FROM bctw.code
          WHERE (code.code_id = a.animal_status)) AS animal_status,
    a.associated_animal_id,
    ( SELECT code.code_description
           FROM bctw.code
          WHERE (code.code_id = a.associated_animal_relationship)) AS associated_animal_relationship,
    a.capture_comment,
    a.capture_date,
    a.capture_latitude,
    a.capture_longitude,
    a.capture_utm_easting,
    a.capture_utm_northing,
    a.capture_utm_zone,
    a.collective_unit,
    a.animal_colouration,
    a.ear_tag_left_id,
    a.ear_tag_right_id,
    a.ear_tag_left_colour,
    a.ear_tag_right_colour,
    a.estimated_age,
    ( SELECT code.code_description
           FROM bctw.code
          WHERE (code.code_id = a.juvenile_at_heel)) AS juvenile_at_heel,
    a.juvenile_at_heel_count,
    ( SELECT code.code_description
           FROM bctw.code
          WHERE (code.code_id = a.life_stage)) AS life_stage,
    ( SELECT code.code_name
           FROM bctw.code
          WHERE (code.code_id = a.map_colour)) AS map_colour,
    a.mortality_comment,
    a.mortality_date,
    a.mortality_latitude,
    a.mortality_longitude,
    a.mortality_utm_easting,
    a.mortality_utm_northing,
    a.mortality_utm_zone,
    ( SELECT code.code_description
           FROM bctw.code
          WHERE (code.code_id = a.proximate_cause_of_death)) AS proximate_cause_of_death,
    ( SELECT code.code_description
           FROM bctw.code
          WHERE (code.code_id = a.ultimate_cause_of_death)) AS ultimate_cause_of_death,
    ( SELECT code.code_description
           FROM bctw.code
          WHERE (code.code_id = a.population_unit)) AS population_unit,
    a.recapture,
    ( SELECT code.code_description
           FROM bctw.code
          WHERE (code.code_id = a.region)) AS region,
    a.release_comment,
    a.release_date,
    a.release_latitude,
    a.release_longitude,
    a.release_utm_easting,
    a.release_utm_northing,
    a.release_utm_zone,
    ( SELECT code.code_description
           FROM bctw.code
          WHERE (code.code_id = a.sex)) AS sex,
    bctw.get_species_name(a.species) AS species,
    a.translocation,
    a.wlh_id,
    a.animal_comment,
    bctw.get_species_name(a.pcod_predator_species) AS pcod_predator_species,
    bctw.get_species_name(a.ucod_predator_species) AS ucod_predator_species,
    a.predator_known,
    a.captivity_status,
    a.mortality_captivity_status,
    ( SELECT code.code_description
           FROM bctw.code
          WHERE (code.code_id = a.pcod_confidence)) AS pcod_confidence,
    ( SELECT code.code_description
           FROM bctw.code
          WHERE (code.code_id = a.ucod_confidence)) AS ucod_confidence,
    a.mortality_report,
    ( SELECT code.code_description
           FROM bctw.code
          WHERE (code.code_id = a.mortality_investigation)) AS mortality_investigation,
    a.valid_from,
    a.valid_to,
    a.created_at,
    a.created_by_user_id,
    a.owned_by_user_id
   FROM bctw.animal a;


ALTER TABLE bctw.animal_v OWNER TO bctw;

--
-- Name: api_vectronics_collar_data; Type: TABLE; Schema: bctw; Owner: bctw
--

CREATE TABLE bctw.api_vectronics_collar_data (
    idcollar integer,
    comtype text,
    idcom text,
    collarkey character varying(1000),
    collartype integer
);


ALTER TABLE bctw.api_vectronics_collar_data OWNER TO bctw;

--
-- Name: TABLE api_vectronics_collar_data; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON TABLE bctw.api_vectronics_collar_data IS 'a table containing Vectronic collar IDs and keys. Used in the Vectronic cronjob to fetch collar data from the api.';


--
-- Name: ats_collar_data; Type: TABLE; Schema: bctw; Owner: bctw
--

CREATE TABLE bctw.ats_collar_data (
    collarserialnumber integer,
    date timestamp with time zone,
    numberfixes integer,
    battvoltage double precision,
    mortality boolean,
    breakoff boolean,
    gpsontime integer,
    satontime integer,
    saterrors integer,
    gmtoffset integer,
    lowbatt boolean,
    event character varying(100),
    latitude double precision,
    longitude double precision,
    cepradius_km integer,
    geom public.geometry(Point,4326),
    temperature character varying,
    hdop character varying,
    numsats character varying,
    fixtime character varying,
    activity character varying,
    timeid text NOT NULL
);


ALTER TABLE bctw.ats_collar_data OWNER TO bctw;

--
-- Name: TABLE ats_collar_data; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON TABLE bctw.ats_collar_data IS 'raw telemetry data from the ATS API';


--
-- Name: code_category; Type: TABLE; Schema: bctw; Owner: bctw
--

CREATE TABLE bctw.code_category (
    code_category_id integer NOT NULL,
    code_category_name character varying(100) NOT NULL,
    code_category_title character varying(40) NOT NULL,
    code_category_description character varying(4096),
    valid_from timestamp without time zone DEFAULT now() NOT NULL,
    valid_to timestamp without time zone,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now(),
    created_by_user_id integer,
    updated_by_user_id integer
);


ALTER TABLE bctw.code_category OWNER TO bctw;

--
-- Name: TABLE code_category; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON TABLE bctw.code_category IS 'A code category is the high level container for code headers and codes';


--
-- Name: code_category_code_category_id_seq; Type: SEQUENCE; Schema: bctw; Owner: bctw
--

CREATE SEQUENCE bctw.code_category_code_category_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE bctw.code_category_code_category_id_seq OWNER TO bctw;

--
-- Name: code_category_code_category_id_seq; Type: SEQUENCE OWNED BY; Schema: bctw; Owner: bctw
--

ALTER SEQUENCE bctw.code_category_code_category_id_seq OWNED BY bctw.code_category.code_category_id;


--
-- Name: code_code_id_seq; Type: SEQUENCE; Schema: bctw; Owner: bctw
--

CREATE SEQUENCE bctw.code_code_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE bctw.code_code_id_seq OWNER TO bctw;

--
-- Name: code_code_id_seq; Type: SEQUENCE OWNED BY; Schema: bctw; Owner: bctw
--

ALTER SEQUENCE bctw.code_code_id_seq OWNED BY bctw.code.code_id;


--
-- Name: code_header; Type: TABLE; Schema: bctw; Owner: bctw
--

CREATE TABLE bctw.code_header (
    code_header_id integer NOT NULL,
    code_category_id integer,
    code_header_name character varying(100) NOT NULL,
    code_header_title character varying(40) NOT NULL,
    code_header_description character varying(4096),
    valid_from timestamp without time zone DEFAULT now() NOT NULL,
    valid_to timestamp without time zone,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now(),
    created_by_user_id integer,
    updated_by_user_id integer
);


ALTER TABLE bctw.code_header OWNER TO bctw;

--
-- Name: TABLE code_header; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON TABLE bctw.code_header IS 'Represents a code type. All codes belogn to to a code header. Ex code Kootenay belongs to the code header Region';


--
-- Name: COLUMN code_header.code_header_name; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.code_header.code_header_name IS 'Technical name for the code table used in the interface to reference this code table.';


--
-- Name: COLUMN code_header.code_header_title; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.code_header.code_header_title IS 'Screen title when dropdown is presented.';


--
-- Name: code_header_code_header_id_seq; Type: SEQUENCE; Schema: bctw; Owner: bctw
--

CREATE SEQUENCE bctw.code_header_code_header_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE bctw.code_header_code_header_id_seq OWNER TO bctw;

--
-- Name: code_header_code_header_id_seq; Type: SEQUENCE OWNED BY; Schema: bctw; Owner: bctw
--

ALTER SEQUENCE bctw.code_header_code_header_id_seq OWNED BY bctw.code_header.code_header_id;


--
-- Name: collar_animal_assignment; Type: TABLE; Schema: bctw; Owner: bctw
--

CREATE TABLE bctw.collar_animal_assignment (
    assignment_id uuid DEFAULT crypto.gen_random_uuid() NOT NULL,
    collar_id uuid NOT NULL,
    critter_id uuid NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    created_by_user_id integer,
    updated_at timestamp without time zone DEFAULT now(),
    updated_by_user_id integer,
    valid_from timestamp with time zone DEFAULT now() NOT NULL,
    valid_to timestamp with time zone,
    attachment_start timestamp with time zone NOT NULL,
    attachment_end timestamp with time zone
);


ALTER TABLE bctw.collar_animal_assignment OWNER TO bctw;

--
-- Name: TABLE collar_animal_assignment; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON TABLE bctw.collar_animal_assignment IS 'A table that tracks devices assigned to a critters.';


--
-- Name: COLUMN collar_animal_assignment.updated_by_user_id; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.collar_animal_assignment.updated_by_user_id IS 'ID of the user that modified the attachment data life';


--
-- Name: COLUMN collar_animal_assignment.valid_from; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.collar_animal_assignment.valid_from IS 'the start of the data life range for which telemetry is considered valid for this animal/device attachment';


--
-- Name: COLUMN collar_animal_assignment.valid_to; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.collar_animal_assignment.valid_to IS 'the end of the data life range for which telemetry is considered valid for this animal/device attachment';


--
-- Name: COLUMN collar_animal_assignment.attachment_start; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.collar_animal_assignment.attachment_start IS 'when the collar was initially attached. the range between the attachment_start and the data_life_start (valid_from)  is considered "invalid"';


--
-- Name: COLUMN collar_animal_assignment.attachment_end; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.collar_animal_assignment.attachment_end IS 'when the collar was actually removed. the range between the data_life_end (valid_to) and attachnent_end is considerd "invalid"';


--
-- Name: collar_file; Type: TABLE; Schema: bctw; Owner: bctw
--

CREATE TABLE bctw.collar_file (
    file_id integer NOT NULL,
    collar_id uuid NOT NULL,
    device_id integer NOT NULL,
    file_name text NOT NULL,
    file_contents bytea,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    created_by_user_id integer,
    updated_at timestamp without time zone DEFAULT now(),
    updated_by_user_id integer,
    valid_from timestamp without time zone DEFAULT now() NOT NULL,
    valid_to timestamp without time zone
);


ALTER TABLE bctw.collar_file OWNER TO bctw;

--
-- Name: TABLE collar_file; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON TABLE bctw.collar_file IS 'incomplete - table for storing files associated with a collar.
todo: how to line break files';


--
-- Name: collar_file_file_id_seq; Type: SEQUENCE; Schema: bctw; Owner: bctw
--

CREATE SEQUENCE bctw.collar_file_file_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE bctw.collar_file_file_id_seq OWNER TO bctw;

--
-- Name: collar_file_file_id_seq; Type: SEQUENCE OWNED BY; Schema: bctw; Owner: bctw
--

ALTER SEQUENCE bctw.collar_file_file_id_seq OWNED BY bctw.collar_file.file_id;


--
-- Name: collar_v; Type: VIEW; Schema: bctw; Owner: bctw
--

CREATE VIEW bctw.collar_v AS
 SELECT c.collar_id,
    c.collar_transaction_id,
    c.camera_device_id,
    c.device_id,
    ( SELECT code.code_description
           FROM bctw.code
          WHERE (code.code_id = c.device_deployment_status)) AS device_deployment_status,
    ( SELECT code.code_description
           FROM bctw.code
          WHERE (code.code_id = c.device_make)) AS device_make,
    ( SELECT code.code_description
           FROM bctw.code
          WHERE (code.code_id = c.device_malfunction_type)) AS device_malfunction_type,
    c.device_model,
    ( SELECT code.code_description
           FROM bctw.code
          WHERE (code.code_id = c.device_status)) AS device_status,
    ( SELECT code.code_description
           FROM bctw.code
          WHERE (code.code_id = c.device_type)) AS device_type,
    c.dropoff_device_id,
    c.dropoff_frequency,
    ( SELECT code.code_description
           FROM bctw.code
          WHERE (code.code_id = c.dropoff_mechanism)) AS dropoff_mechanism,
    ( SELECT code.code_description
           FROM bctw.code
          WHERE (code.code_id = c.dropoff_frequency_unit)) AS dropoff_frequency_unit,
    c.fix_interval,
    ( SELECT code.code_description
           FROM bctw.code
          WHERE (code.code_id = c.fix_interval_rate)) AS fix_interval_rate,
    c.frequency,
    c.implant_device_id,
    ( SELECT code.code_description
           FROM bctw.code
          WHERE (code.code_id = c.frequency_unit)) AS frequency_unit,
    c.mortality_mode,
    c.mortality_period_hr,
    c.malfunction_date,
    c.malfunction_comment,
    c.activation_status,
    c.activation_comment,
    c.first_activation_month,
    c.first_activation_year,
    c.retrieval_date,
    c.retrieved,
    c.retrieval_comment,
    ( SELECT code.code_description
           FROM bctw.code
          WHERE (code.code_id = c.satellite_network)) AS satellite_network,
    c.device_comment,
    c.offline_date,
    ( SELECT code.code_description
           FROM bctw.code
          WHERE (code.code_id = c.offline_type)) AS offline_type,
    c.offline_comment,
    ( SELECT code.code_description
           FROM bctw.code
          WHERE (code.code_id = c.device_condition)) AS device_condition,
    c.created_at,
    c.created_by_user_id,
    c.valid_from,
    c.valid_to,
    c.owned_by_user_id
   FROM bctw.collar c;


ALTER TABLE bctw.collar_v OWNER TO bctw;

--
-- Name: historical_telemetry; Type: TABLE; Schema: bctw; Owner: bctw
--

CREATE TABLE bctw.historical_telemetry (
    time_id text NOT NULL,
    device_id integer NOT NULL,
    device_vendor character varying(20) NOT NULL,
    date_recorded timestamp without time zone NOT NULL,
    geom public.geometry,
    created_at timestamp without time zone DEFAULT now(),
    created_by_user_id integer,
    valid_from timestamp without time zone DEFAULT now(),
    valid_to timestamp without time zone
);


ALTER TABLE bctw.historical_telemetry OWNER TO bctw;

--
-- Name: TABLE historical_telemetry; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON TABLE bctw.historical_telemetry IS 'imported telemetry that does not belong to a vendor.';


--
-- Name: lotek_collar_data; Type: TABLE; Schema: bctw; Owner: bctw
--

CREATE TABLE bctw.lotek_collar_data (
    channelstatus text,
    uploadtimestamp timestamp without time zone,
    latitude double precision,
    longitude double precision,
    altitude double precision,
    ecefx double precision,
    ecefy double precision,
    ecefz double precision,
    rxstatus integer,
    pdop double precision,
    mainv double precision,
    bkupv double precision,
    temperature double precision,
    fixduration integer,
    bhastempvoltage boolean,
    devname text,
    deltatime double precision,
    fixtype text,
    cepradius double precision,
    crc double precision,
    deviceid integer,
    recdatetime timestamp without time zone,
    timeid text NOT NULL,
    geom public.geometry(Point,4326)
);


ALTER TABLE bctw.lotek_collar_data OWNER TO bctw;

--
-- Name: TABLE lotek_collar_data; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON TABLE bctw.lotek_collar_data IS 'raw telemetry data from Lotek';


--
-- Name: vectronics_collar_data; Type: TABLE; Schema: bctw; Owner: bctw
--

CREATE TABLE bctw.vectronics_collar_data (
    idposition integer NOT NULL,
    idcollar integer NOT NULL,
    acquisitiontime timestamp without time zone,
    scts timestamp without time zone,
    origincode text,
    ecefx double precision,
    ecefy double precision,
    ecefz double precision,
    latitude double precision,
    longitude double precision,
    height double precision,
    dop double precision,
    idfixtype integer,
    positionerror double precision,
    satcount integer,
    ch01satid integer,
    ch01satcnr integer,
    ch02satid integer,
    ch02satcnr integer,
    ch03satid integer,
    ch03satcnr integer,
    ch04satid integer,
    ch04satcnr integer,
    ch05satid integer,
    ch05satcnr integer,
    ch06satid integer,
    ch06satcnr integer,
    ch07satid integer,
    ch07satcnr integer,
    ch08satid integer,
    ch08satcnr integer,
    ch09satid integer,
    ch09satcnr integer,
    ch10satid integer,
    ch10satcnr integer,
    ch11satid integer,
    ch11satcnr integer,
    ch12satid integer,
    ch12satcnr integer,
    idmortalitystatus integer,
    activity integer,
    mainvoltage double precision,
    backupvoltage double precision,
    temperature double precision,
    transformedx double precision,
    transformedy double precision,
    geom public.geometry(Point,4326)
);


ALTER TABLE bctw.vectronics_collar_data OWNER TO bctw;

--
-- Name: TABLE vectronics_collar_data; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON TABLE bctw.vectronics_collar_data IS 'raw telemetry data from Vectronics';


--
-- Name: vendor_merge_view_no_critter; Type: MATERIALIZED VIEW; Schema: bctw; Owner: bctw
--

CREATE MATERIALIZED VIEW bctw.vendor_merge_view_no_critter AS
 WITH pings AS (
         SELECT lotek_collar_data.geom,
            lotek_collar_data.recdatetime AS date_recorded,
            lotek_collar_data.deviceid AS device_id,
            'Lotek'::text AS device_vendor
           FROM bctw.lotek_collar_data
          WHERE public.st_isvalid(lotek_collar_data.geom)
        UNION
         SELECT vectronics_collar_data.geom,
            vectronics_collar_data.acquisitiontime AS date_recorded,
            vectronics_collar_data.idcollar AS device_id,
            'Vectronic'::text AS device_vendor
           FROM bctw.vectronics_collar_data
          WHERE public.st_isvalid(vectronics_collar_data.geom)
        UNION
         SELECT ats_collar_data.geom,
            ats_collar_data.date AS date_recorded,
            ats_collar_data.collarserialnumber AS device_id,
            'ATS'::text AS device_vendor
           FROM bctw.ats_collar_data
          WHERE public.st_isvalid(ats_collar_data.geom)
        )
 SELECT p.device_id,
    p.date_recorded,
    p.device_vendor,
    p.geom,
    row_number() OVER (ORDER BY 1::integer) AS vendor_merge_id
   FROM pings p
  WITH NO DATA;


ALTER TABLE bctw.vendor_merge_view_no_critter OWNER TO bctw;

--
-- Name: MATERIALIZED VIEW vendor_merge_view_no_critter; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON MATERIALIZED VIEW bctw.vendor_merge_view_no_critter IS 'Materialized view containing data merged from multiple vendor tables. Additional information from the collar table information, but all animal data is excluded.';


--
-- Name: latest_transmissions; Type: MATERIALIZED VIEW; Schema: bctw; Owner: bctw
--

CREATE MATERIALIZED VIEW bctw.latest_transmissions AS
 SELECT q.collar_id,
    q.device_id,
    q.date_recorded,
    q.device_vendor,
    q.geom,
    q.vendor_merge_id
   FROM ( SELECT DISTINCT ON (vmv.device_id) c.collar_id,
            vmv.device_id,
            vmv.date_recorded,
            vmv.device_vendor,
            vmv.geom,
            vmv.vendor_merge_id
           FROM (bctw.vendor_merge_view_no_critter vmv
             LEFT JOIN bctw.collar c ON ((c.device_id = vmv.device_id)))
          ORDER BY vmv.device_id, vmv.date_recorded DESC) q
  ORDER BY q.date_recorded DESC
  WITH NO DATA;


ALTER TABLE bctw.latest_transmissions OWNER TO bctw;

--
-- Name: onboarding; Type: TABLE; Schema: bctw; Owner: bctw
--

CREATE TABLE bctw.onboarding (
    onboarding_id integer NOT NULL,
    domain bctw.domain_type NOT NULL,
    username character varying(50) NOT NULL,
    firstname character varying(50),
    lastname character varying(50),
    access bctw.onboarding_status NOT NULL,
    email character varying(100),
    phone character varying(20),
    reason character varying(200),
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone,
    valid_from timestamp with time zone DEFAULT now(),
    valid_to timestamp with time zone,
    role_type bctw.role_type NOT NULL
);


ALTER TABLE bctw.onboarding OWNER TO bctw;

--
-- Name: TABLE onboarding; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON TABLE bctw.onboarding IS 'used for onboarding new users to BCTW';


--
-- Name: onboarding_onboarding_id_seq; Type: SEQUENCE; Schema: bctw; Owner: bctw
--

CREATE SEQUENCE bctw.onboarding_onboarding_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE bctw.onboarding_onboarding_id_seq OWNER TO bctw;

--
-- Name: onboarding_onboarding_id_seq; Type: SEQUENCE OWNED BY; Schema: bctw; Owner: bctw
--

ALTER SEQUENCE bctw.onboarding_onboarding_id_seq OWNED BY bctw.onboarding.onboarding_id;


--
-- Name: permission_request; Type: TABLE; Schema: bctw; Owner: bctw
--

CREATE TABLE bctw.permission_request (
    request_id integer NOT NULL,
    user_id_list integer[],
    critter_permission_list jsonb,
    request_comment text,
    created_at timestamp without time zone DEFAULT now(),
    requested_by_user_id integer,
    valid_from timestamp without time zone DEFAULT now(),
    valid_to timestamp without time zone,
    was_denied_reason text,
    status bctw.onboarding_status DEFAULT 'pending'::bctw.onboarding_status
);


ALTER TABLE bctw.permission_request OWNER TO bctw;

--
-- Name: TABLE permission_request; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON TABLE bctw.permission_request IS 'tracks user access requests for permissions to animals';


--
-- Name: COLUMN permission_request.request_id; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.permission_request.request_id IS 'auto generated primary key of the permission table';


--
-- Name: COLUMN permission_request.user_id_list; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.permission_request.user_id_list IS 'integer array of user IDs';


--
-- Name: COLUMN permission_request.critter_permission_list; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.permission_request.critter_permission_list IS 'json array of user_permission objects';


--
-- Name: COLUMN permission_request.request_comment; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.permission_request.request_comment IS 'optional comment that the admin will see';


--
-- Name: COLUMN permission_request.requested_by_user_id; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.permission_request.requested_by_user_id IS 'user ID of the user who submitted the permission request. should be an owner';


--
-- Name: COLUMN permission_request.was_denied_reason; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.permission_request.was_denied_reason IS 'if the request was denied, the administrator can add a reason comment';


--
-- Name: permission_request_request_id_seq; Type: SEQUENCE; Schema: bctw; Owner: bctw
--

CREATE SEQUENCE bctw.permission_request_request_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE bctw.permission_request_request_id_seq OWNER TO bctw;

--
-- Name: permission_request_request_id_seq; Type: SEQUENCE OWNED BY; Schema: bctw; Owner: bctw
--

ALTER SEQUENCE bctw.permission_request_request_id_seq OWNED BY bctw.permission_request.request_id;


--
-- Name: species; Type: TABLE; Schema: bctw; Owner: bctw
--

CREATE TABLE bctw.species (
    species_code character varying(20) NOT NULL,
    species_eng_name character varying(60),
    species_scientific_name character varying(60),
    predator_species boolean DEFAULT false,
    valid_from timestamp without time zone,
    valid_to timestamp without time zone,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    created_by_user_id integer,
    updated_by_user_id integer
);


ALTER TABLE bctw.species OWNER TO bctw;

--
-- Name: telemetry_sensor_alert; Type: TABLE; Schema: bctw; Owner: bctw
--

CREATE TABLE bctw.telemetry_sensor_alert (
    alert_id integer NOT NULL,
    device_id integer NOT NULL,
    device_make text NOT NULL,
    alert_type bctw.telemetry_alert_type,
    valid_from timestamp without time zone DEFAULT now(),
    valid_to timestamp without time zone,
    created_at timestamp without time zone DEFAULT now(),
    snoozed_to timestamp(0) without time zone,
    snooze_count smallint DEFAULT 0,
    latitude double precision,
    longitude double precision,
    updated_at timestamp with time zone
);


ALTER TABLE bctw.telemetry_sensor_alert OWNER TO bctw;

--
-- Name: COLUMN telemetry_sensor_alert.alert_id; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.telemetry_sensor_alert.alert_id IS 'primary key of the alert table';


--
-- Name: COLUMN telemetry_sensor_alert.device_id; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.telemetry_sensor_alert.device_id IS 'ID of the device that triggered the alert';


--
-- Name: COLUMN telemetry_sensor_alert.device_make; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.telemetry_sensor_alert.device_make IS 'supported device makes are ATS, Vectronic, and Lotek';


--
-- Name: COLUMN telemetry_sensor_alert.alert_type; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.telemetry_sensor_alert.alert_type IS 'supported alert types are malfunction and mortality';


--
-- Name: COLUMN telemetry_sensor_alert.valid_from; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.telemetry_sensor_alert.valid_from IS 'todo: is this when the alert was triggered?';


--
-- Name: COLUMN telemetry_sensor_alert.valid_to; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.telemetry_sensor_alert.valid_to IS 'a non null valid_to column indicates the alert has been dealt with by a user';


--
-- Name: COLUMN telemetry_sensor_alert.created_at; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.telemetry_sensor_alert.created_at IS 'todo: is this when the alert was triggered?';


--
-- Name: COLUMN telemetry_sensor_alert.snoozed_to; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.telemetry_sensor_alert.snoozed_to IS 'until this timestamp has passed, a user is not forced to take action.';


--
-- Name: COLUMN telemetry_sensor_alert.snooze_count; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.telemetry_sensor_alert.snooze_count IS 'how many times this alert has been snoozed. a maximum of 3 is permitted';


--
-- Name: telemetry_sensor_alert_alert_id_seq; Type: SEQUENCE; Schema: bctw; Owner: bctw
--

CREATE SEQUENCE bctw.telemetry_sensor_alert_alert_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE bctw.telemetry_sensor_alert_alert_id_seq OWNER TO bctw;

--
-- Name: telemetry_sensor_alert_alert_id_seq; Type: SEQUENCE OWNED BY; Schema: bctw; Owner: bctw
--

ALTER SEQUENCE bctw.telemetry_sensor_alert_alert_id_seq OWNED BY bctw.telemetry_sensor_alert.alert_id;


--
-- Name: user; Type: TABLE; Schema: bctw; Owner: bctw
--

CREATE TABLE bctw."user" (
    id integer NOT NULL,
    idir character varying(50),
    bceid character varying(50),
    email character varying(100),
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    created_by_user_id integer,
    updated_at timestamp without time zone DEFAULT now(),
    updated_by_user_id integer,
    valid_from timestamp without time zone DEFAULT now() NOT NULL,
    valid_to timestamp without time zone,
    firstname character varying(50),
    lastname character varying(50),
    phone character varying(20),
    domain bctw.domain_type,
    username character varying(50)
);


ALTER TABLE bctw."user" OWNER TO bctw;

--
-- Name: TABLE "user"; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON TABLE bctw."user" IS 'BCTW user information table';


--
-- Name: COLUMN "user".phone; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw."user".phone IS 'to be used for alerting the user in the event of mortality alerts';


--
-- Name: COLUMN "user".domain; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw."user".domain IS 'idir or bceid';


--
-- Name: user_animal_assignment; Type: TABLE; Schema: bctw; Owner: bctw
--

CREATE TABLE bctw.user_animal_assignment (
    assignment_id uuid DEFAULT crypto.gen_random_uuid() NOT NULL,
    user_id integer NOT NULL,
    critter_id uuid NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    created_by_user_id integer,
    updated_at timestamp without time zone DEFAULT now(),
    updated_by_user_id integer,
    valid_from timestamp without time zone DEFAULT now() NOT NULL,
    valid_to timestamp without time zone,
    permission_type bctw.user_permission NOT NULL
);


ALTER TABLE bctw.user_animal_assignment OWNER TO bctw;

--
-- Name: TABLE user_animal_assignment; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON TABLE bctw.user_animal_assignment IS 'Tracks user permissions to animals.';


--
-- Name: user_defined_field; Type: TABLE; Schema: bctw; Owner: bctw
--

CREATE TABLE bctw.user_defined_field (
    udf_id integer NOT NULL,
    user_id integer NOT NULL,
    udf jsonb,
    valid_from timestamp without time zone DEFAULT now() NOT NULL,
    valid_to timestamp without time zone
);


ALTER TABLE bctw.user_defined_field OWNER TO bctw;

--
-- Name: user_defined_field_udf_id_seq; Type: SEQUENCE; Schema: bctw; Owner: bctw
--

CREATE SEQUENCE bctw.user_defined_field_udf_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE bctw.user_defined_field_udf_id_seq OWNER TO bctw;

--
-- Name: user_defined_field_udf_id_seq; Type: SEQUENCE OWNED BY; Schema: bctw; Owner: bctw
--

ALTER SEQUENCE bctw.user_defined_field_udf_id_seq OWNED BY bctw.user_defined_field.udf_id;


--
-- Name: user_defined_field_user_id_seq; Type: SEQUENCE; Schema: bctw; Owner: bctw
--

CREATE SEQUENCE bctw.user_defined_field_user_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE bctw.user_defined_field_user_id_seq OWNER TO bctw;

--
-- Name: user_defined_field_user_id_seq; Type: SEQUENCE OWNED BY; Schema: bctw; Owner: bctw
--

ALTER SEQUENCE bctw.user_defined_field_user_id_seq OWNED BY bctw.user_defined_field.user_id;


--
-- Name: user_id_seq1; Type: SEQUENCE; Schema: bctw; Owner: bctw
--

CREATE SEQUENCE bctw.user_id_seq1
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE bctw.user_id_seq1 OWNER TO bctw;

--
-- Name: user_id_seq1; Type: SEQUENCE OWNED BY; Schema: bctw; Owner: bctw
--

ALTER SEQUENCE bctw.user_id_seq1 OWNED BY bctw."user".id;


--
-- Name: user_role_type; Type: TABLE; Schema: bctw; Owner: bctw
--

CREATE TABLE bctw.user_role_type (
    role_id uuid DEFAULT crypto.gen_random_uuid() NOT NULL,
    role_type character varying(50),
    description character varying(200)
);


ALTER TABLE bctw.user_role_type OWNER TO bctw;

--
-- Name: TABLE user_role_type; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON TABLE bctw.user_role_type IS 'Role types that users can be assigned to. [Administrator, Owner, Observer]';


--
-- Name: user_role_xref; Type: TABLE; Schema: bctw; Owner: bctw
--

CREATE TABLE bctw.user_role_xref (
    user_id integer NOT NULL,
    role_id uuid NOT NULL
);


ALTER TABLE bctw.user_role_xref OWNER TO bctw;

--
-- Name: TABLE user_role_xref; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON TABLE bctw.user_role_xref IS 'Table that associates a user with a role type.';


--
-- Name: user_role_xref_user_id_seq; Type: SEQUENCE; Schema: bctw; Owner: bctw
--

CREATE SEQUENCE bctw.user_role_xref_user_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE bctw.user_role_xref_user_id_seq OWNER TO bctw;

--
-- Name: user_role_xref_user_id_seq; Type: SEQUENCE OWNED BY; Schema: bctw; Owner: bctw
--

ALTER SEQUENCE bctw.user_role_xref_user_id_seq OWNED BY bctw.user_role_xref.user_id;


--
-- Name: animal_v; Type: VIEW; Schema: bctw_dapi_v1; Owner: bctw
--

CREATE VIEW bctw_dapi_v1.animal_v AS
 SELECT av.critter_id,
    av.critter_transaction_id,
    av.animal_id,
    av.animal_status,
    av.associated_animal_id,
    av.associated_animal_relationship,
    av.capture_comment,
    av.capture_date,
    av.capture_latitude,
    av.capture_longitude,
    av.capture_utm_easting,
    av.capture_utm_northing,
    av.capture_utm_zone,
    av.collective_unit,
    av.animal_colouration,
    av.ear_tag_left_id,
    av.ear_tag_right_id,
    av.ear_tag_left_colour,
    av.ear_tag_right_colour,
    av.estimated_age,
    av.juvenile_at_heel,
    av.juvenile_at_heel_count,
    av.life_stage,
    av.map_colour,
    av.mortality_comment,
    av.mortality_date,
    av.mortality_latitude,
    av.mortality_longitude,
    av.mortality_utm_easting,
    av.mortality_utm_northing,
    av.mortality_utm_zone,
    av.proximate_cause_of_death,
    av.ultimate_cause_of_death,
    av.population_unit,
    av.recapture,
    av.region,
    av.release_comment,
    av.release_date,
    av.release_latitude,
    av.release_longitude,
    av.release_utm_easting,
    av.release_utm_northing,
    av.release_utm_zone,
    av.sex,
    av.species,
    av.translocation,
    av.wlh_id,
    av.animal_comment,
    av.pcod_predator_species,
    av.ucod_predator_species,
    av.predator_known,
    av.captivity_status,
    av.mortality_captivity_status,
    av.pcod_confidence,
    av.ucod_confidence,
    av.mortality_report,
    av.mortality_investigation,
    av.valid_from,
    av.valid_to,
    av.created_at,
    av.created_by_user_id,
    av.owned_by_user_id
   FROM bctw.animal_v av
  WHERE bctw.is_valid(av.valid_to);


ALTER TABLE bctw_dapi_v1.animal_v OWNER TO bctw;

--
-- Name: collar_v; Type: VIEW; Schema: bctw_dapi_v1; Owner: bctw
--

CREATE VIEW bctw_dapi_v1.collar_v AS
 SELECT collar_v.collar_id,
    collar_v.collar_transaction_id,
    collar_v.camera_device_id,
    collar_v.device_id,
    collar_v.device_deployment_status,
    collar_v.device_make,
    collar_v.device_malfunction_type,
    collar_v.device_model,
    collar_v.device_status,
    collar_v.device_type,
    collar_v.dropoff_device_id,
    collar_v.dropoff_frequency,
    collar_v.dropoff_mechanism,
    collar_v.dropoff_frequency_unit,
    collar_v.fix_interval,
    collar_v.fix_interval_rate,
    collar_v.frequency,
    collar_v.implant_device_id,
    collar_v.frequency_unit,
    collar_v.mortality_mode,
    collar_v.mortality_period_hr,
    collar_v.malfunction_date,
    collar_v.malfunction_comment,
    collar_v.activation_status,
    collar_v.activation_comment,
    collar_v.first_activation_month,
    collar_v.first_activation_year,
    collar_v.retrieval_date,
    collar_v.retrieved,
    collar_v.retrieval_comment,
    collar_v.satellite_network,
    collar_v.device_comment,
    collar_v.offline_date,
    collar_v.offline_type,
    collar_v.offline_comment,
    collar_v.device_condition,
    collar_v.created_at,
    collar_v.created_by_user_id,
    collar_v.valid_from,
    collar_v.valid_to,
    collar_v.owned_by_user_id
   FROM bctw.collar_v
  WHERE bctw.is_valid(collar_v.valid_to);


ALTER TABLE bctw_dapi_v1.collar_v OWNER TO bctw;

--
-- Name: alert_v; Type: VIEW; Schema: bctw_dapi_v1; Owner: bctw
--

CREATE VIEW bctw_dapi_v1.alert_v AS
 SELECT sa.alert_id,
    sa.alert_type,
    sa.snoozed_to,
    sa.snooze_count,
    sa.created_at,
    sa.valid_from,
    sa.valid_to,
    c.collar_id,
    c.device_id,
    c.device_make,
    c.device_status,
    a.critter_id,
    a.animal_id,
    a.wlh_id,
    a.species,
    a.captivity_status,
    a.animal_status,
    ca.assignment_id,
    ca.attachment_start,
    ca.valid_from AS data_life_start,
    ca.valid_to AS data_life_end,
    ca.attachment_end,
    ( SELECT latest_transmissions.date_recorded
           FROM bctw.latest_transmissions
          WHERE (latest_transmissions.collar_id = c.collar_id)) AS last_transmission_date
   FROM (((bctw.telemetry_sensor_alert sa
     JOIN bctw_dapi_v1.collar_v c ON (((sa.device_id = c.device_id) AND (sa.device_make = (c.device_make)::text))))
     JOIN bctw.collar_animal_assignment ca ON ((ca.collar_id = c.collar_id)))
     JOIN bctw_dapi_v1.animal_v a ON ((ca.critter_id = a.critter_id)))
  WHERE (bctw.is_valid(ca.valid_to) AND bctw.is_valid(sa.valid_to));


ALTER TABLE bctw_dapi_v1.alert_v OWNER TO bctw;

--
-- Name: animal_historic_v; Type: VIEW; Schema: bctw_dapi_v1; Owner: bctw
--

CREATE VIEW bctw_dapi_v1.animal_historic_v AS
 SELECT animal_v.critter_id,
    animal_v.critter_transaction_id,
    animal_v.animal_id,
    animal_v.animal_status,
    animal_v.associated_animal_id,
    animal_v.associated_animal_relationship,
    animal_v.capture_comment,
    animal_v.capture_date,
    animal_v.capture_latitude,
    animal_v.capture_longitude,
    animal_v.capture_utm_easting,
    animal_v.capture_utm_northing,
    animal_v.capture_utm_zone,
    animal_v.collective_unit,
    animal_v.animal_colouration,
    animal_v.ear_tag_left_id,
    animal_v.ear_tag_right_id,
    animal_v.ear_tag_left_colour,
    animal_v.ear_tag_right_colour,
    animal_v.estimated_age,
    animal_v.juvenile_at_heel,
    animal_v.juvenile_at_heel_count,
    animal_v.life_stage,
    animal_v.map_colour,
    animal_v.mortality_comment,
    animal_v.mortality_date,
    animal_v.mortality_latitude,
    animal_v.mortality_longitude,
    animal_v.mortality_utm_easting,
    animal_v.mortality_utm_northing,
    animal_v.mortality_utm_zone,
    animal_v.proximate_cause_of_death,
    animal_v.ultimate_cause_of_death,
    animal_v.population_unit,
    animal_v.recapture,
    animal_v.region,
    animal_v.release_comment,
    animal_v.release_date,
    animal_v.release_latitude,
    animal_v.release_longitude,
    animal_v.release_utm_easting,
    animal_v.release_utm_northing,
    animal_v.release_utm_zone,
    animal_v.sex,
    animal_v.species,
    animal_v.translocation,
    animal_v.wlh_id,
    animal_v.animal_comment,
    animal_v.pcod_predator_species,
    animal_v.ucod_predator_species,
    animal_v.predator_known,
    animal_v.captivity_status,
    animal_v.mortality_captivity_status,
    animal_v.pcod_confidence,
    animal_v.ucod_confidence,
    animal_v.mortality_report,
    animal_v.mortality_investigation,
    animal_v.valid_from,
    animal_v.valid_to,
    animal_v.created_at,
    animal_v.created_by_user_id,
    animal_v.owned_by_user_id
   FROM bctw.animal_v;


ALTER TABLE bctw_dapi_v1.animal_historic_v OWNER TO bctw;

--
-- Name: code_category_v; Type: VIEW; Schema: bctw_dapi_v1; Owner: bctw
--

CREATE VIEW bctw_dapi_v1.code_category_v AS
 SELECT code_category.code_category_id,
    code_category.code_category_name,
    code_category.code_category_title,
    code_category.code_category_description
   FROM bctw.code_category
  WHERE bctw.is_valid(code_category.valid_to);


ALTER TABLE bctw_dapi_v1.code_category_v OWNER TO bctw;

--
-- Name: code_header_v; Type: VIEW; Schema: bctw_dapi_v1; Owner: bctw
--

CREATE VIEW bctw_dapi_v1.code_header_v AS
 SELECT code_header.code_header_id,
    code_header.code_category_id,
    code_header.code_header_name,
    code_header.code_header_title,
    code_header.code_header_description
   FROM bctw.code_header
  WHERE bctw.is_valid(code_header.valid_to);


ALTER TABLE bctw_dapi_v1.code_header_v OWNER TO bctw;

--
-- Name: code_v; Type: VIEW; Schema: bctw_dapi_v1; Owner: bctw
--

CREATE VIEW bctw_dapi_v1.code_v AS
 SELECT code.code_id,
    code.code_header_id,
    code.code_name,
    code.code_description,
    code.code_description_long,
    code.code_sort_order
   FROM bctw.code
  WHERE bctw.is_valid(code.valid_to);


ALTER TABLE bctw_dapi_v1.code_v OWNER TO bctw;

--
-- Name: collar_animal_assignment_v; Type: VIEW; Schema: bctw_dapi_v1; Owner: bctw
--

CREATE VIEW bctw_dapi_v1.collar_animal_assignment_v AS
 SELECT collar_animal_assignment.assignment_id,
    collar_animal_assignment.collar_id,
    collar_animal_assignment.critter_id,
    collar_animal_assignment.created_at,
    collar_animal_assignment.created_by_user_id,
    collar_animal_assignment.updated_at,
    collar_animal_assignment.updated_by_user_id,
    collar_animal_assignment.valid_from,
    collar_animal_assignment.valid_to,
    collar_animal_assignment.attachment_start,
    collar_animal_assignment.attachment_end
   FROM bctw.collar_animal_assignment;


ALTER TABLE bctw_dapi_v1.collar_animal_assignment_v OWNER TO bctw;

--
-- Name: collar_historic_v; Type: VIEW; Schema: bctw_dapi_v1; Owner: bctw
--

CREATE VIEW bctw_dapi_v1.collar_historic_v AS
 SELECT collar_v.collar_id,
    collar_v.collar_transaction_id,
    collar_v.camera_device_id,
    collar_v.device_id,
    collar_v.device_deployment_status,
    collar_v.device_make,
    collar_v.device_malfunction_type,
    collar_v.device_model,
    collar_v.device_status,
    collar_v.device_type,
    collar_v.dropoff_device_id,
    collar_v.dropoff_frequency,
    collar_v.dropoff_mechanism,
    collar_v.dropoff_frequency_unit,
    collar_v.fix_interval,
    collar_v.fix_interval_rate,
    collar_v.frequency,
    collar_v.implant_device_id,
    collar_v.frequency_unit,
    collar_v.mortality_mode,
    collar_v.mortality_period_hr,
    collar_v.malfunction_date,
    collar_v.malfunction_comment,
    collar_v.activation_status,
    collar_v.activation_comment,
    collar_v.first_activation_month,
    collar_v.first_activation_year,
    collar_v.retrieval_date,
    collar_v.retrieved,
    collar_v.retrieval_comment,
    collar_v.satellite_network,
    collar_v.device_comment,
    collar_v.offline_date,
    collar_v.offline_type,
    collar_v.offline_comment,
    collar_v.device_condition,
    collar_v.created_at,
    collar_v.created_by_user_id,
    collar_v.valid_from,
    collar_v.valid_to,
    collar_v.owned_by_user_id
   FROM bctw.collar_v;


ALTER TABLE bctw_dapi_v1.collar_historic_v OWNER TO bctw;

--
-- Name: currently_attached_collars_v; Type: VIEW; Schema: bctw_dapi_v1; Owner: bctw
--

CREATE VIEW bctw_dapi_v1.currently_attached_collars_v AS
 SELECT caa.assignment_id,
    caa.collar_id,
    c.device_id,
    concat(c.frequency, ' ', c.frequency_unit) AS frequency,
    a.critter_id,
    caa.attachment_start,
    caa.valid_from AS data_life_start,
    caa.valid_to AS data_life_end,
    caa.attachment_end
   FROM ((bctw.collar_animal_assignment caa
     JOIN bctw_dapi_v1.animal_v a ON ((caa.critter_id = a.critter_id)))
     JOIN bctw_dapi_v1.collar_v c ON ((caa.collar_id = c.collar_id)))
  WHERE bctw.is_valid(caa.valid_to);


ALTER TABLE bctw_dapi_v1.currently_attached_collars_v OWNER TO bctw;

--
-- Name: currently_unattached_critters_v; Type: VIEW; Schema: bctw_dapi_v1; Owner: bctw
--

CREATE VIEW bctw_dapi_v1.currently_unattached_critters_v AS
 WITH no_attachments AS (
         SELECT caa.critter_id
           FROM bctw.collar_animal_assignment caa
          WHERE ((NOT bctw.is_valid(now(), caa.valid_from, caa.valid_to)) AND (NOT (caa.critter_id IN ( SELECT currently_attached_collars_v.critter_id
                   FROM bctw_dapi_v1.currently_attached_collars_v))))
        UNION
         SELECT a.critter_id
           FROM bctw.animal a
          WHERE (NOT (a.critter_id IN ( SELECT collar_animal_assignment.critter_id
                   FROM bctw.collar_animal_assignment)))
        )
 SELECT av.critter_id,
    av.critter_transaction_id,
    av.animal_id,
    av.animal_status,
    av.associated_animal_id,
    av.associated_animal_relationship,
    av.capture_comment,
    av.capture_date,
    av.capture_latitude,
    av.capture_longitude,
    av.capture_utm_easting,
    av.capture_utm_northing,
    av.capture_utm_zone,
    av.collective_unit,
    av.animal_colouration,
    av.ear_tag_left_id,
    av.ear_tag_right_id,
    av.ear_tag_left_colour,
    av.ear_tag_right_colour,
    av.estimated_age,
    av.juvenile_at_heel,
    av.juvenile_at_heel_count,
    av.life_stage,
    av.map_colour,
    av.mortality_comment,
    av.mortality_date,
    av.mortality_latitude,
    av.mortality_longitude,
    av.mortality_utm_easting,
    av.mortality_utm_northing,
    av.mortality_utm_zone,
    av.proximate_cause_of_death,
    av.ultimate_cause_of_death,
    av.population_unit,
    av.recapture,
    av.region,
    av.release_comment,
    av.release_date,
    av.release_latitude,
    av.release_longitude,
    av.release_utm_easting,
    av.release_utm_northing,
    av.release_utm_zone,
    av.sex,
    av.species,
    av.translocation,
    av.wlh_id,
    av.animal_comment,
    av.valid_from,
    av.valid_to,
    av.pcod_predator_species,
    av.ucod_predator_species,
    av.owned_by_user_id,
    av.predator_known,
    av.captivity_status,
    av.mortality_captivity_status,
    av.pcod_confidence,
    av.ucod_confidence,
    av.mortality_report,
    av.mortality_investigation
   FROM bctw.animal_v av
  WHERE ((av.critter_id IN ( SELECT no_attachments.critter_id
           FROM no_attachments)) AND bctw.is_valid(av.valid_to));


ALTER TABLE bctw_dapi_v1.currently_unattached_critters_v OWNER TO bctw;

--
-- Name: onboarding_v; Type: VIEW; Schema: bctw_dapi_v1; Owner: bctw
--

CREATE VIEW bctw_dapi_v1.onboarding_v AS
 SELECT onboarding.onboarding_id,
    onboarding.domain,
    onboarding.username,
    onboarding.firstname,
    onboarding.lastname,
    onboarding.access,
    onboarding.email,
    onboarding.phone,
    onboarding.reason,
    onboarding.created_at,
    onboarding.updated_at,
    onboarding.valid_from,
    onboarding.valid_to,
    onboarding.role_type
   FROM bctw.onboarding
  ORDER BY onboarding.created_at DESC;


ALTER TABLE bctw_dapi_v1.onboarding_v OWNER TO bctw;

--
-- Name: permission_requests_v; Type: VIEW; Schema: bctw_dapi_v1; Owner: bctw
--

CREATE VIEW bctw_dapi_v1.permission_requests_v AS
 WITH expanded_users AS (
         SELECT pr.request_id,
            ( SELECT COALESCE(u.idir, u.bceid) AS "coalesce"
                   FROM bctw."user" u
                  WHERE (u.id = pr.requested_by_user_id)) AS requested_by,
            ( SELECT u.email
                   FROM bctw."user" u
                  WHERE (u.id = pr.requested_by_user_id)) AS requested_by_email,
            ( SELECT (((u.firstname)::text || ''::text) || (u.lastname)::text)
                   FROM bctw."user" u
                  WHERE (u.id = pr.requested_by_user_id)) AS requested_by_name,
            pr.created_at AS requested_date,
            pr.request_comment,
            unnest(pr.user_id_list) AS user_id,
            pr.critter_permission_list AS cr,
            pr.valid_to,
            pr.status,
            pr.was_denied_reason
           FROM bctw.permission_request pr
        ), expanded_permissions AS (
         SELECT es.request_id,
            es.requested_by,
            es.requested_by_email,
            es.requested_by_name,
            es.requested_date,
            es.request_comment,
            es.user_id,
            es.cr,
            es.valid_to,
            es.status,
            es.was_denied_reason,
            ( SELECT u.email
                   FROM bctw."user" u
                  WHERE (u.id = es.user_id)) AS requested_for_email,
            ( SELECT (((u.firstname)::text || ''::text) || (u.lastname)::text)
                   FROM bctw."user" u
                  WHERE (u.id = es.user_id)) AS requested_for_name
           FROM expanded_users es
        )
 SELECT ep.request_id,
    ep.requested_by,
    ep.requested_by_email,
    ep.requested_by_name,
    ep.requested_date,
    ep.request_comment,
    ep.requested_for_email,
    ep.requested_for_name,
    ( SELECT a.animal_id
           FROM bctw.animal a
          WHERE (bctw.is_valid(a.valid_to) AND (a.critter_id = ((ep.cr ->> 'critter_id'::text))::uuid))) AS animal_id,
    ( SELECT a.wlh_id
           FROM bctw.animal a
          WHERE (bctw.is_valid(a.valid_to) AND (a.critter_id = ((ep.cr ->> 'critter_id'::text))::uuid))) AS wlh_id,
    bctw.get_species_name(( SELECT a.species
           FROM bctw.animal a
          WHERE (bctw.is_valid(a.valid_to) AND (a.critter_id = ((ep.cr ->> 'critter_id'::text))::uuid)))) AS species,
    (ep.cr ->> 'permission_type'::text) AS permission_type,
    ep.valid_to,
    ep.status,
    ep.was_denied_reason
   FROM expanded_permissions ep;


ALTER TABLE bctw_dapi_v1.permission_requests_v OWNER TO bctw;

--
-- Name: species_v; Type: VIEW; Schema: bctw_dapi_v1; Owner: bctw
--

CREATE VIEW bctw_dapi_v1.species_v AS
 SELECT species.species_code,
    species.species_eng_name,
    species.species_scientific_name,
    species.predator_species
   FROM bctw.species
  WHERE bctw.is_valid(species.valid_to);


ALTER TABLE bctw_dapi_v1.species_v OWNER TO bctw;

--
-- Name: user_animal_assignment_v; Type: VIEW; Schema: bctw_dapi_v1; Owner: bctw
--

CREATE VIEW bctw_dapi_v1.user_animal_assignment_v AS
 SELECT ua.user_id AS requested_for_id,
    ( SELECT "user".email
           FROM bctw."user"
          WHERE ("user".id = ua.user_id)) AS requested_for_email,
    ( SELECT a.animal_id
           FROM bctw.animal a
          WHERE ((a.critter_id = ua.critter_id) AND bctw.is_valid(a.valid_to))) AS animal_id,
    ( SELECT a.wlh_id
           FROM bctw.animal a
          WHERE ((a.critter_id = ua.critter_id) AND bctw.is_valid(a.valid_to))) AS wlh_id,
    ua.valid_from AS requested_at,
    ua.created_by_user_id AS requested_by_id,
    ( SELECT COALESCE("user".idir, "user".bceid) AS "coalesce"
           FROM bctw."user"
          WHERE ("user".id = ua.user_id)) AS requested_by,
    ua.permission_type
   FROM bctw.user_animal_assignment ua
  WHERE bctw.is_valid(ua.valid_to);


ALTER TABLE bctw_dapi_v1.user_animal_assignment_v OWNER TO bctw;

--
-- Name: VIEW user_animal_assignment_v; Type: COMMENT; Schema: bctw_dapi_v1; Owner: bctw
--

COMMENT ON VIEW bctw_dapi_v1.user_animal_assignment_v IS 'A bctw.user_animal_assignment table view for current user-critter assignments.';


--
-- Name: user_v; Type: VIEW; Schema: bctw_dapi_v1; Owner: bctw
--

CREATE VIEW bctw_dapi_v1.user_v AS
 SELECT u.id,
    u.domain,
    u.username,
    u.idir,
    u.bceid,
    u.firstname,
    u.lastname,
    u.email,
    u.phone,
    (urt.role_type)::text AS role_type,
    (EXISTS ( SELECT 1
           FROM bctw.animal
          WHERE (animal.owned_by_user_id = u.id))) AS is_owner,
    u.created_at,
    u.created_by_user_id,
    u.updated_at
   FROM ((bctw."user" u
     LEFT JOIN bctw.user_role_xref rx ON ((rx.user_id = u.id)))
     LEFT JOIN bctw.user_role_type urt ON ((urt.role_id = rx.role_id)))
  WHERE bctw.is_valid(u.valid_to);


ALTER TABLE bctw_dapi_v1.user_v OWNER TO bctw;

--
-- Name: vectronic_devices_without_keyx_entries; Type: VIEW; Schema: bctw_dapi_v1; Owner: bctw
--

CREATE VIEW bctw_dapi_v1.vectronic_devices_without_keyx_entries AS
 SELECT collar.collar_id,
    collar.collar_transaction_id,
    collar.camera_device_id,
    collar.device_id,
    collar.device_deployment_status,
    collar.device_make,
    collar.device_malfunction_type,
    collar.device_model,
    collar.device_status,
    collar.device_type,
    collar.dropoff_device_id,
    collar.dropoff_frequency,
    collar.dropoff_frequency_unit,
    collar.fix_interval,
    collar.fix_interval_rate,
    collar.frequency,
    collar.frequency_unit,
    collar.malfunction_date,
    collar.activation_comment,
    collar.first_activation_month,
    collar.first_activation_year,
    collar.retrieval_date,
    collar.retrieved,
    collar.satellite_network,
    collar.device_comment,
    collar.activation_status,
    collar.created_at,
    collar.created_by_user_id,
    collar.updated_at,
    collar.updated_by_user_id,
    collar.valid_from,
    collar.valid_to,
    collar.owned_by_user_id,
    collar.offline_date,
    collar.offline_type,
    collar.device_condition,
    collar.retrieval_comment,
    collar.malfunction_comment,
    collar.offline_comment,
    collar.mortality_mode,
    collar.mortality_period_hr,
    collar.dropoff_mechanism,
    collar.implant_device_id
   FROM bctw.collar
  WHERE ((collar.device_make = ( SELECT code.code_id
           FROM bctw.code
          WHERE ((code.code_description)::text = 'Vectronic'::text))) AND (NOT (collar.device_id IN ( SELECT api_vectronics_collar_data.idcollar
           FROM bctw.api_vectronics_collar_data))));


ALTER TABLE bctw_dapi_v1.vectronic_devices_without_keyx_entries OWNER TO bctw;

--
-- Name: code code_id; Type: DEFAULT; Schema: bctw; Owner: bctw
--

ALTER TABLE ONLY bctw.code ALTER COLUMN code_id SET DEFAULT nextval('bctw.code_code_id_seq'::regclass);


--
-- Name: code_category code_category_id; Type: DEFAULT; Schema: bctw; Owner: bctw
--

ALTER TABLE ONLY bctw.code_category ALTER COLUMN code_category_id SET DEFAULT nextval('bctw.code_category_code_category_id_seq'::regclass);


--
-- Name: code_header code_header_id; Type: DEFAULT; Schema: bctw; Owner: bctw
--

ALTER TABLE ONLY bctw.code_header ALTER COLUMN code_header_id SET DEFAULT nextval('bctw.code_header_code_header_id_seq'::regclass);


--
-- Name: collar_file file_id; Type: DEFAULT; Schema: bctw; Owner: bctw
--

ALTER TABLE ONLY bctw.collar_file ALTER COLUMN file_id SET DEFAULT nextval('bctw.collar_file_file_id_seq'::regclass);


--
-- Name: onboarding onboarding_id; Type: DEFAULT; Schema: bctw; Owner: bctw
--

ALTER TABLE ONLY bctw.onboarding ALTER COLUMN onboarding_id SET DEFAULT nextval('bctw.onboarding_onboarding_id_seq'::regclass);


--
-- Name: permission_request request_id; Type: DEFAULT; Schema: bctw; Owner: bctw
--

ALTER TABLE ONLY bctw.permission_request ALTER COLUMN request_id SET DEFAULT nextval('bctw.permission_request_request_id_seq'::regclass);


--
-- Name: telemetry_sensor_alert alert_id; Type: DEFAULT; Schema: bctw; Owner: bctw
--

ALTER TABLE ONLY bctw.telemetry_sensor_alert ALTER COLUMN alert_id SET DEFAULT nextval('bctw.telemetry_sensor_alert_alert_id_seq'::regclass);


--
-- Name: user id; Type: DEFAULT; Schema: bctw; Owner: bctw
--

ALTER TABLE ONLY bctw."user" ALTER COLUMN id SET DEFAULT nextval('bctw.user_id_seq1'::regclass);


--
-- Name: user_defined_field udf_id; Type: DEFAULT; Schema: bctw; Owner: bctw
--

ALTER TABLE ONLY bctw.user_defined_field ALTER COLUMN udf_id SET DEFAULT nextval('bctw.user_defined_field_udf_id_seq'::regclass);


--
-- Name: user_defined_field user_id; Type: DEFAULT; Schema: bctw; Owner: bctw
--

ALTER TABLE ONLY bctw.user_defined_field ALTER COLUMN user_id SET DEFAULT nextval('bctw.user_defined_field_user_id_seq'::regclass);


--
-- Name: animal animal_pkey; Type: CONSTRAINT; Schema: bctw; Owner: bctw
--

ALTER TABLE ONLY bctw.animal
    ADD CONSTRAINT animal_pkey PRIMARY KEY (critter_transaction_id);


--
-- Name: ats_collar_data ats_collar_data_timeid_key; Type: CONSTRAINT; Schema: bctw; Owner: bctw
--

ALTER TABLE ONLY bctw.ats_collar_data
    ADD CONSTRAINT ats_collar_data_timeid_key UNIQUE (timeid);


--
-- Name: code_category category_name_uq; Type: CONSTRAINT; Schema: bctw; Owner: bctw
--

ALTER TABLE ONLY bctw.code_category
    ADD CONSTRAINT category_name_uq UNIQUE (code_category_name, valid_from, valid_to);


--
-- Name: code_category code_category_pk; Type: CONSTRAINT; Schema: bctw; Owner: bctw
--

ALTER TABLE ONLY bctw.code_category
    ADD CONSTRAINT code_category_pk PRIMARY KEY (code_category_id);


--
-- Name: code_header code_header_pk; Type: CONSTRAINT; Schema: bctw; Owner: bctw
--

ALTER TABLE ONLY bctw.code_header
    ADD CONSTRAINT code_header_pk PRIMARY KEY (code_header_id);


--
-- Name: code code_id_name_uq; Type: CONSTRAINT; Schema: bctw; Owner: bctw
--

ALTER TABLE ONLY bctw.code
    ADD CONSTRAINT code_id_name_uq UNIQUE (code_header_id, code_name, valid_from, valid_to);


--
-- Name: code code_pk; Type: CONSTRAINT; Schema: bctw; Owner: bctw
--

ALTER TABLE ONLY bctw.code
    ADD CONSTRAINT code_pk PRIMARY KEY (code_id);


--
-- Name: collar collar2_pkey; Type: CONSTRAINT; Schema: bctw; Owner: bctw
--

ALTER TABLE ONLY bctw.collar
    ADD CONSTRAINT collar2_pkey PRIMARY KEY (collar_transaction_id);


--
-- Name: collar_animal_assignment collar_animal_assignment_t_pkey; Type: CONSTRAINT; Schema: bctw; Owner: bctw
--

ALTER TABLE ONLY bctw.collar_animal_assignment
    ADD CONSTRAINT collar_animal_assignment_t_pkey PRIMARY KEY (assignment_id);


--
-- Name: collar_file collar_file_pkey; Type: CONSTRAINT; Schema: bctw; Owner: bctw
--

ALTER TABLE ONLY bctw.collar_file
    ADD CONSTRAINT collar_file_pkey PRIMARY KEY (file_id);


--
-- Name: collar_vendor_api_credentials collar_vendor_api_credentials_pkey; Type: CONSTRAINT; Schema: bctw; Owner: bctw
--

ALTER TABLE ONLY bctw.collar_vendor_api_credentials
    ADD CONSTRAINT collar_vendor_api_credentials_pkey PRIMARY KEY (api_name);


--
-- Name: code_header header_id_name_uq; Type: CONSTRAINT; Schema: bctw; Owner: bctw
--

ALTER TABLE ONLY bctw.code_header
    ADD CONSTRAINT header_id_name_uq UNIQUE (code_category_id, code_header_name, valid_from, valid_to);


--
-- Name: historical_telemetry historical_telemetry_time_id_key; Type: CONSTRAINT; Schema: bctw; Owner: bctw
--

ALTER TABLE ONLY bctw.historical_telemetry
    ADD CONSTRAINT historical_telemetry_time_id_key UNIQUE (time_id);


--
-- Name: lotek_collar_data lotek_collar_data_timeid_key; Type: CONSTRAINT; Schema: bctw; Owner: bctw
--

ALTER TABLE ONLY bctw.lotek_collar_data
    ADD CONSTRAINT lotek_collar_data_timeid_key UNIQUE (timeid);


--
-- Name: onboarding onboarding_pkey; Type: CONSTRAINT; Schema: bctw; Owner: bctw
--

ALTER TABLE ONLY bctw.onboarding
    ADD CONSTRAINT onboarding_pkey PRIMARY KEY (onboarding_id);


--
-- Name: permission_request permission_request_pkey; Type: CONSTRAINT; Schema: bctw; Owner: bctw
--

ALTER TABLE ONLY bctw.permission_request
    ADD CONSTRAINT permission_request_pkey PRIMARY KEY (request_id);


--
-- Name: species species2_pkey; Type: CONSTRAINT; Schema: bctw; Owner: bctw
--

ALTER TABLE ONLY bctw.species
    ADD CONSTRAINT species2_pkey PRIMARY KEY (species_code);


--
-- Name: telemetry_sensor_alert telemetry_sensor_alert_pkey; Type: CONSTRAINT; Schema: bctw; Owner: bctw
--

ALTER TABLE ONLY bctw.telemetry_sensor_alert
    ADD CONSTRAINT telemetry_sensor_alert_pkey PRIMARY KEY (alert_id);


--
-- Name: user_role_type unique_role_type; Type: CONSTRAINT; Schema: bctw; Owner: bctw
--

ALTER TABLE ONLY bctw.user_role_type
    ADD CONSTRAINT unique_role_type UNIQUE (role_type);


--
-- Name: user_animal_assignment user_animal_assignment_t_pkey; Type: CONSTRAINT; Schema: bctw; Owner: bctw
--

ALTER TABLE ONLY bctw.user_animal_assignment
    ADD CONSTRAINT user_animal_assignment_t_pkey PRIMARY KEY (assignment_id);


--
-- Name: user_defined_field user_defined_field_pkey; Type: CONSTRAINT; Schema: bctw; Owner: bctw
--

ALTER TABLE ONLY bctw.user_defined_field
    ADD CONSTRAINT user_defined_field_pkey PRIMARY KEY (udf_id);


--
-- Name: user user_idir_key; Type: CONSTRAINT; Schema: bctw; Owner: bctw
--

ALTER TABLE ONLY bctw."user"
    ADD CONSTRAINT user_idir_key UNIQUE (idir);


--
-- Name: user user_pkey1; Type: CONSTRAINT; Schema: bctw; Owner: bctw
--

ALTER TABLE ONLY bctw."user"
    ADD CONSTRAINT user_pkey1 PRIMARY KEY (id);


--
-- Name: user_role_type user_role_type_pkey; Type: CONSTRAINT; Schema: bctw; Owner: bctw
--

ALTER TABLE ONLY bctw.user_role_type
    ADD CONSTRAINT user_role_type_pkey PRIMARY KEY (role_id);


--
-- Name: user_role_xref user_role_xref_pkey; Type: CONSTRAINT; Schema: bctw; Owner: bctw
--

ALTER TABLE ONLY bctw.user_role_xref
    ADD CONSTRAINT user_role_xref_pkey PRIMARY KEY (user_id, role_id);


--
-- Name: user user_username_key; Type: CONSTRAINT; Schema: bctw; Owner: bctw
--

ALTER TABLE ONLY bctw."user"
    ADD CONSTRAINT user_username_key UNIQUE (username);


--
-- Name: vectronics_collar_data vectronics_collar_data_idposition_key; Type: CONSTRAINT; Schema: bctw; Owner: bctw
--

ALTER TABLE ONLY bctw.vectronics_collar_data
    ADD CONSTRAINT vectronics_collar_data_idposition_key UNIQUE (idposition);


--
-- Name: latest_transmission_idx; Type: INDEX; Schema: bctw; Owner: bctw
--

CREATE INDEX latest_transmission_idx ON bctw.latest_transmissions USING btree (collar_id);


--
-- Name: lotek_collar_data_gist; Type: INDEX; Schema: bctw; Owner: bctw
--

CREATE INDEX lotek_collar_data_gist ON bctw.lotek_collar_data USING gist (geom);


--
-- Name: lotek_collar_data_idx; Type: INDEX; Schema: bctw; Owner: bctw
--

CREATE INDEX lotek_collar_data_idx ON bctw.lotek_collar_data USING btree (deviceid);


--
-- Name: lotek_collar_data_idx2; Type: INDEX; Schema: bctw; Owner: bctw
--

CREATE INDEX lotek_collar_data_idx2 ON bctw.lotek_collar_data USING btree (recdatetime);


--
-- Name: vectronics_collar_data_gist; Type: INDEX; Schema: bctw; Owner: bctw
--

CREATE INDEX vectronics_collar_data_gist ON bctw.vectronics_collar_data USING gist (geom);


--
-- Name: vendor_merge_critterless_gist; Type: INDEX; Schema: bctw; Owner: bctw
--

CREATE INDEX vendor_merge_critterless_gist ON bctw.vendor_merge_view_no_critter USING gist (geom);


--
-- Name: vendor_merge_critterless_idx; Type: INDEX; Schema: bctw; Owner: bctw
--

CREATE INDEX vendor_merge_critterless_idx ON bctw.vendor_merge_view_no_critter USING btree (vendor_merge_id);


--
-- Name: vendor_merge_critterless_idx2; Type: INDEX; Schema: bctw; Owner: bctw
--

CREATE INDEX vendor_merge_critterless_idx2 ON bctw.vendor_merge_view_no_critter USING btree (date_recorded);


--
-- Name: telemetry_sensor_alert alert_notify_api_sms_trg; Type: TRIGGER; Schema: bctw; Owner: bctw
--

CREATE TRIGGER alert_notify_api_sms_trg AFTER INSERT ON bctw.telemetry_sensor_alert REFERENCING NEW TABLE AS new_table FOR EACH ROW EXECUTE FUNCTION bctw.trg_new_alert();


--
-- Name: animal animal_insert_trg; Type: TRIGGER; Schema: bctw; Owner: bctw
--

CREATE TRIGGER animal_insert_trg AFTER INSERT ON bctw.animal REFERENCING NEW TABLE AS inserted FOR EACH ROW EXECUTE FUNCTION bctw.trg_update_animal_retroactively();


--
-- Name: ats_collar_data ats_insert_trg; Type: TRIGGER; Schema: bctw; Owner: bctw
--

CREATE TRIGGER ats_insert_trg AFTER INSERT ON bctw.ats_collar_data REFERENCING NEW TABLE AS new_table FOR EACH ROW WHEN (new.mortality) EXECUTE FUNCTION bctw.trg_process_ats_insert();


--
-- Name: TRIGGER ats_insert_trg ON ats_collar_data; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON TRIGGER ats_insert_trg ON bctw.ats_collar_data IS 'when new telemetry data is received from the API cronjob, run the trigger handler trg_process_ats_insert if the record has a mortality';


--
-- Name: telemetry_sensor_alert lotek_alert_trg; Type: TRIGGER; Schema: bctw; Owner: bctw
--

CREATE TRIGGER lotek_alert_trg AFTER INSERT ON bctw.telemetry_sensor_alert REFERENCING NEW TABLE AS new_table FOR EACH ROW WHEN ((new.device_make = 'Lotek'::text)) EXECUTE FUNCTION bctw.trg_process_lotek_insert();


--
-- Name: user user_onboarded_trg; Type: TRIGGER; Schema: bctw; Owner: bctw
--

CREATE TRIGGER user_onboarded_trg AFTER INSERT ON bctw."user" REFERENCING NEW TABLE AS new_table FOR EACH STATEMENT EXECUTE FUNCTION bctw.trg_process_new_user();


--
-- Name: vectronics_collar_data vectronic_alert_trg; Type: TRIGGER; Schema: bctw; Owner: bctw
--

CREATE TRIGGER vectronic_alert_trg AFTER INSERT ON bctw.vectronics_collar_data REFERENCING NEW TABLE AS new_table FOR EACH ROW WHEN ((new.idmortalitystatus = 1)) EXECUTE FUNCTION bctw.trg_process_vectronic_insert();


--
-- Name: permission_request permission_request_requested_by_user_id_fkey; Type: FK CONSTRAINT; Schema: bctw; Owner: bctw
--

ALTER TABLE ONLY bctw.permission_request
    ADD CONSTRAINT permission_request_requested_by_user_id_fkey FOREIGN KEY (requested_by_user_id) REFERENCES bctw."user"(id);


--
-- Name: user_animal_assignment user_animal_assignment_fk_user_id; Type: FK CONSTRAINT; Schema: bctw; Owner: bctw
--

ALTER TABLE ONLY bctw.user_animal_assignment
    ADD CONSTRAINT user_animal_assignment_fk_user_id FOREIGN KEY (user_id) REFERENCES bctw."user"(id);


--
-- Name: user_defined_field user_defined_field_user_id_fkey; Type: FK CONSTRAINT; Schema: bctw; Owner: bctw
--

ALTER TABLE ONLY bctw.user_defined_field
    ADD CONSTRAINT user_defined_field_user_id_fkey FOREIGN KEY (user_id) REFERENCES bctw."user"(id);


--
-- Name: user_role_xref user_role_xref_role_id_fkey; Type: FK CONSTRAINT; Schema: bctw; Owner: bctw
--

ALTER TABLE ONLY bctw.user_role_xref
    ADD CONSTRAINT user_role_xref_role_id_fkey FOREIGN KEY (role_id) REFERENCES bctw.user_role_type(role_id);


--
-- Name: user_role_xref user_role_xref_user_id_fkey; Type: FK CONSTRAINT; Schema: bctw; Owner: bctw
--

ALTER TABLE ONLY bctw.user_role_xref
    ADD CONSTRAINT user_role_xref_user_id_fkey FOREIGN KEY (user_id) REFERENCES bctw."user"(id);


--
-- Name: SCHEMA bctw; Type: ACL; Schema: -; Owner: bctw
--

GRANT USAGE ON SCHEMA bctw TO bctw_api;


--
-- Name: SCHEMA bctw_dapi_v1; Type: ACL; Schema: -; Owner: bctw
--

GRANT USAGE ON SCHEMA bctw_dapi_v1 TO bctw_api;


--
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;


--
-- Name: FUNCTION get_animal_collar_assignment_history(stridir text, animalid uuid); Type: ACL; Schema: bctw; Owner: bctw
--

GRANT ALL ON FUNCTION bctw.get_animal_collar_assignment_history(stridir text, animalid uuid) TO bctw_api;


--
-- Name: FUNCTION is_valid(valid_to timestamp without time zone); Type: ACL; Schema: bctw; Owner: bctw
--

GRANT ALL ON FUNCTION bctw.is_valid(valid_to timestamp without time zone) TO bctw_api;


--
-- Name: FUNCTION is_valid(valid_to timestamp with time zone); Type: ACL; Schema: bctw; Owner: bctw
--

GRANT ALL ON FUNCTION bctw.is_valid(valid_to timestamp with time zone) TO bctw_api;


--
-- Name: TABLE animal_v; Type: ACL; Schema: bctw_dapi_v1; Owner: bctw
--

GRANT ALL ON TABLE bctw_dapi_v1.animal_v TO bctw_api;


--
-- Name: TABLE collar_v; Type: ACL; Schema: bctw_dapi_v1; Owner: bctw
--

GRANT ALL ON TABLE bctw_dapi_v1.collar_v TO bctw_api;


--
-- Name: TABLE alert_v; Type: ACL; Schema: bctw_dapi_v1; Owner: bctw
--

GRANT ALL ON TABLE bctw_dapi_v1.alert_v TO bctw_api;


--
-- Name: TABLE animal_historic_v; Type: ACL; Schema: bctw_dapi_v1; Owner: bctw
--

GRANT ALL ON TABLE bctw_dapi_v1.animal_historic_v TO bctw_api;


--
-- Name: TABLE code_category_v; Type: ACL; Schema: bctw_dapi_v1; Owner: bctw
--

GRANT ALL ON TABLE bctw_dapi_v1.code_category_v TO bctw_api;


--
-- Name: TABLE code_header_v; Type: ACL; Schema: bctw_dapi_v1; Owner: bctw
--

GRANT ALL ON TABLE bctw_dapi_v1.code_header_v TO bctw_api;


--
-- Name: TABLE code_v; Type: ACL; Schema: bctw_dapi_v1; Owner: bctw
--

GRANT ALL ON TABLE bctw_dapi_v1.code_v TO bctw_api;


--
-- Name: TABLE collar_animal_assignment_v; Type: ACL; Schema: bctw_dapi_v1; Owner: bctw
--

GRANT ALL ON TABLE bctw_dapi_v1.collar_animal_assignment_v TO bctw_api;


--
-- Name: TABLE collar_historic_v; Type: ACL; Schema: bctw_dapi_v1; Owner: bctw
--

GRANT ALL ON TABLE bctw_dapi_v1.collar_historic_v TO bctw_api;


--
-- Name: TABLE currently_attached_collars_v; Type: ACL; Schema: bctw_dapi_v1; Owner: bctw
--

GRANT ALL ON TABLE bctw_dapi_v1.currently_attached_collars_v TO bctw_api;


--
-- Name: TABLE currently_unattached_critters_v; Type: ACL; Schema: bctw_dapi_v1; Owner: bctw
--

GRANT ALL ON TABLE bctw_dapi_v1.currently_unattached_critters_v TO bctw_api;


--
-- Name: TABLE onboarding_v; Type: ACL; Schema: bctw_dapi_v1; Owner: bctw
--

GRANT ALL ON TABLE bctw_dapi_v1.onboarding_v TO bctw_api;


--
-- Name: TABLE permission_requests_v; Type: ACL; Schema: bctw_dapi_v1; Owner: bctw
--

GRANT ALL ON TABLE bctw_dapi_v1.permission_requests_v TO bctw_api;


--
-- Name: TABLE species_v; Type: ACL; Schema: bctw_dapi_v1; Owner: bctw
--

GRANT ALL ON TABLE bctw_dapi_v1.species_v TO bctw_api;


--
-- Name: TABLE user_animal_assignment_v; Type: ACL; Schema: bctw_dapi_v1; Owner: bctw
--

GRANT ALL ON TABLE bctw_dapi_v1.user_animal_assignment_v TO bctw_api;


--
-- Name: TABLE user_v; Type: ACL; Schema: bctw_dapi_v1; Owner: bctw
--

GRANT ALL ON TABLE bctw_dapi_v1.user_v TO bctw_api;


--
-- Name: TABLE vectronic_devices_without_keyx_entries; Type: ACL; Schema: bctw_dapi_v1; Owner: bctw
--

GRANT ALL ON TABLE bctw_dapi_v1.vectronic_devices_without_keyx_entries TO bctw_api;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: bctw_dapi_v1; Owner: bctw
--

ALTER DEFAULT PRIVILEGES FOR ROLE bctw IN SCHEMA bctw_dapi_v1 REVOKE ALL ON TABLES  FROM bctw;
ALTER DEFAULT PRIVILEGES FOR ROLE bctw IN SCHEMA bctw_dapi_v1 GRANT ALL ON TABLES  TO bctw_api;


--
-- PostgreSQL database dump complete
--

