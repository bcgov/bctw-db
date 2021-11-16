--
-- Name: animal_v; Type: VIEW; Schema: bctw; Owner: bctw
--

CREATE VIEW bctw.animal_v AS
 SELECT a.critter_id,
    a.critter_transaction_id,
    a.animal_id,
    ( SELECT code.code_description
           FROM bctw.code
          WHERE (code.code_id = a.animal_status)) AS animal_status,
    a.associated_animal_id,
    ( SELECT code.code_description
           FROM bctw.code
          WHERE (code.code_id = a.associated_animal_relationship)) AS associated_animal_relationship,
    a.capture_comment,
    a.capture_date,
    a.capture_latitude,
    a.capture_longitude,
    a.capture_utm_easting,
    a.capture_utm_northing,
    a.capture_utm_zone,
    a.collective_unit,
    a.animal_colouration,
    a.ear_tag_left_id,
    a.ear_tag_right_id,
    a.ear_tag_left_colour,
    a.ear_tag_right_colour,
    a.estimated_age,
    ( SELECT code.code_description
           FROM bctw.code
          WHERE (code.code_id = a.juvenile_at_heel)) AS juvenile_at_heel,
    a.juvenile_at_heel_count,
    ( SELECT code.code_description
           FROM bctw.code
          WHERE (code.code_id = a.life_stage)) AS life_stage,
    ( SELECT code.code_name
           FROM bctw.code
          WHERE (code.code_id = a.map_colour)) AS map_colour,
    a.mortality_comment,
    a.mortality_date,
    a.mortality_latitude,
    a.mortality_longitude,
    a.mortality_utm_easting,
    a.mortality_utm_northing,
    a.mortality_utm_zone,
    ( SELECT code.code_description
           FROM bctw.code
          WHERE (code.code_id = a.proximate_cause_of_death)) AS proximate_cause_of_death,
    ( SELECT code.code_description
           FROM bctw.code
          WHERE (code.code_id = a.ultimate_cause_of_death)) AS ultimate_cause_of_death,
    ( SELECT code.code_description
           FROM bctw.code
          WHERE (code.code_id = a.population_unit)) AS population_unit,
    a.recapture,
    ( SELECT code.code_description
           FROM bctw.code
          WHERE (code.code_id = a.region)) AS region,
    a.release_comment,
    a.release_date,
    a.release_latitude,
    a.release_longitude,
    a.release_utm_easting,
    a.release_utm_northing,
    a.release_utm_zone,
    ( SELECT code.code_description
           FROM bctw.code
          WHERE (code.code_id = a.sex)) AS sex,
    bctw.get_species_name(a.species) AS species,
    a.translocation,
    a.wlh_id,
    a.animal_comment,
    bctw.get_species_name(a.pcod_predator_species) AS pcod_predator_species,
    bctw.get_species_name(a.ucod_predator_species) AS ucod_predator_species,
    a.predator_known,
    a.captivity_status,
    a.mortality_captivity_status,
    ( SELECT code.code_description
           FROM bctw.code
          WHERE (code.code_id = a.pcod_confidence)) AS pcod_confidence,
    ( SELECT code.code_description
           FROM bctw.code
          WHERE (code.code_id = a.ucod_confidence)) AS ucod_confidence,
    a.mortality_report,
    ( SELECT code.code_description
           FROM bctw.code
          WHERE (code.code_id = a.mortality_investigation)) AS mortality_investigation,
    a.valid_from,
    a.valid_to,
    a.created_at,
    a.created_by_user_id,
    a.owned_by_user_id
   FROM bctw.animal a;


ALTER TABLE bctw.animal_v OWNER TO bctw;


--
-- Name: collar_v; Type: VIEW; Schema: bctw; Owner: bctw
--

