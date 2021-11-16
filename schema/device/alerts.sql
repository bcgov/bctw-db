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
COMMENT ON COLUMN bctw.telemetry_sensor_alert.alert_id IS 'primary key of the alert table';
COMMENT ON COLUMN bctw.telemetry_sensor_alert.device_id IS 'ID of the device that triggered the alert';
COMMENT ON COLUMN bctw.telemetry_sensor_alert.device_make IS 'supported device makes are ATS, Vectronic, and Lotek';
COMMENT ON COLUMN bctw.telemetry_sensor_alert.alert_type IS 'supported alert types are malfunction and mortality';
COMMENT ON COLUMN bctw.telemetry_sensor_alert.valid_from IS 'todo: is this when the alert was triggered?';
COMMENT ON COLUMN bctw.telemetry_sensor_alert.valid_to IS 'a non null valid_to column indicates the alert has been dealt with by a user';
COMMENT ON COLUMN bctw.telemetry_sensor_alert.created_at IS 'todo: is this when the alert was triggered?';
COMMENT ON COLUMN bctw.telemetry_sensor_alert.snoozed_to IS 'until this timestamp has passed, a user is not forced to take action.';
COMMENT ON COLUMN bctw.telemetry_sensor_alert.snooze_count IS 'how many times this alert has been snoozed. a maximum of 3 is permitted';

CREATE SEQUENCE bctw.telemetry_sensor_alert_alert_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER TABLE bctw.telemetry_sensor_alert_alert_id_seq OWNER TO bctw;
ALTER SEQUENCE bctw.telemetry_sensor_alert_alert_id_seq OWNED BY bctw.telemetry_sensor_alert.alert_id;
ALTER TABLE ONLY bctw.telemetry_sensor_alert ALTER COLUMN alert_id SET DEFAULT nextval('bctw.telemetry_sensor_alert_alert_id_seq'::regclass);
ALTER TABLE ONLY bctw.telemetry_sensor_alert
    ADD CONSTRAINT telemetry_sensor_alert_pkey PRIMARY KEY (alert_id);