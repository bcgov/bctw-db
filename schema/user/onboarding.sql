/*
  Create and document the onboarding table.
  This will fill two purposes:
    1. Power the admin table for granting and denying access to BCTW
    2. The source of truth for allowing users into the site.
*/

CREATE TYPE bctw.onboarding_status AS ENUM (
    'pending',
    'granted',
    'denied'
);

ALTER TYPE bctw.onboarding_status OWNER TO bctw;

drop table if exists bctw.onboarding;
CREATE TABLE bctw.onboarding (
    onboarding_id integer NOT NULL,
    domain bctw.domain_type NOT NULL,
    username character varying(50) NOT NULL,
    firstname character varying(50),
    lastname character varying(50),
    access bctw.onboarding_status NOT NULL,
    email character varying(100),
    phone character varying(20),
    reason character varying(200),
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone,
    valid_from timestamp with time zone DEFAULT now(),
    valid_to timestamp with time zone,
    role_type bctw.role_type NOT NULL
);

ALTER TABLE bctw.onboarding OWNER TO bctw;
CREATE SEQUENCE bctw.onboarding_onboarding_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER TABLE bctw.onboarding_onboarding_id_seq OWNER TO bctw;
ALTER SEQUENCE bctw.onboarding_onboarding_id_seq OWNED BY bctw.onboarding.onboarding_id;
ALTER TABLE ONLY bctw.onboarding ALTER COLUMN onboarding_id SET DEFAULT nextval('bctw.onboarding_onboarding_id_seq'::regclass);

/*
 Comments
*/
comment on table bctw.onboarding is
  'Store all BC Telemetry Warehouse access requests and adjustments';
comment on column bctw.onboarding.idir is 'IDIR user name';
comment on column bctw.onboarding.bceid is 'BCeID user name';
comment on column bctw.onboarding.email is 'Email address';
comment on column bctw.onboarding.firstname is 'User given/first name';
comment on column bctw.onboarding.lastname is 'User family/last name';
ALTER TABLE ONLY bctw.onboarding
    ADD CONSTRAINT onboarding_pkey PRIMARY KEY (onboarding_id);