CREATE VIEW bctw.collar_v AS
 SELECT c.collar_id,
    c.collar_transaction_id,
    c.camera_device_id,
    c.device_id,
    ( SELECT code.code_description
           FROM bctw.code
          WHERE (code.code_id = c.device_deployment_status)) AS device_deployment_status,
    ( SELECT code.code_description
           FROM bctw.code
          WHERE (code.code_id = c.device_make)) AS device_make,
    ( SELECT code.code_description
           FROM bctw.code
          WHERE (code.code_id = c.device_malfunction_type)) AS device_malfunction_type,
    c.device_model,
    ( SELECT code.code_description
           FROM bctw.code
          WHERE (code.code_id = c.device_status)) AS device_status,
    ( SELECT code.code_description
           FROM bctw.code
          WHERE (code.code_id = c.device_type)) AS device_type,
    c.dropoff_device_id,
    c.dropoff_frequency,
    ( SELECT code.code_description
           FROM bctw.code
          WHERE (code.code_id = c.dropoff_mechanism)) AS dropoff_mechanism,
    ( SELECT code.code_description
           FROM bctw.code
          WHERE (code.code_id = c.dropoff_frequency_unit)) AS dropoff_frequency_unit,
    c.fix_interval,
    ( SELECT code.code_description
           FROM bctw.code
          WHERE (code.code_id = c.fix_interval_rate)) AS fix_interval_rate,
    c.frequency,
    c.implant_device_id,
    ( SELECT code.code_description
           FROM bctw.code
          WHERE (code.code_id = c.frequency_unit)) AS frequency_unit,
    c.mortality_mode,
    c.mortality_period_hr,
    c.malfunction_date,
    c.malfunction_comment,
    c.activation_status,
    c.activation_comment,
    c.first_activation_month,
    c.first_activation_year,
    c.retrieval_date,
    c.retrieved,
    c.retrieval_comment,
    ( SELECT code.code_description
           FROM bctw.code
          WHERE (code.code_id = c.satellite_network)) AS satellite_network,
    c.device_comment,
    c.offline_date,
    ( SELECT code.code_description
           FROM bctw.code
          WHERE (code.code_id = c.offline_type)) AS offline_type,
    c.offline_comment,
    ( SELECT code.code_description
           FROM bctw.code
          WHERE (code.code_id = c.device_condition)) AS device_condition,
    c.created_at,
    c.created_by_user_id,
    c.valid_from,
    c.valid_to,
    c.owned_by_user_id
   FROM bctw.collar c;


ALTER TABLE bctw.collar_v OWNER TO bctw;

--
-- Name: vendor_merge_view_no_critter; Type: MATERIALIZED VIEW; Schema: bctw; Owner: bctw
--

CREATE MATERIALIZED VIEW bctw.vendor_merge_view_no_critter AS
 WITH pings AS (
         SELECT lotek_collar_data.geom,
            lotek_collar_data.recdatetime AS date_recorded,
            lotek_collar_data.deviceid AS device_id,
            'Lotek'::text AS device_vendor
           FROM bctw.lotek_collar_data
          WHERE public.st_isvalid(lotek_collar_data.geom)
        UNION
         SELECT vectronics_collar_data.geom,
            vectronics_collar_data.acquisitiontime AS date_recorded,
            vectronics_collar_data.idcollar AS device_id,
            'Vectronic'::text AS device_vendor
           FROM bctw.vectronics_collar_data
          WHERE public.st_isvalid(vectronics_collar_data.geom)
        UNION
         SELECT ats_collar_data.geom,
            ats_collar_data.date AS date_recorded,
            ats_collar_data.collarserialnumber AS device_id,
            'ATS'::text AS device_vendor
           FROM bctw.ats_collar_data
          WHERE public.st_isvalid(ats_collar_data.geom)
        )
 SELECT p.device_id,
    p.date_recorded,
    p.device_vendor,
    p.geom,
    row_number() OVER (ORDER BY 1::integer) AS vendor_merge_id
   FROM pings p
  WITH NO DATA;


ALTER TABLE bctw.vendor_merge_view_no_critter OWNER TO bctw;

--
-- Name: MATERIALIZED VIEW vendor_merge_view_no_critter; Type: COMMENT; Schema: bctw; Owner: bctw
--

COMMENT ON MATERIALIZED VIEW bctw.vendor_merge_view_no_critter IS 'Materialized view containing data merged from multiple vendor tables. Additional information from the collar table information, but all animal data is excluded.';


--
-- Name: latest_transmissions; Type: MATERIALIZED VIEW; Schema: bctw; Owner: bctw
--

