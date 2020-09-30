/* cross referencing table for assigning a collar device to a critter
  - assume a device can only be assigned to one critter at a time
*/

CREATE TABLE collar_assignment (
  device_assignment_id serial PRIMARY KEY,
  animal_id VARCHAR(20) REFERENCES animal(animal_id),
  collar_id INTEGER REFERENCES collar(device_id),
  effective_date DATE,
  end_date DATE
  deleted BOOLEAN
)

COMMENT ON TABLE collar_assignment IS 'A table that tracks devices assigned to a critters'
COMMENT ON COLUMN collar_assignment.device_id IS 'A foreign key for the collar device ID from the collar table'
COMMENT ON COLUMN collar_assignment.animal_id IS 'A foreign ey for the animal ID from the animal table'