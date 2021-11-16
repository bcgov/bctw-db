--
-- Name: user; Type: TABLE; Schema: bctw; Owner: bctw
--

CREATE TABLE bctw."user" (
    id integer NOT NULL,
    idir character varying(50),
    bceid character varying(50),
    email character varying(100),
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    created_by_user_id integer,
    updated_at timestamp without time zone DEFAULT now(),
    updated_by_user_id integer,
    valid_from timestamp without time zone DEFAULT now() NOT NULL,
    valid_to timestamp without time zone,
    firstname character varying(50),
    lastname character varying(50),
    phone character varying(20),
    domain bctw.domain_type,
    username character varying(50)
);


ALTER TABLE bctw."user" OWNER TO bctw;

--
-- Name: TABLE "user"; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON TABLE bctw."user" IS 'BCTW user information table';
COMMENT ON COLUMN bctw."user".phone IS 'to be used for alerting the user in the event of mortality alerts';
COMMENT ON COLUMN bctw."user".domain IS 'idir or bceid';


--
-- Name: user_defined_field; Type: TABLE; Schema: bctw; Owner: bctw
--

CREATE TABLE bctw.user_defined_field (
    udf_id integer NOT NULL,
    user_id integer NOT NULL,
    udf jsonb,
    valid_from timestamp without time zone DEFAULT now() NOT NULL,
    valid_to timestamp without time zone
);


ALTER TABLE bctw.user_defined_field OWNER TO bctw;
CREATE SEQUENCE bctw.user_defined_field_udf_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER TABLE bctw.user_defined_field_udf_id_seq OWNER TO bctw;
ALTER SEQUENCE bctw.user_defined_field_udf_id_seq OWNED BY bctw.user_defined_field.udf_id;
CREATE SEQUENCE bctw.user_defined_field_user_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER TABLE bctw.user_defined_field_user_id_seq OWNER TO bctw;
ALTER SEQUENCE bctw.user_defined_field_user_id_seq OWNED BY bctw.user_defined_field.user_id;
CREATE SEQUENCE bctw.user_id_seq1
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER TABLE bctw.user_id_seq1 OWNER TO bctw;
ALTER SEQUENCE bctw.user_id_seq1 OWNED BY bctw."user".id;


ALTER TABLE ONLY bctw."user" ALTER COLUMN id SET DEFAULT nextval('bctw.user_id_seq1'::regclass);
ALTER TABLE ONLY bctw.user_defined_field ALTER COLUMN udf_id SET DEFAULT nextval('bctw.user_defined_field_udf_id_seq'::regclass);
ALTER TABLE ONLY bctw.user_defined_field ALTER COLUMN user_id SET DEFAULT nextval('bctw.user_defined_field_user_id_seq'::regclass);
ALTER TABLE ONLY bctw.user_defined_field
    ADD CONSTRAINT user_defined_field_pkey PRIMARY KEY (udf_id);
ALTER TABLE ONLY bctw."user"
    ADD CONSTRAINT user_idir_key UNIQUE (idir);
ALTER TABLE ONLY bctw."user"
    ADD CONSTRAINT user_pkey1 PRIMARY KEY (id);
ALTER TABLE ONLY bctw."user"
    ADD CONSTRAINT user_username_key UNIQUE (username);