CREATE MATERIALIZED VIEW bctw.latest_transmissions AS
 SELECT q.collar_id,
    q.device_id,
    q.date_recorded,
    q.device_vendor,
    q.geom,
    q.vendor_merge_id
   FROM ( SELECT DISTINCT ON (vmv.device_id) c.collar_id,
            vmv.device_id,
            vmv.date_recorded,
            vmv.device_vendor,
            vmv.geom,
            vmv.vendor_merge_id
           FROM (bctw.vendor_merge_view_no_critter vmv
             LEFT JOIN bctw.collar c ON ((c.device_id = vmv.device_id)))
          ORDER BY vmv.device_id, vmv.date_recorded DESC) q
  ORDER BY q.date_recorded DESC
  WITH NO DATA;


ALTER TABLE bctw.latest_transmissions OWNER TO bctw;


--
-- Name: animal_v; Type: VIEW; Schema: bctw_dapi_v1; Owner: bctw
--

CREATE VIEW bctw_dapi_v1.animal_v AS
 SELECT av.critter_id,
    av.critter_transaction_id,
    av.animal_id,
    av.animal_status,
    av.associated_animal_id,
    av.associated_animal_relationship,
    av.capture_comment,
    av.capture_date,
    av.capture_latitude,
    av.capture_longitude,
    av.capture_utm_easting,
    av.capture_utm_northing,
    av.capture_utm_zone,
    av.collective_unit,
    av.animal_colouration,
    av.ear_tag_left_id,
    av.ear_tag_right_id,
    av.ear_tag_left_colour,
    av.ear_tag_right_colour,
    av.estimated_age,
    av.juvenile_at_heel,
    av.juvenile_at_heel_count,
    av.life_stage,
    av.map_colour,
    av.mortality_comment,
    av.mortality_date,
    av.mortality_latitude,
    av.mortality_longitude,
    av.mortality_utm_easting,
    av.mortality_utm_northing,
    av.mortality_utm_zone,
    av.proximate_cause_of_death,
    av.ultimate_cause_of_death,
    av.population_unit,
    av.recapture,
    av.region,
    av.release_comment,
    av.release_date,
    av.release_latitude,
    av.release_longitude,
    av.release_utm_easting,
    av.release_utm_northing,
    av.release_utm_zone,
    av.sex,
    av.species,
    av.translocation,
    av.wlh_id,
    av.animal_comment,
    av.pcod_predator_species,
    av.ucod_predator_species,
    av.predator_known,
    av.captivity_status,
    av.mortality_captivity_status,
    av.pcod_confidence,
    av.ucod_confidence,
    av.mortality_report,
    av.mortality_investigation,
    av.valid_from,
    av.valid_to,
    av.created_at,
    av.created_by_user_id,
    av.owned_by_user_id
   FROM bctw.animal_v av
  WHERE bctw.is_valid(av.valid_to);


ALTER TABLE bctw_dapi_v1.animal_v OWNER TO bctw;

--
-- Name: collar_v; Type: VIEW; Schema: bctw_dapi_v1; Owner: bctw
--

CREATE VIEW bctw_dapi_v1.collar_v AS
 SELECT collar_v.collar_id,
    collar_v.collar_transaction_id,
    collar_v.camera_device_id,
    collar_v.device_id,
    collar_v.device_deployment_status,
    collar_v.device_make,
    collar_v.device_malfunction_type,
    collar_v.device_model,
    collar_v.device_status,
    collar_v.device_type,
    collar_v.dropoff_device_id,
    collar_v.dropoff_frequency,
    collar_v.dropoff_mechanism,
    collar_v.dropoff_frequency_unit,
    collar_v.fix_interval,
    collar_v.fix_interval_rate,
    collar_v.frequency,
    collar_v.implant_device_id,
    collar_v.frequency_unit,
    collar_v.mortality_mode,
    collar_v.mortality_period_hr,
    collar_v.malfunction_date,
    collar_v.malfunction_comment,
    collar_v.activation_status,
    collar_v.activation_comment,
    collar_v.first_activation_month,
    collar_v.first_activation_year,
    collar_v.retrieval_date,
    collar_v.retrieved,
    collar_v.retrieval_comment,
    collar_v.satellite_network,
    collar_v.device_comment,
    collar_v.offline_date,
    collar_v.offline_type,
    collar_v.offline_comment,
    collar_v.device_condition,
    collar_v.created_at,
    collar_v.created_by_user_id,
    collar_v.valid_from,
    collar_v.valid_to,
    collar_v.owned_by_user_id
   FROM bctw.collar_v
  WHERE bctw.is_valid(collar_v.valid_to);


