/**************************************************/
/************Database Create Statements************/
/**************************************************/

/**************************************************/
/********api_gpsplusx_device_activity_data*********/
/**************************************************/

-- Table: bctw.api_gpsplusx_device_activity_data

-- DROP TABLE bctw.api_gpsplusx_device_activity_data;

CREATE TABLE bctw.api_gpsplusx_device_activity_data
(
    idactivity integer,
    idcollar integer,
    acquisitiontime timestamp without time zone,
    scts timestamp without time zone,
    origincode text COLLATE pg_catalog."default",
    activitymodecode integer,
    activitymodedt integer,
    activity1 integer,
    activity2 integer,
    temperature double precision,
    activity3 integer
)

TABLESPACE pg_default;

ALTER TABLE bctw.api_gpsplusx_device_activity_data
    OWNER to bctw;

GRANT ALL ON TABLE bctw.api_gpsplusx_device_activity_data TO bctw;

GRANT ALL ON TABLE bctw.api_gpsplusx_device_activity_data TO postgres;

/**************************************************/
/********api_gpsplusx_device_gps_data**************/
/**************************************************/

-- Table: bctw.api_gpsplusx_device_gps_data

-- DROP TABLE bctw.api_gpsplusx_device_gps_data;

CREATE TABLE bctw.api_gpsplusx_device_gps_data
(
    idposition integer,
    idcollar integer,
    acquisitiontime timestamp without time zone,
    scts timestamp without time zone,
    origincode text COLLATE pg_catalog."default",
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
    transformedy double precision
)

TABLESPACE pg_default;

ALTER TABLE bctw.api_gpsplusx_device_gps_data
    OWNER to bctw;

GRANT ALL ON TABLE bctw.api_gpsplusx_device_gps_data TO bctw;    

GRANT ALL ON TABLE bctw.api_gpsplusx_device_gps_data TO postgres;

/**************************************************/
/********api_gpsplusx_device_mortality_data********/
/**************************************************/

-- Table: bctw.api_gpsplusx_device_mortality_data

-- DROP TABLE bctw.api_gpsplusx_device_mortality_data;

CREATE TABLE bctw.api_gpsplusx_device_mortality_data
(
    idmortality integer,
    idcollar integer,
    acquisitiontime timestamp without time zone,
    scts timestamp without time zone,
    origincode text COLLATE pg_catalog."default",
    idkind integer
)

TABLESPACE pg_default;

ALTER TABLE bctw.api_gpsplusx_device_mortality_data
    OWNER to bctw;

GRANT ALL ON TABLE bctw.api_gpsplusx_device_mortality_data TO bctw;

GRANT ALL ON TABLE bctw.api_gpsplusx_device_mortality_data TO postgres; 

/**************************************************/
/****api_gpsplusx_device_mortality_implant_data****/
/**************************************************/

-- Table: bctw.api_gpsplusx_device_mortality_implant_data

-- DROP TABLE bctw.api_gpsplusx_device_mortality_implant_data;

CREATE TABLE bctw.api_gpsplusx_device_mortality_implant_data
(
    idmortalityimplant integer,
    idcollar integer,
    idtransmitter integer,
    acquisitiontime timestamp without time zone,
    scts timestamp without time zone,
    origincode text COLLATE pg_catalog."default",
    heartrate integer,
    temperature double precision,
    reserved text COLLATE pg_catalog."default"
)

TABLESPACE pg_default;

ALTER TABLE bctw.api_gpsplusx_device_mortality_implant_data
    OWNER to bctw;

GRANT ALL ON TABLE bctw.api_gpsplusx_device_mortality_implant_data TO bctw;

GRANT ALL ON TABLE bctw.api_gpsplusx_device_mortality_implant_data TO postgres; 

/**************************************************/
/********api_gpsplusx_device_proximity_data********/
/**************************************************/

-- Table: bctw.api_gpsplusx_device_proximity_data

-- DROP TABLE bctw.api_gpsplusx_device_proximity_data;

CREATE TABLE bctw.api_gpsplusx_device_proximity_data
(
    idproximity integer,
    idcollar integer,
    idtransmitter integer,
    acquisitiontime timestamp without time zone,
    scts timestamp without time zone,
    origincode text COLLATE pg_catalog."default",
    rssi numeric,
    alive boolean
)

TABLESPACE pg_default;

ALTER TABLE bctw.api_gpsplusx_device_proximity_data
    OWNER to bctw;

GRANT ALL ON TABLE bctw.api_gpsplusx_device_proximity_data TO bctw;

