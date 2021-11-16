--
-- Name: animal; Type: TABLE; Schema: bctw; Owner: bctw
--

CREATE TABLE bctw.animal (
    critter_id uuid DEFAULT crypto.gen_random_uuid() NOT NULL,
    critter_transaction_id uuid DEFAULT crypto.gen_random_uuid() NOT NULL,
    animal_id character varying(30),
    animal_status integer,
    associated_animal_id character varying(30),
    associated_animal_relationship integer,
    capture_comment character varying(200),
    capture_date timestamp with time zone,
    capture_latitude double precision,
    capture_longitude double precision,
    capture_utm_easting integer,
    capture_utm_northing integer,
    capture_utm_zone integer,
    collective_unit character varying(60),
    animal_colouration character varying(20),
    ear_tag_left_colour character varying(20),
    ear_tag_right_colour character varying(20),
    estimated_age double precision,
    juvenile_at_heel integer,
    life_stage integer,
    map_colour integer DEFAULT bctw_dapi_v1.get_random_colour_code_id(),
    mortality_comment character varying(200),
    mortality_date timestamp with time zone,
    mortality_latitude double precision,
    mortality_longitude double precision,
    mortality_utm_easting integer,
    mortality_utm_northing integer,
    mortality_utm_zone integer,
    proximate_cause_of_death integer,
    ultimate_cause_of_death integer,
    population_unit integer,
    recapture boolean,
    region integer,
    release_comment character varying(200),
    release_date timestamp with time zone,
    release_latitude double precision,
    release_longitude double precision,
    release_utm_easting integer,
    release_utm_northing integer,
    release_utm_zone integer,
    sex integer,
    species character varying(20),
    translocation boolean,
    wlh_id character varying(20),
    animal_comment character varying(200),
    created_at timestamp without time zone DEFAULT now(),
    created_by_user_id integer,
    updated_at timestamp without time zone DEFAULT now(),
    updated_by_user_id integer,
    valid_from timestamp with time zone DEFAULT now(),
    valid_to timestamp with time zone,
    pcod_predator_species character varying(20),
    owned_by_user_id integer,
    ear_tag_left_id character varying(20),
    ear_tag_right_id character varying(20),
    juvenile_at_heel_count integer,
    predator_known boolean,
    captivity_status boolean,
    mortality_captivity_status boolean,
    ucod_predator_species character varying(20),
    pcod_confidence integer,
    ucod_confidence integer,
    mortality_report boolean,
    mortality_investigation integer,
    device_id integer
);