ALTER TABLE bctw_dapi_v1.collar_v OWNER TO bctw;

--
-- Name: alert_v; Type: VIEW; Schema: bctw_dapi_v1; Owner: bctw
--

CREATE VIEW bctw_dapi_v1.alert_v AS
 SELECT sa.alert_id,
    sa.alert_type,
    sa.snoozed_to,
    sa.snooze_count,
    sa.created_at,
    sa.valid_from,
    sa.valid_to,
    c.collar_id,
    c.device_id,
    c.device_make,
    c.device_status,
    a.critter_id,
    a.animal_id,
    a.wlh_id,
    a.species,
    a.captivity_status,
    a.animal_status,
    ca.assignment_id,
    ca.attachment_start,
    ca.valid_from AS data_life_start,
    ca.valid_to AS data_life_end,
    ca.attachment_end,
    ( SELECT latest_transmissions.date_recorded
           FROM bctw.latest_transmissions
          WHERE (latest_transmissions.collar_id = c.collar_id)) AS last_transmission_date
   FROM (((bctw.telemetry_sensor_alert sa
     JOIN bctw_dapi_v1.collar_v c ON (((sa.device_id = c.device_id) AND (sa.device_make = (c.device_make)::text))))
     JOIN bctw.collar_animal_assignment ca ON ((ca.collar_id = c.collar_id)))
     JOIN bctw_dapi_v1.animal_v a ON ((ca.critter_id = a.critter_id)))
  WHERE (bctw.is_valid(ca.valid_to) AND bctw.is_valid(sa.valid_to));


ALTER TABLE bctw_dapi_v1.alert_v OWNER TO bctw;

--
-- Name: animal_historic_v; Type: VIEW; Schema: bctw_dapi_v1; Owner: bctw
--

CREATE VIEW bctw_dapi_v1.animal_historic_v AS
 SELECT animal_v.critter_id,
    animal_v.critter_transaction_id,
    animal_v.animal_id,
    animal_v.animal_status,
    animal_v.associated_animal_id,
    animal_v.associated_animal_relationship,
    animal_v.capture_comment,
    animal_v.capture_date,
    animal_v.capture_latitude,
    animal_v.capture_longitude,
    animal_v.capture_utm_easting,
    animal_v.capture_utm_northing,
    animal_v.capture_utm_zone,
    animal_v.collective_unit,
    animal_v.animal_colouration,
    animal_v.ear_tag_left_id,
    animal_v.ear_tag_right_id,
    animal_v.ear_tag_left_colour,
    animal_v.ear_tag_right_colour,
    animal_v.estimated_age,
    animal_v.juvenile_at_heel,
    animal_v.juvenile_at_heel_count,
    animal_v.life_stage,
    animal_v.map_colour,
    animal_v.mortality_comment,
    animal_v.mortality_date,
    animal_v.mortality_latitude,
    animal_v.mortality_longitude,
    animal_v.mortality_utm_easting,
    animal_v.mortality_utm_northing,
    animal_v.mortality_utm_zone,
    animal_v.proximate_cause_of_death,
    animal_v.ultimate_cause_of_death,
    animal_v.population_unit,
    animal_v.recapture,
    animal_v.region,
    animal_v.release_comment,
    animal_v.release_date,
    animal_v.release_latitude,
    animal_v.release_longitude,
    animal_v.release_utm_easting,
    animal_v.release_utm_northing,
    animal_v.release_utm_zone,
    animal_v.sex,
    animal_v.species,
    animal_v.translocation,
    animal_v.wlh_id,
    animal_v.animal_comment,
    animal_v.pcod_predator_species,
    animal_v.ucod_predator_species,
    animal_v.predator_known,
    animal_v.captivity_status,
    animal_v.mortality_captivity_status,
    animal_v.pcod_confidence,
    animal_v.ucod_confidence,
    animal_v.mortality_report,
    animal_v.mortality_investigation,
    animal_v.valid_from,
    animal_v.valid_to,
    animal_v.created_at,
    animal_v.created_by_user_id,
    animal_v.owned_by_user_id
   FROM bctw.animal_v;


