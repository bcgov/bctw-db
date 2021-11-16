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
COMMENT ON FUNCTION bctw.add_code_header(stridir text, headerjson jsonb) IS 'adds new code headers, will throw exception if the code header exists.';

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
    (SELECT species_eng_name FROM species WHERE species_code = a.species) AS species,
    (SELECT code_description FROM code WHERE code.code_id = a.population_unit) AS population_unit,
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