GRANT ALL ON TABLE bctw.api_gpsplusx_device_proximity_data TO postgres;

/**************************************************/
/*******api_gpsplusx_device_separation_data********/
/**************************************************/

-- Table: bctw.api_gpsplusx_device_separation_data

-- DROP TABLE bctw.api_gpsplusx_device_separation_data;

CREATE TABLE bctw.api_gpsplusx_device_separation_data
(
    idseparation integer,
    idcollar integer,
    idtransmitter integer,
    acquisitiontime timestamp without time zone,
    scts timestamp without time zone,
    origincode text COLLATE pg_catalog."default",
    received boolean,
    alive boolean,
    description text COLLATE pg_catalog."default"
)

TABLESPACE pg_default;

ALTER TABLE bctw.api_gpsplusx_device_separation_data
    OWNER to bctw;

GRANT ALL ON TABLE bctw.api_gpsplusx_device_separation_data TO bctw;

GRANT ALL ON TABLE bctw.api_gpsplusx_device_separation_data TO postgres; 

/**************************************************/
/****api_gpsplusx_device_vaginal_implant_data******/
/**************************************************/

-- Table: bctw.api_gpsplusx_device_vaginal_implant_data

-- DROP TABLE bctw.api_gpsplusx_device_vaginal_implant_data;

CREATE TABLE bctw.api_gpsplusx_device_vaginal_implant_data
(
    idvaginalimplant integer,
    idcollar integer,
    idtransmitter integer,
    acquisitiontime timestamp without time zone,
    scts timestamp without time zone,
    origincode text COLLATE pg_catalog."default",
    activitylevel integer,
    temperature double precision,
    reserved text COLLATE pg_catalog."default"
)

TABLESPACE pg_default;

ALTER TABLE bctw.api_gpsplusx_device_vaginal_implant_data
    OWNER to bctw;

GRANT ALL ON TABLE bctw.api_gpsplusx_device_vaginal_implant_data TO bctw;

GRANT ALL ON TABLE bctw.api_gpsplusx_device_vaginal_implant_data TO postgres; 

/**************************************************/
/**************api_lotex_device_info***************/
/**************************************************/

-- Table: bctw.api_lotex_device_info

-- DROP TABLE bctw.api_lotex_device_info;

CREATE TABLE bctw.api_lotex_device_info
(
    ndeviceid integer,
    strspecialid text COLLATE pg_catalog."default",
    dtcreated timestamp without time zone,
    strsatellite text COLLATE pg_catalog."default"
)

TABLESPACE pg_default;

ALTER TABLE bctw.api_lotex_device_info
    OWNER to bctw;

GRANT ALL ON TABLE bctw.api_lotex_device_info TO postgres;

GRANT ALL ON TABLE bctw.api_lotex_device_info TO bctw;

GRANT ALL ON TABLE bctw.api_lotex_device_info TO postgres; 

/**************************************************/
/*********api_lotex_device_position_data***********/
/**************************************************/

-- Table: bctw.api_lotex_device_position_data

-- DROP TABLE bctw.api_lotex_device_position_data;

CREATE TABLE bctw.api_lotex_device_position_data
(
    channelstatus character varying(500) COLLATE pg_catalog."default",
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
    devname text COLLATE pg_catalog."default",
    deltatime double precision,
    fixtype text COLLATE pg_catalog."default",
    cepradius double precision,
    crc double precision,
    deviceid integer,
    recdatetime timestamp without time zone
)

TABLESPACE pg_default;

ALTER TABLE bctw.api_lotex_device_position_data
    OWNER to bctw;

GRANT ALL ON TABLE bctw.api_lotex_device_position_data TO bctw;

GRANT ALL ON TABLE bctw.api_lotex_device_position_data TO postgres;

/**************************************************/
/************api_lotex_devices_by_user*************/
/**************************************************/

-- Table: bctw.api_lotex_devices_by_user

-- DROP TABLE bctw.api_lotex_devices_by_user;

CREATE TABLE bctw.api_lotex_devices_by_user
(
    ndeviceid integer,
    strspecialid text COLLATE pg_catalog."default",
    dtcreated timestamp without time zone,
    strsatellite text COLLATE pg_catalog."default"
)

TABLESPACE pg_default;

ALTER TABLE bctw.api_lotex_devices_by_user
    OWNER to bctw;

GRANT ALL ON TABLE bctw.api_lotex_devices_by_user TO bctw;

