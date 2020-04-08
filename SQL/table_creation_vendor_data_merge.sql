-- Table: public.vendor_data_merge

DROP TABLE public.vendor_data_merge;

CREATE TABLE public.vendor_data_merge_with_long_lat
(
animal_id TEXT NOT NULL, -- GPSPlusX only, for others we will initially use the collar_id. May contain text and numbers. Mandatory if telemetry info.
vendor TEXT NOT NULL,
collar_id INTEGER NOT NULL, --CID in TelemetryData-DataDictionary
collar TEXT, -- Typicall the device ID
collar_noprefix INTEGER, -- Collars with no prefix. Typically the device id. 
wlh_id TEXT, -- Provincial Wildlife Health ID
previous_wlh_id TEXT, -- Additional wlh_id to manage animals with previous Wildlife Health ID
species TEXT, -- Can assume Caribou at this point
project TEXT, -- Project name
status TEXT, -- Needs verification
animal_status TEXT, -- Mortality status
collar_status_details TEXT, -- Assuming this is 'fix' status
deactivated BOOLEAN,
region TEXT, -- E.g. Peace
regional_contact TEXT, -- Biologist
ecotype TEXT, -- E.g. Souther Mountain - central group
population_unit TEXT, -- E.g. Moberly
--herd -- deprecated
reg_key BOOLEAN,
spi_bapid INTEGER, -- No sample provided
fix_rate TEXT, -- E.g. 2x/Day
frequency DOUBLE PRECISION, -- E.g. 149.825
collar_type TEXT, -- E.g. VHF
collar_make TEXT, -- E.g. ATS
model TEXT, -- E.g. Expandable VHF
satellite_type TEXT, -- E.g. Iridium
management_area TEXT, -- E.g. Boundary
active BOOLEAN,
historic BOOLEAN,
deployment_date DATE,
capture_date DATE, 
release_date DATE,
recapture BOOLEAN,
translocation BOOLEAN,
inactive_date DATE,
malfunction_date DATE,
collar_retrival_date DATE,
potential_deactivation BOOLEAN,
min_telemetry_date DATE,
max_telemetry DATE,
spatial_min_telemetry_date DATE,
spatial_max_telemetry_date DATE,
capture_utm_zone INTEGER, -- E.g. 10
capture_utm_easting INTEGER, -- E.g. 481893
capture_utm_northing INTEGER, -- E.g. 6175130
mortality_review TEXT,
potential_mortality BOOLEAN,
mortality_zone INTEGER, -- hard code value to hide
mortality_easting INTEGER, -- hard code value to hide
mortality_northing INTEGER, -- hard code value to hide
comments TEXT, -- E.g. Recapture
changed_species BOOLEAN, 
notes TEXT,
internal_notes TEXT, -- E.g. 20190812: Added from ND tab Monthly Summary 20190515_w2019
source TEXT, -- E.g. Monthly_Collar_Summary_20190514_jul31_toCaslys
added_date DATE, 
updated_date DATE,
sex TEXT, -- M/F
life_stage TEXT, -- E.g. NR
calf_at_hell TEXT, -- E.g. NR
ear_tag_left TEXT, -- E.g. 0-2387
ear_tag_right TEXT, -- E.g. None
field_id_collar TEXT, -- E.g. 18-13655R_99490-12
flag_new BOOLEAN, -- Described as a flag, so assumed to be boolean
-- shari_id not used
regional_contact_notes TEXT,
spatially_derived_inactive_date DATE,
spatially_derived_deployment_date DATE,
regional_review_by TEXT, -- E.g. Agnes Pelletier
local_timestamp DATE, -- We will need to transform all dates to a specific standard
lmt_time TIME, -- GPSPlusX only Can be null as not all tables have this column
utc_date DATE, -- GPSPlusX onlyCan be null as not all tables have this column
utc_time TIME, -- GPSPlusX onlyCan be null as not all tables have this column
gmt_timestamp DATE,
longitude DOUBLE PRECISION,
latitude DOUBLE PRECISION,
geometry GEOMETRY, -- Will be a combination of lat/long (make sure order is taken into account)
temperature_celcius DOUBLE PRECISION NOT NULL,
main_v DOUBLE PRECISION, -- GPSPlusX and Lotex only
back_v DOUBLE PRECISION, -- Lotex only
beacon_v DOUBLE PRECISION, -- GPSPlusX only (used to locate animal via VHF tracking)
activity INTEGER, -- ATS and GPSPlusX only (triggers a mortality event)
dop DOUBLE PRECISION, -- GPSPlusX and Lotex only (dilution of precision)
hdop DOUBLE PRECISION, -- ATS only (horizontal dilution of precision)
fixtime INTEGER, -- ATS only (Number of seconds needed to achieve GPS fix)
fixtype TEXT, -- GPSPlusX only (Quality of fix obtained)
fixstatus TEXT, -- Lotex only
two_d_three_d INTEGER, -- ATS only (Dimension of GPS fix)
device_name TEXT, -- Lotex only
scts_date DATE, -- GPSPlusX only (The date/time when the message receives the provider)
scts_datetime TIME, -- GPSPlusX only (The date/time when the message receives the provider)
ecef_x_m DOUBLE PRECISION, -- GPSPlusX only (Coordinates in the Earth Centred Earth Fixed coordinate system) - advanced activity sensor
ecef_y_m DOUBLE PRECISION, -- GPSPlusX only (Coordinates in the Earth Centred Earth Fixed coordinate system) - advanced activity sensor
ecef_z_m DOUBLE PRECISION, -- GPSPlusX only (Coordinates in the Earth Centred Earth Fixed coordinate system) - advanced activity sensor
easting DOUBLE PRECISION, -- GPSPlusX only 
northing DOUBLE PRECISION, -- GPSPlusX only 
height DOUBLE PRECISION, -- GPSPlusX only 
altitude DOUBLE PRECISION, -- Lotex only
group_id INTEGER, -- GPSPlusX only (herd ID/pop_unitid)
mortality_satus TEXT, --GPSPlusX only
mort_date_gmt TIMESTAMP, -- Lotex only
mort_date_local TIMESTAMP, -- Lotex only
cancel_date_gmt TIMESTAMP, -- Lotex only
cancel_date_local TIMESTAMP, -- Lotex only
satellites_number INTEGER, -- ATS only (Number of satellites used in achieving GPS fix)
--satellite INTEGER, GPSPlusX only (no data)
--satellites INTEGER, GPSPlusX only (no data)
origin TEXT, -- GPSPlusX only (satelite name/ satellite type)
three_d_error INTEGER
)

TABLESPACE pg_default;

ALTER TABLE public.vendor_data_merge_with_long_lat
	OWNER to postgres;

# Time conversions

--select to_timestamp(("     Date & Time [GMT]" )) from public.sample_lotex_gps_0081267;

--insert into time_test select to_timestamp(("     Date & Time [GMT]" )) from public.sample_lotex_gps_0081267;

# Geometry

-- ALTER TABLE your_table ADD COLUMN geom geometry(Point, 4326);

-- Then use ST_SetSrid and ST_MakePoint to populate the column:

-- UPDATE your_table SET geom = ST_SetSRID(ST_MakePoint(longitude, latitude), 4326);