ALTER TABLE bctw_dapi_v1.animal_historic_v OWNER TO bctw;

--
-- Name: code_category_v; Type: VIEW; Schema: bctw_dapi_v1; Owner: bctw
--

CREATE VIEW bctw_dapi_v1.code_category_v AS
 SELECT code_category.code_category_id,
    code_category.code_category_name,
    code_category.code_category_title,
    code_category.code_category_description
   FROM bctw.code_category
  WHERE bctw.is_valid(code_category.valid_to);


ALTER TABLE bctw_dapi_v1.code_category_v OWNER TO bctw;

--
-- Name: code_header_v; Type: VIEW; Schema: bctw_dapi_v1; Owner: bctw
--

CREATE VIEW bctw_dapi_v1.code_header_v AS
 SELECT code_header.code_header_id,
    code_header.code_category_id,
    code_header.code_header_name,
    code_header.code_header_title,
    code_header.code_header_description
   FROM bctw.code_header
  WHERE bctw.is_valid(code_header.valid_to);


ALTER TABLE bctw_dapi_v1.code_header_v OWNER TO bctw;

--
-- Name: code_v; Type: VIEW; Schema: bctw_dapi_v1; Owner: bctw
--

CREATE VIEW bctw_dapi_v1.code_v AS
 SELECT code.code_id,
    code.code_header_id,
    code.code_name,
    code.code_description,
    code.code_description_long,
    code.code_sort_order
   FROM bctw.code
  WHERE bctw.is_valid(code.valid_to);


ALTER TABLE bctw_dapi_v1.code_v OWNER TO bctw;

--
-- Name: collar_animal_assignment_v; Type: VIEW; Schema: bctw_dapi_v1; Owner: bctw
--

CREATE VIEW bctw_dapi_v1.collar_animal_assignment_v AS
 SELECT collar_animal_assignment.assignment_id,
    collar_animal_assignment.collar_id,
    collar_animal_assignment.critter_id,
    collar_animal_assignment.created_at,
    collar_animal_assignment.created_by_user_id,
    collar_animal_assignment.updated_at,
    collar_animal_assignment.updated_by_user_id,
    collar_animal_assignment.valid_from,
    collar_animal_assignment.valid_to,
    collar_animal_assignment.attachment_start,
    collar_animal_assignment.attachment_end
   FROM bctw.collar_animal_assignment;


ALTER TABLE bctw_dapi_v1.collar_animal_assignment_v OWNER TO bctw;

--
-- Name: collar_historic_v; Type: VIEW; Schema: bctw_dapi_v1; Owner: bctw
--

CREATE VIEW bctw_dapi_v1.collar_historic_v AS
 SELECT collar_v.collar_id,
    collar_v.collar_transaction_id,
    collar_v.camera_device_id,
    collar_v.device_id,
    collar_v.device_deployment_status,
    collar_v.device_make,
    collar_v.device_malfunction_type,
    collar_v.device_model,
    collar_v.device_status,
    collar_v.device_type,
    collar_v.dropoff_device_id,
    collar_v.dropoff_frequency,
    collar_v.dropoff_mechanism,
    collar_v.dropoff_frequency_unit,
    collar_v.fix_interval,
    collar_v.fix_interval_rate,
    collar_v.frequency,
    collar_v.implant_device_id,
    collar_v.frequency_unit,
    collar_v.mortality_mode,
    collar_v.mortality_period_hr,
    collar_v.malfunction_date,
    collar_v.malfunction_comment,
    collar_v.activation_status,
    collar_v.activation_comment,
    collar_v.first_activation_month,
    collar_v.first_activation_year,
    collar_v.retrieval_date,
    collar_v.retrieved,
    collar_v.retrieval_comment,
    collar_v.satellite_network,
    collar_v.device_comment,
    collar_v.offline_date,
    collar_v.offline_type,
    collar_v.offline_comment,
    collar_v.device_condition,
    collar_v.created_at,
    collar_v.created_by_user_id,
    collar_v.valid_from,
    collar_v.valid_to,
    collar_v.owned_by_user_id
   FROM bctw.collar_v;