ALTER TABLE bctw.animal OWNER TO bctw;
COMMENT ON COLUMN bctw.animal.critter_id IS 'A uuid key that is preserved through changes to the critter';
COMMENT ON COLUMN bctw.animal.critter_transaction_id IS 'Primary key of the animal table. When a critter is modified a new row with the same id but new transaction_id is inserted';
COMMENT ON COLUMN bctw.animal.animal_id IS 'A unique identifier permanently assigned to an animal by the project coordinator, independent of possible changes in mark method used. This data is mandatory if there is telemetry or GPS data for the animal.  Field often contains text and numbers.';
COMMENT ON COLUMN bctw.animal.animal_status IS 'Status of animal that a tracking device has been deployed on.';
COMMENT ON COLUMN bctw.animal.associated_animal_id IS 'another individual with which this animal is associated';
COMMENT ON COLUMN bctw.animal.associated_animal_relationship IS 'describes the relationship between this animal and the individual named in "associated_animal_id"';
COMMENT ON COLUMN bctw.animal.capture_comment IS 'comments from the capture event/workflow';
COMMENT ON COLUMN bctw.animal.capture_date IS 'The date of the start of a deployment (ie. date animal was captured).  A reliable format is dd-mmm-yyyy (e.g. ''7 Jun 2008'' or ''7-Jun-2008''). When entering the date into Excel ensure that Excel interprets it as correct date information.';
COMMENT ON COLUMN bctw.animal.capture_latitude IS 'The latitude of the observation, in decimal degrees. Coordinates must be recorded in WGS84. Do not enter Long-Lat coordinates if UTM coordinates are provided.';
COMMENT ON COLUMN bctw.animal.capture_longitude IS 'The longitude of the observation, in decimal degrees. Coordinates must be recorded in WGS84. Do not enter Long-Lat coordinates if UTM coordinates are provided.';
COMMENT ON COLUMN bctw.animal.capture_utm_easting IS 'The UTM east coordinate in metres. The value in this field must be a 6-digit number. UTM coordinates must be recorded using NAD 83 datum.';
COMMENT ON COLUMN bctw.animal.capture_utm_northing IS 'The UTM north coordinate in metres for the observation recorded. The value in this field must be a 7 digit number. UTM coordinates must be recorded using NAD 83 datum.';
COMMENT ON COLUMN bctw.animal.capture_utm_zone IS 'The UTM zone in which the observation occurs. The value is a 2 digit number.';
COMMENT ON COLUMN bctw.animal.collective_unit IS 'used to represent herds or packs, distinct from population units';
COMMENT ON COLUMN bctw.animal.animal_colouration IS 'general appearance of an animal resulting from the reflection or emission of light from its surfaces';
COMMENT ON COLUMN bctw.animal.ear_tag_left_colour IS 'An ear tag colour on the left ear';
COMMENT ON COLUMN bctw.animal.ear_tag_right_colour IS 'An ear tag colour on the right ear';
COMMENT ON COLUMN bctw.animal.estimated_age IS 'The estimated age, in years, of the organism. A decimal place is permitted.';
COMMENT ON COLUMN bctw.animal.juvenile_at_heel IS 'Fledged birds before their first winter, mammals older than neonates but still requiring parental care, and reptiles and amphibians of adult form that are significantly smaller than adult size.';
COMMENT ON COLUMN bctw.animal.life_stage IS 'The life stage of the individual.';
COMMENT ON COLUMN bctw.animal.map_colour IS 'colour used to represent points on the 2D map of the animal';
COMMENT ON COLUMN bctw.animal.mortality_comment IS 'comments from the mortality event/workflow';
COMMENT ON COLUMN bctw.animal.mortality_date IS 'Date animal died';
COMMENT ON COLUMN bctw.animal.mortality_latitude IS 'Mortality Location in WGS85';
COMMENT ON COLUMN bctw.animal.mortality_longitude IS 'Mortality Location in WGS85';
COMMENT ON COLUMN bctw.animal.mortality_utm_easting IS 'Mortality location easting';
COMMENT ON COLUMN bctw.animal.mortality_utm_northing IS 'Mortality location northing';
COMMENT ON COLUMN bctw.animal.mortality_utm_zone IS 'Mortality location zone';
COMMENT ON COLUMN bctw.animal.proximate_cause_of_death IS 'probable cause of death';
COMMENT ON COLUMN bctw.animal.ultimate_cause_of_death IS 'ultimate cause of death';
COMMENT ON COLUMN bctw.animal.population_unit IS 'A code indicating the species'' population unit (e.g., SnSa). Population unit is a generic term for a provincially defined, geographically discrete population of a species. E.g., for grizzly bear they are called ''population units''; for caribou they are called ''herds''; for moose they are called ''game-management zones''.';
COMMENT ON COLUMN bctw.animal.recapture IS 'Identifies whether the animal is a recapture.';
COMMENT ON COLUMN bctw.animal.region IS 'Region within province the animal inhabits. ex. Peace';
COMMENT ON COLUMN bctw.animal.release_comment IS 'comments from the release event/workflow';
COMMENT ON COLUMN bctw.animal.release_date IS 'Date the animal was released following capture.';
COMMENT ON COLUMN bctw.animal.release_latitude IS 'latitude of location where animal was released';
COMMENT ON COLUMN bctw.animal.release_longitude IS 'longitude of location where animal was released';
COMMENT ON COLUMN bctw.animal.release_utm_easting IS 'UTM easting of location where animal was released';
COMMENT ON COLUMN bctw.animal.release_utm_northing IS 'UTM northing of location where animal was released';
COMMENT ON COLUMN bctw.animal.release_utm_zone IS 'UTM zone compnent of location where animal was released';
COMMENT ON COLUMN bctw.animal.sex IS 'A code indicating the sex of the individual.';
COMMENT ON COLUMN bctw.animal.species IS 'A code that identifies a species or subspecies of wildlife.';
COMMENT ON COLUMN bctw.animal.translocation IS 'Identifies whether the animal is a translocation.';
COMMENT ON COLUMN bctw.animal.wlh_id IS '"A unique identifier assigned to an individual by the B. C. Wildlife Health Program, independent of possible changes in mark method used, to assoicate health data to the indiviudal."';
COMMENT ON COLUMN bctw.animal.animal_comment IS 'general comments about the animal (e.g. missing left ear, scar on neck, etc.)';
COMMENT ON COLUMN bctw.animal.created_at IS 'time this record was created at';
COMMENT ON COLUMN bctw.animal.created_by_user_id IS 'user ID of the user that created the animal';
COMMENT ON COLUMN bctw.animal.updated_at IS 'time this record was updated at';
COMMENT ON COLUMN bctw.animal.updated_by_user_id IS 'user ID of the user that changed the animal';
COMMENT ON COLUMN bctw.animal.valid_from IS 'timestamp of when this record begins being valid';
COMMENT ON COLUMN bctw.animal.valid_to IS 'is this record expired? (null) is valid';
COMMENT ON COLUMN bctw.animal.pcod_predator_species IS 'a common english name of the predator species or subspecies associated with the animal''s proximate cause of death';
COMMENT ON COLUMN bctw.animal.owned_by_user_id IS 'user ID of the user the ''owns'' the animal';
COMMENT ON COLUMN bctw.animal.ear_tag_left_id IS 'numeric or alphanumeric identifier, if marked on left ear tag';
COMMENT ON COLUMN bctw.animal.ear_tag_right_id IS 'numeric or alphanumeric identifier, if marked on right ear tag';
COMMENT ON COLUMN bctw.animal.juvenile_at_heel_count IS 'how many juveniles ';
COMMENT ON COLUMN bctw.animal.predator_known IS ' indicating that species (or genus) of a predator that predated an animal is known or unknown.';
COMMENT ON COLUMN bctw.animal.captivity_status IS 'indicating whether an animal is, or has been, in a captivity program (e.g., maternity pen, conservation breeeding program).';
COMMENT ON COLUMN bctw.animal.mortality_captivity_status IS 'indicating the mortality event occurred when animal was occupying wild habitat (i.e, natural range) or in captivity (i.e.,  maternity pen, conservation breeding centre).';
COMMENT ON COLUMN bctw.animal.ucod_predator_species IS 'a common english name of the predator species or subspecies associated with the animal''s ultimate cause of death';
COMMENT ON COLUMN bctw.animal.pcod_confidence IS 'describes qualitative confidence in the assignment of Proximate Cause of Death of an animal. ';
COMMENT ON COLUMN bctw.animal.ucod_confidence IS 'a code that describes qualitative confidence in the assignment of Ultimate Cause of Death of an animal.';
COMMENT ON COLUMN bctw.animal.mortality_report IS 'indicating that details of animal''s mortality investigation is recorded in a Wildlife Health Group mortality template.';
COMMENT ON COLUMN bctw.animal.mortality_investigation IS 'a code indicating the method of investigation of the animal mortality.';
COMMENT ON COLUMN bctw.animal.device_id IS 'temporary column added to assist with bulk loading animal/collar relationships';


--
-- Name: species; Type: TABLE; Schema: bctw; Owner: bctw
--

CREATE TABLE bctw.species (
    species_code character varying(20) NOT NULL,
    species_eng_name character varying(60),
    species_scientific_name character varying(60),
    predator_species boolean DEFAULT false,
    valid_from timestamp without time zone,
    valid_to timestamp without time zone,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    created_by_user_id integer,
    updated_by_user_id integer
);


ALTER TABLE bctw.species OWNER TO bctw;

ALTER TABLE ONLY bctw.animal
    ADD CONSTRAINT animal_pkey PRIMARY KEY (critter_transaction_id);
ALTER TABLE ONLY bctw.species
    ADD CONSTRAINT species2_pkey PRIMARY KEY (species_code);