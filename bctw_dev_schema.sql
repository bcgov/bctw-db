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
-- Name: role_type; Type: TYPE; Schema: bctw; Owner: bctw
--

CREATE TYPE bctw.role_type AS ENUM (
    'administrator',
    'owner',
    'observer'
);


ALTER TYPE bctw.role_type OWNER TO bctw;

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
-- Name: telemetry_alert_type; Type: TYPE; Schema: bctw; Owner: bctw
--

CREATE TYPE bctw.telemetry_alert_type AS ENUM (
    'mortality',
    'battery'
);


ALTER TYPE bctw.telemetry_alert_type OWNER TO bctw;

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
 
 FOR aid IN SELECT critter_id FROM bctw.animal WHERE critter_id = ANY(ids) LOOP
 	
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
 
 for cid in select collar_id from bctw.collar where collar_id = any(ids) loop
 	-- check collar exists
 	if not exists (
 		select 1 from bctw.collar where collar_id = cid
 		and bctw.is_valid(valid_to) 		
 	) then raise exception 'collar % does not exist', cid;
 	end if;
	
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
	   -- no longer an array, so make it
	   jsonb_build_array(rr.critter_permission_list)
	 );
 END IF;
	
 -- expire the request
 UPDATE permission_request
 SET 
   was_granted = isgrant,
   was_denied_reason = denycomment,
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
-- Name: get_code_id(text, text); Type: FUNCTION; Schema: bctw; Owner: bctw
--

CREATE FUNCTION bctw.get_code_id(codeheader text, description text) RETURNS integer
    LANGUAGE plpgsql
    AS $$
declare code_id integer;
begin
	if description is null
	  then return null;
	end if;

	code_id := (
	  select c.code_id from bctw.code c
	  inner join bctw.code_header ch
	  ON c.code_header_id = ch.code_header_id
	  where ch.code_header_name = codeheader
	  and (c.code_description = description or c.code_name = description)
	);
	if code_id is null then
--	  raise exception 'unable to retrieve valid code from header % and value %', codeheader, description;
	  return null;
	end if;
	return code_id;
END;
$$;


ALTER FUNCTION bctw.get_code_id(codeheader text, description text) OWNER TO bctw;

--
-- Name: FUNCTION get_code_id(codeheader text, description text); Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON FUNCTION bctw.get_code_id(codeheader text, description text) IS 'retrieve a code records ID (code.code_id) from a code_header.code_header_name and either code_name or code_description. Returns NULL if it cannot be found.';


--
-- Name: get_code_id_with_error(text, text); Type: FUNCTION; Schema: bctw; Owner: bctw
--

CREATE FUNCTION bctw.get_code_id_with_error(codeheader text, description text) RETURNS integer
    LANGUAGE plpgsql
    AS $$
declare code_id integer;
begin
	if description is null
	  then return null;
	end if;

	code_id := (
	  select c.code_id from bctw.code c
	  inner join bctw.code_header ch
	  ON c.code_header_id = ch.code_header_id
	  where ch.code_header_name = codeheader
	  and (c.code_description = description or c.code_name = description)
	);

	if code_id is null then
	  raise exception 'unable to determine valid code. Code type "%" and value "%"', codeheader, description;
	end if;
	return code_id;
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
-- Name: get_species_id_with_error(text); Type: FUNCTION; Schema: bctw; Owner: bctw
--

CREATE FUNCTION bctw.get_species_id_with_error(commonname text) RETURNS character varying
    LANGUAGE plpgsql
    AS $$
declare speciesid varchar;
begin
	if commonname is null
	  then return null;
	end if;

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

CREATE FUNCTION bctw.get_telemetry(stridir text, starttime timestamp with time zone, endtime timestamp with time zone) RETURNS SETOF bctw.telemetry
    LANGUAGE plpgsql
    AS $$
DECLARE
  USERID integer := BCTW.GET_USER_ID (STRIDIR);
BEGIN
  IF USERID IS NULL THEN
    RAISE exception 'UNABLE FIND USER WITH IDIR %', STRIDIR;
  END IF;
  RETURN QUERY
  SELECT
    a.critter_id,
    a.critter_transaction_id,
    c.collar_id,
    c.collar_transaction_id,
    (SELECT species_eng_name FROM species WHERE species_code = a.species)::text AS species,
    a.wlh_id,
    a.animal_id,
    vmv.device_id,
    vmv.device_vendor,
    c.frequency,
    (SELECT code_description FROM code WHERE code.code_id = a.animal_status)::text AS animal_status,
    (SELECT code_description FROM code WHERE code.code_id = a.sex)::text AS sex,
    (SELECT code_description FROM code WHERE code.code_id = c.device_status)::text AS device_status,
    (SELECT code_description FROM code WHERE code.code_id = a.population_unit)::text AS population_unit,
    (SELECT code_description FROM code WHERE code.code_id = a.collective_unit)::text AS collective_unit,
    vmv.geom,
    vmv.date_recorded,
    row_number() OVER (ORDER BY 1::integer) AS VENDOR_MERGE_ID,
	 	JSONB_BUILD_OBJECT('type', 'Feature', 'id', row_number() OVER (ORDER BY 1::integer), 'geometry', ST_ASGEOJSON (VMV.geom)::jsonb, 'properties', 
	 		JSONB_BUILD_OBJECT(
	 			'collar_id', c.collar_id,
	 			'critter_id', a.critter_id,
	 			'species', (SELECT species_eng_name FROM species WHERE species_code = a.species),
	 			'wlh_id', a.wlh_id,
	 			'animal_id', a.animal_id,
	 			'device_id', vmv.device_id,
	 			'device_vendor', vmv.device_vendor,
	 			'frequency', c.frequency,
	 			'frequency_unit', (SELECT code_description FROM code WHERE code.code_id = c.frequency_unit),
	 			'animal_status', (SELECT code_description FROM code WHERE code.code_id = a.animal_status),
	 			'mortality_date', a.mortality_date,
	 			'sex', (SELECT code_description FROM code WHERE code.code_id = a.sex),
	 			'device_status', (SELECT code_description FROM code WHERE code.code_id = c.device_status),
	 			'population_unit', (SELECT code_description FROM code WHERE code.code_id = a.population_unit),
	 			'collective_unit', (SELECT code_description FROM code WHERE code.code_id = a.collective_unit),
	 			'date_recorded', vmv.date_recorded,
	 			'map_colour', (select concat(code_name, ',', code_description_long) from bctw.code where code_id = a.map_colour),
	 			'capture_date', a.capture_date -- fixme ( should be the oldest capture date for this particular device id assignment)
	 	 )
 	  ) AS geojson,
 	  (select code_name from bctw.code where code_id = a.map_colour)::text as map_colour
 	
  FROM bctw.vendor_merge_view_no_critter vmv
    JOIN bctw.collar c
      ON c.device_id = VMV.device_id and (SELECT code_description FROM code WHERE code.code_id = c.device_make) = vmv.device_vendor
      
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
			WHERE ua.user_id = USERID
			AND is_valid(a.valid_to)
			AND is_valid(ua.valid_to)
			OR a.owned_by_user_id = USERID
			AND is_valid(a.valid_to)
    )
    AND bctw.is_valid(vmv.date_recorded::timestamp, caa.valid_from::timestamp, caa.valid_to::timestamp);
   -- todo: confirm removing the line below shows 'invalid' animal/device links
--  AND bctw.is_valid(caa.valid_to);
END;
$$;


ALTER FUNCTION bctw.get_telemetry(stridir text, starttime timestamp with time zone, endtime timestamp with time zone) OWNER TO bctw;

