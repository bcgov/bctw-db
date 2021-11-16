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
COMMENT ON TABLE bctw.ats_collar_data IS 'raw telemetry data from the ATS API';

ALTER TABLE ONLY bctw.ats_collar_data
    ADD CONSTRAINT ats_collar_data_timeid_key UNIQUE (timeid);

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
COMMENT ON TABLE bctw.vectronics_collar_data IS 'raw telemetry data from Vectronics';

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
ALTER TABLE ONLY bctw.historical_telemetry
    ADD CONSTRAINT historical_telemetry_time_id_key UNIQUE (time_id);
ALTER TABLE ONLY bctw.lotek_collar_data
    ADD CONSTRAINT lotek_collar_data_timeid_key UNIQUE (timeid);
ALTER TABLE ONLY bctw.collar_vendor_api_credentials
    ADD CONSTRAINT collar_vendor_api_credentials_pkey PRIMARY KEY (api_name);
ALTER TABLE ONLY bctw.vectronics_collar_data
    ADD CONSTRAINT vectronics_collar_data_idposition_key UNIQUE (idposition);