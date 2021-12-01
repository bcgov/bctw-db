--
-- fix malfunction procedure to properly update device status to malfunction
CREATE OR REPLACE PROCEDURE bctw.proc_check_for_missing_telemetry()
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
				j := jsonb_build_array(
					JSONB_BUILD_OBJECT('collar_id', tr.collar_id, 'device_status', 'potential malfunction')
					);
				PERFORM upsert_collar('system', j);
--				RAISE EXCEPTION 'json %', j;

		END IF;
	END LOOP;
	END;
$$;


--
-- add api/cronjob lotek insert handler
CREATE FUNCTION bctw.vendor_insert_raw_lotek(rec jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
  lr record; -- the json record converted to a table row
  j jsonb;   -- the current json record of the rec param array
BEGIN
	FOR j IN SELECT jsonb_array_elements(rec) LOOP
		lr := jsonb_populate_record(NULL::lotek_collar_data, jsonb_strip_nulls(j));
	    INSERT INTO lotek_collar_data
		SELECT 
		  lr.channelstatus,
		  lr.uploadtimestamp,
		  lr.latitude,
		  lr.longitude,
		  lr.altitude,
		  lr.ecefx,
		  lr.ecefy,
		  lr.ecefz,
		  lr.rxstatus,
		  lr.pdop,
		  lr.mainv,
		  lr.bkupv,
		  lr.temperature,
		  lr.fixduration,
		  lr.bhastempvoltage,
		  lr.devname,
		  lr.deltatime,
		  lr.fixtype,
		  lr.cepradius,
		  lr.crc,
		  lr.deviceid,
		  lr.recdatetime,
		  concat(lr.deviceid, '_', lr.recdatetime),
		  st_setSrid(st_point(lr.longitude, lr.latitude), 4326)
		ON CONFLICT (timeid) DO NOTHING;
	END LOOP;
RETURN jsonb_build_object('device_id', lr.deviceid, 'records_found', jsonb_array_length(rec), 'vendor', 'Lotek');
END
$$;
ALTER FUNCTION bctw.vendor_insert_raw_lotek(rec jsonb) OWNER TO bctw;
COMMENT ON FUNCTION bctw.vendor_insert_raw_lotek(rec jsonb) IS 'inserts json rows of lotek_collar_data type. ignores  insert of duplicate timeid
returns a json object of the device_id and number of records inserted. 
todo: include actual records inserted';


--
-- add api/cronjob vectronic insert handler
CREATE FUNCTION bctw.vendor_insert_raw_vectronic(rec jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
  vr record; -- the json record converted to a table row
  j jsonb;   -- the current json record of the rec param array
BEGIN
	FOR j IN SELECT jsonb_array_elements(rec) LOOP
		vr := jsonb_populate_record(NULL::vectronics_collar_data, jsonb_strip_nulls(j));
		INSERT INTO vectronics_collar_data 
		SELECT 
			vr.idposition,
			vr.idcollar,
			vr.acquisitiontime,
			vr.scts,
			vr.origincode,
			vr.ecefx,
			vr.ecefy,
			vr.ecefz,
			vr.latitude,
			vr.longitude,
			vr.height,
			vr.dop,
			vr.idfixtype,
			vr.positionerror,
			vr.satcount,
			vr.ch01satid,
			vr.ch01satcnr,
			vr.ch02satid,
			vr.ch02satcnr,
			vr.ch03satid,
			vr.ch03satcnr,
			vr.ch04satid,
			vr.ch04satcnr,
			vr.ch05satid,
			vr.ch05satcnr,
			vr.ch06satid,
			vr.ch06satcnr,
			vr.ch07satid,
			vr.ch07satcnr,
			vr.ch08satid,
			vr.ch08satcnr,
			vr.ch09satid,
			vr.ch09satcnr,
			vr.ch10satid,
			vr.ch10satcnr,
			vr.ch11satid,
			vr.ch11satcnr,
			vr.ch12satid,
			vr.ch12satcnr,
			vr.idmortalitystatus,
			vr.activity,
			vr.mainvoltage,
			vr.backupvoltage,
			vr.temperature,
			vr.transformedx,
			vr.transformedy,
			st_setSrid(st_point(vr.longitude, vr.latitude), 4326)
		ON CONFLICT (idposition) DO NOTHING;
	END LOOP;
RETURN jsonb_build_object('device_id', vr.idcollar, 'records_found', jsonb_array_length(rec), 'vendor', 'Vectronic');
END
$$;
ALTER FUNCTION bctw.vendor_insert_raw_vectronic(rec jsonb) OWNER TO bctw;
COMMENT ON FUNCTION bctw.vendor_insert_raw_vectronic(rec jsonb) IS 'inserts json rows of vectronic_collar_data type. ignores  insert of duplicate idposition. 
returns a json object of the device_id and number of records inserted. 
todo: include actual records inserted';


--
-- update function to return species instead of animal_species
CREATE OR REPLACE FUNCTION bctw_dapi_v1.get_user_critter_access(stridir text, permission_filter bctw.user_permission[] DEFAULT '{admin,observer,manager,editor}'::bctw.user_permission[]) RETURNS TABLE(critter_id uuid, animal_id character varying, wlh_id character varying, species character varying, permission_type bctw.user_permission, device_id integer, device_make character varying, device_type character varying, frequency double precision)
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
COMMENT ON FUNCTION bctw_dapi_v1.get_user_critter_access(stridir text, permission_filter bctw.user_permission[]) IS 'returns a list of critters a user has access to. Includes some device properties if the critter is attached to a collar. the filter parameter permission_filter defaults to all permissions except "none". so to include "none" you would pass "{none,view, change, owner, subowner}"';

--
-- get_user_telemetry_alerts should only retrieve alerts if the user has editor/admin/manager permission to the animal (it was showing for observer)
CREATE OR REPLACE FUNCTION bctw_dapi_v1.get_user_telemetry_alerts(stridir text) RETURNS SETOF json
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
COMMENT ON FUNCTION bctw_dapi_v1.get_user_telemetry_alerts(stridir text) IS 'retrives telemetry alerts for a provided user identifier. The user must have admin, manager, or editor permission to the animal';

--
-- drop deprecated attachement handlers
drop FUNCTION bctw.unlink_collar_to_animal_bak(text, uuid, uuid, timestamp with time zone);
drop FUNCTION bctw.link_collar_to_animal_bak(text, uuid, uuid, timestamp without time zone, timestamp without time zone);