--
-- Name: FUNCTION get_telemetry(stridir text, starttime timestamp with time zone, endtime timestamp with time zone); Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON FUNCTION bctw.get_telemetry(stridir text, starttime timestamp with time zone, endtime timestamp with time zone) IS 'what the 2D map and 3D terrain viewer use to display data for animals with attached devices.
note: because the result of this function is a user defined type - the query column order matters.';


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
		RAISE EXCEPTION 'could not find user with idir %', stridir;
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
	RETURN COALESCE(bctw.get_user_animal_permission(userid, attached_critter), 'none');
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
    capture_date date,
    capture_latitude double precision,
    capture_longitude double precision,
    capture_utm_easting integer,
    capture_utm_northing integer,
    capture_utm_zone integer,
    collective_unit integer,
    animal_colouration character varying(20),
    ear_tag_left_colour character varying(20),
    ear_tag_right_colour character varying(20),
    estimated_age double precision,
    juvenile_at_heel integer,
    life_stage integer,
    map_colour integer DEFAULT bctw_dapi_v1.get_random_colour_code_id(),
    mortality_comment character varying(200),
    mortality_date date,
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
    release_date date,
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
    predator_species character varying(20),
    owned_by_user_id integer,
    ear_tag_left_id character varying(20),
    ear_tag_right_id character varying(20),
    juvenile_at_heel_count integer
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
-- Name: COLUMN animal.predator_species; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.animal.predator_species IS 'species of the animal that caused the mortality. see pcod and ucod fields. ';


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
	  'collective_unit', bctw.get_code_id_with_error('collective_unit', ar.collective_unit), -- todo / fix
	  'animal_colouration', ar.animal_colouration,
	  'ear_tag_left_id', ar.ear_tag_left_id,
	  'ear_tag_right_id', ar.ear_tag_right_id,
	  'ear_tag_left_colour', ar.ear_tag_left_colour,
	  'ear_tag_right_colour', ar.ear_tag_right_colour,
	  'estimated_age', ar.estimated_age,
	  'juvenile_at_heel', bctw.get_code_id_with_error('juvenile_at_heel', ar.juvenile_at_heel),
	  'juvenile_at_heel_count', ar.juvenile_at_heel_count,
	  'life_stage', bctw.get_code_id_with_error('life_stage', ar.life_stage),
	  -- skip map colour
	  'mortality_comment', ar.mortality_comment,
	  'mortality_date', ar.mortality_date,
	  'mortality_latitude', ar.mortality_latitude,
	  'mortality_longitude', ar.mortality_longitude,
	  'mortality_utm_easting', ar.mortality_utm_easting,
	  'mortality_utm_northing', ar.mortality_utm_northing,
	  'mortality_utm_zone', ar.mortality_utm_zone,
	  'predator_species', bctw.get_species_id_with_error(ar.predator_species),
	  'proximate_cause_of_death', bctw.get_code_id_with_error('proximate_cause_of_death', ar.proximate_cause_of_death)
	  );
	 	
	  ret2 := JSONB_BUILD_OBJECT(
	  'ultimate_cause_of_death', bctw.get_code_id_with_error('ultimate_cause_of_death', ar.ultimate_cause_of_death),
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
	  'valid_from', ar.valid_from,
	  'valid_to', ar.valid_to,
	  'predator_species', ar.predator_species,
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

COMMENT ON FUNCTION bctw.json_to_animal(animaljson jsonb) IS 'converts an animal json record, mapping codes to their integer form';


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
    fix_interval_rate double precision,
    frequency double precision,
    frequency_unit integer,
    malfunction_date date,
    activation_comment character varying(200),
    first_activation_month integer,
    first_activation_year integer,
    retrieval_date date,
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
    offline_date date,
    offline_type integer
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
	  'fix_interval_rate', cr.fix_interval_rate,
	  'frequency', cr.frequency,
	  'frequency_unit', bctw.get_code_id_with_error('frequency_unit', cr.frequency_unit),
--	  'activation_comment', cr.activation_comment, todo:
	  'first_activation_month', cr.first_activation_month,
	  'first_activation_year', cr.first_activation_year,
	  'retrieval_date', cr.retrieval_date,
	  'retrieved', cr.retrieved,
	  'satellite_network', bctw.get_code_id_with_error('satellite_network', cr.satellite_network),
	  'device_comment', cr.device_comment,
	  'activation_status', cr.activation_status,
	  'valid_from', cr.valid_from,
	  'valid_to', cr.valid_to,
	  'offline_date', cr.offline_date,
	  'offline_type', cr.offline_type
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
-- Name: set_user_role(text, text); Type: FUNCTION; Schema: bctw; Owner: bctw
--

CREATE FUNCTION bctw.set_user_role(stridir text, roletype text) RETURNS text
    LANGUAGE plpgsql
    AS $$
declare
	roleid uuid;
	uid integer;
begin
	if not exists (select 1 from bctw.user u where u.idir = strIdir) 
	then raise exception 'couldnt find user with IDIR %', strIdir;
	end if;

	roleid := (select urt.role_id from bctw.user_role_type urt where urt.role_type = roletype);
	uid := (select u.id from bctw.user u where u.idir = stridir);
	
	insert into bctw.user_role_xref(user_id, role_id)
	values (uid, roleid)
	on conflict on constraint user_role_xref_pkey
	do update set role_id = roleid;

return roleid;
end;
$$;


ALTER FUNCTION bctw.set_user_role(stridir text, roletype text) OWNER TO bctw;

--
-- Name: FUNCTION set_user_role(stridir text, roletype text); Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON FUNCTION bctw.set_user_role(stridir text, roletype text) IS 'sets a user role. note that a user can have more than role type. ex. can be an administrator and owner at the same time.';


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
-- Name: trg_process_ats_insert(); Type: FUNCTION; Schema: bctw; Owner: bctw
--

CREATE FUNCTION bctw.trg_process_ats_insert() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
	declare 
	 new_record record;
	 existing_record record;
	 alert_t telemetry_alert_type;
    begin
	    
	    --DISABLED
	    return null;
	   
	    -- the ats_collar_data record
	    select n.*
	    from new_table n
		order by "date" desc
		limit 1
		into new_record;
	
		alert_t := (
		  case 
		    when new_record.lowbatt then 'battery'
		    when new_record.mortality then 'mortality'
		  end
		);
	
		if alert_t is null then
			return null;
--			raise exception 'cant determine alert_type: mort: % batt: %',  new_record.mortality, new_record.lowbatt;
		end if;
	    
		-- check the existing record to see if either flag does not match the new record
		select c.*
		from bctw.collar c
		where c.device_id = new_record.collarserialnumber
		and c.device_make = 'ATS'
		and bctw.is_valid(c.valid_to)
		and (
			c.sensor_mortality::bool <> new_record.mortality::bool
			or c.sensor_battery::bool <> new_record.lowbatt::bool
		)
		into existing_record;
	
		if existing_record is null
		then return null;
		end if;
	
--		if existing_record is null then
--		raise exception 'null existing record mort: % batt: %',  new_record.mortality, new_record.lowbatt;
--		end if;
	
		insert into bctw.telemetry_sensor_alert
		(
			collar_id, device_id, device_make, alert_type, valid_from
		)
		values (
			existing_record.collar_id, existing_record.device_id, 'ATS', alert_t, new_record."date"
		);
		
		-- todo update collar_status???
		perform bctw.update_collar('jcraven', jsonb_build_array(
			JSONB_BUILD_OBJECT(
				'collar_id', existing_record.collar_id,
				'sensor_mortality', new_record.mortality,
				'sensor_battery', new_record.lowbatt)
			)
		);
	   
        RETURN NULL; 
        -- result is ignored since this is an AFTER trigger
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
	-- Lotek alerts are a separate API, they are inserted directly to the telemetry_sensor_alert table.
	declare 
	new_record record;
	collarid uuid;
	critterid uuid;
    begin
	    -- assign the record inserted to the alert table
	    select n.*
	    from new_table n
	    where n.device_make = 'Lotek'
		into new_record;
	
		if new_record is null then return null;	end if;
	    
		collarid := (
			select c.collar_id from bctw.collar c
			where c.device_id = new_record.device_id
			and (select code_description from code where code_id = c.device_make) = 'Lotek'
			and bctw.is_valid(c.valid_to)
		);
	
		if collarid is null then return null; end if;
		
		-- update the collar record's device status to Mortality
		perform bctw.update_collar('Admin', jsonb_build_array(
			JSONB_BUILD_OBJECT(
				'collar_id', collarid,
				'device_status', 'Mortality'
			))
		);
		
		critterid := (
			select animal_id from collar_animal_assignment caa
			where is_valid(caa.valid_to) 
			and caa.collar_id = collarid
		);
	
		if critterid is null then 
		  raise exception 'cannot find matching critter for collar %', collarid;
		  return null; 
		end if;
		
		-- update the animal record's status to Potential Mortality
		perform bctw.update_animal('Admin', jsonb_build_array(
			JSONB_BUILD_OBJECT(
				'critter_id', critterid,
				'animal_status', 'Potential Mortality'
			))
		);
	   
        RETURN NULL; 
        -- result is ignored since this is an AFTER trigger
    END;
$$;


ALTER FUNCTION bctw.trg_process_lotek_insert() OWNER TO bctw;

--
-- Name: FUNCTION trg_process_lotek_insert(); Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON FUNCTION bctw.trg_process_lotek_insert() IS 'triggered on the insert of a Lotek user alert to the telemetry_sensor_alert alert table, this function updates collar and critter metadata if the alert is determined to be valid.';


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
-- Name: update_animal(text, jsonb); Type: FUNCTION; Schema: bctw; Owner: bctw
--

CREATE FUNCTION bctw.update_animal(stridir text, animaljson jsonb) RETURNS SETOF json
    LANGUAGE plpgsql
    AS $$
DECLARE
  userid integer := bctw.get_user_id(stridir);
  j json;
  ar record;
  existing_critters bctw_dapi_v1.animal_historic_v[];
  critterid uuid;
  ids uuid[];
  i integer := 0;
  current_ts timestamp without time zone;
BEGIN
  IF userid IS NULL THEN
    RAISE exception 'user with idir % does not exist', stridir;
  END IF;
 
  FOR j IN SELECT jsonb_array_elements(animaljson)
    LOOP
      i := i + 1;
      BEGIN
	   ar := jsonb_populate_record(NULL::bctw_dapi_v1.animal_historic_v, j::jsonb);
	   critterid := (select critter_id from animal where critter_id = ar.critter_id);
	   -- consider this an update if the animal_id AND wlh_id match
	   if critterid is null then
	   	 raise exception 'critter with ID % not found', critterid;
	   end if;
	  existing_critters := array_append(existing_critters, ar);
	 end;
  END LOOP;
   
  current_ts = now();
 
	 foreach ar in array existing_critters loop
	 	ids := array_append(ids, ar.critter_id);	 
	 	-- expire the existing critter record
	    with existing as (
	    	UPDATE bctw.animal
	    	SET valid_to = current_ts, updated_at = current_ts, updated_by_user_id = userid
	    	where bctw.is_valid(valid_to)
	    	and animal_id = ar.animal_id
	    	and wlh_id = ar.wlh_id
	    	returning *
	    )
		INSERT INTO bctw.animal
		SELECT 
			ar.critter_id,
			crypto.gen_random_uuid(), -- a new transaction_id
			coalesce(ar.animal_id, (SELECT animal_id FROM existing)),
			coalesce(bctw.get_code_id('animal_status', ar.animal_status), (SELECT animal_status FROM existing)),
			coalesce(ar.associated_animal_id, (SELECT associated_animal_id FROM existing)),
			coalesce(ar.associated_animal_relationship, (SELECT associated_animal_relationship FROM existing)),
			coalesce(ar.capture_comment, (SELECT capture_comment FROM existing)),
		    coalesce(ar.capture_date, (SELECT capture_date FROM existing)),
		    coalesce(ar.capture_latitude, (SELECT capture_latitude FROM existing)),
	        coalesce(ar.capture_longitude,  (SELECT capture_longitude FROM existing)),
		    coalesce(ar.capture_utm_easting, (SELECT capture_utm_easting FROM existing)),
		    coalesce(ar.capture_utm_northing, (SELECT capture_utm_northing FROM existing)),
		    coalesce(ar.capture_utm_zone, ( SELECT capture_utm_zone FROM existing)),
		    coalesce(bctw.get_code_id('collective_unit', ar.collective_unit), (SELECT collective_unit FROM existing)),
		    coalesce(ar.animal_colouration, ( SELECT animal_colouration FROM existing)),
			coalesce(ar.ear_tag_left_id, (SELECT ear_tag_left_id FROM existing)),
			coalesce(ar.ear_tag_right_id, (SELECT ear_tag_right_id FROM existing)),
			coalesce(ar.ear_tag_left_colour, (SELECT ear_tag_left_colour FROM existing)),
			coalesce(ar.ear_tag_right_colour, (SELECT ear_tag_right_colour FROM existing)),
		    coalesce(ar.estimated_age, (SELECT estimated_age FROM existing)),
			coalesce(bctw.get_code_id('juvenile_at_heel', ar.juvenile_at_heel), (SELECT juvenile_at_heel FROM existing)),
			coalesce(ar.juvenile_at_heel_count, (SELECT juvenile_at_heel_count FROM existing)),
		    coalesce(bctw.get_code_id('life_stage', ar.life_stage), (SELECT life_stage FROM existing)),
		    (select map_colour from existing), --  never gets updated
		    coalesce(ar.mortality_comment, (SELECT mortality_comment FROM existing)),
		    coalesce(ar.mortality_date, (SELECT mortality_date FROM existing)),
	   	    coalesce(ar.mortality_latitude, (SELECT mortality_latitude FROM existing)),
		    coalesce(ar.mortality_longitude, (SELECT mortality_longitude FROM existing)),
		    coalesce(ar.mortality_utm_easting, (SELECT mortality_utm_easting FROM existing)),
		    coalesce(ar.mortality_utm_northing, (SELECT mortality_utm_northing FROM existing)),
		    coalesce(ar.mortality_utm_zone, (SELECT mortality_utm_zone FROM existing)),
			-- todo: PREDATOR Species
		    coalesce(bctw.get_code_id('proximate_cause_of_death', ar.proximate_cause_of_death), (SELECT proximate_cause_of_death FROM existing)),
		    coalesce(bctw.get_code_id('proximate_cause_of_death', ar.ultimate_cause_of_death), (SELECT ultimate_cause_of_death FROM existing)),
		    coalesce(bctw.get_code_id('population_unit', ar.population_unit), (SELECT population_unit FROM existing)),
		    coalesce(ar.recapture, (SELECT recapture FROM existing)),
		    coalesce(bctw.get_code_id('region', ar.region), (SELECT region FROM existing)),
		    coalesce(ar.release_comment, (SELECT release_comment FROM existing)),
		    coalesce(ar.release_date, (SELECT release_date FROM existing)),
		    coalesce(ar.release_latitude, (SELECT release_latitude FROM existing)),
		    coalesce(ar.release_longitude, (SELECT release_longitude FROM existing)),
		    coalesce(ar.release_utm_easting, (SELECT release_utm_easting FROM existing)),
		    coalesce(ar.release_utm_northing, (SELECT release_utm_northing FROM existing)),
		    coalesce(ar.release_utm_zone, (SELECT release_utm_zone FROM existing)),
		    coalesce(bctw.get_code_id('sex', ar.sex), (SELECT sex FROM existing)),
		    coalesce((select s.species_id from species s where s.scomname = ar.species), (SELECT species FROM existing)),
		    coalesce(ar.translocation, (SELECT translocation FROM existing)),
		    coalesce(ar.wlh_id, (SELECT wlh_id FROM existing)),
		    coalesce(ar.animal_comment, (SELECT animal_comment FROM existing)),
		    current_ts,
		    userid,
		    current_ts,
		    userid,
		    coalesce(ar.valid_from, current_ts),
		    coalesce(ar.valid_to, null);
	   end loop;
 
  RETURN query
  SELECT
    json_agg(t)
  FROM (
    SELECT * FROM bctw_dapi_v1.animal_v
    WHERE critter_id = ANY (ids)
  ) t;
END;

$$;


ALTER FUNCTION bctw.update_animal(stridir text, animaljson jsonb) OWNER TO bctw;

--
-- Name: FUNCTION update_animal(stridir text, animaljson jsonb); Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON FUNCTION bctw.update_animal(stridir text, animaljson jsonb) IS 'not currently exposed to API. used in triggers to update animal metadata
why is this needed??
todo: since not specifying columns in insert, order needs to match';


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
-- Name: update_collar(text, jsonb); Type: FUNCTION; Schema: bctw; Owner: bctw
--

CREATE FUNCTION bctw.update_collar(stridir text, collarjson jsonb) RETURNS SETOF json
    LANGUAGE plpgsql
    AS $$
DECLARE
  userid integer;
  j json;
  cr record;
  existing_collars bctw_dapi_v1.collar_historic_v[];
  crid uuid;
  i integer := 0;
  current_ts timestamp without time zone;
BEGIN
  userid = bctw.get_user_id (stridir);
  IF userid IS NULL THEN
    RAISE exception 'user with idir % does not exist', stridir;
  END IF;
 
  -- iterate the json rows, creating collar records for each one and inserting any errors to the temp table
  FOR j IN SELECT jsonb_array_elements(collarjson)
    LOOP
      i := i + 1;
      BEGIN
	    cr := jsonb_populate_record(NULL::bctw_dapi_v1.collar_historic_v, j::jsonb);
	   	crid := (select collar_id from collar where collar_id = cr.collar_id);
        IF crid IS NULL then
          raise exception 'device with collar ID % does not exist', cr.collar_id;
        END IF;
		existing_collars := array_append(existing_collars, cr);
        END;
    END LOOP;
   
  current_ts = now();
    foreach cr in array existing_collars loop
	  -- expire the current collar record
	  with existing as (
		  UPDATE bctw.collar
		  SET valid_to = current_ts, updated_at = current_ts, updated_by_user_id = userid
		  where bctw.is_valid(valid_to) 
		  and collar_id = cr.collar_id
	      returning *
	  )
	  INSERT INTO bctw.collar SELECT 
		cr.collar_id,
		crypto.gen_random_uuid(), -- a new transaction_id
		coalesce(cr.camera_device_id, (SELECT camera_device_id FROM existing)),
		coalesce(cr.device_id, (SELECT device_id FROM existing)),
		coalesce(bctw.get_code_id('device_deployment_status', cr.device_deployment_status), (SELECT device_deployment_status FROM existing)),
		coalesce(bctw.get_code_id('device_make', cr.device_make), (SELECT device_make FROM existing)),
		coalesce(bctw.get_code_id('device_malfunction_type', cr.device_malfunction_type), (SELECT device_malfunction_type FROM existing)),
		coalesce(cr.device_model, (SELECT device_model FROM existing)),
		coalesce(bctw.get_code_id('device_status', cr.device_status), (SELECT device_status FROM existing)),
		coalesce(bctw.get_code_id('device_type', cr.device_type), (SELECT device_type FROM existing)),
		coalesce(cr.dropoff_device_id, (SELECT dropoff_device_id FROM existing)),
		coalesce(cr.dropoff_frequency, (SELECT dropoff_frequency FROM existing)),
		coalesce(bctw.get_code_id('frequency_unit', cr.dropoff_frequency_unit), (SELECT dropoff_frequency_unit FROM existing)),
		coalesce(cr.fix_rate, (SELECT fix_rate FROM existing)),
		coalesce(cr.fix_success_rate, (SELECT fix_success_rate FROM existing)),
		coalesce(cr.frequency, (SELECT frequency FROM existing)),
		coalesce(bctw.get_code_id('frequency_unit', cr.frequency_unit), (SELECT frequency_unit FROM existing)),
		coalesce(cr.malfunction_date, (SELECT malfunction_date FROM existing)),
		coalesce(cr.purchase_comment, (SELECT purchase_comment FROM existing)),
		coalesce(cr.purchase_month, (SELECT purchase_month FROM existing)),
		coalesce(cr.purchase_date, (SELECT purchase_date FROM existing)),
		coalesce(cr.purchase_year, (SELECT purchase_year FROM existing)),
		coalesce(cr.retrieval_date, (SELECT retrieval_date FROM existing)),
		coalesce(cr.retrieved, (SELECT retrieved FROM existing)),
		coalesce(bctw.get_code_id('satellite_network', cr.satellite_network), (SELECT satellite_network FROM existing)),
		coalesce(cr.device_comment, (SELECT device_comment FROM existing)),
		coalesce(cr.vendor_activation_status, (SELECT vendor_activation_status FROM existing)),
	    current_ts,
		userid,
		current_ts,
		userid,
		coalesce(cr.valid_from, current_ts),
		coalesce(cr.valid_to, null);
	  end loop;

	return query select json_agg(t) from (
		select * from bctw.collar
    	where collar_id in (select collar_id from unnest(existing_collars))
    	and valid_to is null
    ) t;
END;

$$;


ALTER FUNCTION bctw.update_collar(stridir text, collarjson jsonb) OWNER TO bctw;

--
-- Name: FUNCTION update_collar(stridir text, collarjson jsonb); Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON FUNCTION bctw.update_collar(stridir text, collarjson jsonb) IS 'not currently exposed to API. used in triggers to update collar metadata when events are received from vendors. ex. mortality';


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
	   alertid := (select alert_id from telemetry_sensor_alert where alert_id = ar.alert_id);
	   if alertid is null then
	   	 raise exception 'telemetry alert with ID % not found', alertid;
	   end if;
	  alert_records := array_append(alert_records, ar);
	 end;
  END LOOP;
   
  current_ts = now();
 
  foreach ar in array alert_records 
    loop
	  update bctw.telemetry_sensor_alert
	  set valid_to = ar.valid_to, snoozed_to = ar.snoozed_to, snooze_count = ar.snooze_count
	  where alert_id = ar.alert_id;
    end loop;
 
  RETURN query
  SELECT json_agg(t)
  FROM (
    SELECT * FROM telemetry_sensor_alert
    WHERE alert_id = ANY ((select alert_id from unnest(alert_records)))
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
  j json; 					 -- current element of the animaljson loop
  ar record; 				 -- the animal json converted to an animal table row
  er record;				 -- the existing animal row
  existing_critters animal[];-- animal records to be updated
  new_critters animal[]; 	 -- animal records to be added
  ids uuid[]; 				 -- aggregated critter_ids of the animals to be added/updated
  i integer := 0; 			 -- current index of the animaljson loop
  current_ts timestamp WITHOUT time ZONE;
  cur_permission user_permission;

BEGIN
  IF userid IS NULL THEN
    RAISE EXCEPTION 'user with idir % does not exist', stridir;
  END IF;
 
  CREATE TEMPORARY TABLE IF NOT EXISTS errors (
    rownum integer,
    error text,
    ROW json
  );
  -- since most bulk insertion errors will be converting the json to an critter record,
  -- use an exception handler inside the loop that can continue if one is caught
  FOR j IN SELECT jsonb_array_elements(animaljson) LOOP
      i := i + 1;
      BEGIN
	   		ar := json_to_animal(j::jsonb);
	   		
	   		-- consider this an update if the animal_id AND wlh_id match
	   		IF EXISTS (SELECT 1 FROM bctw.animal WHERE animal_id = ar.animal_id AND wlh_id = ar.wlh_id OR critter_id = ar.critter_id) THEN
	   		  existing_critters := array_append(existing_critters, ar);
	   		
	   		-- if the user supplied a critter_id but a corresponding record is missing from the animal table
	  	  ELSE IF j->>'critter_id' IS NOT NULL THEN 
	     		RAISE EXCEPTION 'critter_id was supplied for an animal that does not exist';
	   		ELSE new_critters := array_append(new_critters, ar);
	   	  END IF;
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
 
  current_ts = now();
 
-- create new animals 
WITH ins AS (
	INSERT INTO bctw.animal SELECT
    crypto.gen_random_uuid(), -- critter_id
    critter_transaction_id,
    animal_id,
    animal_status,
    associated_animal_id,
    associated_animal_relationship,
    capture_comment, capture_date, capture_latitude, capture_longitude, capture_utm_easting, capture_utm_northing, capture_utm_zone,
	collective_unit,
	animal_colouration,
	ear_tag_left_colour, ear_tag_right_colour,
    estimated_age,
    juvenile_at_heel,
    life_stage,
    bctw_dapi_v1.get_random_colour_code_id(), -- generate a map colour
    mortality_comment, mortality_date, mortality_latitude, mortality_longitude, mortality_utm_easting, mortality_utm_northing, mortality_utm_zone,
    proximate_cause_of_death, ultimate_cause_of_death,
    population_unit,
    recapture,
    region,
    release_comment, release_date, release_latitude, release_longitude, release_utm_easting, release_utm_northing, release_utm_zone,
	sex,
	species,
    translocation,
    wlh_id, animal_comment,
    current_ts, userid, current_ts, userid,
    COALESCE(valid_from, current_ts),
    COALESCE(valid_to, NULL),
    predator_species,
    userid, -- owned_by_user_id: todo: can this be updated?
    ear_tag_left_id, ear_tag_right_id,
    juvenile_at_heel_count
  FROM UNNEST(new_critters)
  RETURNING critter_id
)
SELECT array_agg(critter_id) INTO ids FROM ins;

-- grant 'manager' permission for the new critter to this user
INSERT INTO bctw.user_animal_assignment (user_id, critter_id, created_by_user_id, permission_type)
SELECT userid, unnest(ids), userid, 'manager'::user_permission;
 
 -- handle updates to animals
 IF array_length(existing_critters, 1) > 0 THEN
	 FOREACH ar IN ARRAY existing_critters LOOP

	 	-- todo: cases where more than one valid?
	 	SELECT * FROM animal
	 	INTO er
	 	WHERE bctw.is_valid(valid_to) AND critter_id = ar.critter_id
	 	OR bctw.is_valid(valid_to) AND animal_id = ar.animal_id AND wlh_id = ar.wlh_id
	  LIMIT 1;
	 
	  -- user must have manager, editor, or change permission in order to edit this animal
	  cur_permission := bctw.get_user_animal_permission(userid, er.critter_id);
	  IF cur_permission IS NULL OR cur_permission = ANY('{"observer", "none"}'::user_permission[]) THEN
		  RAISE EXCEPTION 'you do not have required permission to edit this animal - your permission is: "%"', cur_permission::TEXT;
		END IF;
	
		-- todo: if the animal has a data life set and it's been updated, throw?

	 	ids := array_append(ids, er.critter_id);
	 
	  -- expire the existing critter record
	  -- todo: importing "historical" records
	  IF ar.valid_to IS NULL THEN
	    UPDATE bctw.animal
	    SET valid_to = current_ts, updated_at = current_ts, updated_by_user_id = userid
	    WHERE critter_id = er.critter_id;
	  END IF;
	 
	  -- insert the new record
		INSERT INTO bctw.animal
		SELECT 
			er.critter_id,
			ar.critter_transaction_id,
			coalesce(ar.animal_id, er.animal_id),
			coalesce(ar.animal_status, er.animal_status),
			coalesce(ar.associated_animal_id, er.associated_animal_id),
			coalesce(ar.associated_animal_relationship, er.associated_animal_relationship),
			coalesce(ar.capture_comment, er.capture_comment),
		  	coalesce(ar.capture_date, er.capture_date),
		  	coalesce(ar.capture_latitude, er.capture_latitude),
		  	coalesce(ar.capture_longitude,  er.capture_longitude),
		  	coalesce(ar.capture_utm_easting, er.capture_utm_easting),
		  	coalesce(ar.capture_utm_northing, er.capture_utm_northing),
		  	coalesce(ar.capture_utm_zone, er.capture_utm_zone),
		  	coalesce(ar.collective_unit, er.collective_unit),
		  	coalesce(ar.animal_colouration, er.animal_colouration),
			coalesce(ar.ear_tag_left_colour, er.ear_tag_left_colour),
			coalesce(ar.ear_tag_right_colour, er.ear_tag_right_colour),
		  	coalesce(ar.estimated_age, er.estimated_age),
			coalesce(ar.juvenile_at_heel, er.juvenile_at_heel),
		  	coalesce(ar.life_stage, er.life_stage),
		  	er.map_colour,
		  	coalesce(ar.mortality_comment, er.mortality_comment),
		  	coalesce(ar.mortality_date, er.mortality_date),
	   		coalesce(ar.mortality_latitude, er.mortality_latitude),
		  	coalesce(ar.mortality_longitude, er.mortality_longitude),
		  	coalesce(ar.mortality_utm_easting, er.mortality_utm_easting),
		  	coalesce(ar.mortality_utm_northing, er.mortality_utm_northing),
		  	coalesce(ar.mortality_utm_zone, er.mortality_utm_zone),
		  	coalesce(ar.proximate_cause_of_death, er.proximate_cause_of_death),
		  	coalesce(ar.ultimate_cause_of_death, er.ultimate_cause_of_death),
		  	coalesce(ar.population_unit, er.population_unit),
		  	coalesce(ar.recapture, er.recapture),
		  	coalesce(ar.region, er.region),
		  	coalesce(ar.release_comment, er.release_comment),
		  	coalesce(ar.release_date, er.release_date),
		  	coalesce(ar.release_latitude, er.release_latitude),
		  	coalesce(ar.release_longitude, er.release_longitude),
		  	coalesce(ar.release_utm_easting, er.release_utm_easting),
		  	coalesce(ar.release_utm_northing, er.release_utm_northing),
		  	coalesce(ar.release_utm_zone, er.release_utm_zone),
		  	coalesce(ar.sex, er.sex),
		  	coalesce(ar.species, er.species),
		  	coalesce(ar.translocation, er.translocation),
		  	coalesce(ar.wlh_id, er.wlh_id),
		  	coalesce(ar.animal_comment, er.animal_comment),
		  	er.created_at,
		 	userid, 		-- created_by
		  	current_ts, -- updated_at
		  	userid, 		-- updated_by
		    -- if valid_from & valid_to were in the json record, this record could be historic/not active
		    coalesce(ar.valid_from, current_ts), 
		    coalesce(ar.valid_to, NULL),
		    coalesce(ar.predator_species, er.predator_species),
		    coalesce(ar.owned_by_user_id, er.owned_by_user_id),
   		    coalesce(ar.ear_tag_left_id, er.ear_tag_left_id),
   		    coalesce(ar.ear_tag_right_id, er.ear_tag_right_id),
   		    coalesce(ar.juvenile_at_heel_count, er.juvenile_at_heel_count);
		 
	   END LOOP;
	END IF;
 
  RETURN query
  SELECT json_strip_nulls(
    (SELECT json_agg(t)
  	FROM (
    	SELECT * FROM bctw.animal_v
    	WHERE critter_id = ANY (ids)
    	AND valid_to IS NULL
  ) t));
END;

$$;


ALTER FUNCTION bctw.upsert_animal(stridir text, animaljson jsonb) OWNER TO bctw;

--
-- Name: FUNCTION upsert_animal(stridir text, animaljson jsonb); Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON FUNCTION bctw.upsert_animal(stridir text, animaljson jsonb) IS 'adds or updates one or more animal records.
todo: check importing historical (expired) records works
todo: can owned_by_user_id be modified?
todo: change ids to transaction_ids for historical records';


--
-- Name: upsert_collar(text, jsonb); Type: FUNCTION; Schema: bctw; Owner: bctw
--

CREATE FUNCTION bctw.upsert_collar(stridir text, collarjson jsonb) RETURNS SETOF json
    LANGUAGE plpgsql
    AS $$
DECLARE
  userid integer := bctw.get_user_id(stridir);
  j json;                     -- current element of the collarjson loop
  cr record; 									-- the collar json converted to a collar table ROW
  er record;				  				-- the existing animal row
  existing_collars collar[];  -- collar records TO be updated
  new_collars collar[];       -- NEW collar records
  i integer := 0;							-- current index of the collarjson loop
  ids uuid[];			            -- list of the updated/added collar_ids 
  current_ts timestamp without time zone;
  cur_permission bctw.user_permission;
 
BEGIN
  IF userid IS NULL THEN
    RAISE exception 'user with idir % does not exist', stridir;
  END IF;
 
  CREATE TEMPORARY TABLE if not exists errors (
    rownum integer,
    error text,
    row json
  );
  -- iterate the json rows, creating collar records for each one and inserting any errors to the temp table
  FOR j IN SELECT jsonb_array_elements(collarjson) 
    LOOP
      i := i + 1;
      BEGIN
        -- convert the json record to a collar row
	      cr := json_to_collar(j::jsonb);
	   
        -- the record must have the device ID
        IF cr.device_id IS NULL THEN
          INSERT INTO errors
            VALUES (i, 'Device ID must be supplied', j);
        END IF;
       
        -- Vectronic devices must have a corresponding row in the api_vectronics_collar_data table
        -- in order to retrieve telemetry. Throw an exception asking the user to upload the keyx file first
				IF cr.device_make = get_code_id('device_make', 'Vectronic') THEN
				  IF NOT EXISTS (select 1 from bctw.api_vectronics_collar_data where idcollar = cr.device_id)
				    THEN INSERT INTO errors VALUES (i, format('A KEYX file does not exist for Vectronic device %s, please upload it before adding device metadata', cr.device_id), j);
				  END IF;
				END IF;
		        
		    -- add the record to the appropriate array 
				IF EXISTS (SELECT 1 FROM bctw.collar where device_id = cr.device_id) 
				  THEN existing_collars := array_append(existing_collars, cr);
				  ELSE new_collars := array_append(new_collars, cr);
				END IF;
		
        EXCEPTION
        WHEN sqlstate '22007' THEN
          INSERT INTO errors
            VALUES (i, 'invalid date format, date must be in the format YYYY-MM-DD', j);
        WHEN OTHERS THEN
          INSERT INTO errors
            VALUES (i, sqlerrm, j);
        END;
    END LOOP;
  -- exit function early if there were errors casting the collar records from the JSON
  IF EXISTS (
    SELECT 1 FROM errors) THEN
    RETURN query SELECT JSON_AGG(src) FROM (SELECT * FROM errors) src;
  	RETURN;
	END IF;
  DROP TABLE errors;

  current_ts = now();
 	-- save the new collars
	WITH ins AS (
	INSERT INTO bctw.collar
      SELECT
        crypto.gen_random_uuid(), -- collar_id
        collar_transaction_id,
        camera_device_id,
        device_id,
        device_deployment_status,
        device_make,
        device_malfunction_type,
        device_model,
        device_status,
        device_type,
        dropoff_device_id,
        dropoff_frequency,
        dropoff_frequency_unit,
        fix_interval,
        fix_interval_rate,
        frequency,
        frequency_unit,
        activation_comment,
        first_activation_month,
        first_activation_year,
        retrieval_date,
        retrieved,
        satellite_network,
        device_comment,
        activation_status,
        current_ts,
        userid,
        current_ts,
        userid,
        current_ts,
        NULL, -- todo historical thing
        userid, -- owned_by_user_id
        offline_date,
        offline_type
      FROM unnest(new_collars)
     returning collar_id
     )
    SELECT array_agg(collar_id) INTO ids FROM ins;
       
  -- update existing collar records 
  IF array_length(existing_collars, 1) > 0 THEN
  
    FOREACH cr IN ARRAY existing_collars LOOP
    
		  SELECT * FROM collar
		 	INTO er
		 	WHERE bctw.is_valid(valid_to)
		 	AND device_id = cr.device_id
		  LIMIT 1;
		 
		  -- user must have manager, editor, or change permission
	  	cur_permission := bctw.get_user_collar_permission(userid, er.collar_id);
	  	IF cur_permission IS NULL OR cur_permission = ANY('{"observer", "none"}'::user_permission[]) THEN
		  	RAISE EXCEPTION 'you do not have required permission to edit this device - your permission is: "%"', cur_permission::TEXT;
			END IF;
	 
	  	ids := array_append(ids, er.collar_id);
  
	    -- expire the current collar record if the new record isn't historical
	  	IF cr.valid_to IS NULL THEN
			  UPDATE bctw.collar
				  SET valid_to = current_ts, updated_at = current_ts, updated_by_user_id = userid
				  WHERE bctw.is_valid(valid_to) 
				  AND device_id = er.device_id;
			END IF;
		 
		  INSERT INTO bctw.collar SELECT 
				er.collar_id,
				cr.collar_transaction_id,
				coalesce(cr.camera_device_id, er.camera_device_id),
			  coalesce(cr.device_id, er.device_id),
			  coalesce(cr.device_deployment_status, er.device_deployment_status),
			  coalesce(cr.device_make, er.device_make),
			  coalesce(cr.device_malfunction_type, er.device_malfunction_type),
			  coalesce(cr.device_model, er.device_model),
			  coalesce(cr.device_status, er.device_status),
			  coalesce(cr.device_type, er.device_type),
			  coalesce(cr.dropoff_device_id, er.dropoff_device_id),
			  coalesce(cr.dropoff_frequency, er.dropoff_frequency),
			  coalesce(cr.dropoff_frequency_unit, er.dropoff_frequency_unit),
			  coalesce(cr.fix_interval, er.fix_interval),
			  coalesce(cr.fix_interval_rate, er.fix_interval_rate),
			  coalesce(cr.frequency, er.frequency),
			  coalesce(cr.frequency_unit, er.frequency_unit),
			  coalesce(cr.malfunction_date, er.malfunction_date),
			  coalesce(cr.activation_comment, er.activation_comment),
			  coalesce(cr.first_activation_month, er.first_activation_month),
			  coalesce(cr.first_activation_year, er.first_activation_year),
			  coalesce(cr.retrieval_date, er.retrieval_date),
			  coalesce(cr.retrieved, er.retrieved),
			  coalesce(cr.satellite_network, er.satellite_network),
			  coalesce(cr.device_comment, er.device_comment),
			  coalesce(cr.activation_status, er.activation_status),
			  er.created_at, -- created_at
			  userid, -- created by
			  current_ts, -- updated at
			  userid, -- updated AT by
			  coalesce(cr.valid_from, current_ts),
			  coalesce(cr.valid_to, NULL),
			  coalesce(cr.valid_to, er.owned_by_user_id),
			  er.owned_by_user_id,
			  coalesce(cr.offline_date, er.offline_date),
			  coalesce(cr.offline_type, er.offline_type);
		  END LOOP;
	END IF;

	RETURN query SELECT json_agg(t) FROM (
	  SELECT * FROM bctw.collar_v
      WHERE collar_id = ANY (ids)
      AND valid_to IS NULL
    ) t;
END;

$$;


ALTER FUNCTION bctw.upsert_collar(stridir text, collarjson jsonb) OWNER TO bctw;

--
-- Name: FUNCTION upsert_collar(stridir text, collarjson jsonb); Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON FUNCTION bctw.upsert_collar(stridir text, collarjson jsonb) IS 'adds or updates one or more collar records';


--
-- Name: upsert_udf(text, jsonb); Type: FUNCTION; Schema: bctw; Owner: bctw
--

CREATE FUNCTION bctw.upsert_udf(stridir text, new_udf jsonb) RETURNS SETOF jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
  userid integer := bctw.get_user_id(stridir);
--  elem_index integer;
--  has_udf boolean;
  new_udf_array json;
  udf_type text := jsonb_typeof(new_udf);
begin
	IF userid IS NULL THEN
    RAISE exception 'user with idir % does not exist', stridir;
    END IF;
   
   	-- if the there are no udfs for this user, and the new_udf json is an object,
   	-- put it in an array
    if (udf_type = 'object') then
      new_udf_array := jsonb_build_array(new_udf);
    else if (udf_type = 'array') then
      new_udf_array := new_udf;
    else raise exception 'invalid json, must be object or array';
    end if;
    end if;
    
    if not exists(
      select 1 from user_defined_field
	  where user_id = userid
	  and bctw.is_valid(valid_to)
    )
    then 
   	insert into user_defined_field (user_id, udf) values (userid, new_udf_array);

    else
    update user_defined_field 
    set udf = new_udf_array
    where user_id = userid
    and bctw.is_valid(valid_to);
	
    end if;
   
   return query
   select udf from user_defined_field
   where user_id = userid
   and bctw.is_valid(valid_to);

    -- skip all this for now, and just set the udf field to the passed in json
-- try to find the index of the new_udf's key
--	elem_index := (
--		select pos- 1
--   		from user_defined_field, 
--    	jsonb_array_elements(udf) with ordinality arr(elem, pos)
--		where 
--			elem->>'key' = new_udf->>'key'
--		and user_id = userid
--		and bctw.is_valid(valid_to));
--	-- case when this is a new udf
--	if elem_index is null then
--		update user_defined_field
--    	set udf = jsonb_insert(
--   			udf,
--   			array[0::text], -- insert at the beginning of the array
--   			new_udf
--   		);
--   	else 
--	update user_defined_field
--	    set udf = jsonb_set(
--	   		udf,
--	   		array[elem_index::text],
--	   		new_udf
--	   );
--   end if;
 
END;
$$;


ALTER FUNCTION bctw.upsert_udf(stridir text, new_udf jsonb) OWNER TO bctw;

--
-- Name: FUNCTION upsert_udf(stridir text, new_udf jsonb); Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON FUNCTION bctw.upsert_udf(stridir text, new_udf jsonb) IS 'currently used to store user created animal group filters, this function replaces the provided parameter stridir with the new_udf json in the user_defined_field table. This will need updates to not overwrite existing json records if further udfs are to be implemented.';


--
-- Name: upsert_user(text, json, text); Type: FUNCTION; Schema: bctw; Owner: bctw
--

CREATE FUNCTION bctw.upsert_user(stridir text, userjson json, roletype text DEFAULT 'observer'::bctw.role_type) RETURNS SETOF json
    LANGUAGE plpgsql
    AS $$
DECLARE
  userid integer := bctw.get_user_id (stridir);
--  userrole bctw.role_type;
  current_ts timestamp without time ZONE := now();
  ur record;
  roleid uuid;
BEGIN
  IF userid IS NULL THEN
    RAISE EXCEPTION 'unable find user %', stridir;
  END IF;
 	-- must be an admin
--  userrole := bctw.get_user_role(stridir);
 
--  IF userrole IS NULL OR userrole != 'administrator' THEN
--    RAISE EXCEPTION 'you must be an administrator to perform this action';
--  END IF;
 
--  IF NOT EXISTS (
--    SELECT 1 FROM bctw.user_role_type WHERE role_type = roleType) THEN
--  	RAISE EXCEPTION '% is not a valid role type', roleType;
--  END IF;
 
  ur := json_populate_record(NULL::bctw.user, userjson);
  roleid := (SELECT role_id FROM bctw.user_role_type urt WHERE urt.role_type = roleType);
 
  RETURN query
  
  WITH ins AS (
	  INSERT INTO bctw.USER AS uu (id, idir, bceid, email, lastname, firstname, created_by_user_id)
	  VALUES (
	  	COALESCE(ur.id, nextval('user_id_seq1')),
	  	ur.idir,
	  	ur.bceid,
	  	ur.email,
	  	ur.lastname,
	  	ur.firstname,
	  	userid
	  )
	  ON CONFLICT (id)
	  DO UPDATE SET 
	    idir = COALESCE(excluded.idir, uu.idir),
	    bceid = COALESCE(excluded.bceid, uu.bceid),
	    email = COALESCE(excluded.email, uu.email),
	    lastname = COALESCE(excluded.lastname, uu.lastname),
	    firstname = COALESCE(excluded.firstname, uu.firstname),
	    updated_at = current_ts,
	    updated_by_user_id = userid
	  RETURNING *
  ),
  roleupdate AS (
    INSERT INTO user_role_xref (user_id, role_id)
    VALUES ((SELECT id FROM ins), roleid)
    ON CONFLICT ON CONSTRAINT user_role_xref_pkey
    DO UPDATE SET role_id = roleid
  )
  SELECT row_to_json(t) FROM (SELECT * FROM ins) t; 
END;
$$;


ALTER FUNCTION bctw.upsert_user(stridir text, userjson json, roletype text) OWNER TO bctw;

--
-- Name: FUNCTION upsert_user(stridir text, userjson json, roletype text); Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON FUNCTION bctw.upsert_user(stridir text, userjson json, roletype text) IS 'adds or updates a user. user performing the action must have a role type of administrator. returns the user row as JSON.';


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
	    WHERE s.predator_species IS TRUE
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
-- Name: get_user_critter_access_json(text, bctw.user_permission[]); Type: FUNCTION; Schema: bctw_dapi_v1; Owner: bctw
--

CREATE FUNCTION bctw_dapi_v1.get_user_critter_access_json(stridir text, permission_filter bctw.user_permission[] DEFAULT '{admin,observer,manager,editor}'::bctw.user_permission[]) RETURNS SETOF json
    LANGUAGE plpgsql
    AS $$
DECLARE
	userid integer := bctw.get_user_id(stridir);
BEGIN
	IF userid IS NULL
		THEN RAISE EXCEPTION 'unable to find user with idir %', stridir;
	END IF;

	RETURN query SELECT row_to_json(t) FROM (
	
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


ALTER FUNCTION bctw_dapi_v1.get_user_critter_access_json(stridir text, permission_filter bctw.user_permission[]) OWNER TO bctw;

--
-- Name: FUNCTION get_user_critter_access_json(stridir text, permission_filter bctw.user_permission[]); Type: COMMENT; Schema: bctw_dapi_v1; Owner: bctw
--

COMMENT ON FUNCTION bctw_dapi_v1.get_user_critter_access_json(stridir text, permission_filter bctw.user_permission[]) IS 'returns a list of critters a user has access to. Includes some device properties if the critter is attached to a collar. the filter parameter permission_filter defaults to all permissions except ''none''. so to include ''none'' you would pass ''{none,view, change, owner, subowner}''';


--
-- Name: get_user_device_access_json(text, bctw.user_permission[]); Type: FUNCTION; Schema: bctw_dapi_v1; Owner: bctw
--

CREATE FUNCTION bctw_dapi_v1.get_user_device_access_json(stridir text, permission_filter bctw.user_permission[] DEFAULT '{admin,observer,manager,editor}'::bctw.user_permission[]) RETURNS SETOF json
    LANGUAGE plpgsql
    AS $$
DECLARE
  user_id integer := bctw.get_user_id(stridir);
  collar_ids uuid[] := bctw.get_user_collar_access(stridir);
BEGIN
	RETURN query SELECT row_to_json(t) FROM (
		SELECT c.*,
		bctw.get_user_collar_permission(user_id, c.collar_id) AS "permission_type"
		FROM collar c
		WHERE c.collar_id = ANY(collar_ids)
	 ) t;
END;
$$;


ALTER FUNCTION bctw_dapi_v1.get_user_device_access_json(stridir text, permission_filter bctw.user_permission[]) OWNER TO bctw;

--
-- Name: FUNCTION get_user_device_access_json(stridir text, permission_filter bctw.user_permission[]); Type: COMMENT; Schema: bctw_dapi_v1; Owner: bctw
--

COMMENT ON FUNCTION bctw_dapi_v1.get_user_device_access_json(stridir text, permission_filter bctw.user_permission[]) IS 'similar to get_user_critter_access_json, but for devices';


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
  critter_access uuid[] := bctw.get_user_critter_access(stridir);
BEGIN
  RETURN query
  SELECT json_agg(t) FROM (
  SELECT * FROM bctw_dapi_v1.alert_v
  WHERE critter_id = ANY(critter_access)
  ) t;
END;
$$;


ALTER FUNCTION bctw_dapi_v1.get_user_telemetry_alerts(stridir text) OWNER TO bctw;

--
-- Name: FUNCTION get_user_telemetry_alerts(stridir text); Type: COMMENT; Schema: bctw_dapi_v1; Owner: bctw
--

COMMENT ON FUNCTION bctw_dapi_v1.get_user_telemetry_alerts(stridir text) IS 'retrives telemetry alerts for a provided user identifier';


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
    ( SELECT code.code_description
           FROM bctw.code
          WHERE (code.code_id = a.collective_unit)) AS collective_unit,
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
    bctw.get_species_name(a.predator_species) AS predator_species,
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
    a.valid_from,
    a.valid_to,
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
          WHERE (code.code_id = c.dropoff_frequency_unit)) AS dropoff_frequency_unit,
    c.fix_interval,
    c.fix_interval_rate,
    c.frequency,
    ( SELECT code.code_description
           FROM bctw.code
          WHERE (code.code_id = c.frequency_unit)) AS frequency_unit,
    c.malfunction_date,
    c.activation_status,
    c.first_activation_month,
    c.first_activation_year,
    c.retrieval_date,
    c.retrieved,
    ( SELECT code.code_description
           FROM bctw.code
          WHERE (code.code_id = c.satellite_network)) AS satellite_network,
    c.device_comment,
    c.offline_date,
    ( SELECT code.code_description
           FROM bctw.code
          WHERE (code.code_id = c.offline_type)) AS offline_type,
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
-- Name: onboarding; Type: TABLE; Schema: bctw; Owner: bctw
--

CREATE TABLE bctw.onboarding (
    onboarding_id integer NOT NULL,
    idir character varying(50),
    bceid character varying(50),
    email character varying(200),
    given_name character varying(200),
    family_name character varying(200),
    full_name character varying(600),
    request_date date,
    request_access character varying(14),
    access_status character varying(8),
    access_status_date date,
    CONSTRAINT enforce_access CHECK (((request_access)::text = ANY (ARRAY['administrator'::text, 'manager'::text, 'editor'::text, 'observer'::text]))),
    CONSTRAINT enforce_status CHECK (((access_status)::text = ANY (ARRAY['pending'::text, 'denied'::text, 'granted'::text])))
);


ALTER TABLE bctw.onboarding OWNER TO bctw;

--
-- Name: TABLE onboarding; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON TABLE bctw.onboarding IS 'Store all BC Telemetry Warehouse access requests and adjustments';


--
-- Name: COLUMN onboarding.idir; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.onboarding.idir IS 'IDIR user name';


--
-- Name: COLUMN onboarding.bceid; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.onboarding.bceid IS 'BCeID user name';


--
-- Name: COLUMN onboarding.email; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.onboarding.email IS 'Email address';


--
-- Name: COLUMN onboarding.given_name; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.onboarding.given_name IS 'User given/first name';


--
-- Name: COLUMN onboarding.family_name; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.onboarding.family_name IS 'User family/last name';


--
-- Name: COLUMN onboarding.full_name; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.onboarding.full_name IS 'User full name. This may include multiple middle names';


--
-- Name: COLUMN onboarding.request_date; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.onboarding.request_date IS 'Date the user initially requested access';


--
-- Name: COLUMN onboarding.request_access; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.onboarding.request_access IS 'The level of access the user has requested. The column is restricted to one of the following; administrator, manager, editor & observer';


--
-- Name: COLUMN onboarding.access_status; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.onboarding.access_status IS 'Status the user access request is in. The column is restricted to one of the following; pending, denied & granted';


--
-- Name: COLUMN onboarding.access_status_date; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.onboarding.access_status_date IS 'Date the status was set';


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
    was_granted boolean,
    was_denied_reason text
);


ALTER TABLE bctw.permission_request OWNER TO bctw;

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
-- Name: COLUMN permission_request.was_granted; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.permission_request.was_granted IS 'whether or not the request was granted/denied, should only be set on expired requests';


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
    timeid text,
    alert_type bctw.telemetry_alert_type,
    valid_from timestamp without time zone DEFAULT now(),
    valid_to timestamp without time zone,
    created_at timestamp without time zone DEFAULT now(),
    snoozed_to timestamp(0) without time zone,
    snooze_count smallint DEFAULT 0
);