GRANT ALL ON TABLE bctw.api_lotex_devices_by_user TO postgres;

/**************************************************/
/***************veondor_data_merge*****************/
/**************************************************/

-- Table: bctw.vendor_data_merge

-- DROP TABLE bctw.vendor_data_merge;

CREATE TABLE bctw.vendor_data_merge
(
    animal_id text COLLATE pg_catalog."default" NOT NULL,
    vendor text COLLATE pg_catalog."default" NOT NULL,
    collar_id integer NOT NULL,
    collar text COLLATE pg_catalog."default",
    collar_noprefix integer,
    wlh_id text COLLATE pg_catalog."default",
    previous_wlh_id text COLLATE pg_catalog."default",
    species text COLLATE pg_catalog."default",
    project text COLLATE pg_catalog."default",
    status text COLLATE pg_catalog."default",
    animal_status text COLLATE pg_catalog."default",
    collar_status_details text COLLATE pg_catalog."default",
    deactivated boolean,
    region text COLLATE pg_catalog."default",
    regional_contact text COLLATE pg_catalog."default",
    ecotype text COLLATE pg_catalog."default",
    population_unit text COLLATE pg_catalog."default",
    reg_key boolean,
    spi_bapid integer,
    fix_rate text COLLATE pg_catalog."default",
    frequency double precision,
    collar_type text COLLATE pg_catalog."default",
    collar_make text COLLATE pg_catalog."default",
    model text COLLATE pg_catalog."default",
    satellite_type text COLLATE pg_catalog."default",
    management_area text COLLATE pg_catalog."default",
    active boolean,
    historic boolean,
    deployment_date date,
    capture_date date,
    release_date date,
    recapture boolean,
    translocation boolean,
    inactive_date date,
    malfunction_date date,
    collar_retrival_date date,
    potential_deactivation boolean,
    min_telemetry_date date,
    max_telemetry date,
    spatial_min_telemetry_date date,
    spatial_max_telemetry_date date,
    capture_utm_zone integer,
    capture_utm_easting integer,
    capture_utm_northing integer,
    mortality_review text COLLATE pg_catalog."default",
    potential_mortality boolean,
    mortality_zone integer,
    mortality_easting integer,
    mortality_northing integer,
    comments text COLLATE pg_catalog."default",
    changed_species boolean,
    notes text COLLATE pg_catalog."default",
    internal_notes text COLLATE pg_catalog."default",
    source text COLLATE pg_catalog."default",
    added_date date,
    updated_date date,
    sex text COLLATE pg_catalog."default",
    life_stage text COLLATE pg_catalog."default",
    calf_at_hell text COLLATE pg_catalog."default",
    ear_tag_left text COLLATE pg_catalog."default",
    ear_tag_right text COLLATE pg_catalog."default",
    field_id_collar text COLLATE pg_catalog."default",
    flag_new boolean,
    regional_contact_notes text COLLATE pg_catalog."default",
    spatially_derived_inactive_date date,
    spatially_derived_deployment_date date,
    regional_review_by text COLLATE pg_catalog."default",
    local_timestamp date,
    lmt_time time without time zone,
    utc_date date,
    utc_time time without time zone,
    gmt_timestamp date,
    longitude double precision,
    latitude double precision,
    geometry geometry,
    temperature_celcius double precision NOT NULL,
    main_v double precision,
    back_v double precision,
    beacon_v double precision,
    activity integer,
    dop double precision,
    hdop double precision,
    fixtime integer,
    fixtype text COLLATE pg_catalog."default",
    fixstatus text COLLATE pg_catalog."default",
    two_d_three_d integer,
    device_name text COLLATE pg_catalog."default",
    scts_date date,
    scts_datetime time without time zone,
    ecef_x_m double precision,
    ecef_y_m double precision,
    ecef_z_m double precision,
    easting double precision,
    northing double precision,
    height double precision,
    altitude double precision,
    group_id integer,
    mortality_satus text COLLATE pg_catalog."default",
    mort_date_gmt timestamp without time zone,
    mort_date_local timestamp without time zone,
    cancel_date_gmt timestamp without time zone,
    cancel_date_local timestamp without time zone,
    satellites_number integer,
    origin text COLLATE pg_catalog."default",
    three_d_error integer
)

TABLESPACE pg_default;

ALTER TABLE bctw.vendor_data_merge
    OWNER to bctw;

GRANT ALL ON TABLE bctw.vendor_data_merge TO bctw;

GRANT ALL ON TABLE bctw.vendor_data_merge TO postgres;