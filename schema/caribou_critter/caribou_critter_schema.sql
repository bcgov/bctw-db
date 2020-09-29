--------------------------------------------------------------------
-- Create collar table: caribou_critter
-- Possibly temporary and may be replace
--------------------------------------------------------------------

drop table if exists caribou_critter;

create table caribou_critter (
  region VARCHAR(50),
  regional_contact VARCHAR(50),
  regional_review VARCHAR(50),
  regional_contact_comments VARCHAR(300),
  project VARCHAR(200),
  species VARCHAR(50),
  caribou_ecotype VARCHAR(70),
  caribou_population_unit VARCHAR(50),
  management_area VARCHAR(50),
  wlh_id VARCHAR(20),
  animal_id VARCHAR(20),
  sex VARCHAR(10),
  life_stage VARCHAR(10),
  calf_at_heel VARCHAR(10),
  ear_tag_right VARCHAR(50),
  ear_tag_left VARCHAR(50),
  device_id INTEGER, -- todo: primary key? some rows have null
  radio_frequency DOUBLE PRECISION,
  re_capture BOOLEAN,
  reg_key BOOLEAN,
  trans_location VARCHAR(10),
  collar_type VARCHAR(20),
  collar_make VARCHAR(50),
  collar_model VARCHAR(100),
  satellite_network VARCHAR(50),
  capture_date DATE, -- format DD-MM-YYYY
  capture_date_year INTEGER,
  capture_date_month INTEGER,
  capture_utm_zone INTEGER,
  capture_utm_easting INTEGER,
  capture_utm_northing INTEGER,
  release_date DATE, -- current format '15-Jan-19'
  animal_status VARCHAR(100),
  collar_status VARCHAR(50),
  collar_status_details VARCHAR(100),
  deactivated BOOLEAN,
  mortality_date DATE,
  malfunction_date DATE,
  retreival_date DATE,
  mortality_utm_zone INTEGER,
  mortality_utm_easting INTEGER,
  mortality_utm_northing INTEGER,
  max_transmission_date DATE
);

create index device_id_idx on caribou_critter (device_id);
create index collar_make_idx on caribou_critter (collar_make);

COMMENT ON TABLE caribou_critter IS 'Caribou telemetry collar summary - Snapshot 02-2020';
COMMENT ON COLUMN caribou_critter.caribou_population_unit IS 'Name of the caribou population (herd)'
COMMENT ON COLUMN caribou_critter.caribou_ecotype IS 'Ecotype which categorizes caribou populations (herds) based on ecological conditions and behavioral adaptations'
COMMENT ON COLUMN caribou_critter.capture_date IS 'Date animal was captured'
COMMENT ON COLUMN caribou_critter.re_capture IS 'Has the animal been recaptured?'
COMMENT ON COLUMN caribou_critter.wlh_id IS 'A unique identifier assigned to an individual, independent of possible changes in mark method used. This field is mandatory if there is telemetry data for the individual. Format "xx-xxxx" is a 2 digit code for the year the biological sample kit was created for the capture event, followed by the numberic idnetifier of that indiviudal (eg, 18-1384)'
COMMENT ON COLUMN caribou_critter.trans_location IS 'Identifies whether the animal is a translocation. TRUE = Animal is being captured for translocation and will be released at a new destination'
COMMENT ON COLUMN caribou_critter.radio_frequency IS 'VHF frequency of the collar'
COMMENT ON COLUMN caribou_critter.animal_id IS 'Primary key. An identifier assigned to the animal by the project coordinator, independent of possible changes in mark method used. This field is mandatory if there is telemetry data for the animal. Field often contains text and numbers.'