ALTER TABLE bctw.telemetry_sensor_alert OWNER TO bctw;

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
    access character varying(8),
    phone character varying(20),
    CONSTRAINT enforce_access CHECK (((access)::text = ANY (ARRAY['pending'::text, 'denied'::text, 'granted'::text])))
);


ALTER TABLE bctw."user" OWNER TO bctw;

--
-- Name: TABLE "user"; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON TABLE bctw."user" IS 'BCTW user information table';


--
-- Name: COLUMN "user".access; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw."user".access IS 'Status of user onboarding. They have passed through keycloak then must request special access to the application. Limited to: pending, denied or granted';


--
-- Name: COLUMN "user".phone; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw."user".phone IS 'to be used for alerting the user in the event of mortality alerts';


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
    av.predator_species,
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
    av.owned_by_user_id
   FROM bctw.animal_v av
  WHERE bctw.is_valid(av.valid_to);


ALTER TABLE bctw_dapi_v1.animal_v OWNER TO bctw;

--
-- Name: collar_v; Type: VIEW; Schema: bctw_dapi_v1; Owner: bctw
--

CREATE VIEW bctw_dapi_v1.collar_v AS
 SELECT cv.collar_id,
    cv.collar_transaction_id,
    cv.camera_device_id,
    cv.device_id,
    cv.device_deployment_status,
    cv.device_make,
    cv.device_malfunction_type,
    cv.device_model,
    cv.device_status,
    cv.device_type,
    cv.dropoff_device_id,
    cv.dropoff_frequency,
    cv.dropoff_frequency_unit,
    cv.fix_interval,
    cv.fix_interval_rate,
    cv.frequency,
    cv.frequency_unit,
    cv.malfunction_date,
    cv.activation_status,
    cv.first_activation_month,
    cv.first_activation_year,
    cv.retrieval_date,
    cv.retrieved,
    cv.satellite_network,
    cv.device_comment,
    cv.offline_date,
    cv.offline_type,
    cv.created_by_user_id,
    cv.valid_from,
    cv.valid_to,
    cv.owned_by_user_id
   FROM bctw.collar_v cv
  WHERE bctw.is_valid(cv.valid_to);


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
    a.animal_status,
    ca.assignment_id,
    ca.attachment_start,
    ca.valid_from AS data_life_start,
    ca.valid_to AS data_life_end,
    ca.attachment_end
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
    animal_v.predator_species,
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
    animal_v.valid_from,
    animal_v.valid_to,
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
    collar_v.dropoff_frequency_unit,
    collar_v.fix_interval,
    collar_v.fix_interval_rate,
    collar_v.frequency,
    collar_v.frequency_unit,
    collar_v.malfunction_date,
    collar_v.activation_status,
    collar_v.first_activation_month,
    collar_v.first_activation_year,
    collar_v.retrieval_date,
    collar_v.retrieved,
    collar_v.satellite_network,
    collar_v.device_comment,
    collar_v.offline_date,
    collar_v.offline_type,
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
    c.device_id,
    caa.collar_id,
    a.animal_id,
    a.wlh_id,
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
          WHERE (NOT bctw.is_valid((now())::timestamp without time zone, (caa.valid_from)::timestamp without time zone, (caa.valid_to)::timestamp without time zone))
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
    av.predator_species,
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
    av.owned_by_user_id
   FROM bctw.animal_v av
  WHERE ((av.critter_id IN ( SELECT no_attachments.critter_id
           FROM no_attachments)) AND bctw.is_valid(av.valid_to));


