--
-- Name: permission_request; Type: TABLE; Schema: bctw; Owner: bctw
--

CREATE TABLE bctw.permission_request (
    request_id integer NOT NULL,
    user_id_list integer[],
    critter_permission_list jsonb,
    request_comment text,
    created_at timestamp without time zone DEFAULT now(),
    requested_by_user_id integer,
    valid_from timestamp without time zone DEFAULT now(),
    valid_to timestamp without time zone,
    was_denied_reason text,
    status bctw.onboarding_status DEFAULT 'pending'::bctw.onboarding_status
);


ALTER TABLE bctw.permission_request OWNER TO bctw;

--
-- Name: COLUMN permission_request.request_id; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON COLUMN bctw.permission_request.request_id IS 'auto generated primary key of the permission table';
COMMENT ON COLUMN bctw.permission_request.user_id_list IS 'integer array of user IDs';
COMMENT ON COLUMN bctw.permission_request.critter_permission_list IS 'json array of user_permission objects';
COMMENT ON COLUMN bctw.permission_request.request_comment IS 'optional comment that the admin will see';
COMMENT ON COLUMN bctw.permission_request.requested_by_user_id IS 'user ID of the user who submitted the permission request. should be an owner';
COMMENT ON COLUMN bctw.permission_request.was_denied_reason IS 'if the request was denied, the administrator can add a reason comment';
CREATE SEQUENCE bctw.permission_request_request_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER TABLE bctw.permission_request_request_id_seq OWNER TO bctw;
ALTER SEQUENCE bctw.permission_request_request_id_seq OWNED BY bctw.permission_request.request_id;


--
-- Name: user_animal_assignment; Type: TABLE; Schema: bctw; Owner: bctw
--

CREATE TABLE bctw.user_animal_assignment (
    assignment_id uuid DEFAULT crypto.gen_random_uuid() NOT NULL,
    user_id integer NOT NULL,
    critter_id uuid NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    created_by_user_id integer,
    updated_at timestamp without time zone DEFAULT now(),
    updated_by_user_id integer,
    valid_from timestamp without time zone DEFAULT now() NOT NULL,
    valid_to timestamp without time zone,
    permission_type bctw.user_permission NOT NULL
);


ALTER TABLE bctw.user_animal_assignment OWNER TO bctw;
COMMENT ON TABLE bctw.user_animal_assignment IS 'Tracks user permissions to animals.';

--
-- Name: user_role_type; Type: TABLE; Schema: bctw; Owner: bctw
--

CREATE TABLE bctw.user_role_type (
    role_id uuid DEFAULT crypto.gen_random_uuid() NOT NULL,
    role_type character varying(50),
    description character varying(200)
);


ALTER TABLE bctw.user_role_type OWNER TO bctw;
COMMENT ON TABLE bctw.user_role_type IS 'Role types that users can be assigned to. [Administrator, Owner, Observer]';
CREATE TABLE bctw.user_role_xref (
    user_id integer NOT NULL,
    role_id uuid NOT NULL
);
ALTER TABLE bctw.user_role_xref OWNER TO bctw;
ALTER TABLE ONLY bctw.user_role_type
    ADD CONSTRAINT unique_role_type UNIQUE (role_type);

COMMENT ON TABLE bctw.user_role_xref IS 'Table that associates a user with a role type.';
CREATE SEQUENCE bctw.user_role_xref_user_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER TABLE bctw.user_role_xref_user_id_seq OWNER TO bctw;
ALTER SEQUENCE bctw.user_role_xref_user_id_seq OWNED BY bctw.user_role_xref.user_id;
ALTER TABLE ONLY bctw.permission_request ALTER COLUMN request_id SET DEFAULT nextval('bctw.permission_request_request_id_seq'::regclass);

ALTER TABLE ONLY bctw.permission_request
    ADD CONSTRAINT permission_request_pkey PRIMARY KEY (request_id);
ALTER TABLE ONLY bctw.user_animal_assignment
    ADD CONSTRAINT user_animal_assignment_t_pkey PRIMARY KEY (assignment_id);
ALTER TABLE ONLY bctw.user_role_type
    ADD CONSTRAINT user_role_type_pkey PRIMARY KEY (role_id);
ALTER TABLE ONLY bctw.user_role_xref
    ADD CONSTRAINT user_role_xref_pkey PRIMARY KEY (user_id, role_id);
ALTER TABLE ONLY bctw.user_role_xref
    ADD CONSTRAINT user_role_xref_role_id_fkey FOREIGN KEY (role_id) REFERENCES bctw.user_role_type(role_id);
ALTER TABLE ONLY bctw.user_role_xref
    ADD CONSTRAINT user_role_xref_user_id_fkey FOREIGN KEY (user_id) REFERENCES bctw."user"(id);
ALTER TABLE ONLY bctw.permission_request
    ADD CONSTRAINT permission_request_requested_by_user_id_fkey FOREIGN KEY (requested_by_user_id) REFERENCES bctw."user"(id);
ALTER TABLE ONLY bctw.user_animal_assignment
    ADD CONSTRAINT user_animal_assignment_fk_user_id FOREIGN KEY (user_id) REFERENCES bctw."user"(id);
ALTER TABLE ONLY bctw.user_defined_field
    ADD CONSTRAINT user_defined_field_user_id_fkey FOREIGN KEY (user_id) REFERENCES bctw."user"(id);