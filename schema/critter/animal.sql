
-- DROP TABLE IF EXISTS animal;

CREATE TABLE animal (
  animal_id VARCHAR(20) PRIMARY KEY, -- nulls in existing table
  animal_status VARCHAR(100),
  calf_at_heel VARCHAR(10),
  capture_date DATE, -- format DD-MM-YYYY
  capture_date_month INTEGER,
  capture_date_year INTEGER,
  capture_utm_zone INTEGER,
  capture_utm_easting INTEGER,
  capture_utm_northing INTEGER,
  ecotype VARCHAR(70), -- caribou_ecotype
  population_unit VARCHAR(50),
  ear_tag_left VARCHAR(50),
  ear_tag_right VARCHAR(50),
  life_stage VARCHAR(10),
  management_area VARCHAR(50),
  mortality_date DATE,
  mortality_utm_zone INTEGER,
  mortality_utm_easting INTEGER,
  mortality_utm_northing INTEGER,
  project VARCHAR(200),
  re_capture BOOLEAN,
  region VARCHAR(50),
  regional_contact VARCHAR(50),
  -- regional_review VARCHAR(50),
  -- regional_contact_comments VARCHAR(300),
  release_date DATE, -- current format '15-Jan-19'
  sex VARCHAR(10),
  species VARCHAR(50),
  trans_location BOOLEAN,
  wlh_id VARCHAR(20)
);

CREATE index animal_id_idx on animal (animal_id);

COMMENT ON TABLE animal IS '';
COMMENT ON COLUMN animal.population_unit IS 'Name of the caribou population (herd)'
COMMENT ON COLUMN animal.ecotype IS 'Ecotype which categorizes caribou populations (herds) based on ecological conditions and behavioral adaptations'
COMMENT ON COLUMN animal.capture_date IS 'Date animal was captured'
COMMENT ON COLUMN animal.re_capture IS 'Has the animal been recaptured?'
COMMENT ON COLUMN animal.wlh_id IS 'A unique identifier assigned to an individual, independent of possible changes in mark method used. This field is mandatory if there is telemetry data for the individual. Format "xx-xxxx" is a 2 digit code for the year the biological sample kit was created for the capture event, followed by the numberic idnetifier of that indiviudal (eg, 18-1384)'
COMMENT ON COLUMN animal.mortality_date IS 'Date animal died'
COMMENT ON COLUMN animal.regional_contact IS 'Name of project coordinator - VC: should be an IDIR (or the logged-in ID)'
COMMENT ON COLUMN animal.animal_id IS 'Primary key. An identifier assigned to the animal by the project coordinator, independent of possible changes in mark method used. This field is mandatory if there is telemetry data for the animal. Field often contains text and numbers.'
COMMENT ON COLUMN animal.release_date IS 'Date the animal was released following capture. Generally, an animal is captured, collared and released at the same location on the same date. However, translocated animals will have a capture date that differs from the release date, with the release date corresponding to release at the new destination, be it a hard release into caribou habitat or a soft release into a temporary holding pen.'
COMMENT ON COLUMN animal.sex IS 'Animal gender'
COMMENT ON COLUMN animal.trans_location IS 'Identifies whether the animal is a translocation. TRUE = Animal is being captured for translocation and will be released at a new destination'