ALTER TABLE bctw_dapi_v1.collar_historic_v OWNER TO bctw;

--
-- Name: currently_attached_collars_v; Type: VIEW; Schema: bctw_dapi_v1; Owner: bctw
--

CREATE VIEW bctw_dapi_v1.currently_attached_collars_v AS
 SELECT caa.assignment_id,
    caa.collar_id,
    c.device_id,
    concat(c.frequency, ' ', c.frequency_unit) AS frequency,
    a.critter_id,
    caa.attachment_start,
    caa.valid_from AS data_life_start,
    caa.valid_to AS data_life_end,
    caa.attachment_end
   FROM ((bctw.collar_animal_assignment caa
     JOIN bctw_dapi_v1.animal_v a ON ((caa.critter_id = a.critter_id)))
     JOIN bctw_dapi_v1.collar_v c ON ((caa.collar_id = c.collar_id)))
  WHERE bctw.is_valid(caa.valid_to);


ALTER TABLE bctw_dapi_v1.currently_attached_collars_v OWNER TO bctw;

--
-- Name: currently_unattached_critters_v; Type: VIEW; Schema: bctw_dapi_v1; Owner: bctw
--

CREATE VIEW bctw_dapi_v1.currently_unattached_critters_v AS
 WITH no_attachments AS (
         SELECT caa.critter_id
           FROM bctw.collar_animal_assignment caa
          WHERE ((NOT bctw.is_valid(now(), caa.valid_from, caa.valid_to)) AND (NOT (caa.critter_id IN ( SELECT currently_attached_collars_v.critter_id
                   FROM bctw_dapi_v1.currently_attached_collars_v))))
        UNION
         SELECT a.critter_id
           FROM bctw.animal a
          WHERE (NOT (a.critter_id IN ( SELECT collar_animal_assignment.critter_id
                   FROM bctw.collar_animal_assignment)))
        )
 SELECT av.critter_id,
    av.critter_transaction_id,
    av.animal_id,
    av.animal_status,
    av.associated_animal_id,
    av.associated_animal_relationship,
    av.capture_comment,
    av.capture_date,
    av.capture_latitude,
    av.capture_longitude,
    av.capture_utm_easting,
    av.capture_utm_northing,
    av.capture_utm_zone,
    av.collective_unit,
    av.animal_colouration,
    av.ear_tag_left_id,
    av.ear_tag_right_id,
    av.ear_tag_left_colour,
    av.ear_tag_right_colour,
    av.estimated_age,
    av.juvenile_at_heel,
    av.juvenile_at_heel_count,
    av.life_stage,
    av.map_colour,
    av.mortality_comment,
    av.mortality_date,
    av.mortality_latitude,
    av.mortality_longitude,
    av.mortality_utm_easting,
    av.mortality_utm_northing,
    av.mortality_utm_zone,
    av.proximate_cause_of_death,
    av.ultimate_cause_of_death,
    av.population_unit,
    av.recapture,
    av.region,
    av.release_comment,
    av.release_date,
    av.release_latitude,
    av.release_longitude,
    av.release_utm_easting,
    av.release_utm_northing,
    av.release_utm_zone,
    av.sex,
    av.species,
    av.translocation,
    av.wlh_id,
    av.animal_comment,
    av.valid_from,
    av.valid_to,
    av.pcod_predator_species,
    av.ucod_predator_species,
    av.owned_by_user_id,
    av.predator_known,
    av.captivity_status,
    av.mortality_captivity_status,
    av.pcod_confidence,
    av.ucod_confidence,
    av.mortality_report,
    av.mortality_investigation
   FROM bctw.animal_v av
  WHERE ((av.critter_id IN ( SELECT no_attachments.critter_id
           FROM no_attachments)) AND bctw.is_valid(av.valid_to));


ALTER TABLE bctw_dapi_v1.currently_unattached_critters_v OWNER TO bctw;

--
-- Name: onboarding_v; Type: VIEW; Schema: bctw_dapi_v1; Owner: bctw
--