ALTER TABLE bctw_dapi_v1.currently_unattached_critters_v OWNER TO bctw;

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
            pr.was_granted,
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
            es.was_granted,
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
    ep.was_granted,
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
-- Name: user_defined_fields_v; Type: VIEW; Schema: bctw_dapi_v1; Owner: bctw
--

CREATE VIEW bctw_dapi_v1.user_defined_fields_v AS
 SELECT u.udf_id,
    u.user_id,
    specs.type,
    specs.key,
    to_jsonb(specs.value) AS value
   FROM bctw.user_defined_field u,
    LATERAL jsonb_to_recordset(u.udf) specs(type text, key text, value uuid[])
  WHERE bctw.is_valid(u.valid_to);


ALTER TABLE bctw_dapi_v1.user_defined_fields_v OWNER TO bctw;

--
-- Name: user_v; Type: VIEW; Schema: bctw_dapi_v1; Owner: bctw
--

CREATE VIEW bctw_dapi_v1.user_v AS
 SELECT u.id,
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
    u.access,
    u.created_at,
    u.created_by_user_id,
    u.updated_at,
    u.updated_by_user_id,
    u.valid_from,
    u.valid_to
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
    collar.offline_type
   FROM bctw.collar
  WHERE ((collar.device_make = ( SELECT code.code_id
           FROM bctw.code
          WHERE ((code.code_description)::text = 'Vectronic'::text))) AND (NOT (collar.device_id IN ( SELECT api_vectronics_collar_data.idcollar
           FROM bctw.api_vectronics_collar_data))));


