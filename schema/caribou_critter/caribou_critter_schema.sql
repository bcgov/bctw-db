--------------------------------------------------------------------
-- Create collar table: caribou_critter
-- Possibly temporary and may be replace
--------------------------------------------------------------------

drop table if exists caribou_critter;

create table caribou_critter (
  region text,
  regional_contact text,
  regional_review text,
  regional_contact_comments text,
  project text,
  species text,
  caribou_ecotype text,
  caribou_population_unit text,
  management_area text,
  wlh_id text,
  animal_id text,
  sex text,
  life_stage text,
  calf_at_heel text,
  ear_tag_right text,
  ear_tag_left text,
  device_id integer,
  radio_frequency text,
  re_capture text,
  reg_key text,
  trans_location text,
  collar_type text,
  collar_make text,
  collar_model text,
  satellite_network text,
  capture_date text,
  capture_date_year text,
  capture_date_month text,
  capture_utm_zone text,
  capture_utm_easting text,
  capture_utm_northing text,
  release_date text,
  animal_status text,
  collar_status text,
  collar_status_details text,
  deactivated text,
  mortality_date text,
  malfunction_date text,
  retreival_date text,
  mortality_utm_zone text,
  mortality_utm_easting text,
  mortality_utm_northing text,
  max_transmission_date text
);

create index device_id_idx on caribou_critter (device_id);

comment on table caribou_critter is 'Caribou telemetry collar summary - Snapshot 02-2020';
