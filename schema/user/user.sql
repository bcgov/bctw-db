DROP TABLE IF EXISTS user;
DROP TABLE IF EXISTS user_role_type;
DROP TABLE IF EXISTS user_role_xref;
DROP TABLE IF EXISTS user_collar_access;

-- enabling uuid_generate functions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- note - may need to change this table name. user is technically a reserved word in psql
-- so referencing this table will require prepending schema name or referencing it in double quotes
-- idirs should be unique to the table?
CREATE TABLE bctw.user
(
  user_id     uuid PRIMARY key DEFAULT uuid_generate_v1(),
  idir        VARCHAR(50) UNIQUE,
  bceid       VARCHAR(50),
  email       VARCHAR(50),
  expire_date TIMESTAMP,
  deleted     BOOLEAN DEFAULT false,
  deleted_at  TIMESTAMP
);

/* todo: could possibly be moved into code table? */
CREATE TABLE bctw.user_role_type
(
  role_id     uuid PRIMARY key DEFAULT uuid_generate_v1(),
  role_type   VARCHAR(50),
  description VARCHAR(200)
);
COMMENT ON TABLE bctw.user_role_type is 'User Role Type is a code table for role types. Current role types are Administrator, Owner, Observer';

/*
*/
CREATE TABLE bctw.user_role_xref 
(
  user_id uuid REFERENCES bctw.user(user_id),
  role_id uuid REFERENCES bctw.user_role_type(role_id),
  PRIMARY KEY (user_id, role_id)
);
COMMENT ON TABLE bctw.user_role_xref is 'Table that associates a user with a role type. A user can have multiple roles';

/* 
*/
CREATE TYPE bctw.collar_access_type AS ENUM ('none', 'view', 'manage');
COMMENT ON TYPE bctw.collar_access_type IS 'Used in the user_collar_access table for defining how a user can interact with a collar.';

/* ****** user/collar relationship is being changed to user/critter
todo: deprecate this table?
*/
CREATE TABLE bctw.user_collar_access 
(
  user_id       uuid NOT NULL,
  collar_id     INTEGER NOT NULL,
  collar_access collar_access_type DEFAULT 'none',
  collar_vendor VARCHAR(50) NOT NULL,
  expire_date   TIMESTAMP,
  deleted       BOOLEAN DEFAULT false,
  deleted_at    TIMESTAMP,
  PRIMARY KEY (user_id, collar_id, collar_vendor)
);
COMMENT ON TABLE user_collar_access is 'User Collar Access is a table for associating a user with critter collars and the collar permissions';

/*
workflow for adding an animal -
  * user inputs animal data:
      - insert to animal table
      - row inserted to user_animal_assignment table.
  * user can then:
    * link the animal to an existing device 
    * or upload data for a new vectronics device
      - insert new data to to collar table
    * in either case:
      - insert to collar_animal_assignment table
*/

CREATE TABLE bctw.user_animal_assignment 
(
  user_id uuid REFERENCES bctw.user(user_id)
  animal_id VARCHAR(20) REFERENCES animal(animal_id),
  effective_date DATE, 
  end_date DATE
)
comment on table bctw.user_animal_assignment is '';