CREATE VIEW bctw_dapi_v1.onboarding_v AS
 SELECT onboarding.onboarding_id,
    onboarding.domain,
    onboarding.username,
    onboarding.firstname,
    onboarding.lastname,
    onboarding.access,
    onboarding.email,
    onboarding.phone,
    onboarding.reason,
    onboarding.created_at,
    onboarding.updated_at,
    onboarding.valid_from,
    onboarding.valid_to,
    onboarding.role_type
   FROM bctw.onboarding
  ORDER BY onboarding.created_at DESC;


ALTER TABLE bctw_dapi_v1.onboarding_v OWNER TO bctw;

--
-- Name: permission_requests_v; Type: VIEW; Schema: bctw_dapi_v1; Owner: bctw
--

CREATE VIEW bctw_dapi_v1.permission_requests_v AS
 WITH expanded_users AS (
         SELECT pr.request_id,
            ( SELECT COALESCE(u.idir, u.bceid) AS "coalesce"
                   FROM bctw."user" u
                  WHERE (u.id = pr.requested_by_user_id)) AS requested_by,
            ( SELECT u.email
                   FROM bctw."user" u
                  WHERE (u.id = pr.requested_by_user_id)) AS requested_by_email,
            ( SELECT (((u.firstname)::text || ''::text) || (u.lastname)::text)
                   FROM bctw."user" u
                  WHERE (u.id = pr.requested_by_user_id)) AS requested_by_name,
            pr.created_at AS requested_date,
            pr.request_comment,
            unnest(pr.user_id_list) AS user_id,
            pr.critter_permission_list AS cr,
            pr.valid_to,
            pr.status,
            pr.was_denied_reason
           FROM bctw.permission_request pr
        ), expanded_permissions AS (
         SELECT es.request_id,
            es.requested_by,
            es.requested_by_email,
            es.requested_by_name,
            es.requested_date,
            es.request_comment,
            es.user_id,
            es.cr,
            es.valid_to,
            es.status,
            es.was_denied_reason,
            ( SELECT u.email
                   FROM bctw."user" u
                  WHERE (u.id = es.user_id)) AS requested_for_email,
            ( SELECT (((u.firstname)::text || ''::text) || (u.lastname)::text)
                   FROM bctw."user" u
                  WHERE (u.id = es.user_id)) AS requested_for_name
           FROM expanded_users es
        )
 SELECT ep.request_id,
    ep.requested_by,
    ep.requested_by_email,
    ep.requested_by_name,
    ep.requested_date,
    ep.request_comment,
    ep.requested_for_email,
    ep.requested_for_name,
    ( SELECT a.animal_id
           FROM bctw.animal a
          WHERE (bctw.is_valid(a.valid_to) AND (a.critter_id = ((ep.cr ->> 'critter_id'::text))::uuid))) AS animal_id,
    ( SELECT a.wlh_id
           FROM bctw.animal a
          WHERE (bctw.is_valid(a.valid_to) AND (a.critter_id = ((ep.cr ->> 'critter_id'::text))::uuid))) AS wlh_id,
    bctw.get_species_name(( SELECT a.species
           FROM bctw.animal a
          WHERE (bctw.is_valid(a.valid_to) AND (a.critter_id = ((ep.cr ->> 'critter_id'::text))::uuid)))) AS species,
    (ep.cr ->> 'permission_type'::text) AS permission_type,
    ep.valid_to,
    ep.status,
    ep.was_denied_reason
   FROM expanded_permissions ep;


ALTER TABLE bctw_dapi_v1.permission_requests_v OWNER TO bctw;

--
-- Name: species_v; Type: VIEW; Schema: bctw_dapi_v1; Owner: bctw
--

CREATE VIEW bctw_dapi_v1.species_v AS
 SELECT species.species_code,
    species.species_eng_name,
    species.species_scientific_name,
    species.predator_species
   FROM bctw.species
  WHERE bctw.is_valid(species.valid_to);


ALTER TABLE bctw_dapi_v1.species_v OWNER TO bctw;

--
-- Name: user_animal_assignment_v; Type: VIEW; Schema: bctw_dapi_v1; Owner: bctw
--

