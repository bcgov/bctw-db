
/*
  The collar data table. 
  rows are inserted to this table when a user registers/deregisters a collar?
*/

-- DROP TABLE IF EXISTS collar

CREATE TABLE collar (
  device_id INTEGER PRIMARY KEY,
  make VARCHAR(50),
  model VARCHAR(100),
  deployment_status VARCHAR(30),
  collar_status VARCHAR(50),
  -- collar_status_details VARCHAR(100),
  collar_type VARCHAR(20),
  deactivated BOOLEAN,
  radio_frequency DOUBLE PRECISION,
  malfunction_date DATE,
  max_transmission_date DATE,
  reg_key VARCHAR(30),
  retreival_date DATE,
  satellite_network VARCHAR(50),
)

CREATE index device_id_idx on collar (device_id);

COMMENT ON TABLE collar IS 'Device collar information table';
COMMENT ON COLUMN collar.collar_type IS 'The type of device/collar used to mark the animal.'
COMMENT ON COLUMN collar.device_id IS 'The numeric identifier (i.e. serial number) for the device/collar. Numeric field'
COMMENT ON COLUMN collar.deactivated IS 'Is the collar deactivated from the manufacturer?'
COMMENT ON COLUMN collar.make IS 'The manufacturer of the collar/device'
COMMENT ON COLUMN collar.max_transmission_date IS "Time of last transmission received from this animal's most recent collar (filtered by Mortality Date, Malfunction Date, Collar Retrieval Date)"
COMMENT ON COLUMN collar.radio_frequency IS 'VHF frequency of the collar'
COMMENT ON COLUMN collar.reg_key IS 'Vendor-supplied registration (access) key for the telemetry collar'
COMMENT ON COLUMN collar.retrieval_date IS 'Date collar/device retrieved from animal. Collar Retrieval Date= The earliest date in which the 1) the collar/device was removed from animal, 2) the collar/device was retrieved from the field, or 3) the date an animal with an existing collar/device was recaptured for translocation.' 
COMMENT ON COLUMN collar.satellite_network IS 'Satellite Network of GPS collar, Iridium or Globalstar. Globalstar collars ship ACTIVE from the manufacturing plant however, Iridium collars ship INACTIVE from the manufacturing plant and require the user to request activation'