ALTER TABLE bctw_dapi_v1.vectronic_devices_without_keyx_entries OWNER TO bctw;

--
-- Name: VIEW vectronic_devices_without_keyx_entries; Type: COMMENT; Schema: bctw_dapi_v1; Owner: bctw
--

COMMENT ON VIEW bctw_dapi_v1.vectronic_devices_without_keyx_entries IS 'is this actually used anywhere?';


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
-- Name: telemetry_sensor_alert telemetry_sensor_alert_timeid_key; Type: CONSTRAINT; Schema: bctw; Owner: bctw
--

ALTER TABLE ONLY bctw.telemetry_sensor_alert
    ADD CONSTRAINT telemetry_sensor_alert_timeid_key UNIQUE (timeid);


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
-- Name: vectronics_collar_data vectronics_collar_data_idposition_key; Type: CONSTRAINT; Schema: bctw; Owner: bctw
--

ALTER TABLE ONLY bctw.vectronics_collar_data
    ADD CONSTRAINT vectronics_collar_data_idposition_key UNIQUE (idposition);


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
-- Name: onboarding_id_idx; Type: INDEX; Schema: bctw; Owner: bctw
--

CREATE INDEX onboarding_id_idx ON bctw.onboarding USING btree (onboarding_id);


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
-- Name: animal animal_insert_trg; Type: TRIGGER; Schema: bctw; Owner: bctw
--

CREATE TRIGGER animal_insert_trg AFTER INSERT ON bctw.animal REFERENCING NEW TABLE AS inserted FOR EACH ROW EXECUTE FUNCTION bctw.trg_update_animal_retroactively();


--
-- Name: ats_collar_data ats_insert_trg; Type: TRIGGER; Schema: bctw; Owner: bctw
--

CREATE TRIGGER ats_insert_trg AFTER INSERT ON bctw.ats_collar_data REFERENCING NEW TABLE AS new_table FOR EACH STATEMENT EXECUTE FUNCTION bctw.trg_process_ats_insert();


--
-- Name: telemetry_sensor_alert lotek_alert_trg; Type: TRIGGER; Schema: bctw; Owner: bctw
--

CREATE TRIGGER lotek_alert_trg AFTER INSERT ON bctw.telemetry_sensor_alert REFERENCING NEW TABLE AS new_table FOR EACH STATEMENT EXECUTE FUNCTION bctw.trg_process_lotek_insert();


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
-- Name: TABLE user_defined_fields_v; Type: ACL; Schema: bctw_dapi_v1; Owner: bctw
--

GRANT ALL ON TABLE bctw_dapi_v1.user_defined_fields_v TO bctw_api;


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