CREATE VIEW bctw_dapi_v1.user_animal_assignment_v AS
 SELECT ua.user_id AS requested_for_id,
    ( SELECT "user".email
           FROM bctw."user"
          WHERE ("user".id = ua.user_id)) AS requested_for_email,
    ( SELECT a.animal_id
           FROM bctw.animal a
          WHERE ((a.critter_id = ua.critter_id) AND bctw.is_valid(a.valid_to))) AS animal_id,
    ( SELECT a.wlh_id
           FROM bctw.animal a
          WHERE ((a.critter_id = ua.critter_id) AND bctw.is_valid(a.valid_to))) AS wlh_id,
    ua.valid_from AS requested_at,
    ua.created_by_user_id AS requested_by_id,
    ( SELECT COALESCE("user".idir, "user".bceid) AS "coalesce"
           FROM bctw."user"
          WHERE ("user".id = ua.user_id)) AS requested_by,
    ua.permission_type
   FROM bctw.user_animal_assignment ua
  WHERE bctw.is_valid(ua.valid_to);


ALTER TABLE bctw_dapi_v1.user_animal_assignment_v OWNER TO bctw;

--
-- Name: VIEW user_animal_assignment_v; Type: COMMENT; Schema: bctw_dapi_v1; Owner: bctw
--

COMMENT ON VIEW bctw_dapi_v1.user_animal_assignment_v IS 'A bctw.user_animal_assignment table view for current user-critter assignments.';


--
-- Name: user_v; Type: VIEW; Schema: bctw_dapi_v1; Owner: bctw
--

CREATE VIEW bctw_dapi_v1.user_v AS
 SELECT u.id,
    u.domain,
    u.username,
    u.idir,
    u.bceid,
    u.firstname,
    u.lastname,
    u.email,
    u.phone,
    (urt.role_type)::text AS role_type,
    (EXISTS ( SELECT 1
           FROM bctw.animal
          WHERE (animal.owned_by_user_id = u.id))) AS is_owner,
    u.created_at,
    u.created_by_user_id,
    u.updated_at
   FROM ((bctw."user" u
     LEFT JOIN bctw.user_role_xref rx ON ((rx.user_id = u.id)))
     LEFT JOIN bctw.user_role_type urt ON ((urt.role_id = rx.role_id)))
  WHERE bctw.is_valid(u.valid_to);


ALTER TABLE bctw_dapi_v1.user_v OWNER TO bctw;

--
-- Name: vectronic_devices_without_keyx_entries; Type: VIEW; Schema: bctw_dapi_v1; Owner: bctw
--

CREATE VIEW bctw_dapi_v1.vectronic_devices_without_keyx_entries AS
 SELECT collar.collar_id,
    collar.collar_transaction_id,
    collar.camera_device_id,
    collar.device_id,
    collar.device_deployment_status,
    collar.device_make,
    collar.device_malfunction_type,
    collar.device_model,
    collar.device_status,
    collar.device_type,
    collar.dropoff_device_id,
    collar.dropoff_frequency,
    collar.dropoff_frequency_unit,
    collar.fix_interval,
    collar.fix_interval_rate,
    collar.frequency,
    collar.frequency_unit,
    collar.malfunction_date,
    collar.activation_comment,
    collar.first_activation_month,
    collar.first_activation_year,
    collar.retrieval_date,
    collar.retrieved,
    collar.satellite_network,
    collar.device_comment,
    collar.activation_status,
    collar.created_at,
    collar.created_by_user_id,
    collar.updated_at,
    collar.updated_by_user_id,
    collar.valid_from,
    collar.valid_to,
    collar.owned_by_user_id,
    collar.offline_date,
    collar.offline_type,
    collar.device_condition,
    collar.retrieval_comment,
    collar.malfunction_comment,
    collar.offline_comment,
    collar.mortality_mode,
    collar.mortality_period_hr,
    collar.dropoff_mechanism,
    collar.implant_device_id
   FROM bctw.collar
  WHERE ((collar.device_make = ( SELECT code.code_id
           FROM bctw.code
          WHERE ((code.code_description)::text = 'Vectronic'::text))) AND (NOT (collar.device_id IN ( SELECT api_vectronics_collar_data.idcollar
           FROM bctw.api_vectronics_collar_data))));


ALTER TABLE bctw_dapi_v1.vectronic_devices_without_keyx_entries OWNER TO bctw;
