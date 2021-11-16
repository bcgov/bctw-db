--
-- Name: code_category; Type: TABLE; Schema: bctw; Owner: bctw
--

CREATE TABLE bctw.code_category (
    code_category_id integer NOT NULL,
    code_category_name character varying(100) NOT NULL,
    code_category_title character varying(40) NOT NULL,
    code_category_description character varying(4096),
    valid_from timestamp without time zone DEFAULT now() NOT NULL,
    valid_to timestamp without time zone,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now(),
    created_by_user_id integer,
    updated_by_user_id integer
);


ALTER TABLE bctw.code_category OWNER TO bctw;

--
-- Name: TABLE code_category; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON TABLE bctw.code_category IS 'A code category is the high level container for code headers and codes';


--
-- Name: code_category_code_category_id_seq; Type: SEQUENCE; Schema: bctw; Owner: bctw
--

CREATE SEQUENCE bctw.code_category_code_category_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE bctw.code_category_code_category_id_seq OWNER TO bctw;

--
-- Name: code_category_code_category_id_seq; Type: SEQUENCE OWNED BY; Schema: bctw; Owner: bctw
--

ALTER SEQUENCE bctw.code_category_code_category_id_seq OWNED BY bctw.code_category.code_category_id;


--
-- Name: code_code_id_seq; Type: SEQUENCE; Schema: bctw; Owner: bctw
--

CREATE SEQUENCE bctw.code_code_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE bctw.code_code_id_seq OWNER TO bctw;

--
-- Name: code_code_id_seq; Type: SEQUENCE OWNED BY; Schema: bctw; Owner: bctw
--

ALTER SEQUENCE bctw.code_code_id_seq OWNED BY bctw.code.code_id;


--
-- Name: code_header; Type: TABLE; Schema: bctw; Owner: bctw
--

CREATE TABLE bctw.code_header (
    code_header_id integer NOT NULL,
    code_category_id integer,
    code_header_name character varying(100) NOT NULL,
    code_header_title character varying(40) NOT NULL,
    code_header_description character varying(4096),
    valid_from timestamp without time zone DEFAULT now() NOT NULL,
    valid_to timestamp without time zone,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now(),
    created_by_user_id integer,
    updated_by_user_id integer
);


ALTER TABLE bctw.code_header OWNER TO bctw;
COMMENT ON TABLE bctw.code_header IS 'Represents a code type. All codes belogn to to a code header. Ex code Kootenay belongs to the code header Region';
COMMENT ON COLUMN bctw.code_header.code_header_name IS 'Technical name for the code table used in the interface to reference this code table.';
COMMENT ON COLUMN bctw.code_header.code_header_title IS 'Screen title when dropdown is presented.';
CREATE SEQUENCE bctw.code_header_code_header_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE bctw.code_header_code_header_id_seq OWNER TO bctw;
ALTER SEQUENCE bctw.code_header_code_header_id_seq OWNED BY bctw.code_header.code_header_id;


--
-- Name: code; Type: TABLE; Schema: bctw; Owner: bctw
--

CREATE TABLE bctw.code (
    code_id integer NOT NULL,
    code_header_id integer NOT NULL,
    code_name character varying(30) NOT NULL,
    code_description character varying(300) NOT NULL,
    code_sort_order smallint,
    valid_from timestamp without time zone DEFAULT now() NOT NULL,
    valid_to timestamp without time zone,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now(),
    created_by_user_id integer,
    updated_by_user_id integer,
    code_description_long character varying(300),
    custom_1 jsonb
);


ALTER TABLE bctw.code OWNER TO bctw;
COMMENT ON TABLE bctw.code IS 'This is the generic code table containing all codes.';
COMMENT ON COLUMN bctw.code.valid_from IS 'Validity of this code from date.';
COMMENT ON COLUMN bctw.code.valid_to IS 'Validity of this code until this date';

ALTER TABLE ONLY bctw.code ALTER COLUMN code_id SET DEFAULT nextval('bctw.code_code_id_seq'::regclass);
ALTER TABLE ONLY bctw.code_category ALTER COLUMN code_category_id SET DEFAULT nextval('bctw.code_category_code_category_id_seq'::regclass);
ALTER TABLE ONLY bctw.code_header ALTER COLUMN code_header_id SET DEFAULT nextval('bctw.code_header_code_header_id_seq'::regclass);
ALTER TABLE ONLY bctw.code_category
    ADD CONSTRAINT category_name_uq UNIQUE (code_category_name, valid_from, valid_to);
ALTER TABLE ONLY bctw.code_category
    ADD CONSTRAINT code_category_pk PRIMARY KEY (code_category_id);
ALTER TABLE ONLY bctw.code_header
    ADD CONSTRAINT code_header_pk PRIMARY KEY (code_header_id);
ALTER TABLE ONLY bctw.code
    ADD CONSTRAINT code_id_name_uq UNIQUE (code_header_id, code_name, valid_from, valid_to);
ALTER TABLE ONLY bctw.code
    ADD CONSTRAINT code_pk PRIMARY KEY (code_id);
ALTER TABLE ONLY bctw.code_header
    ADD CONSTRAINT header_id_name_uq UNIQUE (code_category_id, code_header_name, valid_from, valid_to);