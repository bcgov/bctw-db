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
COMMENT ON COLUMN bctw.collar.collar_id IS 'A uuid key that is preserved through changes to the device';
COMMENT ON COLUMN bctw.collar.collar_transaction_id IS 'Primary key of the collar table. When a device is modified a new row with the same id but new transaction_id is inserted';
COMMENT ON COLUMN bctw.collar.camera_device_id IS 'ID of the camera component';
COMMENT ON COLUMN bctw.collar.device_id IS 'An identifying number or label (e.g. serial number) that the manufacturer of a device has applied to the device.';
COMMENT ON COLUMN bctw.collar.device_deployment_status IS 'The deployment status of a device.';
COMMENT ON COLUMN bctw.collar.device_make IS 'The manufacturer of a device';
COMMENT ON COLUMN bctw.collar.device_malfunction_type IS 'Type of device malfunction. ex: VHF signal of device has malfunctioned';
COMMENT ON COLUMN bctw.collar.device_model IS 'The model of a device. Text and numerici field.';
COMMENT ON COLUMN bctw.collar.device_status IS 'The functional status of a device';
COMMENT ON COLUMN bctw.collar.device_type IS 'Type of tracking device';
COMMENT ON COLUMN bctw.collar.dropoff_device_id IS 'ID of the drop-off component';
COMMENT ON COLUMN bctw.collar.dropoff_frequency IS 'radio frequency of the device’s drop-off component';
COMMENT ON COLUMN bctw.collar.dropoff_frequency_unit IS 'should always be MHz, but created to match the way VHF frequency is modelled';
COMMENT ON COLUMN bctw.collar.fix_interval IS 'Number of gps fixes per unit of time (fixes per hour) the device is programmed to collect.  Some devices allow for fix rate to be modified remotely over the device life.';
COMMENT ON COLUMN bctw.collar.fix_interval_rate IS 'Fix success rate is quantified as the number of attempted gps fixes that were successful relative to the expected number of gps fixes.';
COMMENT ON COLUMN bctw.collar.frequency IS 'The frequency of electromagnetic signal emitted by a tag or mark.';
COMMENT ON COLUMN bctw.collar.frequency_unit IS 'A code indicating the frequency-unit used when recording the Frequency of a tag or mark, e.g., kHz.';
COMMENT ON COLUMN bctw.collar.malfunction_date IS 'Malfunction date of the device';
COMMENT ON COLUMN bctw.collar.activation_comment IS 'comments about the purchase (e.g. invoice number, funding agency, etc.)';
COMMENT ON COLUMN bctw.collar.first_activation_month IS 'month in which the device was first activated';
COMMENT ON COLUMN bctw.collar.first_activation_year IS 'year in which the device was first activated';
COMMENT ON COLUMN bctw.collar.retrieval_date IS 'The earliest date in which the 1) the device was removed from animal or 2) the device was retrieved from the field.';
COMMENT ON COLUMN bctw.collar.retrieved IS 'Device retrieved from animal (i.e., no longer deployed)';
COMMENT ON COLUMN bctw.collar.satellite_network IS 'The satellite network of GPS collar';
COMMENT ON COLUMN bctw.collar.device_comment IS 'general comments about the device (e.g. expansion collar, previously repaired, etc.)';
COMMENT ON COLUMN bctw.collar.activation_status IS 'Device activation status by the manufacturer';
COMMENT ON COLUMN bctw.collar.created_by_user_id IS 'user ID of the user that created the collar';
COMMENT ON COLUMN bctw.collar.updated_at IS 'timestamp that the collar was updated at';
COMMENT ON COLUMN bctw.collar.updated_by_user_id IS 'user ID of the user that updated the collar';
COMMENT ON COLUMN bctw.collar.valid_from IS 'timestamp of when this record begins being valid';
COMMENT ON COLUMN bctw.collar.valid_to IS 'is this record expired? (null) is valid';
COMMENT ON COLUMN bctw.collar.owned_by_user_id IS 'user ID of the user the ''owns'' the collar.';
COMMENT ON COLUMN bctw.collar.offline_date IS 'the date the malfunction occurred';
COMMENT ON COLUMN bctw.collar.offline_type IS 'TODO - assuming this is a code?';
COMMENT ON COLUMN bctw.collar.device_condition IS 'the condition of the device upon retrieval';
COMMENT ON COLUMN bctw.collar.retrieval_comment IS 'informative comments or notes about retrieval event for this device.';
COMMENT ON COLUMN bctw.collar.malfunction_comment IS 'informative comments or notes about malfunction event for this device.';
COMMENT ON COLUMN bctw.collar.offline_comment IS 'informative comments or notes about offline event for this device.';
COMMENT ON COLUMN bctw.collar.mortality_mode IS 'indicates the device has a mortality sensor.  A device movement sensor detects no movement, after a pre-programmed period of time can change the VHF pulse rate to indicate a change in animal behaviour (e.g., stationary, resting); this can also trigger a GPS device to send notification of a mortlity signal.';
COMMENT ON COLUMN bctw.collar.mortality_period_hr IS 'the pre-programmed period of time (hours) of no movement detected, after which the device is programmed to trigger a mortality notification signal.';
COMMENT ON COLUMN bctw.collar.dropoff_mechanism IS 'a code for the drop-off mechanism for the device (e.g., device released by radio or timer)';
COMMENT ON COLUMN bctw.collar.implant_device_id IS 'an identifying number or label (e.g. serial number) that the manufacturer of a device has applied to the implant module.';
ALTER TABLE ONLY bctw.collar
    ADD CONSTRAINT collar2_pkey PRIMARY KEY (collar_transaction_id);