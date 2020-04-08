-- Insert statements

INSERT INTO public.vendor_data_merge_with_long_lat
	SELECT "CollarSerialNumber", -- animal_id (no other choice for now)
			'ATS', --vendor
			"CollarSerialNumber", -- collar_id
			NULL, -- collar
			NULL, -- collar_noprefix
			NULL, -- wlh_id
			NULL, -- previous_wlh_id,
			NULL, -- species TEXT, -- Can assume Caribou at this point
			NULL, -- project TEXT, -- Project name
			NULL, -- status TEXT, -- Needs verification
			NULL, -- animal_status TEXT, -- Mortality status
			NULL, -- collar_status_details TEXT, -- Assuming this is 'fix' status
			NULL, -- deactivated BOOLEAN,
			NULL, -- region TEXT, -- E.g. Peace
			NULL, -- regional_contact TEXT, -- Biologist
			NULL, -- ecotype TEXT, -- E.g. Souther Mountain - central group
			NULL, -- population_unit TEXT, -- E.g. Moberly
			--herd -- deprecated
			NULL, -- reg_key BOOLEAN,
			NULL, -- spi_bapid INTEGER, -- No sample provided
			NULL, -- fix_rate TEXT, -- E.g. 2x/Day
			NULL, -- frequency DOUBLE PRECISION, -- E.g. 149.825
			NULL, -- collar_type TEXT, -- E.g. VHF
			NULL, -- collar_make TEXT, -- E.g. ATS
			NULL, -- model TEXT, -- E.g. Expandable VHF
			NULL, -- satellite_type TEXT, -- E.g. Iridium
			NULL, -- management_area TEXT, -- E.g. Boundary
			NULL, -- active BOOLEAN,
			NULL, -- historic BOOLEAN,
			NULL, -- deployment_date DATE,
			NULL, -- capture_date DATE, 
			NULL, -- release_date DATE,
			NULL, -- recapture BOOLEAN,
			NULL, -- translocation BOOLEAN,
			NULL, -- inactive_date DATE
			NULL, -- malfunction_date DATE,
			NULL, -- collar_retrival_date DATE,
			NULL, -- potential_deactivation BOOLEAN,
			NULL, -- min_telemetry_date DATE,
			NULL, -- max_telemetry DATE,
			NULL, -- spatial_min_telemetry_date DATE,
			NULL, -- spatial_max_telemetry_date DATE,
			50, -- capture_utm_zone INTEGER, -- E.g. 10
			0, -- capture_utm_easting INTEGER, -- E.g. 481893
			0, -- capture_utm_northing INTEGER, -- E.g. 6175130
			NULL, -- mortality_review TEXT
			NULL, -- potential_mortality BOOLEAN
			0, -- mortality_zone INTEGER -- hard code value to hide
			0, -- mortality_easting INTEGER -- hard code value to hide
			0, -- mortality_northing INTEGER -- hard code value to hide
			NULL, -- comments TEXT, -- E.g. Recapture
			NULL, -- changed_species BOOLEAN, 
			NULL, -- notes TEXT,
			NULL, -- internal_notes TEXT, -- E.g. 20190812: Added from ND tab Monthly Summary 20190515_w2019
			NULL, -- source TEXT, -- E.g. Monthly_Collar_Summary_20190514_jul31_toCaslys
			NULL, -- added_date DATE, 
			NULL, -- updated_date DATE,
			NULL, -- sex TEXT, -- M/F
			NULL, -- life_stage TEXT, -- E.g. NR
			NULL, -- calf_at_hell TEXT, -- E.g. NR
			NULL, -- ear_tag_left TEXT, -- E.g. 0-2387
			NULL, -- ear_tag_right TEXT, -- E.g. None
			NULL, -- field_id_collar TEXT, -- E.g. 18-13655R_99490-12
			NULL, -- flag_new BOOLEAN, -- Described as a flag, so assumed to be boolean
			-- shari_id not used
			NULL, -- regional_contact_notes TEXT,
			NULL, -- spatially_derived_inactive_date DATE,
			NULL, -- spatially_derived_deployment_date DATE,
			NULL, -- regional_review_by TEXT, -- E.g. Agnes Pelletier
			to_date('20'||"Year"||"Julianday"::int, 'YYYYDDD'), -- local_timestamp
			NULL, -- lmy_time
			NULL, -- utc_date
			NULL, -- utc_time
			NULL, -- gmt_timestamp
			"Longitude", -- longitude
			"Latitude", -- Latitude
			ST_MakePoint("Longitude","Latitude") , --geometry
			"Temperature", -- temperature 
			NULL, -- Main [V]
			NULL, --Back [V]
			NULL, -- beacon_v double precision,
			NULL, -- activity integer,
			NULL, -- dop double precision,
			"HDOP", -- hdop double precision,
			"FixTime", -- fixtime integer,
			NULL, -- fixtype text COLLATE pg_catalog."default",
			NULL, -- fixstatus text COLLATE pg_catalog."default",
			"2D/3D", -- two_d_three_d integer,
			NULL, -- device_name text COLLATE pg_catalog."default",
			NULL, -- scts_date date,
			NULL, -- scts_datetime time without time zone,
			NULL, -- ecef_x_m double precision,
			NULL, -- ecef_y_m double precision,
			NULL, -- ecef_z_m double precision,
			NULL, -- easting double precision,
			NULL, -- northing double precision,
			NULL, -- height double precision,
			NULL, -- altitude double precision,
			NULL, -- group_id integer,
			NULL, -- mortality_satus
			NULL, -- mort_date_gmt timestamp without time zone,
			NULL, -- mort_date_local timestamp without time zone,
			NULL, -- cancel_date_gmt timestamp without time zone,
			NULL, -- cancel_date_local timestamp without time zone,
			"NumSats", -- satellites_number integer,
			--satellite INTEGER, GPSPlusX only (no data)
			--satellites INTEGER, GPSPlusX only (no data)
			NULL, -- origin text
			NULL -- three_d_error INTEGER
FROM public.sample_ats;	