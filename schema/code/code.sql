CREATE TABLE code (
  id serial PRIMARY KEY,
  code VARCHAR(10),
  description VARCHAR(100),
  code_type VARCHAR(40)
)

COMMENT ON TABLE code IS 'This is a look-up table for telemetry data' 
COMMENT ON COLUMN code.description IS 'The codes description'
COMMENT ON COLUMN code.type IS 'Code Type may not be needed, but is a way of separating codes ex. population unit'

/*
  INSERT INTO code VALUES (
    'A',
    'Animal is alive',
    'animal_status'
  )
*/

/* code types from critter data model
- animal_species
- animal_status
- region
- gender / animal_gender
- collar_type
- collar_status
- collar_make
- collar_deployment_status
- network_provider
(specific to species?)
- population_unit / caribou_population_unit 
- life_stage / caribou_life_stage
- ecotype / caribou_ecotype
- cah_status / caribou_cah_status

*/