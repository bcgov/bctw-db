
CREATE TYPE bctw.user_permission AS ENUM (
    'admin',
    'editor',
    'none',
    'observer',
    'manager'
);
ALTER TYPE bctw.user_permission OWNER TO bctw;

CREATE TYPE bctw.critter_permission_json AS (
	critter_id uuid,
	permission_type bctw.user_permission
);
ALTER TYPE bctw.critter_permission_json OWNER TO bctw;

CREATE TYPE bctw.domain_type AS ENUM (
    'bceid',
    'idir'
);
ALTER TYPE bctw.domain_type OWNER TO bctw;
COMMENT ON TYPE bctw.domain_type IS 'Keycloak domain types, stored in the user and onboarding tables as column "domain"';

CREATE TYPE bctw.role_type AS ENUM (
    'administrator',
    'manager',
    'owner',
    'observer'
);
ALTER TYPE bctw.role_type OWNER TO bctw;
COMMENT ON TYPE bctw.role_type IS 'BCTW user role types. note: owner is deprecated';

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
COMMENT ON TYPE bctw.telemetry IS 'returned in function that retrieves telemetry data to be displayed in the map. (get_user_telemetry)';

CREATE TYPE bctw.telemetry_alert_type AS ENUM (
    'malfunction',
    'mortality',
    'missing_data',
    'battery'
);
ALTER TYPE bctw.telemetry_alert_type OWNER TO bctw;
COMMENT ON TYPE bctw.telemetry_alert_type IS 'user alert notifications. 
	malfunction: alert indicating telemetry has not been received from a device for more than 7 days.
	mortality: telemetry alert from vendor indicating the animal is a potential mortality.
	battery: alert from vendor indicating the device battery may be low. (net yet implemented).
	missing_data: deprecated.
';

CREATE TYPE bctw.unattached_telemetry AS (
	collar_id uuid,
	device_id integer,
	geom public.geometry,
	date_recorded timestamp with time zone,
	geojson jsonb
);
ALTER TYPE bctw.unattached_telemetry OWNER TO bctw;
