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

CREATE FUNCTION bctw_dapi_v1.get_user_critter_access(stridir text, permission_filter bctw.user_permission[] DEFAULT '{admin,observer,manager,editor}'::bctw.user_permission[]) RETURNS TABLE(critter_id uuid, animal_id character varying, wlh_id character varying, animal_species character varying, permission_type bctw.user_permission, device_id integer, device_make character varying, device_type character varying, frequency double precision)
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
  critter_access uuid[] := bctw.get_user_critter_access(stridir);
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


CREATE TRIGGER alert_notify_api_sms_trg AFTER INSERT ON bctw.telemetry_sensor_alert REFERENCING NEW TABLE AS new_table FOR EACH ROW EXECUTE FUNCTION bctw.trg_new_alert();
CREATE TRIGGER animal_insert_trg AFTER INSERT ON bctw.animal REFERENCING NEW TABLE AS inserted FOR EACH ROW EXECUTE FUNCTION bctw.trg_update_animal_retroactively();
CREATE TRIGGER ats_insert_trg AFTER INSERT ON bctw.ats_collar_data REFERENCING NEW TABLE AS new_table FOR EACH ROW WHEN (new.mortality) EXECUTE FUNCTION bctw.trg_process_ats_insert();
COMMENT ON TRIGGER ats_insert_trg ON bctw.ats_collar_data IS 'when new telemetry data is received from the API cronjob, run the trigger handler trg_process_ats_insert if the record has a mortality';
CREATE TRIGGER lotek_alert_trg AFTER INSERT ON bctw.telemetry_sensor_alert REFERENCING NEW TABLE AS new_table FOR EACH ROW WHEN ((new.device_make = 'Lotek'::text)) EXECUTE FUNCTION bctw.trg_process_lotek_insert();
CREATE TRIGGER user_onboarded_trg AFTER INSERT ON bctw."user" REFERENCING NEW TABLE AS new_table FOR EACH STATEMENT EXECUTE FUNCTION bctw.trg_process_new_user();
CREATE TRIGGER vectronic_alert_trg AFTER INSERT ON bctw.vectronics_collar_data REFERENCING NEW TABLE AS new_table FOR EACH ROW WHEN ((new.idmortalitystatus = 1)) EXECUTE FUNCTION bctw.trg_process_vectronic_insert();