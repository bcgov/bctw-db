--
-- Name: collar_animal_assignment; Type: TABLE; Schema: bctw; Owner: bctw
--

CREATE TABLE bctw.collar_animal_assignment (
    assignment_id uuid DEFAULT crypto.gen_random_uuid() NOT NULL,
    collar_id uuid NOT NULL,
    critter_id uuid NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    created_by_user_id integer,
    updated_at timestamp without time zone DEFAULT now(),
    updated_by_user_id integer,
    valid_from timestamp with time zone DEFAULT now() NOT NULL,
    valid_to timestamp with time zone,
    attachment_start timestamp with time zone NOT NULL,
    attachment_end timestamp with time zone
);


ALTER TABLE bctw.collar_animal_assignment OWNER TO bctw;
COMMENT ON TABLE bctw.collar_animal_assignment IS 'A table that tracks devices assigned to a critters.';
COMMENT ON COLUMN bctw.collar_animal_assignment.updated_by_user_id IS 'ID of the user that modified the attachment data life';
COMMENT ON COLUMN bctw.collar_animal_assignment.valid_from IS 'the start of the data life range for which telemetry is considered valid for this animal/device attachment';
COMMENT ON COLUMN bctw.collar_animal_assignment.valid_to IS 'the end of the data life range for which telemetry is considered valid for this animal/device attachment';
COMMENT ON COLUMN bctw.collar_animal_assignment.attachment_start IS 'when the collar was initially attached. the range between the attachment_start and the data_life_start (valid_from)  is considered "invalid"';
COMMENT ON COLUMN bctw.collar_animal_assignment.attachment_end IS 'when the collar was actually removed. the range between the data_life_end (valid_to) and attachnent_end is considerd "invalid"';

ALTER TABLE ONLY bctw.collar_animal_assignment
    ADD CONSTRAINT collar_animal_assignment_t_pkey PRIMARY KEY (assignment_id);

